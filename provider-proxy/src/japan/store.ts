import type {
  BuiltSnapshot,
  LastRunRecord,
  SnapshotManifest,
  StationsShard,
  TripShard
} from "./contracts";
import { SNAPSHOT_SCHEMA } from "./contracts";
import { array, finiteNumber, record, text } from "./json";

// Layout in the JAPAN_DATA KV namespace. Shards live under their snapshot id and
// are never modified. Only the two manifest keys are ever overwritten, so a
// reader sees either the whole old snapshot or the whole new one.
const PREFIX = "japan/v1";
export const MANIFEST_KEY = `${PREFIX}/manifest`;
export const PREVIOUS_MANIFEST_KEY = `${PREFIX}/manifest-previous`;
export const LAST_RUN_KEY = `${PREFIX}/last-run`;

const MANIFEST_MEMO_MILLISECONDS = 30_000;
const MAX_MEMOIZED_SHARDS = 48;
const MANIFEST_EDGE_CACHE_SECONDS = 60;
const SHARD_EDGE_CACHE_SECONDS = 3_600;
const MIN_SHARD_LIFETIME_DAYS = 3;
const MAX_SHARD_LIFETIME_DAYS = 60;
const SHARD_GRACE_DAYS = 8;
const WRITE_CONCURRENCY = 8;
const LAST_RUN_LIFETIME_SECONDS = 30 * 86_400;

export function snapshotShardKey(snapshotId: string, name: string): string {
  return `${PREFIX}/snap/${snapshotId}/${name}`;
}

/** The stored snapshot is missing, unreadable, or not in the format this Worker writes. */
export class SnapshotUnavailableError extends Error {
  constructor(readonly key: string) {
    super("snapshot unavailable");
  }
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

export interface PublishDependencies {
  sleep: (milliseconds: number) => Promise<void>;
  now: () => Date;
  /** Wait between writing shards and flipping the manifest so KV can propagate them. */
  settleMilliseconds: number;
}

/**
 * Publish a built snapshot atomically from a reader's point of view.
 *
 * 1. Write every immutable shard (with an expiry as a storage backstop).
 * 2. Wait for the shards to propagate to other locations.
 * 3. Keep the current manifest as "previous", then point "current" at the new
 *    snapshot. This is the only step readers can observe.
 * 4. Best-effort delete the snapshot that just fell out of the two-snapshot
 *    window, unless it is still one of the two being served (an earlier run can
 *    fail between the two writes of step 3). Readers holding a slightly old
 *    manifest still find the previous snapshot's shards.
 *
 * Any failure before step 3 leaves the served snapshot untouched.
 */
export async function publishSnapshot(
  kv: KVNamespace,
  built: BuiltSnapshot,
  dependencies: PublishDependencies
): Promise<void> {
  const expirationTtl = shardLifetimeSeconds(built.manifest.coverage.until, dependencies.now());
  for (let index = 0; index < built.shards.length; index += WRITE_CONCURRENCY) {
    await Promise.all(
      built.shards.slice(index, index + WRITE_CONCURRENCY).map((shard) =>
        kv.put(shard.key, shard.body, { expirationTtl })
      )
    );
  }

  await dependencies.sleep(dependencies.settleMilliseconds);

  const current = await kv.get(MANIFEST_KEY);
  const previous = await kv.get(PREVIOUS_MANIFEST_KEY);
  if (current !== null) await kv.put(PREVIOUS_MANIFEST_KEY, current);
  await kv.put(MANIFEST_KEY, JSON.stringify(built.manifest));

  if (previous !== null) {
    try {
      const stale = parseManifest(JSON.parse(previous), PREVIOUS_MANIFEST_KEY);
      const serving = new Set([built.manifest.snapshotId]);
      if (current !== null) serving.add(parseManifest(JSON.parse(current), MANIFEST_KEY).snapshotId);
      if (!serving.has(stale.snapshotId)) await deleteSnapshotShards(kv, stale);
    } catch {
      // Expiry removes anything a failed cleanup leaves behind.
    }
  }
}

async function deleteSnapshotShards(kv: KVNamespace, manifest: SnapshotManifest): Promise<void> {
  const keys = [manifest.stationsKey, ...manifest.lines.flatMap((line) =>
    Object.values(line.shards).map((shard) => shard.key)
  )];
  await Promise.allSettled(keys.map((key) => kv.delete(key)));
}

/** Seconds a shard should live: through the coverage window plus a grace period. */
export function shardLifetimeSeconds(coverageUntil: string, now: Date): number {
  const untilMilliseconds = Date.parse(`${coverageUntil}T00:00:00+09:00`);
  const remainingDays = Number.isFinite(untilMilliseconds)
    ? Math.ceil((untilMilliseconds - now.getTime()) / 86_400_000)
    : 0;
  const days = Math.min(
    MAX_SHARD_LIFETIME_DAYS,
    Math.max(MIN_SHARD_LIFETIME_DAYS, remainingDays + SHARD_GRACE_DAYS)
  );
  return days * 86_400;
}

/** Reads the served manifest without the isolate memo, for the ingestion regression guard. */
export async function readManifestUncached(kv: KVNamespace): Promise<SnapshotManifest | null> {
  const raw = await kv.get(MANIFEST_KEY, "json");
  return raw === null ? null : parseManifest(raw, MANIFEST_KEY);
}

export async function writeLastRun(kv: KVNamespace, run: LastRunRecord): Promise<void> {
  await kv.put(LAST_RUN_KEY, JSON.stringify(run), { expirationTtl: LAST_RUN_LIFETIME_SECONDS });
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

interface Memo {
  manifest?: { value: SnapshotManifest | null; at: number };
  shards: Map<string, unknown>;
}

const memos = new WeakMap<object, Memo>();

function memoFor(kv: KVNamespace): Memo {
  let memo = memos.get(kv);
  if (!memo) {
    memo = { shards: new Map() };
    memos.set(kv, memo);
  }
  return memo;
}

/**
 * Reads the served snapshot. Manifests are re-read every 30 seconds; shards are
 * immutable and keyed by snapshot id, so a parsed shard is reused for as long as
 * its isolate lives. Both save KV reads and JSON parsing on the request path.
 */
export class SnapshotReader {
  constructor(
    private readonly kv: KVNamespace,
    private readonly now: () => Date
  ) {}

  async manifest(): Promise<SnapshotManifest | null> {
    const memo = memoFor(this.kv);
    const nowMilliseconds = this.now().getTime();
    if (memo.manifest && nowMilliseconds - memo.manifest.at < MANIFEST_MEMO_MILLISECONDS) {
      return memo.manifest.value;
    }
    const raw = await this.read(MANIFEST_KEY, MANIFEST_EDGE_CACHE_SECONDS);
    const value = raw === null ? null : parseManifest(raw, MANIFEST_KEY);
    memo.manifest = { value, at: nowMilliseconds };
    return value;
  }

  async stations(manifest: SnapshotManifest): Promise<StationsShard> {
    return this.shard(manifest.stationsKey, parseStationsShard);
  }

  async tripShard(manifest: SnapshotManifest, lineSlug: string, calendarSlug: string): Promise<TripShard | null> {
    const entry = manifest.lines.find((line) => line.slug === lineSlug)?.shards[calendarSlug];
    return entry ? this.shard(entry.key, parseTripShard) : null;
  }

  async lastRun(): Promise<LastRunRecord | null> {
    try {
      const raw = await this.read(LAST_RUN_KEY, MANIFEST_EDGE_CACHE_SECONDS);
      return raw === null ? null : parseLastRun(raw);
    } catch {
      return null;
    }
  }

  private async shard<T>(key: string, parse: (raw: unknown, key: string) => T): Promise<T> {
    const memo = memoFor(this.kv);
    if (memo.shards.has(key)) return memo.shards.get(key) as T;
    const raw = await this.read(key, SHARD_EDGE_CACHE_SECONDS);
    // A manifest that names a shard KV does not have is a failed or still
    // propagating publish, not an empty timetable.
    if (raw === null) throw new SnapshotUnavailableError(key);
    const value = parse(raw, key);
    if (memo.shards.size >= MAX_MEMOIZED_SHARDS) {
      const oldest = memo.shards.keys().next();
      if (!oldest.done) memo.shards.delete(oldest.value);
    }
    memo.shards.set(key, value);
    return value;
  }

  private async read(key: string, cacheTtl: number): Promise<unknown> {
    try {
      return await this.kv.get(key, { type: "json", cacheTtl });
    } catch {
      throw new SnapshotUnavailableError(key);
    }
  }
}

// ---------------------------------------------------------------------------
// Parsers: structural checks on what is read back, so that a truncated or
// foreign value becomes a retryable 503 instead of a crash deep in a route.
// ---------------------------------------------------------------------------

const SERVICE_DATE = /^\d{4}-\d{2}-\d{2}$/u;

function parseLocalizedName(value: unknown, key: string): { ja: string; en?: string } {
  const name = record(value);
  const ja = text(name?.ja, 200);
  if (!name || !ja) throw new SnapshotUnavailableError(key);
  const en = name.en === undefined ? undefined : text(name.en, 200);
  if (name.en !== undefined && en === undefined) throw new SnapshotUnavailableError(key);
  return en === undefined ? { ja } : { ja, en };
}

export function parseManifest(raw: unknown, key: string): SnapshotManifest {
  const manifest = record(raw);
  const source = record(manifest?.source);
  const coverage = record(manifest?.coverage);
  const counts = record(manifest?.counts);
  if (
    !manifest || manifest.schema !== SNAPSHOT_SCHEMA
    || !text(manifest.snapshotId, 80)
    || !text(manifest.generatedAt, 40) || !Number.isFinite(Date.parse(String(manifest.generatedAt)))
    || !source || !text(source.id, 40) || !text(source.name, 200) || !text(source.attribution, 400) || !text(source.license, 80)
    || !coverage || !SERVICE_DATE.test(String(coverage.from)) || !SERVICE_DATE.test(String(coverage.until))
    || !text(manifest.stationsKey, 512)
    || !Array.isArray(manifest.lines)
    || !record(manifest.calendars)
    || !counts
    || finiteNumber(counts.trips) === undefined || finiteNumber(counts.stations) === undefined || finiteNumber(counts.lines) === undefined
  ) throw new SnapshotUnavailableError(key);

  for (const entry of manifest.lines) {
    const line = record(entry);
    if (!line || !text(line.id, 160) || !text(line.slug, 80) || !text(line.operator, 160) || !record(line.shards)) {
      throw new SnapshotUnavailableError(key);
    }
    parseLocalizedName(line.name, key);
    for (const shard of Object.values(line.shards as Record<string, unknown>)) {
      const shardRecord = record(shard);
      if (!shardRecord || !text(shardRecord.key, 512)) throw new SnapshotUnavailableError(key);
    }
  }
  for (const rule of Object.values(manifest.calendars as Record<string, unknown>)) {
    const calendar = record(rule);
    const valid = calendar?.kind === "days"
      ? Array.isArray(calendar.dayClasses)
      : calendar?.kind === "dates" && Array.isArray(calendar.dates);
    if (!valid) throw new SnapshotUnavailableError(key);
  }
  return manifest as unknown as SnapshotManifest;
}

function parseStationsShard(raw: unknown, key: string): StationsShard {
  const shard = record(raw);
  if (!shard || shard.schema !== SNAPSHOT_SCHEMA || !Array.isArray(shard.stations)) throw new SnapshotUnavailableError(key);
  for (const entry of shard.stations) {
    const station = record(entry);
    if (
      !station || !text(station.id, 160) || !Array.isArray(station.lines)
      || (station.railway !== undefined && !text(station.railway, 80))
    ) throw new SnapshotUnavailableError(key);
    parseLocalizedName(station.name, key);
  }
  return shard as unknown as StationsShard;
}

function parseTripShard(raw: unknown, key: string): TripShard {
  const shard = record(raw);
  if (
    !shard || shard.schema !== SNAPSHOT_SCHEMA
    || !text(shard.line, 80) || !text(shard.calendar, 80)
    || !Array.isArray(shard.stations) || !Array.isArray(shard.trips)
  ) throw new SnapshotUnavailableError(key);
  const stationCount = shard.stations.length;
  for (const entry of shard.trips) {
    const trip = record(entry);
    if (
      !trip || !text(trip.id, 200) || !text(trip.trainNumber, 40) || !text(trip.operator, 160)
      || !Array.isArray(trip.lines) || trip.lines.length === 0
      || !SERVICE_DATE.test(String(trip.validUntil))
      || !Array.isArray(trip.stops) || trip.stops.length < 2
    ) throw new SnapshotUnavailableError(key);
    for (const stop of trip.stops) {
      const fields = array(stop);
      const index = fields[0];
      if (
        fields.length < 3 || !Number.isInteger(index) || (index as number) < 0 || (index as number) >= stationCount
        || (fields[1] !== null && finiteNumber(fields[1]) === undefined)
        || (fields[2] !== null && finiteNumber(fields[2]) === undefined)
      ) throw new SnapshotUnavailableError(key);
    }
  }
  return shard as unknown as TripShard;
}

function parseLastRun(raw: unknown): LastRunRecord | null {
  const run = record(raw);
  if (!run || !text(run.outcome, 40) || !text(run.finishedAt, 40) || !text(run.startedAt, 40)) return null;
  return run as unknown as LastRunRecord;
}
