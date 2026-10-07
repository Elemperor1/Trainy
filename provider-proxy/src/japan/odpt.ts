// ODPT (Public Transportation Open Data Center) v4 adapter.
//
// It fetches a fixed set of resources for a fixed list of railway ids and turns
// them into the source-neutral feed in snapshot.ts. docs/japan-data-decision-record.md
// explains why this source is not expected to return Shinkansen timetables; the
// adapter reports what it finds per railway so a live run can confirm or refute
// that. Nothing here logs or returns an upstream URL, because the consumer key
// travels in the query string.

import { ProxyFault } from "../contracts";
import {
  MINUTES_PER_DAY,
  parseClockMinutes,
  SERVICE_DAY_START_MINUTE,
  isSupportedServiceDate,
  serviceDateOfInstant
} from "./calendar";
import type { CalendarRule, LocalizedName, PublicDisruption, RailwayReport } from "./contracts";
import type { UnknownRecord } from "./json";
import { array, compact, finiteNumber, record, text } from "./json";
import type { FeedLine, FeedStation, FeedStop, FeedTrip, NormalizedFeed } from "./snapshot";

export const ODPT_BASE_URL = "https://api.odpt.org/api/v4";
export const ODPT_SOURCE_ID = "odpt";
export const ODPT_SOURCE_NAME = "Public Transportation Open Data Center (ODPT)";
// The exact credit text ODPT requires is an open gap (G2 in the decision record).
export const ODPT_ATTRIBUTION = "Timetable data from the Public Transportation Open Data Center (ODPT).";

/** The railway ids the app's route catalog guessed for each Shinkansen line. */
export const DEFAULT_ODPT_RAILWAYS: readonly string[] = [
  "odpt.Railway:JR-Central.TokaidoShinkansen",
  "odpt.Railway:JR-West.SanyoShinkansen",
  "odpt.Railway:JR-Kyushu.KyushuShinkansen",
  "odpt.Railway:JR-East.TohokuShinkansen",
  "odpt.Railway:JR-East.HokurikuShinkansen",
  "odpt.Railway:JR-West.HokurikuShinkansen",
  "odpt.Railway:JR-East.JoetsuShinkansen",
  "odpt.Railway:JR-Hokkaido.HokkaidoShinkansen",
  "odpt.Railway:JR-East.AkitaShinkansen",
  "odpt.Railway:JR-East.YamagataShinkansen"
];

const RAILWAY_ID = /^odpt\.Railway:[A-Za-z0-9._-]{1,120}$/u;
const SOURCE_ID = /^[A-Za-z0-9._:-]{1,160}$/u;
const MAX_UPSTREAM_BYTES = 8 * 1_024 * 1_024;
const UPSTREAM_TIMEOUT_MS = 30_000;
const MAX_STOPS = 120;
const MAX_TRIP_SPAN_MINUTES = 30 * 60;
const MAX_ROLLOVER_GAP_MINUTES = 12 * 60;
const MAX_REPORTED_CALENDARS = 20;

const GENERIC_CALENDARS: Readonly<Record<string, CalendarRule>> = {
  "odpt.Calendar:Weekday": { kind: "days", dayClasses: ["weekday"] },
  "odpt.Calendar:Saturday": { kind: "days", dayClasses: ["saturday"] },
  "odpt.Calendar:Holiday": { kind: "days", dayClasses: ["holiday"] },
  "odpt.Calendar:SaturdayHoliday": { kind: "days", dayClasses: ["saturday", "holiday"] },
  "odpt.Calendar:Everyday": { kind: "days", dayClasses: ["weekday", "saturday", "holiday"] }
};

export interface OdptRuntime {
  fetcher: typeof fetch;
  token: string;
  /** Per-request deadline; defaults to 30 seconds. Tests shorten it. */
  timeoutMilliseconds?: number;
}

export interface OdptFeedResult {
  feed: Omit<NormalizedFeed, "source">;
  reports: RailwayReport[];
  timetables: number;
  rejected: number;
}

export function parseRailwayList(value: string | undefined): string[] {
  const configured = (value ?? "").split(",").map((item) => item.trim()).filter(Boolean);
  if (configured.length === 0) return [...DEFAULT_ODPT_RAILWAYS];
  const unique = [...new Set(configured)];
  if (unique.length > 40 || unique.some((id) => !RAILWAY_ID.test(id))) {
    throw new RangeError("JAPAN_ODPT_RAILWAYS must list up to 40 odpt.Railway ids.");
  }
  return unique;
}

// ---------------------------------------------------------------------------
// Transport
// ---------------------------------------------------------------------------

function encodeQueryPart(value: string): string {
  // ODPT's own examples leave ":" unescaped in names and values.
  return encodeURIComponent(value).replace(/%3A/giu, ":");
}

function odptURL(resource: string, filters: Record<string, string>, token: string): URL {
  const query = [...Object.entries(filters), ["acl:consumerKey", token]]
    .map(([key, value]) => `${encodeQueryPart(key)}=${encodeQueryPart(value)}`)
    .join("&");
  return new URL(`${ODPT_BASE_URL}/${resource}?${query}`);
}

function unavailable(code: string, status = 503): ProxyFault {
  return new ProxyFault(code, "offline", status, "Japan rail data is temporarily unavailable.");
}

export async function fetchOdptJSON(
  runtime: OdptRuntime,
  resource: string,
  filters: Record<string, string> = {}
): Promise<unknown[]> {
  const controller = new AbortController();
  const timeout = setTimeout(
    () => controller.abort("upstream-timeout"),
    runtime.timeoutMilliseconds ?? UPSTREAM_TIMEOUT_MS
  );
  try {
    const response = await runtime.fetcher(odptURL(resource, filters, runtime.token), {
      method: "GET",
      headers: { accept: "application/json" },
      redirect: "manual",
      signal: controller.signal
    });

    if (response.status >= 300 && response.status < 400) throw unavailable("upstream_redirected", 502);
    if (response.status === 429) {
      throw new ProxyFault("upstream_rate_limited", "rateLimited", 429, "Japan rail data is busy. Try again shortly.", 60);
    }
    if (response.status === 401 || response.status === 403) {
      throw new ProxyFault(
        "credential_rejected",
        "missingCredential",
        503,
        "Japan rail data is not configured on the provider proxy."
      );
    }
    // An unknown railway or empty resource answers 404; treat it as no records.
    if (response.status === 404) return [];
    if (!response.ok) throw unavailable("upstream_unavailable");

    const declaredLength = Number(response.headers.get("content-length"));
    if (Number.isFinite(declaredLength) && declaredLength > MAX_UPSTREAM_BYTES) throw unavailable("upstream_too_large", 502);
    const body = response.body;
    if (!body) throw unavailable("empty_upstream", 502);

    const reader = body.getReader();
    const chunks: Uint8Array[] = [];
    let total = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        total += value.byteLength;
        if (total > MAX_UPSTREAM_BYTES) {
          await reader.cancel();
          throw unavailable("upstream_too_large", 502);
        }
        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(new TextDecoder().decode(bytes));
    } catch {
      throw unavailable("invalid_upstream_json", 502);
    }
    if (!Array.isArray(parsed)) throw unavailable("invalid_upstream_response", 502);
    return parsed;
  } catch (error) {
    if (error instanceof ProxyFault) throw error;
    throw unavailable(controller.signal.aborted ? "upstream_timeout" : "upstream_network_error");
  } finally {
    clearTimeout(timeout);
  }
}

// ---------------------------------------------------------------------------
// Feed
// ---------------------------------------------------------------------------

export async function fetchOdptFeed(runtime: OdptRuntime, railways: string[]): Promise<OdptFeedResult> {
  const calendars = new Map<string, CalendarRule>(Object.entries(GENERIC_CALENDARS));
  for (const [id, rule] of normalizeCalendars(await fetchOdptJSON(runtime, "odpt:Calendar"))) {
    if (!calendars.has(id)) calendars.set(id, rule);
  }

  // Pass one reads the small resources for every railway, so a trip can name a
  // station that belongs to a neighbouring railway (through services).
  const stations = new Map<string, FeedStation>();
  const lines: FeedLine[] = [];
  const reports: RailwayReport[] = [];
  for (const railway of railways) {
    const report: RailwayReport = {
      railway,
      railwayFound: false,
      stations: 0,
      timetables: 0,
      trips: 0,
      rejected: {},
      unsupportedCalendars: []
    };
    const railwayRecord = (await fetchOdptJSON(runtime, "odpt:Railway", { "owl:sameAs": railway }))
      .map(normalizeRailway)
      .find((candidate) => candidate?.id === railway);
    report.railwayFound = railwayRecord !== undefined && railwayRecord !== null;
    lines.push({
      id: railway,
      name: railwayRecord?.name ?? { ja: railway.slice(railway.indexOf(":") + 1) },
      operator: railwayRecord?.operator ?? operatorOfRailway(railway)
    });
    for (const raw of await fetchOdptJSON(runtime, "odpt:Station", { "odpt:railway": railway })) {
      const station = normalizeStation(raw);
      if (station && !stations.has(station.id)) {
        stations.set(station.id, station);
        report.stations += 1;
      }
    }
    reports.push(report);
  }

  // Pass two normalizes one railway's timetables at a time, so only one raw
  // response is in memory.
  const trips: FeedTrip[] = [];
  const seen = new Set<string>();
  const stationIds = new Set(stations.keys());
  let timetables = 0;
  let rejected = 0;
  for (const report of reports) {
    const records = await fetchOdptJSON(runtime, "odpt:TrainTimetable", { "odpt:railway": report.railway });
    report.timetables = records.length;
    timetables += records.length;
    const unsupported = new Set<string>();
    for (const raw of records) {
      const result = normalizeTimetable(raw, { railway: report.railway, stationIds, calendars, seen });
      if (result.trip) {
        trips.push(result.trip);
        report.trips += 1;
        continue;
      }
      rejected += 1;
      report.rejected[result.reject] = (report.rejected[result.reject] ?? 0) + 1;
      if (result.reject === "unsupported_calendar" && result.detail && unsupported.size < MAX_REPORTED_CALENDARS) {
        unsupported.add(result.detail);
      }
    }
    report.unsupportedCalendars = [...unsupported].sort();
  }

  const calendarRules: Record<string, CalendarRule> = {};
  for (const id of new Set(trips.map((trip) => trip.calendar))) {
    const rule = calendars.get(id);
    if (rule) calendarRules[id] = rule;
  }
  return { feed: { lines, stations: [...stations.values()], trips, calendars: calendarRules }, reports, timetables, rejected };
}

function operatorOfRailway(railway: string): string {
  const local = railway.slice(railway.indexOf(":") + 1);
  return `odpt.Operator:${local.split(".")[0] ?? local}`;
}

// ---------------------------------------------------------------------------
// Normalizers (exported for contract tests)
// ---------------------------------------------------------------------------

function sourceID(raw: UnknownRecord): string | undefined {
  const id = text(raw["owl:sameAs"], 160) ?? text(raw["@id"], 160);
  return id !== undefined && SOURCE_ID.test(id) ? id : undefined;
}


export function localizedName(value: unknown, maximumCharacters = 120): LocalizedName | undefined {
  if (typeof value === "string") {
    const ja = text(value, maximumCharacters);
    return ja === undefined ? undefined : { ja };
  }
  const names = record(value);
  if (!names) return undefined;
  const ja = text(names.ja, maximumCharacters);
  const en = text(names.en, maximumCharacters);
  if (ja === undefined && en === undefined) return undefined;
  return compact({ ja: ja ?? en!, en });
}

export function normalizeRailway(value: unknown): { id: string; name: LocalizedName; operator: string } | null {
  const railway = record(value);
  if (!railway) return null;
  const id = sourceID(railway);
  const name = localizedName(railway["odpt:railwayTitle"]) ?? localizedName(railway["dc:title"]);
  const operator = text(railway["odpt:operator"], 160);
  if (!id || !name || !operator) return null;
  return { id, name, operator };
}

export function normalizeStation(value: unknown): FeedStation | null {
  const station = record(value);
  if (!station) return null;
  const id = sourceID(station);
  const name = localizedName(station["odpt:stationTitle"]) ?? localizedName(station["dc:title"]);
  if (!id || !name) return null;
  const latitude = finiteNumber(station["geo:lat"]);
  const longitude = finiteNumber(station["geo:long"]);
  const inJapan = latitude !== undefined && longitude !== undefined
    && latitude >= 20 && latitude <= 46 && longitude >= 122 && longitude <= 154;
  return compact({
    id,
    name,
    latitude: inJapan ? latitude : undefined,
    longitude: inJapan ? longitude : undefined,
    code: text(station["odpt:stationCode"], 16),
    railway: text(station["odpt:railway"], 160)
  });
}

export function normalizeCalendars(records: unknown[]): Map<string, CalendarRule> {
  const rules = new Map<string, CalendarRule>();
  for (const raw of records) {
    const calendar = record(raw);
    const id = calendar ? sourceID(calendar) : undefined;
    if (!calendar || !id) continue;
    const days = typeof calendar["odpt:day"] === "string" ? [calendar["odpt:day"]] : array(calendar["odpt:day"]);
    const dates = days.filter((day): day is string => typeof day === "string" && isSupportedServiceDate(day));
    if (dates.length > 0) rules.set(id, { kind: "dates", dates });
  }
  return rules;
}

interface TimetableContext {
  railway: string;
  stationIds: ReadonlySet<string>;
  calendars: ReadonlyMap<string, CalendarRule>;
  seen: Set<string>;
}

type TimetableResult = { trip: FeedTrip; reject?: undefined } | { trip?: undefined; reject: string; detail?: string };

function categoryOf(trainType: string | undefined): string | undefined {
  if (!trainType) return undefined;
  const last = trainType.split(/[.:]/u).pop();
  return last ? text(last, 40) : undefined;
}

export function normalizeTimetable(value: unknown, context: TimetableContext): TimetableResult {
  const timetable = record(value);
  if (!timetable) return { reject: "invalid_record" };
  const id = sourceID(timetable);
  if (!id) return { reject: "invalid_id" };
  if (text(timetable["odpt:railway"], 160) !== context.railway) return { reject: "railway_mismatch" };
  if (context.seen.has(id)) return { reject: "duplicate" };

  const operator = text(timetable["odpt:operator"], 160);
  const trainNumber = text(timetable["odpt:trainNumber"], 40);
  if (!operator) return { reject: "missing_operator" };
  if (!trainNumber) return { reject: "missing_train_number" };

  const calendar = text(timetable["odpt:calendar"], 160);
  if (!calendar || !context.calendars.has(calendar)) return { reject: "unsupported_calendar", detail: calendar };

  const rawStops = array(timetable["odpt:trainTimetableObject"]);
  if (rawStops.length > MAX_STOPS) return { reject: "too_many_stops" };
  const stops: FeedStop[] = [];
  for (const entry of rawStops) {
    const object = record(entry);
    if (!object) return { reject: "invalid_stop" };
    const departureStation = text(object["odpt:departureStation"], 160);
    const arrivalStation = text(object["odpt:arrivalStation"], 160);
    const stationId = departureStation ?? arrivalStation;
    if (departureStation && arrivalStation && departureStation !== arrivalStation) return { reject: "invalid_stop" };
    const arrivalText = object["odpt:arrivalTime"];
    const departureText = object["odpt:departureTime"];
    if ((arrivalText ?? null) === null && (departureText ?? null) === null) continue;
    if (!stationId) return { reject: "invalid_stop" };
    const arrival = (arrivalText ?? null) === null ? undefined : parseClockMinutes(String(arrivalText));
    const departure = (departureText ?? null) === null ? undefined : parseClockMinutes(String(departureText));
    if (arrival === null || departure === null) return { reject: "invalid_time" };
    stops.push(compact<FeedStop>({
      stationId,
      arrival,
      departure,
      platform: text(object["odpt:departurePlatformNumber"], 8)
        ?? text(object["odpt:arrivalPlatformNumber"], 8)
        ?? text(object["odpt:platformNumber"], 8)
    }));
  }
  if (stops.length < 2) return { reject: "too_few_stops" };
  if (stops.some((stop) => !context.stationIds.has(stop.stationId))) return { reject: "unknown_station" };
  if (!rollPastMidnight(stops)) return { reject: "non_monotonic" };

  const nameRecord = array(timetable["odpt:trainName"])[0] ?? timetable["odpt:trainName"];
  const validValue = text(timetable["dct:valid"], 64);
  const validUntil = validValue === undefined ? undefined : serviceDateOfInstant(validValue) ?? undefined;
  context.seen.add(id);
  return {
    trip: compact<FeedTrip>({
      sourceId: id,
      trainNumber,
      name: localizedName(nameRecord, 60),
      category: categoryOf(text(timetable["odpt:trainType"], 160)),
      operator,
      lineIds: [context.railway],
      calendar,
      validUntil,
      stops
    })
  };
}

/**
 * Stops carry clock times. Anything before 04:00 belongs after midnight of the
 * service day, and a time earlier than the one before it has crossed midnight.
 * A rollover that would leave more than 12 hours between consecutive stops, or
 * a trip that spans more than 30 hours, is a data error rather than an
 * overnight run, so the trip is rejected.
 */
export function rollPastMidnight(stops: FeedStop[]): boolean {
  let previous: number | null = null;
  let first: number | null = null;
  let offset = 0;
  for (const stop of stops) {
    for (const field of ["arrival", "departure"] as const) {
      const clock = stop[field];
      if (clock === undefined) continue;
      let value = clock + offset;
      if (previous === null) {
        if (clock < SERVICE_DAY_START_MINUTE) {
          offset = MINUTES_PER_DAY;
          value = clock + offset;
        }
        first = value;
      } else if (value < previous) {
        const rolled = clock + offset + MINUTES_PER_DAY;
        if (rolled - previous > MAX_ROLLOVER_GAP_MINUTES) return false;
        offset += MINUTES_PER_DAY;
        value = rolled;
      }
      stop[field] = value;
      previous = value;
    }
  }
  return first !== null && previous !== null && previous - first <= MAX_TRIP_SPAN_MINUTES;
}

// ---------------------------------------------------------------------------
// Line-level operation information
// ---------------------------------------------------------------------------

const NORMAL_SERVICE = /平常|normal|on schedule/iu;
const SUSPENDED = /見合わせ|運休|運転中止|不通|suspend|cancel|halt|stopp/iu;

export function normalizeTrainInformation(value: unknown, railway: string, now: Date): PublicDisruption | null {
  const information = record(value);
  if (!information) return null;
  const validValue = text(information["dct:valid"], 64);
  if (validValue !== undefined) {
    const validUntil = Date.parse(validValue);
    if (Number.isFinite(validUntil) && validUntil <= now.getTime()) return null;
  }

  const status = localizedName(information["odpt:trainInformationStatus"], 180);
  const body = localizedName(information["odpt:trainInformationText"], 1_000);
  const cause = localizedName(information["odpt:trainInformationCause"], 500);
  if (!status && !body) return null;

  const statusText = `${status?.ja ?? ""} ${status?.en ?? ""}`;
  if (NORMAL_SERVICE.test(statusText) && !SUSPENDED.test(statusText)) return null;

  const detailParts = [body?.en ?? body?.ja, cause ? `Cause: ${cause.en ?? cause.ja}` : undefined].filter(Boolean) as string[];
  const reportedValue = text(information["odpt:timeOfOrigin"], 64) ?? text(information["dc:date"], 64);
  const reportedMilliseconds = reportedValue === undefined ? Number.NaN : Date.parse(reportedValue);
  const title = status?.en ?? status?.ja ?? "Service notice";
  return compact<PublicDisruption>({
    id: sourceID(information) ?? `${railway}:${title}`,
    lineId: railway,
    title,
    detail: (detailParts.join(" ") || "The operator reported a service disruption.").slice(0, 1_000),
    severity: SUSPENDED.test(`${statusText} ${body?.ja ?? ""} ${body?.en ?? ""}`) ? "major" : "watch",
    reportedAt: Number.isFinite(reportedMilliseconds) ? new Date(reportedMilliseconds).toISOString() : undefined,
    scope: "line"
  });
}

export async function fetchTrainInformation(
  runtime: OdptRuntime,
  railways: string[],
  now: Date
): Promise<PublicDisruption[]> {
  // Notices are small, so every railway is asked at once; any failure fails the whole read.
  const groups = await Promise.all(railways.map(async (railway) => {
    const records = await fetchOdptJSON(runtime, "odpt:TrainInformation", { "odpt:railway": railway });
    return records.flatMap((raw) => normalizeTrainInformation(raw, railway, now) ?? []);
  }));
  return groups.flat();
}
