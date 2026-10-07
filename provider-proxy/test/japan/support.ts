// Shared fixtures for the Japan snapshot tests: an in-memory KV that enforces
// the real KV limits we depend on, ODPT-shaped payload builders, a fake ODPT
// server, and a request harness mirroring the NS one.

import { vi } from "vitest";
import type { RuntimeDependencies } from "../../src/handler";
import type { BuiltSnapshot, CalendarRule } from "../../src/japan/contracts";
import type { NormalizedFeed, FeedStop, FeedTrip } from "../../src/japan/snapshot";
import { buildSnapshot } from "../../src/japan/snapshot";
import { publishSnapshot } from "../../src/japan/store";

export const TOKEN = "odpt-fixture-token-0123456789abcdef";
export const NOW = new Date("2026-10-08T00:00:00Z"); // 09:00 JST, service date 2026-10-08 (Thursday)
export const GENERATED_AT = new Date("2026-10-07T18:10:00Z"); // 03:10 JST, still service date 2026-10-07

// ---------------------------------------------------------------------------
// Infrastructure fakes
// ---------------------------------------------------------------------------

export class MemoryCache {
  private readonly values = new Map<string, Response>();

  async match(request: RequestInfo | URL): Promise<Response | undefined> {
    return this.values.get(this.key(request))?.clone();
  }

  async put(request: RequestInfo | URL, response: Response): Promise<void> {
    this.values.set(this.key(request), response.clone());
  }

  async delete(request: RequestInfo | URL): Promise<boolean> {
    return this.values.delete(this.key(request));
  }

  private key(request: RequestInfo | URL): string {
    return request instanceof Request ? request.url : String(request);
  }
}

export interface KVOperation {
  /** "mark" is a test-inserted event (such as the settle delay) kept in KV order. */
  op: "get" | "put" | "delete" | "mark";
  key: string;
  options?: unknown;
}

/** An in-memory KV that rejects the option values the real service rejects. */
export class FakeKV {
  readonly values = new Map<string, { value: string; expirationTtl?: number }>();
  readonly operations: KVOperation[] = [];
  failPut: (key: string) => boolean = () => false;
  failGet: (key: string) => boolean = () => false;

  async get(key: string, optionsOrType?: unknown): Promise<unknown> {
    this.operations.push({ op: "get", key, options: optionsOrType });
    const options = typeof optionsOrType === "object" && optionsOrType !== null
      ? optionsOrType as { type?: string; cacheTtl?: number }
      : { type: optionsOrType as string | undefined };
    if (options.cacheTtl !== undefined && options.cacheTtl < 30) throw new Error("cacheTtl must be at least 30");
    if (this.failGet(key)) throw new Error("KV GET failed");
    const entry = this.values.get(key);
    if (!entry) return null;
    return options.type === "json" ? JSON.parse(entry.value) : entry.value;
  }

  async put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void> {
    this.operations.push({ op: "put", key, options });
    if (new TextEncoder().encode(key).byteLength > 512) throw new Error("key too long");
    if (typeof value !== "string") throw new Error("value must be a string in these tests");
    if (options?.expirationTtl !== undefined && options.expirationTtl < 60) throw new Error("expirationTtl must be at least 60");
    if (this.failPut(key)) throw new Error("KV PUT failed");
    this.values.set(key, { value, expirationTtl: options?.expirationTtl });
  }

  async delete(key: string): Promise<void> {
    this.operations.push({ op: "delete", key });
    this.values.delete(key);
  }

  mark(label: string): void {
    this.operations.push({ op: "mark", key: label });
  }

  keys(prefix = ""): string[] {
    return [...this.values.keys()].filter((key) => key.startsWith(prefix)).sort();
  }

  gets(key: string): number {
    return this.operations.filter((operation) => operation.op === "get" && operation.key === key).length;
  }
}

export function asKV(kv: FakeKV): KVNamespace {
  return kv as unknown as KVNamespace;
}

// ---------------------------------------------------------------------------
// Request harness
// ---------------------------------------------------------------------------

export function harness(options: {
  kv?: FakeKV | null;
  token?: string | null;
  license?: string;
  railways?: string;
  fetcher?: typeof fetch;
  now?: () => Date;
  clientAllowed?: boolean;
  upstreamAllowed?: boolean;
  cache?: MemoryCache;
} = {}) {
  const waits: Promise<unknown>[] = [];
  const records: Array<Record<string, string | number>> = [];
  const kv = options.kv === undefined ? new FakeKV() : options.kv;
  const env = {
    NS_SUBSCRIPTION_KEY: "fixture-credential",
    CLIENT_RATE_LIMITER: { limit: vi.fn(async () => ({ success: options.clientAllowed ?? true })) },
    UPSTREAM_RATE_LIMITER: { limit: vi.fn(async () => ({ success: options.upstreamAllowed ?? true })) },
    ...(kv ? { JAPAN_DATA: kv } : {}),
    ...(options.token === null ? {} : { ODPT_CONSUMER_KEY: options.token ?? TOKEN }),
    JAPAN_SOURCE_LICENSE: options.license ?? "odpt-basic",
    ...(options.railways === undefined ? {} : { JAPAN_ODPT_RAILWAYS: options.railways })
  } as unknown as Env;
  const context = {
    waitUntil(promise: Promise<unknown>) { waits.push(promise); },
    passThroughOnException() {},
    props: {}
  } as ExecutionContext;
  const cache = options.cache ?? new MemoryCache();
  const dependencies: Partial<RuntimeDependencies> = {
    fetcher: options.fetcher ?? (vi.fn(async () => new Response("[]")) as typeof fetch),
    cache: cache as unknown as Cache,
    now: options.now ?? (() => NOW),
    requestID: () => "request-fixture",
    log: (record) => records.push(record),
    reserveProviderBudget: vi.fn(async () => ({ allowed: true, retryAfterSeconds: 0 }))
  };
  return { env, context, dependencies, records, kv, cache, drain: async () => Promise.all(waits) };
}

/** Builds a snapshot from a feed and publishes it into a KV through the real publisher. */
export async function seed(
  kv: FakeKV,
  feed: NormalizedFeed = fixtureFeed(),
  options: { snapshotId?: string; generatedAt?: Date } = {}
): Promise<BuiltSnapshot> {
  const built = buildSnapshot(feed, {
    snapshotId: options.snapshotId ?? "snap-fixture",
    generatedAt: options.generatedAt ?? GENERATED_AT
  });
  await publishSnapshot(asKV(kv), built, { sleep: async () => undefined, now: () => options.generatedAt ?? GENERATED_AT, settleMilliseconds: 0 });
  return built;
}

// ---------------------------------------------------------------------------
// Feed-level fixture: a small two-line network
// ---------------------------------------------------------------------------

export const ALPHA = "odpt.Railway:Test-Central.AlphaShinkansen";
export const BETA = "odpt.Railway:Test-West.BetaShinkansen";
export const TOKYO = "odpt.Station:Test-Central.AlphaShinkansen.Tokyo";
export const NAGOYA = "odpt.Station:Test-Central.AlphaShinkansen.Nagoya";
export const SHIN_OSAKA = "odpt.Station:Test-Central.AlphaShinkansen.ShinOsaka";
export const HAKATA = "odpt.Station:Test-West.BetaShinkansen.Hakata";
export const WEEKDAY = "odpt.Calendar:Weekday";
export const SATURDAY_HOLIDAY = "odpt.Calendar:SaturdayHoliday";
export const SPECIFIC = "odpt.Calendar:Specific.Test.Extra";

export const CALENDARS: Record<string, CalendarRule> = {
  [WEEKDAY]: { kind: "days", dayClasses: ["weekday"] },
  [SATURDAY_HOLIDAY]: { kind: "days", dayClasses: ["saturday", "holiday"] },
  [SPECIFIC]: { kind: "dates", dates: ["2026-10-09"] }
};

export function minutes(clock: string): number {
  const [hours, mins] = clock.split(":").map(Number);
  return hours! * 60 + mins!;
}

export function stop(stationId: string, arrival: string | null, departure: string | null, platform?: string): FeedStop {
  return {
    stationId,
    ...(arrival === null ? {} : { arrival: minutes(arrival) }),
    ...(departure === null ? {} : { departure: minutes(departure) }),
    ...(platform === undefined ? {} : { platform })
  };
}

export function trip(overrides: Partial<FeedTrip> & Pick<FeedTrip, "trainNumber" | "stops">): FeedTrip {
  return {
    sourceId: `odpt.TrainTimetable:Test.${overrides.trainNumber}`,
    name: { ja: "のぞみ", en: "Nozomi" },
    category: "Nozomi",
    operator: "odpt.Operator:Test-Central",
    lineIds: [ALPHA],
    calendar: WEEKDAY,
    ...overrides
  };
}

export function fixtureFeed(): NormalizedFeed {
  const station = (id: string, railway: string, ja: string, en: string, latitude?: number, longitude?: number, code?: string) => ({
    id,
    name: { ja, en },
    railway,
    ...(latitude === undefined ? {} : { latitude, longitude }),
    ...(code === undefined ? {} : { code })
  });
  return {
    source: {
      id: "odpt",
      name: "Public Transportation Open Data Center (ODPT)",
      attribution: "Timetable data from the Public Transportation Open Data Center (ODPT).",
      license: "odpt-basic"
    },
    lines: [
      { id: ALPHA, name: { ja: "アルファ新幹線", en: "Alpha Shinkansen" }, operator: "odpt.Operator:Test-Central" },
      { id: BETA, name: { ja: "ベータ新幹線", en: "Beta Shinkansen" }, operator: "odpt.Operator:Test-West" }
    ],
    stations: [
      station(TOKYO, ALPHA, "東京", "Tokyo", 35.681, 139.767, "TK01"),
      station(NAGOYA, ALPHA, "名古屋", "Nagoya", 35.17, 136.882),
      station(SHIN_OSAKA, ALPHA, "新大阪", "Shin-Osaka", 34.733, 135.5),
      station(HAKATA, BETA, "博多", "Hakata", 33.59, 130.421)
    ],
    calendars: CALENDARS,
    trips: [
      trip({ trainNumber: "1", stops: [stop(TOKYO, null, "06:00", "14"), stop(NAGOYA, "07:36", "07:37", "16"), stop(SHIN_OSAKA, "08:30", null, "25")] }),
      trip({ trainNumber: "3", stops: [stop(TOKYO, null, "07:00", "14"), stop(NAGOYA, "08:36", "08:37", "16"), stop(SHIN_OSAKA, "09:30", null, "25")] }),
      trip({
        trainNumber: "101",
        name: { ja: "こだま", en: "Kodama" },
        category: "Kodama",
        stops: [stop(TOKYO, null, "06:30"), stop(NAGOYA, "09:13", "09:15"), stop(SHIN_OSAKA, "10:40", null)]
      }),
      // Leaves Tokyo at 23:20 and reaches Shin-Osaka after midnight.
      trip({ trainNumber: "99", stops: [stop(TOKYO, null, "23:20"), stop(SHIN_OSAKA, "25:30", null)] }),
      trip({
        trainNumber: "201",
        calendar: SATURDAY_HOLIDAY,
        stops: [stop(TOKYO, null, "08:00"), stop(SHIN_OSAKA, "10:30", null)]
      }),
      trip({
        trainNumber: "9001",
        calendar: SPECIFIC,
        stops: [stop(TOKYO, null, "12:00"), stop(SHIN_OSAKA, "14:30", null)]
      }),
      // A through train recorded on both lines; Shin-Osaka is one shared station.
      trip({
        trainNumber: "301",
        lineIds: [ALPHA, BETA],
        stops: [
          stop(TOKYO, null, "10:00"),
          stop(NAGOYA, "11:36", "11:37"),
          stop(SHIN_OSAKA, "12:30", "12:33"),
          stop(HAKATA, "15:20", null)
        ]
      }),
      trip({
        trainNumber: "541",
        lineIds: [BETA],
        operator: "odpt.Operator:Test-West",
        name: { ja: "さくら", en: "Sakura" },
        category: "Sakura",
        stops: [stop(SHIN_OSAKA, null, "13:00"), stop(HAKATA, "15:30", null)]
      })
    ]
  };
}

// ---------------------------------------------------------------------------
// ODPT-shaped payloads and a fake ODPT server
// ---------------------------------------------------------------------------

export function odptRailway(railway: string, operator: string, ja: string, en: string) {
  return { "@id": `urn:fixture:${railway}`, "owl:sameAs": railway, "odpt:operator": operator, "odpt:railwayTitle": { ja, en } };
}

export function odptStation(id: string, railway: string, ja: string, en: string, lat = 35.68, lon = 139.76) {
  return {
    "@id": `urn:fixture:${id}`,
    "owl:sameAs": id,
    "odpt:railway": railway,
    "odpt:stationTitle": { ja, en },
    "geo:lat": lat,
    "geo:long": lon
  };
}

export interface OdptStopInput {
  station: string;
  arrival?: string;
  departure?: string;
  platform?: string;
}

export function odptTimetable(options: {
  railway: string;
  number: string;
  calendar?: string;
  operator?: string;
  stops: OdptStopInput[];
  valid?: string;
  type?: string;
  name?: unknown;
  id?: string;
}) {
  return {
    "@id": `urn:fixture:tt:${options.railway}:${options.number}:${options.calendar ?? WEEKDAY}`,
    "owl:sameAs": options.id ?? `odpt.TrainTimetable:${options.railway.slice(options.railway.indexOf(":") + 1)}.${options.number}.${(options.calendar ?? WEEKDAY).split(":")[1]}`,
    "odpt:operator": options.operator ?? "odpt.Operator:Test-Central",
    "odpt:railway": options.railway,
    "odpt:calendar": options.calendar ?? WEEKDAY,
    "odpt:trainNumber": options.number,
    "odpt:trainType": options.type ?? "odpt.TrainType:Test-Central.Nozomi",
    "odpt:trainName": options.name ?? [{ ja: "のぞみ", en: "Nozomi" }],
    "odpt:trainTimetableObject": options.stops.map((entry) => ({
      ...(entry.departure === undefined ? {} : { "odpt:departureStation": entry.station, "odpt:departureTime": entry.departure }),
      ...(entry.arrival === undefined ? {} : { "odpt:arrivalStation": entry.station, "odpt:arrivalTime": entry.arrival }),
      ...(entry.platform === undefined ? {} : { "odpt:platformNumber": entry.platform })
    })),
    ...(options.valid === undefined ? {} : { "dct:valid": options.valid })
  };
}

export interface FakeOdptData {
  calendars?: unknown[];
  railways?: Record<string, unknown[]>;
  stations?: Record<string, unknown[]>;
  timetables?: Record<string, unknown[]>;
  information?: Record<string, unknown[]>;
  status?: (resource: string, railway: string | null) => number | undefined;
}

export function fakeOdpt(data: FakeOdptData) {
  const requests: Array<{ resource: string; filter: string | null; tokenSeen: string | null; url: string }> = [];
  const mock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = new URL(String(input));
    expectGetNoRedirect(init);
    const resource = decodeURIComponent(url.pathname.split("/").pop() ?? "");
    const filter = url.searchParams.get("odpt:railway") ?? url.searchParams.get("owl:sameAs");
    requests.push({ resource, filter, tokenSeen: url.searchParams.get("acl:consumerKey"), url: String(input) });
    const override = data.status?.(resource, filter);
    if (override !== undefined) return new Response("{}", { status: override });
    const lookup = (table: Record<string, unknown[]> | undefined) => table?.[filter ?? ""] ?? [];
    const body = resource === "odpt:Calendar" ? data.calendars ?? []
      : resource === "odpt:Railway" ? lookup(data.railways)
      : resource === "odpt:Station" ? lookup(data.stations)
      : resource === "odpt:TrainTimetable" ? lookup(data.timetables)
      : resource === "odpt:TrainInformation" ? lookup(data.information)
      : [];
    return new Response(JSON.stringify(body), { status: 200, headers: { "content-type": "application/json" } });
  });
  return { fetcher: mock as unknown as typeof fetch, requests, mock };
}

function expectGetNoRedirect(init?: RequestInit): void {
  if (init?.method !== "GET" || init.redirect !== "manual") {
    throw new Error("Upstream requests must be GET with redirects disabled.");
  }
}

/** A complete two-railway ODPT dataset with `count` weekday trips on each railway. */
export function odptNetwork(count = 12, options: { valid?: string } = {}): FakeOdptData & { railways: Record<string, unknown[]> } {
  const alphaStations = [
    odptStation(TOKYO, ALPHA, "東京", "Tokyo", 35.681, 139.767),
    odptStation(NAGOYA, ALPHA, "名古屋", "Nagoya", 35.17, 136.882),
    odptStation(SHIN_OSAKA, ALPHA, "新大阪", "Shin-Osaka", 34.733, 135.5)
  ];
  const betaStations = [
    odptStation("odpt.Station:Test-West.BetaShinkansen.ShinOsaka", BETA, "新大阪", "Shin-Osaka", 34.733, 135.5),
    odptStation(HAKATA, BETA, "博多", "Hakata", 33.59, 130.421)
  ];
  const alphaTrips = Array.from({ length: count }, (_, index) => {
    const hour = 6 + index;
    const clock = (offset: number) => {
      const total = hour * 60 + offset;
      return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
    };
    return odptTimetable({
      railway: ALPHA,
      number: String(index * 2 + 1),
      valid: options.valid,
      stops: [
        { station: TOKYO, departure: clock(0), platform: "14" },
        { station: NAGOYA, arrival: clock(96), departure: clock(97) },
        { station: SHIN_OSAKA, arrival: clock(150), platform: "25" }
      ]
    });
  });
  const betaTrips = Array.from({ length: count }, (_, index) => {
    const hour = 7 + index;
    return odptTimetable({
      railway: BETA,
      number: String(500 + index),
      operator: "odpt.Operator:Test-West",
      valid: options.valid,
      type: "odpt.TrainType:Test-West.Sakura",
      name: [{ ja: "さくら", en: "Sakura" }],
      stops: [
        { station: "odpt.Station:Test-West.BetaShinkansen.ShinOsaka", departure: `${String(hour).padStart(2, "0")}:10` },
        { station: HAKATA, arrival: `${String(hour + 2).padStart(2, "0")}:40` }
      ]
    });
  });
  return {
    calendars: [],
    railways: {
      [ALPHA]: [odptRailway(ALPHA, "odpt.Operator:Test-Central", "アルファ新幹線", "Alpha Shinkansen")],
      [BETA]: [odptRailway(BETA, "odpt.Operator:Test-West", "ベータ新幹線", "Beta Shinkansen")]
    },
    stations: { [ALPHA]: alphaStations, [BETA]: betaStations },
    timetables: { [ALPHA]: alphaTrips, [BETA]: betaTrips }
  };
}

export const NETWORK_RAILWAYS = `${ALPHA},${BETA}`;
