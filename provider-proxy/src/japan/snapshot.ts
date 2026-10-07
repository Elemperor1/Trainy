import { addDays, currentServiceDate, isSupportedServiceDate } from "./calendar";
import type {
  BuiltSnapshot,
  CalendarRule,
  LocalizedName,
  ManifestLine,
  SourceInfo,
  StoredStation,
  StoredStop,
  StoredTrip,
  TripShard
} from "./contracts";
import { IngestFailure, SNAPSHOT_SCHEMA } from "./contracts";
import { snapshotShardKey } from "./store";

// ---------------------------------------------------------------------------
// The source-neutral feed every adapter produces. Nothing here is ODPT-specific.
// ---------------------------------------------------------------------------

export interface FeedStation {
  id: string;
  name: LocalizedName;
  latitude?: number;
  longitude?: number;
  code?: string;
  /** The line the source says this station belongs to; narrows the lines shown for it. */
  railway?: string;
}

export interface FeedLine {
  id: string;
  name: LocalizedName;
  operator: string;
}

export interface FeedStop {
  stationId: string;
  /** Minutes since the service date began; may pass 1,440 after midnight. */
  arrival?: number;
  departure?: number;
  platform?: string;
}

export interface FeedTrip {
  /** The source's own identifier; used only to keep ordering deterministic. */
  sourceId: string;
  trainNumber: string;
  name?: LocalizedName;
  category?: string;
  operator: string;
  /** Every line the trip runs on, in travel order. */
  lineIds: string[];
  calendar: string;
  /** Last service date the source declares the trip valid for, when it says. */
  validUntil?: string;
  stops: FeedStop[];
}

export interface NormalizedFeed {
  source: SourceInfo;
  lines: FeedLine[];
  stations: FeedStation[];
  trips: FeedTrip[];
  /** Calendar rules keyed by the source's calendar id. */
  calendars: Record<string, CalendarRule>;
}

/** When a source does not say how long a trip is valid, claim only this many days. */
export const DEFAULT_HORIZON_DAYS = 14;
const MAX_HORIZON_DAYS = 400;
const MAX_SHARD_BYTES = 20 * 1_024 * 1_024;
const MAX_EXPLICIT_DATES = 400;

/** A URL-safe, bounded fragment of a source id: the part after "scheme:". */
export function slugOf(id: string, maximumCharacters: number): string {
  const local = id.includes(":") ? id.slice(id.indexOf(":") + 1) : id;
  const slug = local
    .replace(/[^A-Za-z0-9._-]+/gu, "_")
    .replace(/^[_.-]+|[_.-]+$/gu, "")
    .slice(0, maximumCharacters);
  return slug || "x";
}

function uniqueSlugs(ids: string[], maximumCharacters: number): Map<string, string> {
  const slugs = new Map<string, string>();
  const taken = new Set<string>();
  for (const id of [...ids].sort()) {
    const base = slugOf(id, maximumCharacters);
    let candidate = base;
    for (let suffix = 2; taken.has(candidate); suffix += 1) {
      candidate = `${base.slice(0, Math.max(1, maximumCharacters - 4))}-${suffix}`;
    }
    taken.add(candidate);
    slugs.set(id, candidate);
  }
  return slugs;
}

function firstDeparture(trip: FeedTrip): number {
  const first = trip.stops[0];
  return first?.departure ?? first?.arrival ?? 0;
}

function compareText(left: string, right: string): number {
  return left < right ? -1 : left > right ? 1 : 0;
}

function sanitizedCalendar(rule: CalendarRule): CalendarRule | null {
  if (rule.kind === "days") {
    return rule.dayClasses.length > 0 ? { kind: "days", dayClasses: [...new Set(rule.dayClasses)].sort() } : null;
  }
  const dates = [...new Set(rule.dates.filter(isSupportedServiceDate))].sort().slice(0, MAX_EXPLICIT_DATES);
  return dates.length > 0 ? { kind: "dates", dates } : null;
}

/**
 * Turn a normalized feed into immutable shards plus a manifest.
 *
 * Trips are sharded by (line, calendar): a request for one day reads only the
 * shards of the lines serving the boarding station and the calendars that apply
 * that day. A trip that runs on several lines is written into every one of them.
 */
export function buildSnapshot(
  feed: NormalizedFeed,
  options: { snapshotId: string; generatedAt: Date }
): BuiltSnapshot {
  const coverageFrom = currentServiceDate(options.generatedAt);
  const defaultUntil = addDays(coverageFrom, DEFAULT_HORIZON_DAYS);
  const maxUntil = addDays(coverageFrom, MAX_HORIZON_DAYS);

  const lineSlugs = uniqueSlugs(feed.lines.map((line) => line.id), 60);
  const calendarRules = new Map<string, CalendarRule>();
  for (const [id, rule] of Object.entries(feed.calendars)) {
    const clean = sanitizedCalendar(rule);
    if (clean) calendarRules.set(id, clean);
  }
  const calendarSlugs = uniqueSlugs([...calendarRules.keys()], 40);
  const stationsById = new Map(feed.stations.map((station) => [station.id, station]));

  interface Kept {
    trip: FeedTrip;
    validUntil: string;
    lineSlugs: string[];
    calendarSlug: string;
  }
  const kept: Kept[] = [];
  let expiredTrips = 0;
  for (const trip of feed.trips) {
    const slugsForTrip = trip.lineIds.map((id) => lineSlugs.get(id));
    const calendarSlug = calendarSlugs.get(trip.calendar);
    if (
      calendarSlug === undefined
      || trip.lineIds.length === 0
      || slugsForTrip.some((slug) => slug === undefined)
      || trip.stops.length < 2
      || trip.stops.some((stop) => !stationsById.has(stop.stationId))
    ) continue;

    const declared = trip.validUntil !== undefined && isSupportedServiceDate(trip.validUntil)
      ? trip.validUntil
      : defaultUntil;
    if (declared < coverageFrom) {
      expiredTrips += 1;
      continue;
    }
    kept.push({
      trip,
      validUntil: declared > maxUntil ? maxUntil : declared,
      lineSlugs: [...new Set(slugsForTrip as string[])],
      calendarSlug
    });
  }
  if (kept.length === 0) throw new IngestFailure("no_data", "no_current_trips");

  kept.sort((left, right) =>
    compareText(left.lineSlugs[0]!, right.lineSlugs[0]!)
    || compareText(left.calendarSlug, right.calendarSlug)
    || firstDeparture(left.trip) - firstDeparture(right.trip)
    || compareText(left.trip.trainNumber, right.trip.trainNumber)
    || compareText(left.trip.sourceId, right.trip.sourceId)
  );

  // Trip ids are "<line>~<calendar>~<train>". They name the primary line and
  // calendar so the detail route can find the shard from the id alone.
  const usedIds = new Set<string>();
  const shards = new Map<string, { lineSlug: string; calendarSlug: string; stations: string[]; index: Map<string, number>; trips: StoredTrip[] }>();
  const stationLines = new Map<string, Set<string>>();
  const usedCalendars = new Set<string>();

  for (const entry of kept) {
    const base = `${entry.lineSlugs[0]}~${entry.calendarSlug}~${slugOf(entry.trip.trainNumber, 40)}`;
    let id = base;
    for (let suffix = 2; usedIds.has(id); suffix += 1) id = `${base}-${suffix}`;
    usedIds.add(id);
    usedCalendars.add(entry.calendarSlug);

    for (const lineSlug of entry.lineSlugs) {
      const shardName = `${lineSlug}~${entry.calendarSlug}`;
      let shard = shards.get(shardName);
      if (!shard) {
        shard = { lineSlug, calendarSlug: entry.calendarSlug, stations: [], index: new Map(), trips: [] };
        shards.set(shardName, shard);
      }
      const stops: StoredStop[] = entry.trip.stops.map((stop) => {
        let position = shard!.index.get(stop.stationId);
        if (position === undefined) {
          position = shard!.stations.length;
          shard!.stations.push(stop.stationId);
          shard!.index.set(stop.stationId, position);
        }
        return stop.platform === undefined
          ? [position, stop.arrival ?? null, stop.departure ?? null]
          : [position, stop.arrival ?? null, stop.departure ?? null, stop.platform];
      });
      const stored: StoredTrip = {
        id,
        trainNumber: entry.trip.trainNumber,
        operator: entry.trip.operator,
        lines: entry.lineSlugs,
        validUntil: entry.validUntil,
        stops
      };
      if (entry.trip.name) stored.name = entry.trip.name;
      if (entry.trip.category) stored.category = entry.trip.category;
      shard.trips.push(stored);
    }
    for (const stop of entry.trip.stops) {
      let linesAtStation = stationLines.get(stop.stationId);
      if (!linesAtStation) {
        linesAtStation = new Set();
        stationLines.set(stop.stationId, linesAtStation);
      }
      for (const lineSlug of entry.lineSlugs) linesAtStation.add(lineSlug);
    }
  }

  const stationsKey = snapshotShardKey(options.snapshotId, "stations");
  const storedStations: StoredStation[] = [...stationLines.keys()].sort().map((stationId) => {
    const station = stationsById.get(stationId)!;
    const stored: StoredStation = {
      id: station.id,
      name: station.name,
      lines: [...stationLines.get(stationId)!].sort()
    };
    if (station.latitude !== undefined && station.longitude !== undefined) {
      stored.latitude = station.latitude;
      stored.longitude = station.longitude;
    }
    if (station.code) stored.code = station.code;
    const ownLine = station.railway === undefined ? undefined : lineSlugs.get(station.railway);
    if (ownLine !== undefined) stored.railway = ownLine;
    return stored;
  });

  const builtShards: BuiltSnapshot["shards"] = [{
    key: stationsKey,
    body: JSON.stringify({ schema: SNAPSHOT_SCHEMA, stations: storedStations })
  }];
  const manifestLines: ManifestLine[] = [];
  for (const line of [...feed.lines].sort((left, right) => compareText(left.id, right.id))) {
    const lineSlug = lineSlugs.get(line.id)!;
    const lineShards: ManifestLine["shards"] = {};
    for (const shard of [...shards.values()].filter((candidate) => candidate.lineSlug === lineSlug)) {
      const key = snapshotShardKey(options.snapshotId, `${shard.lineSlug}~${shard.calendarSlug}`);
      const body: TripShard = {
        schema: SNAPSHOT_SCHEMA,
        line: shard.lineSlug,
        calendar: shard.calendarSlug,
        stations: shard.stations,
        trips: shard.trips
      };
      builtShards.push({ key, body: JSON.stringify(body) });
      lineShards[shard.calendarSlug] = { key, trips: shard.trips.length };
    }
    if (Object.keys(lineShards).length > 0) {
      manifestLines.push({ id: line.id, slug: lineSlug, name: line.name, operator: line.operator, shards: lineShards });
    }
  }
  for (const shard of builtShards) {
    if (new TextEncoder().encode(shard.body).byteLength > MAX_SHARD_BYTES) {
      throw new IngestFailure("storage_failed", "shard_too_large");
    }
  }

  const calendars: Record<string, CalendarRule> = {};
  for (const [id, rule] of calendarRules) {
    const slug = calendarSlugs.get(id)!;
    if (usedCalendars.has(slug)) calendars[slug] = rule;
  }
  const coverageUntil = kept.reduce((latest, entry) => entry.validUntil > latest ? entry.validUntil : latest, coverageFrom);

  return {
    manifest: {
      schema: SNAPSHOT_SCHEMA,
      snapshotId: options.snapshotId,
      generatedAt: options.generatedAt.toISOString(),
      source: feed.source,
      coverage: { from: coverageFrom, until: coverageUntil },
      stationsKey,
      lines: manifestLines,
      calendars,
      counts: { stations: storedStations.length, lines: manifestLines.length, trips: kept.length }
    },
    shards: builtShards,
    expiredTrips
  };
}
