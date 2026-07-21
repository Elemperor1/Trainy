import type { DepartureStatus, DepartureSummary, DisruptionSummary, StationSummary } from "./contracts";
import { ProxyFault } from "./contracts";

const NS_UPSTREAM = "https://gateway.apiportal.ns.nl/reisinformatie-api/api";
const MAX_UPSTREAM_BYTES = 2 * 1_024 * 1_024;
const UPSTREAM_TIMEOUT_MS = 5_500;
const STATION_CODE = /^[A-Z0-9]{1,8}$/u;

const FIELD_LIMITS = {
  identifier: 160,
  stationName: 120,
  stationShortName: 80,
  countryCode: 3,
  service: 120,
  destination: 160,
  timestamp: 64,
  platform: 16,
  status: 32,
  disruptionTitle: 180,
  disruptionPart: 500,
  disruptionDetail: 1_000
} as const;

type UnknownRecord = Record<string, unknown>;

interface ParsedTimestamp {
  canonical: string;
  instant: number;
}

export interface UpstreamRuntime {
  fetcher: typeof fetch;
  credential: string | undefined;
}

export async function fetchStations(runtime: UpstreamRuntime): Promise<StationSummary[]> {
  const body = await fetchUpstreamJSON(runtime, "v2/stations", []);
  return normalizedCollection(stationCollection(body), mapStation);
}

export async function fetchDepartures(runtime: UpstreamRuntime, stationCode: string): Promise<DepartureSummary[]> {
  const body = await fetchUpstreamJSON(runtime, "v2/departures", [
    new URLSearchParams({ station: stationCode })
  ]);
  return normalizedCollection(departureCollection(body), mapDeparture);
}

export async function fetchDisruptions(runtime: UpstreamRuntime): Promise<DisruptionSummary[]> {
  const body = await fetchUpstreamJSON(runtime, "v3/disruptions", [
    new URLSearchParams({ isActive: "true" })
  ]);
  return normalizedCollection(disruptionCollection(body), mapDisruption);
}

async function fetchUpstreamJSON(
  runtime: UpstreamRuntime,
  path: string,
  queryGroups: URLSearchParams[]
): Promise<unknown> {
  const credential = runtime.credential?.trim();
  if (!credential || credential.startsWith("$(") || /[\r\n]/u.test(credential)) {
    throw new ProxyFault(
      "missing_credential",
      "missingCredential",
      503,
      "NS data is not configured on the provider proxy."
    );
  }

  const url = new URL(`${NS_UPSTREAM}/${path}`);
  for (const group of queryGroups) {
    for (const [key, value] of group.entries()) url.searchParams.append(key, value);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort("upstream-timeout"), UPSTREAM_TIMEOUT_MS);
  try {
    const fetcher = runtime.fetcher;
    const response = await fetcher(url, {
      method: "GET",
      headers: {
        accept: "application/json",
        "ocp-apim-subscription-key": credential
      },
      redirect: "manual",
      signal: controller.signal
    });

    if (response.status >= 300 && response.status < 400) {
      throw new ProxyFault("upstream_redirected", "offline", 502, "NS data is temporarily unavailable.");
    }

    if (response.status === 429) {
      throw new ProxyFault("upstream_rate_limited", "rateLimited", 429, "NS is busy. Try again shortly.", 60);
    }
    if (response.status === 401 || response.status === 403) {
      throw new ProxyFault(
        "credential_rejected",
        "missingCredential",
        503,
        "NS data is not configured on the provider proxy."
      );
    }
    if (path === "v2/departures" && (response.status === 400 || response.status === 404)) {
      throw new ProxyFault("unknown_station", "invalidRequest", 400, "NS does not recognize that station code.");
    }
    if (!response.ok) {
      throw new ProxyFault("upstream_unavailable", "offline", 503, "NS data is temporarily unavailable.");
    }

    const declaredLength = Number(response.headers.get("content-length"));
    if (Number.isFinite(declaredLength) && declaredLength > MAX_UPSTREAM_BYTES) {
      throw new ProxyFault("upstream_too_large", "offline", 502, "NS returned an unreadable response.");
    }

    const body = response.body;
    if (!body) throw new ProxyFault("empty_upstream", "offline", 502, "NS returned an unreadable response.");
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
          throw new ProxyFault("upstream_too_large", "offline", 502, "NS returned an unreadable response.");
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
    try {
      return JSON.parse(new TextDecoder().decode(bytes)) as unknown;
    } catch {
      throw new ProxyFault("invalid_upstream_json", "offline", 502, "NS returned an unreadable response.");
    }
  } catch (error) {
    if (error instanceof ProxyFault) throw error;
    const code = controller.signal.aborted ? "upstream_timeout" : "upstream_network_error";
    throw new ProxyFault(code, "offline", 503, "NS data is temporarily unavailable.");
  } finally {
    clearTimeout(timeout);
  }
}

function mapStation(value: unknown): StationSummary | null {
  const station = record(value);
  if (!station) return null;
  const code = stationCode(station.code);
  const names = record(station.namen) ?? record(station.names);
  const name = text(names?.lang, FIELD_LIMITS.stationName) ?? text(names?.long, FIELD_LIMITS.stationName)
    ?? text(names?.middel, FIELD_LIMITS.stationName) ?? text(names?.medium, FIELD_LIMITS.stationName)
    ?? text(names?.kort, FIELD_LIMITS.stationName) ?? text(names?.short, FIELD_LIMITS.stationName);
  if (!code || !name) return null;
  return compact({
    code,
    name,
    shortName: text(names?.kort, FIELD_LIMITS.stationShortName) ?? text(names?.short, FIELD_LIMITS.stationShortName),
    countryCode: (text(station.land, FIELD_LIMITS.countryCode) ?? text(station.country, FIELD_LIMITS.countryCode))?.toUpperCase(),
    latitude: number(station.lat),
    longitude: number(station.lng)
  });
}

function mapDeparture(value: unknown): DepartureSummary | null {
  const departure = record(value);
  if (!departure) return null;
  const scheduledAt = parsedTimestamp(departure.plannedDateTime);
  const destination = text(departure.direction, FIELD_LIMITS.destination);
  if (!scheduledAt || !destination) return null;
  const product = record(departure.product);
  const service = text(departure.name, FIELD_LIMITS.service)
    ?? text(product?.shortCategoryName, FIELD_LIMITS.service)
    ?? text(product?.longCategoryName, FIELD_LIMITS.service)
    ?? "NS train";
  const expectedAt = optionalTimestamp(departure, "actualDateTime");
  if (expectedAt === null) return null;
  const tripID = text(product?.number, FIELD_LIMITS.identifier) ?? text(departure.name, FIELD_LIMITS.identifier);
  return compact({
    id: tripID ?? `${service}:${destination}:${scheduledAt.canonical}`,
    service,
    destination,
    scheduledAt: scheduledAt.canonical,
    expectedAt: expectedAt?.canonical,
    platform: text(departure.actualTrack, FIELD_LIMITS.platform) ?? text(departure.plannedTrack, FIELD_LIMITS.platform),
    status: departureStatus(departure, scheduledAt.instant, expectedAt?.instant)
  });
}

function departureStatus(
  departure: UnknownRecord,
  scheduledAt: number,
  expectedAt: number | undefined
): DepartureStatus {
  if (departure.cancelled === true) return "cancelled";
  switch (text(departure.departureStatus, FIELD_LIMITS.status)?.toUpperCase()) {
    case "ON_STATION": return "atPlatform";
    case "LEFT": return "departed";
    case "BOARDING": return "boarding";
    case "ARRIVING":
    case "INCOMING": return "arriving";
    default:
      if (expectedAt === undefined) return "scheduled";
      return expectedAt > scheduledAt ? "delayed" : "onTime";
  }
}

function mapDisruption(value: unknown): DisruptionSummary | null {
  const disruption = record(value);
  if (!disruption) return null;
  const title = text(disruption.title, FIELD_LIMITS.disruptionTitle);
  if (!title) return null;
  const timespans = array(disruption.timespans).map(record).filter(Boolean) as UnknownRecord[];
  const situation = timespans.map((span) => text(record(span.situation)?.label, FIELD_LIMITS.disruptionPart)).find(Boolean);
  const cause = timespans.map((span) => text(record(span.cause)?.label, FIELD_LIMITS.disruptionPart)).find(Boolean);
  const expectedDuration = text(record(disruption.expectedDuration)?.description, FIELD_LIMITS.disruptionPart);
  const detailParts = [situation, cause ? `Cause: ${cause}` : undefined, expectedDuration].filter(Boolean) as string[];
  const impact = number(record(disruption.impact)?.value) ?? 0;
  const publicationSections = array(disruption.publicationSections).map(record).filter(Boolean) as UnknownRecord[];
  const affectedStationCodes = publicationSections.flatMap((publication) =>
    array(record(publication.section)?.stations)
      .map((station) => stationCode(record(station)?.stationCode))
      .filter((code): code is string => Boolean(code))
  );
  const noTrains = publicationSections.some(
    (publication) => text(record(publication.consequence)?.level, FIELD_LIMITS.status)?.toUpperCase() === "NO_TRAINS"
  );
  const detailText = detailParts
    .map((part) => /[.!?]$/u.test(part) ? part : `${part}.`)
    .join(" ");
  const detail = text(detailText, FIELD_LIMITS.disruptionDetail)
    ?? "Active NS disruption reported.";
  return {
    id: text(disruption.id, FIELD_LIMITS.identifier) ?? `disruption:${title}`,
    title,
    detail,
    severity: impact >= 3 || noTrains ? "major" : "watch",
    affectedStationCodes: [...new Set(affectedStationCodes)].sort()
  };
}

function record(value: unknown): UnknownRecord | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as UnknownRecord
    : null;
}

function stationCollection(body: unknown): unknown[] {
  if (Array.isArray(body)) return body;
  const root = record(body);
  if (!root) return invalidUpstreamCollection();

  const rootStations = presentArray(root, "stations");
  if (rootStations) return rootStations;
  if (!hasOwn(root, "payload")) return invalidUpstreamCollection();
  if (Array.isArray(root.payload)) return root.payload;
  const payload = record(root.payload);
  if (!payload) return invalidUpstreamCollection();
  return presentArray(payload, "stations") ?? invalidUpstreamCollection();
}

function departureCollection(body: unknown): unknown[] {
  const root = record(body);
  if (!root) return invalidUpstreamCollection();

  const rootDepartures = presentArray(root, "departures");
  if (rootDepartures) return rootDepartures;
  if (!hasOwn(root, "payload")) return invalidUpstreamCollection();
  const payload = record(root.payload);
  if (!payload) return invalidUpstreamCollection();
  return presentArray(payload, "departures") ?? invalidUpstreamCollection();
}

function disruptionCollection(body: unknown): unknown[] {
  if (Array.isArray(body)) return body;
  const root = record(body);
  if (!root) return invalidUpstreamCollection();

  const rootDisruptions = presentArray(root, "disruptions");
  if (rootDisruptions) return rootDisruptions;
  if (!hasOwn(root, "payload")) return invalidUpstreamCollection();
  if (Array.isArray(root.payload)) return root.payload;
  const payload = record(root.payload);
  if (!payload) return invalidUpstreamCollection();
  return presentArray(payload, "disruptions") ?? invalidUpstreamCollection();
}

function presentArray(container: UnknownRecord, key: string): unknown[] | undefined {
  if (!hasOwn(container, key)) return undefined;
  return Array.isArray(container[key]) ? container[key] : invalidUpstreamCollection();
}

function normalizedCollection<T>(values: unknown[], mapper: (value: unknown) => T | null): T[] {
  if (values.length === 0) return [];
  const normalized = values.map(mapper).filter((value): value is T => value !== null);
  return normalized.length > 0 ? normalized : invalidUpstreamCollection();
}

function invalidUpstreamCollection(): never {
  throw new ProxyFault(
    "invalid_upstream_response",
    "offline",
    502,
    "NS returned an unreadable response."
  );
}

function hasOwn(container: UnknownRecord, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(container, key);
}

function array(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function optionalTimestamp(container: UnknownRecord, key: string): ParsedTimestamp | undefined | null {
  const value = container[key];
  if (value === undefined || value === null) return undefined;
  return parsedTimestamp(value);
}

function parsedTimestamp(value: unknown): ParsedTimestamp | null {
  const raw = text(value, FIELD_LIMITS.timestamp);
  if (!raw) return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|([+-])(\d{2}):?(\d{2}))$/u.exec(raw);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = Number(match[4]);
  const minute = Number(match[5]);
  const second = Number(match[6]);
  const milliseconds = Number(`${match[7] ?? ""}000`.slice(0, 3));
  const offsetHours = Number(match[10] ?? 0);
  const offsetMinutes = Number(match[11] ?? 0);
  if (
    year < 2000 || year > 2999
    || month < 1 || month > 12
    || day < 1 || day > 31
    || hour > 23 || minute > 59 || second > 59
    || offsetHours > 23 || offsetMinutes > 59
  ) return null;

  const local = Date.UTC(year, month - 1, day, hour, minute, second, milliseconds);
  const calendarCheck = new Date(local);
  if (
    calendarCheck.getUTCFullYear() !== year
    || calendarCheck.getUTCMonth() !== month - 1
    || calendarCheck.getUTCDate() !== day
    || calendarCheck.getUTCHours() !== hour
    || calendarCheck.getUTCMinutes() !== minute
    || calendarCheck.getUTCSeconds() !== second
  ) return null;

  const signedOffset = match[8] === "Z"
    ? 0
    : (match[9] === "+" ? 1 : -1) * (offsetHours * 60 + offsetMinutes) * 60_000;
  const instant = local - signedOffset;
  return { canonical: new Date(instant).toISOString(), instant };
}

function text(value: unknown, maximumCharacters: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed || [...trimmed].length > maximumCharacters) return undefined;
  return trimmed;
}

function stationCode(value: unknown): string | undefined {
  const code = text(value, 8)?.toUpperCase();
  return code && STATION_CODE.test(code) ? code : undefined;
}

function number(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function compact<T extends Record<string, unknown>>(value: T): T {
  return Object.fromEntries(Object.entries(value).filter(([, item]) => item !== undefined)) as T;
}
