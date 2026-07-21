export const PROVIDER_ID = "ns";
export const PROVIDER_SOURCE = "NS Reisinformatie API";
export const PROVIDER_ATTRIBUTION = "Data from Nederlandse Spoorwegen (NS)";

export type CacheStatus = "hit" | "miss" | "stale-fallback";
export type Freshness = "fresh" | "stale";

export interface ResponseMeta {
  provider: typeof PROVIDER_ID;
  source: typeof PROVIDER_SOURCE;
  attribution: typeof PROVIDER_ATTRIBUTION;
  fetchedAt: string;
  expiresAt: string;
  freshness: Freshness;
  cacheStatus: CacheStatus;
}

export interface StationSummary {
  code: string;
  name: string;
  shortName?: string;
  countryCode?: string;
  latitude?: number;
  longitude?: number;
}

export type DepartureStatus =
  | "scheduled"
  | "onTime"
  | "delayed"
  | "boarding"
  | "arriving"
  | "atPlatform"
  | "departed"
  | "cancelled";

export interface DepartureSummary {
  id: string;
  service: string;
  destination: string;
  scheduledAt: string;
  expectedAt?: string;
  platform?: string;
  status: DepartureStatus;
}

export type DisruptionSeverity = "watch" | "major";

export interface DisruptionSummary {
  id: string;
  title: string;
  detail: string;
  severity: DisruptionSeverity;
  affectedStationCodes: string[];
}

export interface CachedEnvelope<T> {
  value: T;
  fetchedAt: string;
  freshUntil: string;
  staleUntil: string;
}

export class ProxyFault extends Error {
  constructor(
    readonly code: string,
    readonly publicStatus: string,
    readonly httpStatus: number,
    readonly publicMessage: string,
    readonly retryAfterSeconds?: number
  ) {
    super(code);
  }
}

const CONTROL_CHARACTERS = /[\u0000-\u001f\u007f]/u;
const STATION_CODE = /^[A-Z0-9]{1,8}$/u;

export function validatedSearchQuery(value: string | null): string {
  const rawQuery = value ?? "";
  const query = rawQuery.trim().replace(/\s+/gu, " ");
  if (query.length < 2 || query.length > 80 || CONTROL_CHARACTERS.test(rawQuery)) {
    throw new ProxyFault(
      "invalid_query",
      "invalidRequest",
      400,
      "Enter between 2 and 80 visible characters."
    );
  }
  return query;
}

export function validatedStationCode(value: string | null): string {
  const stationCode = value?.trim().toUpperCase() ?? "";
  if (!STATION_CODE.test(stationCode)) {
    throw new ProxyFault(
      "invalid_station",
      "invalidRequest",
      400,
      "Use a valid NS station code."
    );
  }
  return stationCode;
}

export function validatedLimit(value: string | null, fallback = 20): number {
  if (value === null) return fallback;
  if (!/^[0-9]{1,2}$/u.test(value)) {
    throw new ProxyFault("invalid_limit", "invalidRequest", 400, "Limit must be an integer from 1 through 25.");
  }
  const limit = Number(value);
  if (limit < 1 || limit > 25) {
    throw new ProxyFault("invalid_limit", "invalidRequest", 400, "Limit must be an integer from 1 through 25.");
  }
  return limit;
}

export function rejectUnknownQueryParameters(url: URL, allowed: ReadonlySet<string>): void {
  const seen = new Set<string>();
  for (const key of url.searchParams.keys()) {
    if (!allowed.has(key)) {
      throw new ProxyFault(
        "unsupported_parameter",
        "invalidRequest",
        400,
        "The request contains an unsupported parameter."
      );
    }
    if (seen.has(key)) {
      throw new ProxyFault(
        "duplicate_parameter",
        "invalidRequest",
        400,
        "Each request parameter may be supplied only once."
      );
    }
    seen.add(key);
  }
}

export function normalizedSearchValue(value: string): string {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .toLocaleLowerCase("nl-NL");
}
