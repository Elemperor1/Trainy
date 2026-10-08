// Public /v1/japan/* operations. All timetable answers come from the published
// snapshot in KV; nothing here calls the upstream source except line-level
// disruption notices, which are short-cached and rate guarded.

import { loadWithCache } from "../cache";
import {
  ProxyFault,
  rejectUnknownQueryParameters,
  validatedLimit,
  validatedSearchQuery
} from "../contracts";
import { jsonResponse } from "../http";
import { dayClassOf, timestampAt } from "./calendar";
import type {
  JapanResponseMeta,
  LastRunRecord,
  ManifestLine,
  PublicDisruption,
  PublicLine,
  PublicStation,
  PublicStop,
  PublicTrip,
  PublicTripDetail,
  PublicTripMatch,
  SnapshotManifest,
  StationsShard,
  StoredStation,
  StoredStop,
  StoredTrip,
  TripShard
} from "./contracts";
import {
  JAPAN_PROVIDER_ID,
  operatorDisplayName,
  outOfCoverage,
  PUBLISHABLE_LICENSES,
  validatedLineID,
  validatedServiceDate,
  validatedStationID,
  validatedTimeOfDay,
  validatedTripID
} from "./contracts";
import { japanEnv } from "./env";
import { compact } from "./json";
import { fetchTrainInformation, ODPT_ATTRIBUTION, ODPT_SOURCE_NAME, parseRailwayList } from "./odpt";
import { SnapshotReader, SnapshotUnavailableError } from "./store";

export interface JapanRuntime {
  now: () => Date;
  fetcher: typeof fetch;
  cache: Cache;
}

/** A snapshot older than this is labeled stale; it still answers for its covered dates. */
export const SNAPSHOT_FRESH_MILLISECONDS = 36 * 3_600_000;
const DISRUPTIONS_KEY = "japan-disruptions-v1";
const DISRUPTIONS_FRESH_SECONDS = 60;
const DISRUPTIONS_STALE_SECONDS = 600;
const TRIP_PATH_PREFIX = "/v1/japan/trips/";

// ---------------------------------------------------------------------------
// Snapshot access
// ---------------------------------------------------------------------------

function snapshotUnavailable(): ProxyFault {
  return new ProxyFault(
    "snapshot_unavailable",
    "offline",
    503,
    "Japan timetable data is not available yet.",
    300
  );
}

async function reading<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    if (error instanceof SnapshotUnavailableError) {
      throw new ProxyFault(
        "snapshot_unavailable",
        "offline",
        503,
        "Japan timetable data is temporarily unavailable.",
        60
      );
    }
    throw error;
  }
}

async function loadSnapshot(
  env: Env,
  runtime: JapanRuntime
): Promise<{ reader: SnapshotReader; manifest: SnapshotManifest }> {
  // Declaring a licence that does not allow republishing switches serving off at
  // once, even while an older snapshot is still in storage.
  const { kv, license } = japanEnv(env);
  if (!kv || !PUBLISHABLE_LICENSES.has(license)) throw snapshotUnavailable();
  const reader = new SnapshotReader(kv, runtime.now);
  const manifest = await reading(() => reader.manifest());
  if (!manifest) throw snapshotUnavailable();
  return { reader, manifest };
}

function snapshotMeta(manifest: SnapshotManifest, now: Date): JapanResponseMeta {
  const expires = Date.parse(manifest.generatedAt) + SNAPSHOT_FRESH_MILLISECONDS;
  const fresh = now.getTime() < expires;
  return {
    provider: JAPAN_PROVIDER_ID,
    source: manifest.source.name,
    attribution: manifest.source.attribution,
    license: manifest.source.license,
    snapshotId: manifest.snapshotId,
    fetchedAt: manifest.generatedAt,
    expiresAt: new Date(expires).toISOString(),
    freshness: fresh ? "fresh" : "stale",
    cacheStatus: fresh ? "hit" : "stale-fallback",
    coverage: manifest.coverage
  };
}

function notFound(code: string, message: string): ProxyFault {
  return new ProxyFault(code, "notFound", 404, message);
}

function checkCoverage(manifest: SnapshotManifest, serviceDate: string): void {
  if (serviceDate < manifest.coverage.from || serviceDate > manifest.coverage.until) {
    throw outOfCoverage(manifest.coverage);
  }
}

function applicableCalendars(manifest: SnapshotManifest, serviceDate: string): string[] {
  const dayClass = dayClassOf(serviceDate);
  return Object.entries(manifest.calendars)
    .filter(([, rule]) => rule.kind === "days" ? rule.dayClasses.includes(dayClass) : rule.dates.includes(serviceDate))
    .map(([slug]) => slug)
    .sort();
}

/**
 * The calendars in force for each line on a date, by line slug. A calendar listed by explicit
 * dates is a special-day timetable: on those dates the trains a line has under it replace the
 * line's recurring service, and several special calendars on one date combine (the ODPT
 * specification's rule for Specific calendars). A line with no trains under a special calendar
 * keeps its recurring service.
 */
function calendarsInForce(manifest: SnapshotManifest, serviceDate: string): Map<string, ReadonlySet<string>> {
  const matching = applicableCalendars(manifest, serviceDate);
  const inForce = new Map<string, ReadonlySet<string>>();
  for (const line of manifest.lines) {
    const available = matching.filter((slug) => Object.hasOwn(line.shards, slug));
    const special = available.filter((slug) => manifest.calendars[slug]?.kind === "dates");
    inForce.set(line.slug, new Set(special.length > 0 ? special : available));
  }
  return inForce;
}

const stationIndexes = new WeakMap<StationsShard, Map<string, StoredStation>>();

function stationIndex(shard: StationsShard): Map<string, StoredStation> {
  let index = stationIndexes.get(shard);
  if (!index) {
    index = new Map(shard.stations.map((station) => [station.id, station]));
    stationIndexes.set(shard, index);
  }
  return index;
}

// ---------------------------------------------------------------------------
// Public shapes
// ---------------------------------------------------------------------------

function publicLine(line: ManifestLine): PublicLine {
  return compact({ id: line.id, name: line.name.ja, nameEn: line.name.en, operator: operatorDisplayName(line.operator) });
}

function publicStation(station: StoredStation, linesBySlug: Map<string, ManifestLine>): PublicStation {
  // A source that names the station's own line gets exactly that line; otherwise
  // the lines whose trips call here are the best the data supports.
  const slugs = station.railway === undefined ? station.lines : [station.railway];
  return compact({
    id: station.id,
    name: station.name.ja,
    nameEn: station.name.en,
    latitude: station.latitude,
    longitude: station.longitude,
    code: station.code,
    lineIds: slugs.flatMap((slug) => {
      const line = linesBySlug.get(slug);
      return line ? [line.id] : [];
    })
  });
}

function publicStop(
  shard: TripShard,
  stop: StoredStop,
  serviceDate: string,
  stations: Map<string, StoredStation>
): PublicStop {
  const [index, arrival, departure, platform] = stop;
  const stationId = shard.stations[index] ?? "";
  const station = stations.get(stationId);
  return compact({
    stationId,
    name: station?.name.ja ?? stationId,
    nameEn: station?.name.en,
    arrivalAt: arrival === null ? undefined : timestampAt(serviceDate, arrival),
    departureAt: departure === null ? undefined : timestampAt(serviceDate, departure),
    platform
  });
}

function publicTrip(
  manifest: SnapshotManifest,
  stations: Map<string, StoredStation>,
  shard: TripShard,
  trip: StoredTrip,
  serviceDate: string
): PublicTrip {
  const linesBySlug = new Map(manifest.lines.map((line) => [line.slug, line]));
  const first = trip.stops[0]!;
  const last = trip.stops[trip.stops.length - 1]!;
  return compact({
    id: trip.id,
    serviceDate,
    trainNumber: trip.trainNumber,
    trainName: trip.name?.ja,
    trainNameEn: trip.name?.en,
    category: trip.category,
    operator: operatorDisplayName(trip.operator),
    lines: trip.lines.flatMap((slug) => {
      const line = linesBySlug.get(slug);
      return line ? [publicLine(line)] : [];
    }),
    origin: publicStop(shard, [first[0], null, first[2] ?? first[1], first[3]], serviceDate, stations),
    destination: publicStop(shard, [last[0], last[1] ?? last[2], null, last[3]], serviceDate, stations)
  });
}

function fold(value: string): string {
  return value
    .normalize("NFKC")
    .normalize("NFD")
    .replace(/[̀-ͯ]/gu, "")
    .normalize("NFC")
    .toLocaleLowerCase("en")
    .replace(/[\s'’.\-・･]/gu, "");
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

export async function stationsResponse(
  url: URL,
  env: Env,
  runtime: JapanRuntime,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["query", "limit"]));
  const query = fold(validatedSearchQuery(url.searchParams.get("query")));
  const limit = validatedLimit(url.searchParams.get("limit"));
  const now = runtime.now();
  const { reader, manifest } = await loadSnapshot(env, runtime);
  const shard = await reading(() => reader.stations(manifest));
  const linesBySlug = new Map(manifest.lines.map((line) => [line.slug, line]));

  const ranked = shard.stations.flatMap((station) => {
    const names = [fold(station.name.ja), fold(station.name.en ?? ""), fold(station.code ?? "")].filter(Boolean);
    if (!names.some((name) => name.includes(query))) return [];
    const rank = names.some((name) => name === query) ? 0 : names.some((name) => name.startsWith(query)) ? 1 : 2;
    return [{ station, rank }];
  });
  ranked.sort((left, right) =>
    left.rank - right.rank
    || (left.station.name.en ?? left.station.name.ja).localeCompare(right.station.name.en ?? right.station.name.ja, "en")
    || left.station.id.localeCompare(right.station.id, "en")
  );

  const meta = snapshotMeta(manifest, now);
  return jsonResponse({
    data: { stations: ranked.slice(0, limit).map(({ station }) => publicStation(station, linesBySlug)) },
    meta,
    requestId: requestID
  }, 200, requestID, meta.cacheStatus);
}

interface TripMatch {
  shard: TripShard;
  trip: StoredTrip;
  fromStop: StoredStop;
  toStop: StoredStop;
}

function matchesInShard(
  shard: TripShard,
  from: string,
  to: string,
  serviceDate: string,
  after: number
): TripMatch[] {
  const fromIndex = shard.stations.indexOf(from);
  const toIndex = shard.stations.indexOf(to);
  if (fromIndex < 0 || toIndex < 0) return [];

  const matches: TripMatch[] = [];
  for (const trip of shard.trips) {
    if (trip.validUntil < serviceDate) continue;
    const boarding = trip.stops.findIndex((stop) => stop[0] === fromIndex && stop[2] !== null);
    if (boarding < 0) continue;
    const alighting = trip.stops.findIndex((stop, position) => position > boarding && stop[0] === toIndex && stop[1] !== null);
    if (alighting < 0) continue;
    const fromStop = trip.stops[boarding]!;
    if ((fromStop[2] as number) < after) continue;
    matches.push({ shard, trip, fromStop, toStop: trip.stops[alighting]! });
  }
  return matches;
}

export async function tripsResponse(
  url: URL,
  env: Env,
  runtime: JapanRuntime,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["from", "to", "date", "after", "limit"]));
  const from = validatedStationID(url.searchParams.get("from"));
  const to = validatedStationID(url.searchParams.get("to"));
  if (from === to) {
    throw new ProxyFault("invalid_station_pair", "invalidRequest", 400, "Choose two different stations.");
  }
  const limit = validatedLimit(url.searchParams.get("limit"), 10);
  const after = validatedTimeOfDay(url.searchParams.get("after"));
  const now = runtime.now();
  const serviceDate = validatedServiceDate(url.searchParams.get("date"), now);

  const { reader, manifest } = await loadSnapshot(env, runtime);
  checkCoverage(manifest, serviceDate);
  const stationsShard = await reading(() => reader.stations(manifest));
  const stations = stationIndex(stationsShard);
  const origin = stations.get(from);
  if (!origin || !stations.has(to)) throw notFound("station_not_found", "That station is not in the timetable.");

  const inForce = calendarsInForce(manifest, serviceDate);
  const shards = await reading(() => Promise.all(
    origin.lines.flatMap((lineSlug) => [...(inForce.get(lineSlug) ?? [])].map((calendarSlug) => reader.tripShard(manifest, lineSlug, calendarSlug)))
  ));

  const unique = new Map<string, TripMatch>();
  for (const shard of shards) {
    if (!shard) continue;
    for (const match of matchesInShard(shard, from, to, serviceDate, after)) {
      // A through train is stored on every line it runs on but belongs to its first line, so
      // that line's calendars decide whether it runs.
      if (!inForce.get(match.trip.lines[0] ?? "")?.has(shard.calendar)) continue;
      if (!unique.has(match.trip.id)) unique.set(match.trip.id, match);
    }
  }
  const trips: PublicTripMatch[] = [...unique.values()]
    .sort((left, right) =>
      (left.fromStop[2] as number) - (right.fromStop[2] as number)
      || (left.toStop[1] as number) - (right.toStop[1] as number)
      || left.trip.id.localeCompare(right.trip.id, "en")
    )
    .slice(0, limit)
    .map((match) => ({
      ...publicTrip(manifest, stations, match.shard, match.trip, serviceDate),
      from: publicStop(match.shard, [match.fromStop[0], null, match.fromStop[2], match.fromStop[3]], serviceDate, stations),
      to: publicStop(match.shard, [match.toStop[0], match.toStop[1], null, match.toStop[3]], serviceDate, stations)
    }));

  const meta = snapshotMeta(manifest, now);
  return jsonResponse({ data: { serviceDate, trips }, meta, requestId: requestID }, 200, requestID, meta.cacheStatus);
}

export function tripIDFromPath(pathname: string): string | null {
  if (!pathname.startsWith(TRIP_PATH_PREFIX)) return null;
  const encoded = pathname.slice(TRIP_PATH_PREFIX.length);
  try {
    return decodeURIComponent(encoded);
  } catch {
    return "";
  }
}

export async function tripResponse(
  tripID: string,
  url: URL,
  env: Env,
  runtime: JapanRuntime,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["date"]));
  const id = validatedTripID(tripID);
  const now = runtime.now();
  const serviceDate = validatedServiceDate(url.searchParams.get("date"), now);

  const { reader, manifest } = await loadSnapshot(env, runtime);
  checkCoverage(manifest, serviceDate);
  const [lineSlug, calendarSlug] = id.split("~");
  const entry = manifest.lines.find((line) => line.slug === lineSlug)?.shards[calendarSlug ?? ""];
  if (!lineSlug || !calendarSlug || !entry) throw notFound("trip_not_found", "That train is not in the timetable.");
  if (!calendarsInForce(manifest, serviceDate).get(lineSlug)?.has(calendarSlug)) {
    throw notFound("trip_not_running", "That train does not run on the requested date.");
  }

  const shard = await reading(() => reader.tripShard(manifest, lineSlug, calendarSlug));
  const trip = shard?.trips.find((candidate) => candidate.id === id);
  if (!shard || !trip) throw notFound("trip_not_found", "That train is not in the timetable.");
  if (trip.validUntil < serviceDate) throw notFound("trip_not_running", "That train does not run on the requested date.");

  const stationsShard = await reading(() => reader.stations(manifest));
  const stations = stationIndex(stationsShard);
  const detail: PublicTripDetail = {
    ...publicTrip(manifest, stations, shard, trip, serviceDate),
    stops: trip.stops.map((stop) => publicStop(shard, stop, serviceDate, stations))
  };
  const meta = snapshotMeta(manifest, now);
  return jsonResponse({ data: { trip: detail }, meta, requestId: requestID }, 200, requestID, meta.cacheStatus);
}

async function guardedOdptUpstream<T>(
  env: Env,
  token: string | undefined,
  load: (token: string) => Promise<T>
): Promise<T> {
  if (!token) {
    throw new ProxyFault(
      "missing_credential",
      "missingCredential",
      503,
      "Japan line status is not configured on the provider proxy."
    );
  }
  const allowance = await env.UPSTREAM_RATE_LIMITER.limit({ key: `${JAPAN_PROVIDER_ID}:odpt` });
  if (!allowance.success) {
    throw new ProxyFault("provider_budget_exhausted", "rateLimited", 429, "Japan line status is busy. Try again shortly.", 60);
  }
  return load(token);
}

function lineStatusUnavailable(): ProxyFault {
  return new ProxyFault("line_status_unavailable", "offline", 503, "Japan line status is not available yet.", 300);
}

/**
 * Line-level notices. They come straight from the operator feed through a short
 * cache and do not depend on a timetable snapshot, so line status can work even
 * when the source publishes no usable timetables. They obey the same licence
 * declaration as the timetable.
 */
export async function disruptionsResponse(
  url: URL,
  env: Env,
  context: ExecutionContext,
  runtime: JapanRuntime,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["line", "limit"]));
  const lineParameter = url.searchParams.get("line");
  const lineID = lineParameter === null ? null : validatedLineID(lineParameter);
  const limit = validatedLimit(url.searchParams.get("limit"), 10);
  const now = runtime.now();

  const config = japanEnv(env);
  if (!PUBLISHABLE_LICENSES.has(config.license)) throw lineStatusUnavailable();
  let railways: string[];
  try {
    railways = parseRailwayList(config.railways);
  } catch {
    throw lineStatusUnavailable();
  }
  if (lineID && !railways.includes(lineID)) {
    throw notFound("line_not_found", "That line is not covered by line status.");
  }

  const loaded = await loadWithCache<PublicDisruption[]>({
    cache: runtime.cache,
    key: DISRUPTIONS_KEY,
    now,
    freshSeconds: DISRUPTIONS_FRESH_SECONDS,
    staleSeconds: DISRUPTIONS_STALE_SECONDS,
    context,
    unavailableMessage: "Japan line status is temporarily unavailable.",
    load: () => guardedOdptUpstream(env, config.token, (token) =>
      fetchTrainInformation({ fetcher: runtime.fetcher, token }, railways, now)
    ),
    onLoadResult: () => undefined
  });

  const disruptions = loaded.envelope.value
    .filter((item) => !lineID || item.lineId === lineID)
    .slice(0, limit);
  return jsonResponse({
    data: { disruptions },
    meta: {
      provider: JAPAN_PROVIDER_ID,
      source: ODPT_SOURCE_NAME,
      attribution: ODPT_ATTRIBUTION,
      license: config.license,
      fetchedAt: loaded.envelope.fetchedAt,
      expiresAt: loaded.envelope.freshUntil,
      freshness: loaded.freshness,
      cacheStatus: loaded.cacheStatus
    },
    requestId: requestID
  }, 200, requestID, loaded.cacheStatus);
}

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

export interface JapanProviderHealth {
  id: typeof JAPAN_PROVIDER_ID;
  region: "JP";
  configured: boolean;
  status: "ok" | "stale" | "offline" | "missingCredential" | "unsupported" | "unknown";
  capabilities: string[];
  cache: { staticFeed: "fresh" | "stale" | "missing"; updatedAt: string | null };
  checkedAt: string | null;
  message: string;
}

export async function japanHealth(env: Env, runtime: Pick<JapanRuntime, "now">): Promise<JapanProviderHealth> {
  const config = japanEnv(env);
  const now = runtime.now();
  const licensed = PUBLISHABLE_LICENSES.has(config.license);
  let manifest: SnapshotManifest | null = null;
  let lastRun: LastRunRecord | null = null;
  if (config.kv && licensed) {
    const reader = new SnapshotReader(config.kv, runtime.now);
    manifest = await reader.manifest().catch(() => null);
    lastRun = await reader.lastRun();
  }
  const alerts = Boolean(config.token && licensed);
  const base: Pick<JapanProviderHealth, "id" | "region" | "configured" | "checkedAt"> = {
    id: JAPAN_PROVIDER_ID,
    region: "JP",
    configured: Boolean(config.kv && config.token && licensed),
    checkedAt: lastRun?.finishedAt ?? null
  };
  const withAlerts = (capabilities: string[]) => alerts ? [...capabilities, "serviceAlerts"] : capabilities;
  const none = { cache: { staticFeed: "missing" as const, updatedAt: null } };

  if (!config.kv) {
    return { ...base, ...none, capabilities: [], status: "unsupported", message: "Japan timetable data is not offered by this proxy." };
  }
  if (!licensed) {
    return {
      ...base,
      ...none,
      capabilities: [],
      status: "unsupported",
      message: "Japan data is off until a source licence that allows republishing is declared."
    };
  }

  if (manifest) {
    const fresh = now.getTime() - Date.parse(manifest.generatedAt) <= SNAPSHOT_FRESH_MILLISECONDS;
    const failedSince = lastRun !== null && lastRun.outcome !== "published"
      && Date.parse(lastRun.finishedAt) > Date.parse(manifest.generatedAt);
    return {
      ...base,
      status: fresh ? "ok" : "stale",
      capabilities: withAlerts(["stationSearch", "schedule"]),
      cache: { staticFeed: fresh ? "fresh" : "stale", updatedAt: manifest.generatedAt },
      message: (fresh
        ? `Timetable snapshot covers ${manifest.coverage.from} through ${manifest.coverage.until}.`
        : `The timetable snapshot is more than 36 hours old but still answers for ${manifest.coverage.from} through ${manifest.coverage.until}.`)
        + (failedSince ? " The latest refresh did not publish." : "")
        + (config.token ? "" : " Refreshing is not configured.")
    };
  }

  const waiting = { ...base, ...none, capabilities: withAlerts([]) };
  if (!config.token) return { ...waiting, status: "missingCredential", message: "Japan timetable ingestion is not configured." };
  switch (lastRun?.outcome) {
    case "license_blocked":
    case "no_data":
      return { ...waiting, status: "unsupported", message: "The source is publishing no usable timetable data." };
    case "upstream_failed":
    case "storage_failed":
    case "internal_error":
    case "too_many_rejected":
    case "regression":
      return { ...waiting, status: "offline", message: "The last timetable refresh failed and no snapshot is published." };
    default:
      return { ...waiting, status: "unknown", message: "Waiting for the first timetable snapshot." };
  }
}
