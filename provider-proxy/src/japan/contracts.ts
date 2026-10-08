import { ProxyFault } from "../contracts";
import type { DayClass } from "./calendar";
import { currentServiceDate, isSupportedServiceDate, parseClockMinutes } from "./calendar";

export const JAPAN_PROVIDER_ID = "japan";
export const SNAPSHOT_SCHEMA = 1;
/** The furthest ahead, in days, that a snapshot may claim to cover. Storage keeps its shards at least this long. */
export const MAX_COVERAGE_DAYS = 400;

/** Sources whose licence allows Trainy to republish normalized data in a paid app. */
export const PUBLISHABLE_LICENSES: ReadonlySet<string> = new Set([
  "odpt-basic",
  "commercial-agreement",
  "cc-by-4.0"
]);

/** Licences the Worker refuses by name, with the reason surfaced in ingest reports. */
export const REFUSED_LICENSES: ReadonlyMap<string, string> = new Map([
  ["odpt-challenge", "The ODPT Challenge Limited License forbids republishing data to third parties."]
]);

export interface LocalizedName {
  ja: string;
  en?: string;
}

export interface SourceInfo {
  id: string;
  name: string;
  attribution: string;
  license: string;
}

/**
 * Which service dates a calendar covers: by day class, or an explicit date list. A `days` calendar
 * is a line's regular service. A `dates` calendar is a special-day timetable: on its dates, the
 * trains a line has under it replace that line's regular trains. A source that runs extra trains on
 * a special day must therefore list the regular trains under the same calendar.
 */
export type CalendarRule =
  | { kind: "days"; dayClasses: DayClass[] }
  | { kind: "dates"; dates: string[] };

// ---------------------------------------------------------------------------
// Stored snapshot format (schema 1). Written by ingestion, read by the routes.
// ---------------------------------------------------------------------------

export interface ManifestLine {
  id: string;
  slug: string;
  name: LocalizedName;
  operator: string;
  /** Trip shard key by calendar slug. */
  shards: Record<string, { key: string; trips: number }>;
}

export interface SnapshotManifest {
  schema: typeof SNAPSHOT_SCHEMA;
  snapshotId: string;
  generatedAt: string;
  source: SourceInfo;
  /** First and last service date the snapshot can answer for, inclusive. */
  coverage: { from: string; until: string };
  stationsKey: string;
  lines: ManifestLine[];
  /** Calendar rules by calendar slug. */
  calendars: Record<string, CalendarRule>;
  counts: { stations: number; lines: number; trips: number };
}

export interface StoredStation {
  id: string;
  name: LocalizedName;
  latitude?: number;
  longitude?: number;
  code?: string;
  /**
   * Slugs of every line whose shards hold a trip that calls here. Through trains
   * are stored on each line they run on, so this is what a trip lookup must read.
   */
  lines: string[];
  /** Slug of the line the source says the station belongs to, when it says. */
  railway?: string;
}

export interface StationsShard {
  schema: typeof SNAPSHOT_SCHEMA;
  stations: StoredStation[];
}

/** [station index, arrival minutes | null, departure minutes | null, platform?] */
export type StoredStop = [number, number | null, number | null, string?];

export interface StoredTrip {
  id: string;
  trainNumber: string;
  name?: LocalizedName;
  category?: string;
  operator: string;
  /** Line slugs this trip touches, first line first. */
  lines: string[];
  /** Last service date the source declares this trip valid for. */
  validUntil: string;
  stops: StoredStop[];
}

export interface TripShard {
  schema: typeof SNAPSHOT_SCHEMA;
  line: string;
  calendar: string;
  /** Interned station ids that `StoredStop[0]` indexes into. */
  stations: string[];
  trips: StoredTrip[];
}

export type IngestOutcome =
  | "published"
  | "not_configured"
  | "license_blocked"
  | "no_data"
  | "too_many_rejected"
  | "regression"
  | "upstream_failed"
  | "storage_failed"
  | "internal_error";

/** A snapshot ready to store: immutable shard bodies plus the manifest that points at them. */
export interface BuiltSnapshot {
  manifest: SnapshotManifest;
  shards: Array<{ key: string; body: string }>;
  /** Trips dropped because the source declared them valid only before today. */
  expiredTrips: number;
}

/** A deliberate, reportable reason a run did not publish. Never carries upstream detail. */
export class IngestFailure extends Error {
  constructor(readonly outcome: IngestOutcome, readonly code: string) {
    super(code);
  }
}

/** What one railway contributed to a run. Counts and ids only; never upstream content. */
export interface RailwayReport {
  railway: string;
  railwayFound: boolean;
  stations: number;
  timetables: number;
  trips: number;
  rejected: Record<string, number>;
  /** Calendar ids the adapter could not interpret, so an operator can extend it. */
  unsupportedCalendars: string[];
}

export interface LastRunRecord {
  outcome: IngestOutcome;
  code?: string;
  startedAt: string;
  finishedAt: string;
  snapshotId?: string;
  counts?: { stations: number; lines: number; trips: number; rejected: number };
  railways?: RailwayReport[];
}

// ---------------------------------------------------------------------------
// Public response shapes.
// ---------------------------------------------------------------------------

export interface PublicLine {
  id: string;
  name: string;
  nameEn?: string;
  operator: string;
}

export interface PublicStation {
  id: string;
  name: string;
  nameEn?: string;
  latitude?: number;
  longitude?: number;
  code?: string;
  lineIds: string[];
}

export interface PublicStop {
  stationId: string;
  name: string;
  nameEn?: string;
  arrivalAt?: string;
  departureAt?: string;
  platform?: string;
}

export interface PublicTrip {
  id: string;
  serviceDate: string;
  trainNumber: string;
  trainName?: string;
  trainNameEn?: string;
  category?: string;
  operator: string;
  lines: PublicLine[];
  origin: PublicStop;
  destination: PublicStop;
}

export interface PublicTripMatch extends PublicTrip {
  /** The requested boarding stop. */
  from: PublicStop;
  /** The requested alighting stop. */
  to: PublicStop;
}

export interface PublicTripDetail extends PublicTrip {
  stops: PublicStop[];
}

export type DisruptionSeverity = "watch" | "major";

export interface PublicDisruption {
  id: string;
  lineId: string;
  title: string;
  detail: string;
  severity: DisruptionSeverity;
  reportedAt?: string;
  scope: "line";
}

export interface JapanResponseMeta {
  provider: typeof JAPAN_PROVIDER_ID;
  source: string;
  attribution: string;
  license: string;
  snapshotId: string;
  fetchedAt: string;
  expiresAt: string;
  freshness: "fresh" | "stale";
  cacheStatus: "hit" | "stale-fallback" | "miss";
  coverage: { from: string; until: string };
}

// ---------------------------------------------------------------------------
// Input validation.
// ---------------------------------------------------------------------------

// Ingestion keeps source ids of up to 160 characters, so a request must be able to carry any id
// that station search or the timetable returned.
const STATION_ID = /^[A-Za-z0-9._:-]{1,160}$/u;
const LINE_ID = /^[A-Za-z0-9._:-]{1,160}$/u;
const TRIP_ID = /^[A-Za-z0-9._~-]{1,160}$/u;

function invalid(code: string, message: string): ProxyFault {
  return new ProxyFault(code, "invalidRequest", 400, message);
}

export function validatedStationID(value: string | null): string {
  const id = value?.trim() ?? "";
  if (!STATION_ID.test(id)) throw invalid("invalid_station", "Use a station id returned by station search.");
  return id;
}

export function validatedLineID(value: string): string {
  const id = value.trim();
  if (!LINE_ID.test(id)) throw invalid("invalid_line", "Use a line id returned by the timetable.");
  return id;
}

export function validatedTripID(value: string | null): string {
  const id = value ?? "";
  if (!TRIP_ID.test(id)) throw invalid("invalid_trip", "Use a trip id returned by trip search.");
  return id;
}

/** Defaults to the service date in effect now; otherwise a real date in the supported years. */
export function validatedServiceDate(value: string | null, now: Date): string {
  if (value === null) return currentServiceDate(now);
  if (!isSupportedServiceDate(value)) throw invalid("invalid_date", "Use a date like 2026-10-08.");
  return value;
}

/** "HH:MM" on the service-day clock (00:00 through 29:59), as minutes; defaults to the start of day. */
export function validatedTimeOfDay(value: string | null): number {
  if (value === null) return 0;
  const minutes = parseClockMinutes(value);
  if (minutes === null) throw invalid("invalid_time", "Use a time like 08:30.");
  return minutes;
}

export function outOfCoverage(coverage: { from: string; until: string }): ProxyFault {
  return invalid(
    "date_out_of_range",
    `The timetable covers ${coverage.from} through ${coverage.until}.`
  );
}

/** "odpt.Operator:JR-Central" -> "JR Central": a display name derived from the id. */
export function operatorDisplayName(operatorID: string): string {
  const local = operatorID.includes(":") ? operatorID.slice(operatorID.indexOf(":") + 1) : operatorID;
  return local.replace(/[-_]+/gu, " ").trim() || operatorID;
}
