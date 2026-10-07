import { describe, expect, it, vi } from "vitest";
import { ProxyFault } from "../../src/contracts";
import type { CalendarRule } from "../../src/japan/contracts";
import {
  DEFAULT_ODPT_RAILWAYS,
  fetchOdptFeed,
  fetchOdptJSON,
  normalizeCalendars,
  normalizeStation,
  normalizeTimetable,
  normalizeTrainInformation,
  parseRailwayList,
  rollPastMidnight
} from "../../src/japan/odpt";
import type { FeedStop } from "../../src/japan/snapshot";
import {
  ALPHA,
  BETA,
  fakeOdpt,
  HAKATA,
  NAGOYA,
  odptNetwork,
  odptStation,
  odptTimetable,
  SATURDAY_HOLIDAY,
  SHIN_OSAKA,
  TOKEN,
  TOKYO,
  WEEKDAY
} from "./support";

const runtimeWith = (fetcher: typeof fetch, extra: { timeoutMilliseconds?: number } = {}) => ({
  fetcher,
  token: TOKEN,
  ...extra
});

async function faultOf(promise: Promise<unknown>): Promise<ProxyFault> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof ProxyFault) return error;
    throw error;
  }
  throw new Error("Expected a ProxyFault.");
}

describe("ODPT transport", () => {
  it("sends a fixed GET with the key as the last query parameter and leaves colons readable", async () => {
    const fetcher = vi.fn(async () => new Response("[]")) as unknown as typeof fetch;
    await fetchOdptJSON(runtimeWith(fetcher), "odpt:TrainTimetable", { "odpt:railway": ALPHA });

    const [input, init] = (fetcher as unknown as ReturnType<typeof vi.fn>).mock.calls[0] as [URL, RequestInit];
    expect(input.origin).toBe("https://api.odpt.org");
    expect(input.pathname).toBe("/api/v4/odpt:TrainTimetable");
    expect(input.search).toBe(`?odpt:railway=${ALPHA}&acl:consumerKey=${TOKEN}`);
    expect(init).toMatchObject({ method: "GET", redirect: "manual", headers: { accept: "application/json" } });
    expect(Object.keys(init.headers as object)).toEqual(["accept"]);
  });

  it("percent-encodes reserved characters in filters and the key", async () => {
    const fetcher = vi.fn(async () => new Response("[]")) as unknown as typeof fetch;
    await fetchOdptJSON({ fetcher, token: "a b&c" }, "odpt:Station", { "odpt:railway": "x&y=z" });
    const [input] = (fetcher as unknown as ReturnType<typeof vi.fn>).mock.calls[0] as [URL];
    expect(input.search).toBe("?odpt:railway=x%26y%3Dz&acl:consumerKey=a%20b%26c");
  });

  const failures: Array<{ label: string; response: () => Response; code: string; status: number; publicStatus: string }> = [
    { label: "a redirect", response: () => new Response("", { status: 302, headers: { location: "https://elsewhere.example/" } }), code: "upstream_redirected", status: 502, publicStatus: "offline" },
    { label: "throttling", response: () => new Response("{}", { status: 429 }), code: "upstream_rate_limited", status: 429, publicStatus: "rateLimited" },
    { label: "a rejected key (401)", response: () => new Response("{}", { status: 401 }), code: "credential_rejected", status: 503, publicStatus: "missingCredential" },
    { label: "a rejected key (403)", response: () => new Response("{}", { status: 403 }), code: "credential_rejected", status: 503, publicStatus: "missingCredential" },
    { label: "a server error", response: () => new Response("{}", { status: 500 }), code: "upstream_unavailable", status: 503, publicStatus: "offline" },
    { label: "invalid JSON", response: () => new Response("<html>", { status: 200 }), code: "invalid_upstream_json", status: 502, publicStatus: "offline" },
    { label: "a non-array body", response: () => new Response('{"error":"nope"}', { status: 200 }), code: "invalid_upstream_response", status: 502, publicStatus: "offline" },
    { label: "an oversized declared length", response: () => new Response("[]", { status: 200, headers: { "content-length": String(8 * 1_024 * 1_024 + 1) } }), code: "upstream_too_large", status: 502, publicStatus: "offline" }
  ];

  for (const scenario of failures) {
    it(`maps ${scenario.label} to a compact fault without upstream detail`, async () => {
      const fetcher = vi.fn(async () => scenario.response()) as unknown as typeof fetch;
      const fault = await faultOf(fetchOdptJSON(runtimeWith(fetcher), "odpt:Calendar"));

      expect(fault.code).toBe(scenario.code);
      expect(fault.httpStatus).toBe(scenario.status);
      expect(fault.publicStatus).toBe(scenario.publicStatus);
      expect(JSON.stringify({ message: fault.message, public: fault.publicMessage })).not.toContain(TOKEN);
      expect(JSON.stringify({ message: fault.message, public: fault.publicMessage })).not.toContain("odpt.org");
    });
  }

  it("treats 404 as no records", async () => {
    const fetcher = vi.fn(async () => new Response("{}", { status: 404 })) as unknown as typeof fetch;
    await expect(fetchOdptJSON(runtimeWith(fetcher), "odpt:TrainTimetable", { "odpt:railway": ALPHA })).resolves.toEqual([]);
  });

  it("stops reading a streamed body that exceeds the ceiling", async () => {
    const chunk = new Uint8Array(1_024 * 1_024).fill(0x20);
    let delivered = 0;
    const body = new ReadableStream<Uint8Array>({
      pull(controller) {
        delivered += 1;
        controller.enqueue(chunk);
        if (delivered > 20) controller.close();
      }
    });
    const fetcher = vi.fn(async () => new Response(body, { status: 200 })) as unknown as typeof fetch;
    const fault = await faultOf(fetchOdptJSON(runtimeWith(fetcher), "odpt:Calendar"));

    expect(fault.code).toBe("upstream_too_large");
    expect(delivered).toBeLessThan(20);
  });

  it("aborts a stalled upstream and reports a timeout", async () => {
    let aborted = false;
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const body = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new TextEncoder().encode("["));
          init?.signal?.addEventListener("abort", () => {
            aborted = true;
            controller.error(new DOMException("aborted", "AbortError"));
          }, { once: true });
        }
      });
      return new Response(body, { status: 200 });
    }) as unknown as typeof fetch;

    const fault = await faultOf(fetchOdptJSON(runtimeWith(fetcher, { timeoutMilliseconds: 40 }), "odpt:Calendar"));
    expect(aborted).toBe(true);
    expect(fault.code).toBe("upstream_timeout");
  });

  it("reports a network failure without the exception text", async () => {
    const fetcher = vi.fn(async () => { throw new TypeError(`connect failed for https://api.odpt.org/?acl:consumerKey=${TOKEN}`); }) as unknown as typeof fetch;
    const fault = await faultOf(fetchOdptJSON(runtimeWith(fetcher), "odpt:Calendar"));

    expect(fault.code).toBe("upstream_network_error");
    expect(JSON.stringify(fault.publicMessage)).not.toContain(TOKEN);
    expect(fault.message).not.toContain(TOKEN);
  });
});

describe("railway list configuration", () => {
  it("defaults to the Shinkansen railway ids the app guessed", () => {
    expect(parseRailwayList(undefined)).toEqual([...DEFAULT_ODPT_RAILWAYS]);
    expect(parseRailwayList("  ")).toEqual([...DEFAULT_ODPT_RAILWAYS]);
    expect(DEFAULT_ODPT_RAILWAYS).toContain("odpt.Railway:JR-Central.TokaidoShinkansen");
    expect(DEFAULT_ODPT_RAILWAYS).toHaveLength(10);
  });

  it("accepts an explicit comma-separated override and drops duplicates", () => {
    expect(parseRailwayList(`${ALPHA}, ${BETA},${ALPHA}`)).toEqual([ALPHA, BETA]);
  });

  it("rejects values that are not odpt.Railway ids", () => {
    expect(() => parseRailwayList("odpt.Station:JR-East.Yamanote.Tokyo")).toThrow(RangeError);
    expect(() => parseRailwayList("odpt.Railway:../../etc")).toThrow(RangeError);
    expect(() => parseRailwayList("odpt.Railway:a b")).toThrow(RangeError);
  });
});

describe("station normalization", () => {
  it("reads titles, coordinates, and codes", () => {
    expect(normalizeStation({
      "owl:sameAs": TOKYO,
      "odpt:stationTitle": { ja: "東京", en: "Tokyo" },
      "odpt:railway": ALPHA,
      "geo:lat": 35.681,
      "geo:long": 139.767,
      "odpt:stationCode": "TK01"
    })).toEqual({
      id: TOKYO,
      name: { ja: "東京", en: "Tokyo" },
      latitude: 35.681,
      longitude: 139.767,
      code: "TK01",
      railway: ALPHA
    });
  });

  it("drops coordinates outside Japan but keeps the station", () => {
    expect(normalizeStation(odptStation(TOKYO, ALPHA, "東京", "Tokyo", 0, 0))).toEqual({
      id: TOKYO,
      name: { ja: "東京", en: "Tokyo" },
      railway: ALPHA
    });
  });

  it("falls back to dc:title and rejects records without an id or name", () => {
    expect(normalizeStation({ "@id": "urn:ucode:_00001", "dc:title": "新大阪" })?.name).toEqual({ ja: "新大阪" });
    expect(normalizeStation({ "owl:sameAs": TOKYO })).toBeNull();
    expect(normalizeStation({ "odpt:stationTitle": { ja: "東京" } })).toBeNull();
    expect(normalizeStation({ "owl:sameAs": "bad id with spaces", "dc:title": "x" })).toBeNull();
    expect(normalizeStation("nope")).toBeNull();
  });
});

describe("calendar normalization", () => {
  it("keeps explicit dates from specific calendars and ignores unusable ones", () => {
    const rules = normalizeCalendars([
      { "owl:sameAs": "odpt.Calendar:Specific.Test.A", "odpt:day": ["2026-12-30", "2026-12-31", "2026-02-30", "bogus"] },
      { "owl:sameAs": "odpt.Calendar:Specific.Test.B", "odpt:day": "2027-01-02" },
      { "owl:sameAs": "odpt.Calendar:Weekday" },
      { "owl:sameAs": "odpt.Calendar:Specific.Test.C", "odpt:day": ["1999-01-01"] },
      "not a record"
    ]);

    expect(rules.get("odpt.Calendar:Specific.Test.A")).toEqual({ kind: "dates", dates: ["2026-12-30", "2026-12-31"] });
    expect(rules.get("odpt.Calendar:Specific.Test.B")).toEqual({ kind: "dates", dates: ["2027-01-02"] });
    expect(rules.has("odpt.Calendar:Weekday")).toBe(false);
    expect(rules.has("odpt.Calendar:Specific.Test.C")).toBe(false);
  });
});

describe("midnight handling", () => {
  const times = (...values: Array<[number | undefined, number | undefined]>): FeedStop[] =>
    values.map(([arrival, departure], index) => ({
      stationId: `station-${index}`,
      ...(arrival === undefined ? {} : { arrival }),
      ...(departure === undefined ? {} : { departure })
    }));

  it("keeps a daytime run unchanged", () => {
    const stops = times([undefined, 540], [600, 601], [660, undefined]);
    expect(rollPastMidnight(stops)).toBe(true);
    expect(stops.map((stop) => [stop.arrival, stop.departure])).toEqual([[undefined, 540], [600, 601], [660, undefined]]);
  });

  it("carries a run across midnight", () => {
    const stops = times([undefined, 23 * 60 + 50], [10, 11], [40, undefined]);
    expect(rollPastMidnight(stops)).toBe(true);
    expect(stops.map((stop) => [stop.arrival, stop.departure])).toEqual([
      [undefined, 1_430],
      [1_450, 1_451],
      [1_480, undefined]
    ]);
  });

  it("treats times before 04:00 as after midnight of the service day", () => {
    const stops = times([undefined, 25], [55, undefined]);
    expect(rollPastMidnight(stops)).toBe(true);
    expect(stops.map((stop) => [stop.arrival, stop.departure])).toEqual([[undefined, 1_465], [1_495, undefined]]);
  });

  it("accepts times already written past 24:00", () => {
    const stops = times([undefined, 24 * 60 + 5], [24 * 60 + 40, undefined]);
    expect(rollPastMidnight(stops)).toBe(true);
    expect(stops[1]!.arrival).toBe(1_480);
  });

  it("rejects a time that goes backwards by hours instead of crossing midnight", () => {
    expect(rollPastMidnight(times([undefined, 600], [300, undefined]))).toBe(false);
    expect(rollPastMidnight(times([undefined, 659], [658, 650], [700, undefined]))).toBe(false);
  });

  it("rejects a trip that spans more than 30 hours", () => {
    expect(rollPastMidnight(times([undefined, 300], [900, 901], [1_700, 1_701], [2_300, undefined]))).toBe(false);
  });
});

describe("timetable normalization", () => {
  const context = (overrides: { railway?: string; calendars?: ReadonlyMap<string, CalendarRule> } = {}) => ({
    railway: overrides.railway ?? ALPHA,
    stationIds: new Set([TOKYO, NAGOYA, SHIN_OSAKA]),
    calendars: overrides.calendars ?? new Map<string, CalendarRule>([[WEEKDAY, { kind: "days", dayClasses: ["weekday"] }]]),
    seen: new Set<string>()
  });
  const base = () => odptTimetable({
    railway: ALPHA,
    number: "231A",
    valid: "2026-12-31T14:59:00Z",
    stops: [
      { station: TOKYO, departure: "09:21", platform: "14" },
      { station: NAGOYA, arrival: "10:58", departure: "10:59" },
      { station: SHIN_OSAKA, arrival: "11:48", platform: "25" }
    ]
  });

  it("maps a valid timetable into a feed trip", () => {
    const result = normalizeTimetable(base(), context());

    expect(result.trip).toEqual({
      sourceId: "odpt.TrainTimetable:Test-Central.AlphaShinkansen.231A.Weekday",
      trainNumber: "231A",
      name: { ja: "のぞみ", en: "Nozomi" },
      category: "Nozomi",
      operator: "odpt.Operator:Test-Central",
      lineIds: [ALPHA],
      calendar: WEEKDAY,
      validUntil: "2026-12-31",
      stops: [
        { stationId: TOKYO, departure: 561, platform: "14" },
        { stationId: NAGOYA, arrival: 658, departure: 659 },
        { stationId: SHIN_OSAKA, arrival: 708, platform: "25" }
      ]
    });
  });

  it("accepts a plain-string train name and tolerates null times", () => {
    const raw = base() as Record<string, unknown>;
    raw["odpt:trainName"] = "ひかり";
    (raw["odpt:trainTimetableObject"] as Array<Record<string, unknown>>)[0]!["odpt:arrivalTime"] = null;

    const result = normalizeTimetable(raw, context());
    expect(result.trip?.name).toEqual({ ja: "ひかり" });
    expect(result.trip?.stops[0]).toEqual({ stationId: TOKYO, departure: 561, platform: "14" });
  });

  it("skips stops that have no times and uses the departure platform first", () => {
    const raw = base() as Record<string, unknown>;
    const stops = raw["odpt:trainTimetableObject"] as Array<Record<string, unknown>>;
    stops.splice(1, 0, { "odpt:departureStation": "odpt.Station:somewhere" });
    stops[2]!["odpt:departurePlatformNumber"] = "7";
    stops[2]!["odpt:arrivalPlatformNumber"] = "8";

    const result = normalizeTimetable(raw, context());
    expect(result.trip?.stops.map((stop) => stop.stationId)).toEqual([TOKYO, NAGOYA, SHIN_OSAKA]);
    expect(result.trip?.stops[1]?.platform).toBe("7");
  });

  it("ignores a validity it cannot read, leaving the default horizon to apply", () => {
    const raw = { ...base(), "dct:valid": "soon" };
    expect(normalizeTimetable(raw, context()).trip?.validUntil).toBeUndefined();
  });

  const rejections: Array<{ label: string; reason: string; mutate: (raw: Record<string, any>) => void }> = [
    { label: "a missing id", reason: "invalid_id", mutate: (raw) => { delete raw["owl:sameAs"]; delete raw["@id"]; } },
    { label: "an id with unsafe characters", reason: "invalid_id", mutate: (raw) => { raw["owl:sameAs"] = "odpt.TrainTimetable:../x y"; } },
    { label: "a different railway", reason: "railway_mismatch", mutate: (raw) => { raw["odpt:railway"] = BETA; } },
    { label: "a missing operator", reason: "missing_operator", mutate: (raw) => { delete raw["odpt:operator"]; } },
    { label: "a missing train number", reason: "missing_train_number", mutate: (raw) => { delete raw["odpt:trainNumber"]; } },
    { label: "an unknown calendar", reason: "unsupported_calendar", mutate: (raw) => { raw["odpt:calendar"] = "odpt.Calendar:Unheard"; } },
    { label: "a missing calendar", reason: "unsupported_calendar", mutate: (raw) => { delete raw["odpt:calendar"]; } },
    { label: "a single stop", reason: "too_few_stops", mutate: (raw) => { raw["odpt:trainTimetableObject"] = raw["odpt:trainTimetableObject"].slice(0, 1); } },
    { label: "an unreadable time", reason: "invalid_time", mutate: (raw) => { raw["odpt:trainTimetableObject"][1]["odpt:arrivalTime"] = "late"; } },
    { label: "a time past 29:59", reason: "invalid_time", mutate: (raw) => { raw["odpt:trainTimetableObject"][1]["odpt:arrivalTime"] = "31:00"; } },
    { label: "an unknown station", reason: "unknown_station", mutate: (raw) => { raw["odpt:trainTimetableObject"][1]["odpt:departureStation"] = "odpt.Station:Elsewhere"; raw["odpt:trainTimetableObject"][1]["odpt:arrivalStation"] = "odpt.Station:Elsewhere"; } },
    { label: "mismatched arrival and departure stations", reason: "invalid_stop", mutate: (raw) => { raw["odpt:trainTimetableObject"][1]["odpt:arrivalStation"] = TOKYO; } },
    { label: "a stop with times but no station", reason: "invalid_stop", mutate: (raw) => { delete raw["odpt:trainTimetableObject"][1]["odpt:departureStation"]; delete raw["odpt:trainTimetableObject"][1]["odpt:arrivalStation"]; } },
    { label: "a non-object stop", reason: "invalid_stop", mutate: (raw) => { raw["odpt:trainTimetableObject"][1] = "stop"; } },
    { label: "times that run backwards", reason: "non_monotonic", mutate: (raw) => { raw["odpt:trainTimetableObject"][2]["odpt:arrivalTime"] = "06:00"; } },
    { label: "too many stops", reason: "too_many_stops", mutate: (raw) => { raw["odpt:trainTimetableObject"] = Array.from({ length: 121 }, () => raw["odpt:trainTimetableObject"][1]); } }
  ];

  for (const scenario of rejections) {
    it(`rejects ${scenario.label}`, () => {
      const raw = JSON.parse(JSON.stringify(base())) as Record<string, any>;
      scenario.mutate(raw);
      expect(normalizeTimetable(raw, context()).reject).toBe(scenario.reason);
    });
  }

  it("rejects a record that is not an object", () => {
    expect(normalizeTimetable(null, context()).reject).toBe("invalid_record");
    expect(normalizeTimetable([], context()).reject).toBe("invalid_record");
  });

  it("reports the calendar id it could not interpret", () => {
    const raw = { ...base(), "odpt:calendar": "odpt.Calendar:Unheard" };
    expect(normalizeTimetable(raw, context())).toEqual({ reject: "unsupported_calendar", detail: "odpt.Calendar:Unheard" });
  });

  it("rejects a repeated timetable without letting a rejected one poison later ones", () => {
    const shared = context();
    expect(normalizeTimetable(base(), shared).trip).toBeDefined();
    expect(normalizeTimetable(base(), shared).reject).toBe("duplicate");

    const second = context();
    const broken = { ...base(), "odpt:trainNumber": undefined };
    expect(normalizeTimetable(broken, second).reject).toBe("missing_train_number");
    expect(normalizeTimetable(base(), second).trip).toBeDefined();
  });

  it("interprets a late-night run as ending after midnight", () => {
    const raw = odptTimetable({
      railway: ALPHA,
      number: "99",
      stops: [{ station: TOKYO, departure: "23:20" }, { station: SHIN_OSAKA, arrival: "01:30" }]
    });
    expect(normalizeTimetable(raw, context()).trip?.stops.map((stop) => stop.departure ?? stop.arrival)).toEqual([1_400, 1_530]);
  });

  it("derives a category from the train type id", () => {
    const raw = { ...base(), "odpt:trainType": "odpt.TrainType:JR-Central.Hikari" };
    expect(normalizeTimetable(raw, context()).trip?.category).toBe("Hikari");
  });
});

describe("fetching a feed", () => {
  it("reads small resources for every railway before any timetable, one timetable at a time", async () => {
    const odpt = fakeOdpt(odptNetwork(12));
    const result = await fetchOdptFeed({ fetcher: odpt.fetcher, token: TOKEN }, [ALPHA, BETA]);

    const sequence = odpt.requests.map((request) => `${request.resource}${request.filter ? ` ${request.filter}` : ""}`);
    expect(sequence).toEqual([
      "odpt:Calendar",
      `odpt:Railway ${ALPHA}`,
      `odpt:Station ${ALPHA}`,
      `odpt:Railway ${BETA}`,
      `odpt:Station ${BETA}`,
      `odpt:TrainTimetable ${ALPHA}`,
      `odpt:TrainTimetable ${BETA}`
    ]);
    expect(odpt.requests.every((request) => request.tokenSeen === TOKEN)).toBe(true);

    expect(result.feed.trips).toHaveLength(24);
    expect(result.feed.lines.map((line) => line.id)).toEqual([ALPHA, BETA]);
    expect(result.feed.lines[0]).toEqual({
      id: ALPHA,
      name: { ja: "アルファ新幹線", en: "Alpha Shinkansen" },
      operator: "odpt.Operator:Test-Central"
    });
    expect(result.feed.calendars).toEqual({ [WEEKDAY]: { kind: "days", dayClasses: ["weekday"] } });
    expect(result.reports).toEqual([
      { railway: ALPHA, railwayFound: true, stations: 3, timetables: 12, trips: 12, rejected: {}, unsupportedCalendars: [] },
      { railway: BETA, railwayFound: true, stations: 2, timetables: 12, trips: 12, rejected: {}, unsupportedCalendars: [] }
    ]);
    expect(result.timetables).toBe(24);
    expect(result.rejected).toBe(0);
  });

  it("resolves a station that belongs to a neighbouring railway", async () => {
    const data = odptNetwork(1);
    data.timetables![ALPHA] = [odptTimetable({
      railway: ALPHA,
      number: "301",
      stops: [{ station: TOKYO, departure: "10:00" }, { station: HAKATA, arrival: "15:20" }]
    })];
    const odpt = fakeOdpt(data);
    const result = await fetchOdptFeed({ fetcher: odpt.fetcher, token: TOKEN }, [ALPHA, BETA]);

    expect(result.feed.trips.filter((trip) => trip.lineIds[0] === ALPHA)).toHaveLength(1);
  });

  it("combines generic calendars with specific ones and keeps only calendars that trips use", async () => {
    const data = odptNetwork(1);
    data.calendars = [{ "owl:sameAs": "odpt.Calendar:Specific.Test.Extra", "odpt:day": ["2026-10-09"] }];
    data.timetables![ALPHA] = [
      odptTimetable({ railway: ALPHA, number: "1", stops: [{ station: TOKYO, departure: "09:00" }, { station: SHIN_OSAKA, arrival: "11:30" }] }),
      odptTimetable({ railway: ALPHA, number: "2", calendar: SATURDAY_HOLIDAY, stops: [{ station: TOKYO, departure: "09:00" }, { station: SHIN_OSAKA, arrival: "11:30" }] }),
      odptTimetable({ railway: ALPHA, number: "3", calendar: "odpt.Calendar:Specific.Test.Extra", stops: [{ station: TOKYO, departure: "09:00" }, { station: SHIN_OSAKA, arrival: "11:30" }] }),
      odptTimetable({ railway: ALPHA, number: "4", calendar: "odpt.Calendar:Specific.Test.Missing", stops: [{ station: TOKYO, departure: "09:00" }, { station: SHIN_OSAKA, arrival: "11:30" }] })
    ];
    const result = await fetchOdptFeed({ fetcher: fakeOdpt(data).fetcher, token: TOKEN }, [ALPHA]);

    expect(Object.keys(result.feed.calendars).sort()).toEqual([
      "odpt.Calendar:SaturdayHoliday",
      "odpt.Calendar:Specific.Test.Extra",
      "odpt.Calendar:Weekday"
    ]);
    expect(result.reports[0]?.rejected).toEqual({ unsupported_calendar: 1 });
    expect(result.reports[0]?.unsupportedCalendars).toEqual(["odpt.Calendar:Specific.Test.Missing"]);
  });

  it("reports what a source without Shinkansen data returns: nothing, railway by railway", async () => {
    const odpt = fakeOdpt({});
    const result = await fetchOdptFeed({ fetcher: odpt.fetcher, token: TOKEN }, [...DEFAULT_ODPT_RAILWAYS]);

    expect(result.feed.trips).toEqual([]);
    expect(result.feed.stations).toEqual([]);
    expect(result.reports).toHaveLength(10);
    expect(result.reports.every((report) => !report.railwayFound && report.timetables === 0 && report.trips === 0)).toBe(true);
    // The line is still named so a report can say which railway had no data.
    expect(result.feed.lines[0]?.name).toEqual({ ja: "JR-Central.TokaidoShinkansen" });
    expect(result.feed.lines[0]?.operator).toBe("odpt.Operator:JR-Central");
  });

  it("counts rejected timetables per railway", async () => {
    const data = odptNetwork(2);
    (data.timetables![ALPHA] as Array<Record<string, unknown>>)[0]!["odpt:trainNumber"] = undefined;
    const result = await fetchOdptFeed({ fetcher: fakeOdpt(data).fetcher, token: TOKEN }, [ALPHA]);

    expect(result.reports[0]).toMatchObject({ timetables: 2, trips: 1, rejected: { missing_train_number: 1 } });
    expect(result.rejected).toBe(1);
  });

  it("fails the whole fetch when any resource fails", async () => {
    const odpt = fakeOdpt({ ...odptNetwork(2), status: (resource) => resource === "odpt:TrainTimetable" ? 503 : undefined });
    const fault = await faultOf(fetchOdptFeed({ fetcher: odpt.fetcher, token: TOKEN }, [ALPHA]));
    expect(fault.code).toBe("upstream_unavailable");
  });
});

describe("line-level operation information", () => {
  const now = new Date("2026-10-08T00:00:00Z");

  it("maps a suspension to a major notice with English text", () => {
    const notice = normalizeTrainInformation({
      "owl:sameAs": "odpt.TrainInformation:Test.Alpha.1",
      "odpt:timeOfOrigin": "2026-10-07T23:40:00+09:00",
      "odpt:trainInformationStatus": { ja: "運転見合わせ", en: "Suspended" },
      "odpt:trainInformationText": { ja: "強風のため運転を見合わせています。", en: "Service is suspended because of strong winds." },
      "odpt:trainInformationCause": { ja: "強風", en: "Strong winds" }
    }, ALPHA, now);

    expect(notice).toEqual({
      id: "odpt.TrainInformation:Test.Alpha.1",
      lineId: ALPHA,
      title: "Suspended",
      detail: "Service is suspended because of strong winds. Cause: Strong winds",
      severity: "major",
      reportedAt: "2026-10-07T14:40:00.000Z",
      scope: "line"
    });
  });

  it("maps a delay to a watch notice and falls back to Japanese text", () => {
    const notice = normalizeTrainInformation({
      "odpt:trainInformationStatus": { ja: "遅延" },
      "odpt:trainInformationText": { ja: "一部列車に遅れが出ています。" }
    }, ALPHA, now);

    expect(notice).toMatchObject({ title: "遅延", detail: "一部列車に遅れが出ています。", severity: "watch" });
    expect(notice?.id).toBe(`${ALPHA}:遅延`);
  });

  it("drops normal-service notices, expired notices, and empty records", () => {
    expect(normalizeTrainInformation({ "odpt:trainInformationStatus": { ja: "平常運転", en: "Normal service" } }, ALPHA, now)).toBeNull();
    expect(normalizeTrainInformation({
      "odpt:trainInformationStatus": { en: "Delay" },
      "dct:valid": "2026-10-07T23:00:00Z"
    }, ALPHA, now)).toBeNull();
    expect(normalizeTrainInformation({}, ALPHA, now)).toBeNull();
    expect(normalizeTrainInformation("nope", ALPHA, now)).toBeNull();
  });

  it("keeps a notice whose status looks normal but whose text reports a suspension", () => {
    const notice = normalizeTrainInformation({
      "odpt:trainInformationStatus": { en: "Service suspended; normal service expected tomorrow" }
    }, ALPHA, now);
    expect(notice?.severity).toBe("major");
  });
});
