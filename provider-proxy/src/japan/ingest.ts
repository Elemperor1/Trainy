// Scheduled ingestion: fetch, validate, build, and publish a Japan timetable snapshot.
//
// A run either publishes a complete new snapshot or changes nothing a rider can
// see. Every outcome is recorded (KV "last-run" and one structured log event),
// and none of them carries an upstream URL, response body, or the credential.

import { ProxyFault } from "../contracts";
import type { IngestOutcome, LastRunRecord, ManifestLine, RailwayReport, SnapshotManifest, SourceInfo } from "./contracts";
import { IngestFailure, PUBLISHABLE_LICENSES, REFUSED_LICENSES } from "./contracts";
import { japanEnv } from "./env";
import {
  fetchOdptFeed,
  ODPT_ATTRIBUTION,
  ODPT_SOURCE_ID,
  ODPT_SOURCE_NAME,
  parseRailwayList
} from "./odpt";
import { buildSnapshot } from "./snapshot";
import { publishSnapshot, readManifestUncached, writeLastRun } from "./store";

/** Fewer trips than this is treated as "the source has no timetable", not a small timetable. */
export const MIN_TRIPS = 10;
/** More than this share of fetched timetables failing validation fails the run. */
export const MAX_REJECTED_RATIO = 0.25;
/** A run that would shrink the served trip count below this share is held back. */
export const MIN_RETAINED_RATIO = 0.5;
/** KV is eventually consistent, so wait before pointing readers at new shards. */
export const DEFAULT_SETTLE_MILLISECONDS = 65_000;

export interface IngestDependencies {
  fetcher: typeof fetch;
  now: () => Date;
  sleep: (milliseconds: number) => Promise<void>;
  log: (record: Record<string, string | number>) => void;
  settleMilliseconds: number;
  snapshotId: (now: Date) => string;
}

export interface IngestReport extends LastRunRecord {
  durationMilliseconds: number;
}

function defaultSnapshotId(now: Date): string {
  const stamp = now.toISOString().replace(/[-:]/gu, "").replace(/\.\d+Z$/u, "Z");
  const random = [...crypto.getRandomValues(new Uint8Array(3))]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `${stamp}-${random}`;
}

function defaults(): IngestDependencies {
  return {
    fetcher: fetch,
    now: () => new Date(),
    sleep: (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
    log: (record) => console.log(JSON.stringify(record)),
    settleMilliseconds: DEFAULT_SETTLE_MILLISECONDS,
    snapshotId: defaultSnapshotId
  };
}

function flattenRejections(railways: RailwayReport[]): number {
  return railways.reduce(
    (total, report) => total + Object.values(report.rejected).reduce((sum, count) => sum + count, 0),
    0
  );
}

function tripsOnLine(line: ManifestLine): number {
  return Object.values(line.shards).reduce((total, shard) => total + shard.trips, 0);
}

/**
 * True when a line the run was asked to fetch, and that the served snapshot carried with a real
 * timetable, would lose more than the allowed share of its trips. The total-only check lets a
 * whole railway vanish from a large snapshot; a railway removed from the configuration is not
 * in `configured`, so dropping it on purpose is never held back.
 */
function lostConfiguredLine(served: SnapshotManifest, next: SnapshotManifest, configured: ReadonlySet<string>): boolean {
  const nextTrips = new Map(next.lines.map((line) => [line.id, tripsOnLine(line)]));
  return served.lines.some((line) => {
    if (!configured.has(line.id)) return false;
    const before = tripsOnLine(line);
    return before >= MIN_TRIPS && (nextTrips.get(line.id) ?? 0) < before * MIN_RETAINED_RATIO;
  });
}

export async function runIngest(env: Env, overrides: Partial<IngestDependencies> = {}): Promise<IngestReport> {
  const dependencies: IngestDependencies = { ...defaults(), ...overrides };
  const config = japanEnv(env);
  const startedAt = dependencies.now();
  const progress: { railways?: RailwayReport[]; counts?: LastRunRecord["counts"]; snapshotId?: string } = {};
  let outcome: IngestOutcome = "published";
  let code: string | undefined;

  try {
    if (!config.kv) throw new IngestFailure("not_configured", "storage_not_bound");
    if (!config.token) throw new IngestFailure("not_configured", "credential_missing");
    if (REFUSED_LICENSES.has(config.license)) throw new IngestFailure("license_blocked", "license_not_permitted");
    if (!PUBLISHABLE_LICENSES.has(config.license)) {
      throw new IngestFailure("license_blocked", config.license ? "license_unrecognized" : "license_not_declared");
    }
    let railways: string[];
    try {
      railways = parseRailwayList(config.railways);
    } catch {
      throw new IngestFailure("not_configured", "invalid_railway_list");
    }

    const fetched = await fetchOdptFeed({ fetcher: dependencies.fetcher, token: config.token }, railways);
    progress.railways = fetched.reports;
    const rejected = flattenRejections(fetched.reports);
    progress.counts = {
      stations: fetched.feed.stations.length,
      lines: fetched.feed.lines.length,
      trips: fetched.feed.trips.length,
      rejected
    };
    if (fetched.timetables > 0 && rejected / fetched.timetables > MAX_REJECTED_RATIO) {
      throw new IngestFailure("too_many_rejected", "rejected_ratio");
    }
    if (fetched.feed.trips.length < MIN_TRIPS) throw new IngestFailure("no_data", "insufficient_trips");

    const source: SourceInfo = {
      id: ODPT_SOURCE_ID,
      name: ODPT_SOURCE_NAME,
      attribution: ODPT_ATTRIBUTION,
      license: config.license
    };
    const snapshotId = dependencies.snapshotId(startedAt);
    const built = buildSnapshot({ source, ...fetched.feed }, { snapshotId, generatedAt: startedAt });
    progress.snapshotId = snapshotId;
    progress.counts = { ...built.manifest.counts, rejected };
    // Building drops expired trips and trips that name an unknown station, line or calendar, so
    // the minimum has to hold for what the snapshot would actually serve.
    if (built.manifest.counts.trips < MIN_TRIPS) throw new IngestFailure("no_data", "insufficient_trips");

    let current: SnapshotManifest | null;
    try {
      current = await readManifestUncached(config.kv);
    } catch {
      // The served snapshot may be healthy. Without its trip count the guard below cannot run,
      // so publishing could replace a large snapshot with a small one.
      throw new IngestFailure("storage_failed", "manifest_read_failed");
    }
    if (current && built.manifest.counts.trips < current.counts.trips * MIN_RETAINED_RATIO) {
      throw new IngestFailure("regression", "trip_count_dropped");
    }
    if (current && lostConfiguredLine(current, built.manifest, new Set(fetched.feed.lines.map((line) => line.id)))) {
      throw new IngestFailure("regression", "line_trip_count_dropped");
    }

    try {
      await publishSnapshot(config.kv, built, {
        sleep: dependencies.sleep,
        now: dependencies.now,
        settleMilliseconds: dependencies.settleMilliseconds
      });
    } catch {
      throw new IngestFailure("storage_failed", "publish_failed");
    }
  } catch (error) {
    if (error instanceof IngestFailure) {
      outcome = error.outcome;
      code = error.code;
    } else if (error instanceof ProxyFault) {
      outcome = "upstream_failed";
      code = error.code;
    } else {
      outcome = "internal_error";
      code = "unexpected";
    }
  }

  const finishedAt = dependencies.now();
  const report: IngestReport = {
    outcome,
    ...(code ? { code } : {}),
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    ...(outcome === "published" && progress.snapshotId ? { snapshotId: progress.snapshotId } : {}),
    ...(progress.counts ? { counts: progress.counts } : {}),
    ...(progress.railways ? { railways: progress.railways } : {}),
    durationMilliseconds: finishedAt.getTime() - startedAt.getTime()
  };

  if (config.kv) {
    const { durationMilliseconds: _, ...stored } = report;
    await writeLastRun(config.kv, stored).catch(() => undefined);
  }
  logReport(dependencies, report);
  return report;
}

function logReport(dependencies: IngestDependencies, report: IngestReport): void {
  dependencies.log({
    event: "japan_ingest",
    outcome: report.outcome,
    code: report.code ?? "none",
    duration: report.durationMilliseconds,
    trips: report.counts?.trips ?? 0,
    stations: report.counts?.stations ?? 0,
    lines: report.counts?.lines ?? 0,
    rejected: report.counts?.rejected ?? 0
  });
  // One line per railway answers "did the source have this line at all?".
  for (const railway of report.railways ?? []) {
    dependencies.log({
      event: "japan_ingest_railway",
      railway: railway.railway,
      found: railway.railwayFound ? 1 : 0,
      stations: railway.stations,
      timetables: railway.timetables,
      trips: railway.trips,
      rejected: Object.values(railway.rejected).reduce((sum, count) => sum + count, 0)
    });
  }
}

/** The Cron Trigger entry point: never throws, always leaves a record. */
export async function runScheduledIngest(env: Env): Promise<void> {
  try {
    await runIngest(env);
  } catch {
    console.log(JSON.stringify({ event: "japan_ingest", outcome: "internal_error", code: "unexpected" }));
  }
}
