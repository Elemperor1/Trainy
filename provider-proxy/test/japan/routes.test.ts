import { describe, expect, it, vi } from "vitest";
import { handleRequest } from "../../src/handler";
import type { LastRunRecord } from "../../src/japan/contracts";
import { validatedLineID, validatedStationID } from "../../src/japan/contracts";
import { tripIDFromPath } from "../../src/japan/routes";
import type { NormalizedFeed } from "../../src/japan/snapshot";
import { LAST_RUN_KEY, MANIFEST_KEY } from "../../src/japan/store";
import {
  ALPHA,
  BETA,
  fakeOdpt,
  type FakeOdptData,
  FakeKV,
  fixtureFeed,
  GENERATED_AT,
  HAKATA,
  harness,
  NAGOYA,
  NOW,
  odptNetwork,
  SHIN_OSAKA,
  seed,
  stop,
  TOKEN,
  TOKYO,
  trip
} from "./support";

type HarnessOptions = NonNullable<Parameters<typeof harness>[0]>;
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Json = any;

async function scenario(options: HarnessOptions & { feed?: NormalizedFeed; seeded?: boolean; generatedAt?: Date } = {}) {
  const kv = options.kv === undefined ? new FakeKV() : options.kv;
  if (kv && options.seeded !== false) {
    await seed(kv, options.feed, { generatedAt: options.generatedAt });
    kv.operations.length = 0; // tests observe what requests do, not how the fixture was written
  }
  const h = harness({ ...options, kv });
  async function request(path: string, init?: RequestInit) {
    const response = await handleRequest(new Request(`https://proxy.example${path}`, init), h.env, h.context, h.dependencies);
    await h.drain();
    const text = await response.text();
    return { response, status: response.status, text, body: JSON.parse(text) as Json };
  }
  return { ...h, kv, request };
}

const q = encodeURIComponent;
const ALPHA_SLUG = "Test-Central.AlphaShinkansen";
const BETA_SLUG = "Test-West.BetaShinkansen";
const ID = (calendar: string, train: string) => `${ALPHA_SLUG}~${calendar}~${train}`;

const TOKYO_STOP = { stationId: TOKYO, name: "東京", nameEn: "Tokyo" };
const NAGOYA_STOP = { stationId: NAGOYA, name: "名古屋", nameEn: "Nagoya" };
const OSAKA_STOP = { stationId: SHIN_OSAKA, name: "新大阪", nameEn: "Shin-Osaka" };
const HAKATA_STOP = { stationId: HAKATA, name: "博多", nameEn: "Hakata" };
const ALPHA_LINE = { id: ALPHA, name: "アルファ新幹線", nameEn: "Alpha Shinkansen", operator: "Test Central" };
const BETA_LINE = { id: BETA, name: "ベータ新幹線", nameEn: "Beta Shinkansen", operator: "Test West" };

const summary = (body: Json) => (body.data.trips as Json[]).map((item) => `${item.trainNumber}@${(item.from.departureAt as string).slice(11, 16)}`);
const TOKYO_TO_OSAKA = `/v1/japan/trips?from=${q(TOKYO)}&to=${q(SHIN_OSAKA)}`;

// ---------------------------------------------------------------------------
// Station search
// ---------------------------------------------------------------------------

describe("GET /v1/japan/stations", () => {
  it("finds a station by its English or Japanese name and returns its details", async () => {
    const s = await scenario();
    const english = await s.request("/v1/japan/stations?query=tokyo");
    const japanese = await s.request(`/v1/japan/stations?query=${q("東京")}`);

    const tokyo = { id: TOKYO, name: "東京", nameEn: "Tokyo", latitude: 35.681, longitude: 139.767, code: "TK01", lineIds: [ALPHA] };
    expect(english.status).toBe(200);
    expect(english.body.data.stations).toEqual([tokyo]);
    expect(japanese.body.data.stations).toEqual([tokyo]);
  });

  it("ignores case, spacing, hyphens, accents, and full-width letters", async () => {
    const s = await scenario();
    for (const query of ["Shin Osaka", "shin-osaka", "SHINOSAKA", "ｓｈｉｎ－ｏｓａｋａ"]) {
      const result = await s.request(`/v1/japan/stations?query=${q(query)}`);
      expect((result.body.data.stations as Json[]).map((station) => station.id)).toEqual([SHIN_OSAKA]);
    }
    const accented = await s.request(`/v1/japan/stations?query=${q("Tōkyō")}`);
    expect((accented.body.data.stations as Json[]).map((station) => station.id)).toEqual([TOKYO]);
  });

  it("matches a station code", async () => {
    const s = await scenario();
    const result = await s.request("/v1/japan/stations?query=tk01");
    expect((result.body.data.stations as Json[]).map((station) => station.id)).toEqual([TOKYO]);
  });

  it("names a station's own line even when through trains from other lines call there", async () => {
    const s = await scenario();
    const result = await s.request("/v1/japan/stations?query=hakata");
    expect(result.body.data.stations[0].lineIds).toEqual([BETA]);
  });

  it("ranks an exact name first, then names that start with the query, then the rest", async () => {
    const station = (slug: string, ja: string, en: string) => ({ id: `odpt.Station:Test-Central.AlphaShinkansen.${slug}`, name: { ja, en }, railway: ALPHA });
    const stations = [station("Kyoto", "京都", "Kyoto"), station("ShinOsaka2", "新大阪", "Shin-Osaka"), station("OsakaJo", "大阪城", "Osaka-jo"), station("Osaka", "大阪", "Osaka")];
    const feed: NormalizedFeed = {
      ...fixtureFeed(),
      stations,
      trips: [trip({
        trainNumber: "1",
        stops: [
          stop(stations[0]!.id, null, "09:00"), stop(stations[1]!.id, "09:10", "09:11"),
          stop(stations[2]!.id, "09:20", "09:21"), stop(stations[3]!.id, "09:30", null)
        ]
      })]
    };
    const s = await scenario({ feed });

    const english = await s.request("/v1/japan/stations?query=osaka");
    expect((english.body.data.stations as Json[]).map((item) => item.nameEn)).toEqual(["Osaka", "Osaka-jo", "Shin-Osaka"]);
    const japanese = await s.request(`/v1/japan/stations?query=${q("大阪")}`);
    expect((japanese.body.data.stations as Json[]).map((item) => item.name)).toEqual(["大阪", "大阪城", "新大阪"]);
  });

  it("honors the limit and answers an unmatched search with an empty list", async () => {
    const s = await scenario();
    const all = await s.request("/v1/japan/stations?query=ka");
    expect((all.body.data.stations as Json[]).map((station) => station.nameEn)).toEqual(["Hakata", "Shin-Osaka"]);
    const limited = await s.request("/v1/japan/stations?query=ka&limit=1");
    expect((limited.body.data.stations as Json[]).map((station) => station.nameEn)).toEqual(["Hakata"]);

    const none = await s.request("/v1/japan/stations?query=zzzz");
    expect(none.status).toBe(200);
    expect(none.body.data.stations).toEqual([]);
  });

  it("describes the snapshot it answered from", async () => {
    const s = await scenario();
    const { body, response } = await s.request("/v1/japan/stations?query=tokyo");

    expect(body.meta).toEqual({
      provider: "japan",
      source: "Public Transportation Open Data Center (ODPT)",
      attribution: "Timetable data from the Public Transportation Open Data Center (ODPT).",
      license: "odpt-basic",
      snapshotId: "snap-fixture",
      fetchedAt: "2026-10-07T18:10:00.000Z",
      expiresAt: "2026-10-09T06:10:00.000Z",
      freshness: "fresh",
      cacheStatus: "hit",
      coverage: { from: "2026-10-07", until: "2026-10-21" }
    });
    expect(body.requestId).toBe("request-fixture");
    expect(response.headers.get("x-trainy-cache")).toBe("hit");
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("content-type")).toBe("application/json; charset=utf-8");
    expect(response.headers.get("x-content-type-options")).toBe("nosniff");
  });

  it("labels a snapshot older than 36 hours as stale while it still answers", async () => {
    const s = await scenario({ now: () => new Date("2026-10-09T07:00:00Z") });
    const { body, response } = await s.request("/v1/japan/stations?query=tokyo");

    expect(response.status).toBe(200);
    expect(body.meta).toMatchObject({ freshness: "stale", cacheStatus: "stale-fallback", fetchedAt: "2026-10-07T18:10:00.000Z" });
    expect(response.headers.get("x-trainy-cache")).toBe("stale-fallback");
  });

  it.each([
    ["no query", "/v1/japan/stations", "invalid_query"],
    ["a one-character query", "/v1/japan/stations?query=a", "invalid_query"],
    ["a control character", `/v1/japan/stations?query=to${q("\n")}ky`, "invalid_query"],
    ["a limit of zero", "/v1/japan/stations?query=tokyo&limit=0", "invalid_limit"],
    ["a limit over 25", "/v1/japan/stations?query=tokyo&limit=26", "invalid_limit"],
    ["an unknown parameter", "/v1/japan/stations?query=tokyo&sort=name", "unsupported_parameter"],
    ["a repeated parameter", "/v1/japan/stations?query=tokyo&query=osaka", "duplicate_parameter"]
  ])("rejects %s before reading any data", async (_name, path, code) => {
    const s = await scenario();
    const operationsBefore = s.kv!.operations.length;
    const result = await s.request(path);

    expect(result.status).toBe(400);
    expect(result.body).toMatchObject({ provider_id: "japan", status: "invalidRequest", error: { code } });
    expect(s.kv!.operations.length).toBe(operationsBefore);
  });
});

// ---------------------------------------------------------------------------
// Trip search
// ---------------------------------------------------------------------------

describe("GET /v1/japan/trips", () => {
  it("lists the trains that run between two stations on a weekday, in departure order", async () => {
    const s = await scenario();
    const { body, status } = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);

    expect(status).toBe(200);
    expect(body.data.serviceDate).toBe("2026-10-08");
    expect(summary(body)).toEqual(["1@06:00", "101@06:30", "3@07:00", "301@10:00", "99@23:20"]);
  });

  it("describes each train, its whole run, and the requested part of it", async () => {
    const s = await scenario();
    const { body } = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08&limit=1`);

    expect(body.data.trips).toEqual([{
      id: ID("Weekday", "1"),
      serviceDate: "2026-10-08",
      trainNumber: "1",
      trainName: "のぞみ",
      trainNameEn: "Nozomi",
      category: "Nozomi",
      operator: "Test Central",
      lines: [ALPHA_LINE],
      origin: { ...TOKYO_STOP, departureAt: "2026-10-08T06:00:00+09:00", platform: "14" },
      destination: { ...OSAKA_STOP, arrivalAt: "2026-10-08T08:30:00+09:00", platform: "25" },
      from: { ...TOKYO_STOP, departureAt: "2026-10-08T06:00:00+09:00", platform: "14" },
      to: { ...OSAKA_STOP, arrivalAt: "2026-10-08T08:30:00+09:00", platform: "25" }
    }]);
  });

  it("separates the requested leg from the whole run for a trip joined midway", async () => {
    const s = await scenario();
    const { body } = await s.request(`/v1/japan/trips?from=${q(NAGOYA)}&to=${q(SHIN_OSAKA)}&date=2026-10-08&after=08:00`);

    const first = body.data.trips[0];
    expect(first.trainNumber).toBe("3");
    expect(first.origin.stationId).toBe(TOKYO);
    expect(first.from).toEqual({ ...NAGOYA_STOP, departureAt: "2026-10-08T08:37:00+09:00", platform: "16" });
    expect(first.to).toEqual({ ...OSAKA_STOP, arrivalAt: "2026-10-08T09:30:00+09:00", platform: "25" });
  });

  it("reports an arrival after midnight on the next calendar day", async () => {
    const s = await scenario();
    const { body } = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08&after=23:00`);

    expect(summary(body)).toEqual(["99@23:20"]);
    expect(body.data.trips[0].to.arrivalAt).toBe("2026-10-09T01:30:00+09:00");
    expect(body.data.trips[0].serviceDate).toBe("2026-10-08");
  });

  it("filters by earliest departure, keeping a train that leaves exactly then", async () => {
    const s = await scenario();
    const seven = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08&after=07:00`);
    expect(summary(seven.body)).toEqual(["3@07:00", "301@10:00", "99@23:20"]);

    const none = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08&after=24:00`);
    expect(none.body.data.trips).toEqual([]);
  });

  it("honors the limit", async () => {
    const s = await scenario();
    const { body } = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08&limit=2`);
    expect(summary(body)).toEqual(["1@06:00", "101@06:30"]);
  });

  it("finds a through train once even though it is stored on two lines", async () => {
    const s = await scenario();
    const { body } = await s.request(`/v1/japan/trips?from=${q(SHIN_OSAKA)}&to=${q(HAKATA)}&date=2026-10-08`);

    expect(summary(body)).toEqual(["301@12:33", "541@13:00"]);
    const through = body.data.trips[0];
    expect(through.id).toBe(ID("Weekday", "301"));
    expect(through.lines).toEqual([ALPHA_LINE, BETA_LINE]);
    expect(through.origin).toMatchObject({ ...TOKYO_STOP, departureAt: "2026-10-08T10:00:00+09:00" });
    expect(through.destination).toMatchObject({ ...HAKATA_STOP, arrivalAt: "2026-10-08T15:20:00+09:00" });
    expect(through.from.departureAt).toBe("2026-10-08T12:33:00+09:00");
    expect(through.to.arrivalAt).toBe("2026-10-08T15:20:00+09:00");
    expect(body.data.trips[1].operator).toBe("Test West");
  });

  it("answers in the right direction only", async () => {
    const s = await scenario();
    const reverse = await s.request(`/v1/japan/trips?from=${q(SHIN_OSAKA)}&to=${q(TOKYO)}&date=2026-10-08`);
    expect(reverse.status).toBe(200);
    expect(reverse.body.data.trips).toEqual([]);

    const skipped = await s.request(`/v1/japan/trips?from=${q(NAGOYA)}&to=${q(TOKYO)}&date=2026-10-08`);
    expect(skipped.body.data.trips).toEqual([]);
  });

  it("applies Saturday, Sunday, and national-holiday timetables", async () => {
    const s = await scenario();
    for (const date of ["2026-10-10", "2026-10-11", "2026-10-12"]) { // Saturday, Sunday, Sports Day
      const { body } = await s.request(`${TOKYO_TO_OSAKA}&date=${date}`);
      expect(summary(body), date).toEqual(["201@08:00"]);
      expect(body.data.trips[0].id).toBe(ID("SaturdayHoliday", "201"));
    }
    const tuesday = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-13`);
    expect(summary(tuesday.body)).toEqual(["1@06:00", "101@06:30", "3@07:00", "301@10:00", "99@23:20"]);
  });

  it("adds trains that run only on explicitly listed dates", async () => {
    const s = await scenario();
    const listed = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-09`);
    expect(summary(listed.body)).toEqual(["1@06:00", "101@06:30", "3@07:00", "301@10:00", "9001@12:00", "99@23:20"]);
    expect(listed.body.data.trips[4].id).toBe(ID("Specific.Test.Extra", "9001"));

    const unlisted = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    expect(summary(unlisted.body)).not.toContain("9001@12:00");
  });

  it("stops listing a train after the last date its source declares", async () => {
    const feed = fixtureFeed();
    feed.trips = feed.trips.map((item) => item.trainNumber === "3" ? { ...item, validUntil: "2026-10-09" } : item);
    const s = await scenario({ feed });

    const friday = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-09`);
    expect(summary(friday.body)).toContain("3@07:00");
    const tuesday = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-13`);
    expect(summary(tuesday.body)).not.toContain("3@07:00");
  });

  it("defaults to the current service date, which ends at 04:00 Japan time", async () => {
    const day = await scenario();
    expect((await day.request(TOKYO_TO_OSAKA)).body.data.serviceDate).toBe("2026-10-08");

    // 03:30 on October 8 still belongs to October 7's service day.
    const lateNight = await scenario({ now: () => new Date("2026-10-07T18:30:00Z") });
    expect((await lateNight.request(TOKYO_TO_OSAKA)).body.data.serviceDate).toBe("2026-10-07");
  });

  it("limits answers to the dates the snapshot covers", async () => {
    const s = await scenario();
    for (const date of ["2026-10-06", "2026-10-22", "2027-01-01"]) {
      const result = await s.request(`${TOKYO_TO_OSAKA}&date=${date}`);
      expect(result.status, date).toBe(400);
      expect(result.body.error).toMatchObject({ code: "date_out_of_range", message: "The timetable covers 2026-10-07 through 2026-10-21." });
    }
    expect((await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-07`)).status).toBe(200);
    expect((await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-21`)).status).toBe(200);
  });

  it("answers an unknown station with 404", async () => {
    const s = await scenario();
    const result = await s.request(`/v1/japan/trips?from=odpt.Station:Nope.X&to=${q(SHIN_OSAKA)}&date=2026-10-08`);
    expect(result.status).toBe(404);
    expect(result.body.error.code).toBe("station_not_found");

    const destination = await s.request(`/v1/japan/trips?from=${q(TOKYO)}&to=odpt.Station:Nope.X&date=2026-10-08`);
    expect(destination.body.error.code).toBe("station_not_found");
  });

  it.each([
    ["no origin", `/v1/japan/trips?to=${q(SHIN_OSAKA)}`, "invalid_station"],
    ["a malformed station", `/v1/japan/trips?from=${q("a b")}&to=${q(SHIN_OSAKA)}`, "invalid_station"],
    ["the same station twice", `/v1/japan/trips?from=${q(TOKYO)}&to=${q(TOKYO)}`, "invalid_station_pair"],
    ["a date that does not exist", `${TOKYO_TO_OSAKA}&date=2026-02-30`, "invalid_date"],
    ["a date in words", `${TOKYO_TO_OSAKA}&date=tomorrow`, "invalid_date"],
    ["a date outside the supported years", `${TOKYO_TO_OSAKA}&date=2100-01-01`, "invalid_date"],
    ["a time past 29:59", `${TOKYO_TO_OSAKA}&after=30:00`, "invalid_time"],
    ["a malformed time", `${TOKYO_TO_OSAKA}&after=8am`, "invalid_time"],
    ["a limit of 100", `${TOKYO_TO_OSAKA}&limit=100`, "invalid_limit"],
    ["an unknown parameter", `${TOKYO_TO_OSAKA}&via=Nagoya`, "unsupported_parameter"]
  ])("rejects %s", async (_name, path, code) => {
    const s = await scenario();
    const result = await s.request(path);
    expect(result.status).toBe(400);
    expect(result.body.error.code).toBe(code);
  });
});

describe("identifier bounds", () => {
  it("accepts every id that ingestion can publish, and nothing longer", () => {
    const longest = `odpt.Station:${"A".repeat(147)}`;
    expect(longest).toHaveLength(160);

    expect(validatedStationID(longest)).toBe(longest);
    expect(validatedLineID(longest)).toBe(longest);
    expect(() => validatedStationID(`${longest}A`)).toThrow();
    expect(() => validatedLineID(`${longest}A`)).toThrow();
  });
});

// ---------------------------------------------------------------------------
// Trip detail
// ---------------------------------------------------------------------------

describe("GET /v1/japan/trips/{id}", () => {
  it("returns every stop with its times and platform", async () => {
    const s = await scenario();
    const { status, body } = await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`);

    expect(status).toBe(200);
    expect(body.data.trip).toEqual({
      id: ID("Weekday", "1"),
      serviceDate: "2026-10-08",
      trainNumber: "1",
      trainName: "のぞみ",
      trainNameEn: "Nozomi",
      category: "Nozomi",
      operator: "Test Central",
      lines: [ALPHA_LINE],
      origin: { ...TOKYO_STOP, departureAt: "2026-10-08T06:00:00+09:00", platform: "14" },
      destination: { ...OSAKA_STOP, arrivalAt: "2026-10-08T08:30:00+09:00", platform: "25" },
      stops: [
        { ...TOKYO_STOP, departureAt: "2026-10-08T06:00:00+09:00", platform: "14" },
        { ...NAGOYA_STOP, arrivalAt: "2026-10-08T07:36:00+09:00", departureAt: "2026-10-08T07:37:00+09:00", platform: "16" },
        { ...OSAKA_STOP, arrivalAt: "2026-10-08T08:30:00+09:00", platform: "25" }
      ]
    });
    expect(body.meta).toMatchObject({ snapshotId: "snap-fixture", freshness: "fresh" });
  });

  it("accepts the id with its separators percent-encoded", async () => {
    const s = await scenario();
    const result = await s.request(`/v1/japan/trips/${ID("Weekday", "1").replaceAll("~", "%7E")}?date=2026-10-08`);
    expect(result.status).toBe(200);
    expect(result.body.data.trip.id).toBe(ID("Weekday", "1"));
  });

  it("defaults to today's service date", async () => {
    const s = await scenario();
    const result = await s.request(`/v1/japan/trips/${ID("Weekday", "1")}`);
    expect(result.body.data.trip.serviceDate).toBe("2026-10-08");
  });

  it("rolls a late-night run's later stops onto the next calendar day", async () => {
    const s = await scenario();
    const { body } = await s.request(`/v1/japan/trips/${ID("Weekday", "99")}?date=2026-10-08`);
    expect((body.data.trip.stops as Json[]).map((item) => item.arrivalAt ?? item.departureAt)).toEqual([
      "2026-10-08T23:20:00+09:00",
      "2026-10-09T01:30:00+09:00"
    ]);
  });

  it("finds a through train by its id and lists both of its lines", async () => {
    const s = await scenario();
    const { body } = await s.request(`/v1/japan/trips/${ID("Weekday", "301")}?date=2026-10-08`);
    expect(body.data.trip.lines).toEqual([ALPHA_LINE, BETA_LINE]);
    expect((body.data.trip.stops as Json[]).map((item) => item.stationId)).toEqual([TOKYO, NAGOYA, SHIN_OSAKA, HAKATA]);
  });

  it("answers 404 for a train that does not run on the requested date", async () => {
    const s = await scenario();
    const saturday = await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-10`);
    expect(saturday.status).toBe(404);
    expect(saturday.body.error.code).toBe("trip_not_running");

    const weekdayOnly = await s.request(`/v1/japan/trips/${ID("SaturdayHoliday", "201")}?date=2026-10-08`);
    expect(weekdayOnly.body.error.code).toBe("trip_not_running");

    const listedDay = await s.request(`/v1/japan/trips/${ID("Specific.Test.Extra", "9001")}?date=2026-10-09`);
    expect(listedDay.status).toBe(200);
    const otherDay = await s.request(`/v1/japan/trips/${ID("Specific.Test.Extra", "9001")}?date=2026-10-08`);
    expect(otherDay.body.error.code).toBe("trip_not_running");
  });

  it("answers 404 after the last date a train is declared valid", async () => {
    const feed = fixtureFeed();
    feed.trips = feed.trips.map((item) => item.trainNumber === "3" ? { ...item, validUntil: "2026-10-09" } : item);
    const s = await scenario({ feed });

    expect((await s.request(`/v1/japan/trips/${ID("Weekday", "3")}?date=2026-10-09`)).status).toBe(200);
    const after = await s.request(`/v1/japan/trips/${ID("Weekday", "3")}?date=2026-10-13`);
    expect(after.status).toBe(404);
    expect(after.body.error.code).toBe("trip_not_running");
  });

  it("answers 404 for ids that name nothing in the snapshot", async () => {
    const s = await scenario();
    for (const id of [ID("Weekday", "777"), "Nope~Weekday~1", `${ALPHA_SLUG}~Nope~1`, "plainid", `${BETA_SLUG}~Weekday~301`]) {
      const result = await s.request(`/v1/japan/trips/${id}?date=2026-10-08`);
      expect(result.status, id).toBe(404);
      expect(result.body.error.code, id).toBe("trip_not_found");
    }
  });

  it.each([
    ["an empty id", "/v1/japan/trips/"],
    ["a space", "/v1/japan/trips/bad%20id"],
    ["an encoded slash", "/v1/japan/trips/a%2Fb"],
    ["an invalid escape", "/v1/japan/trips/%E0%A4%A"],
    ["a script tag", `/v1/japan/trips/${q("<script>")}`]
  ])("rejects an id with %s", async (_name, path) => {
    const s = await scenario();
    const result = await s.request(path);
    expect(result.status).toBe(400);
    expect(result.body.error.code).toBe("invalid_trip");
  });

  it("rejects bad dates and extra parameters", async () => {
    const s = await scenario();
    expect((await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2027-01-01`)).body.error.code).toBe("date_out_of_range");
    expect((await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=soon`)).body.error.code).toBe("invalid_date");
    expect((await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?limit=3`)).body.error.code).toBe("unsupported_parameter");
  });

  it("reads trip ids out of paths", () => {
    expect(tripIDFromPath("/v1/japan/trips/abc~def")).toBe("abc~def");
    expect(tripIDFromPath("/v1/japan/trips/a%7Eb")).toBe("a~b");
    expect(tripIDFromPath("/v1/japan/trips/")).toBe("");
    expect(tripIDFromPath("/v1/japan/trips/%E0%A4%A")).toBe("");
    expect(tripIDFromPath("/v1/japan/trips")).toBeNull();
    expect(tripIDFromPath("/v1/ns/trips/abc")).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Line status
// ---------------------------------------------------------------------------

function notice(railway: string, slug: string, kind: "suspension" | "delay" = "suspension") {
  return {
    "owl:sameAs": `odpt.TrainInformation:Test.${slug}.1`,
    "odpt:railway": railway,
    "odpt:timeOfOrigin": "2026-10-07T23:40:00+09:00",
    "odpt:trainInformationStatus": kind === "suspension" ? { ja: "運転見合わせ", en: "Suspended" } : { ja: "遅延", en: "Delay" },
    "odpt:trainInformationText": kind === "suspension"
      ? { ja: "強風のため運転を見合わせています。", en: "Service is suspended because of strong winds." }
      : { ja: "一部列車に遅れが出ています。", en: "Some trains are running late." },
    ...(kind === "suspension" ? { "odpt:trainInformationCause": { ja: "強風", en: "Strong winds" } } : {})
  };
}

function lineStatus(extra: Partial<FakeOdptData> = {}) {
  return fakeOdpt({
    ...odptNetwork(1),
    information: { [ALPHA]: [notice(ALPHA, "Alpha")], [BETA]: [notice(BETA, "Beta", "delay")] },
    ...extra
  });
}

const SUSPENSION = {
  id: "odpt.TrainInformation:Test.Alpha.1",
  lineId: ALPHA,
  title: "Suspended",
  detail: "Service is suspended because of strong winds. Cause: Strong winds",
  severity: "major",
  reportedAt: "2026-10-07T14:40:00.000Z",
  scope: "line"
};
const DELAY = {
  id: "odpt.TrainInformation:Test.Beta.1",
  lineId: BETA,
  title: "Delay",
  detail: "Some trains are running late.",
  severity: "watch",
  reportedAt: "2026-10-07T14:40:00.000Z",
  scope: "line"
};

describe("GET /v1/japan/disruptions", () => {
  it("reports line-level notices from the operator feed", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}` });
    const { status, body, response } = await s.request("/v1/japan/disruptions");

    expect(status).toBe(200);
    expect(body.data.disruptions).toEqual([SUSPENSION, DELAY]);
    expect(body.meta).toEqual({
      provider: "japan",
      source: "Public Transportation Open Data Center (ODPT)",
      attribution: "Timetable data from the Public Transportation Open Data Center (ODPT).",
      license: "odpt-basic",
      fetchedAt: "2026-10-08T00:00:00.000Z",
      expiresAt: "2026-10-08T00:01:00.000Z",
      freshness: "fresh",
      cacheStatus: "miss"
    });
    expect(response.headers.get("x-trainy-cache")).toBe("miss");
    expect(odpt.requests.map((request) => [request.resource, request.filter, request.tokenSeen])).toEqual([
      ["odpt:TrainInformation", ALPHA, TOKEN],
      ["odpt:TrainInformation", BETA, TOKEN]
    ]);
    expect(s.env.UPSTREAM_RATE_LIMITER.limit).toHaveBeenCalledWith({ key: "japan:odpt" });
  });

  it("works without any timetable snapshot", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, seeded: false });
    const { status, body } = await s.request("/v1/japan/disruptions");

    expect(status).toBe(200);
    expect(body.data.disruptions).toHaveLength(2);
  });

  it("asks the default Shinkansen railways when none are configured", async () => {
    const odpt = fakeOdpt({});
    const s = await scenario({ fetcher: odpt.fetcher, seeded: false });
    const { status, body } = await s.request("/v1/japan/disruptions");

    expect(status).toBe(200);
    expect(body.data.disruptions).toEqual([]);
    expect(odpt.requests).toHaveLength(10);
    expect(new Set(odpt.requests.map((request) => request.resource))).toEqual(new Set(["odpt:TrainInformation"]));
    expect(odpt.requests[0]!.filter).toBe("odpt.Railway:JR-Central.TokaidoShinkansen");
  });

  it("serves repeat requests from the short cache", async () => {
    const odpt = lineStatus();
    let current = NOW;
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, now: () => current });

    await s.request("/v1/japan/disruptions");
    current = new Date(NOW.getTime() + 30_000);
    const second = await s.request("/v1/japan/disruptions");

    expect(second.body.meta).toMatchObject({ cacheStatus: "hit", freshness: "fresh" });
    expect(odpt.requests).toHaveLength(2);
  });

  it("serves the last notices, marked stale, while the feed is failing", async () => {
    let failing = false;
    const odpt = lineStatus({ status: () => failing ? 500 : undefined });
    let current = NOW;
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, now: () => current });

    await s.request("/v1/japan/disruptions");
    failing = true;
    current = new Date(NOW.getTime() + 120_000);
    const degraded = await s.request("/v1/japan/disruptions");

    expect(degraded.status).toBe(200);
    expect(degraded.body.data.disruptions).toEqual([SUSPENSION, DELAY]);
    expect(degraded.body.meta).toMatchObject({ cacheStatus: "stale-fallback", freshness: "stale", fetchedAt: "2026-10-08T00:00:00.000Z" });

    current = new Date(NOW.getTime() + 700_000);
    const expired = await s.request("/v1/japan/disruptions");
    expect(expired.status).toBe(503);
    expect(expired.body.error.code).toBe("upstream_unavailable");
  });

  it("filters by line, serving the filter from the same cached read", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}` });

    const alpha = await s.request(`/v1/japan/disruptions?line=${q(ALPHA)}`);
    expect(alpha.body.data.disruptions).toEqual([SUSPENSION]);
    const beta = await s.request(`/v1/japan/disruptions?line=${q(BETA)}`);
    expect(beta.body.data.disruptions).toEqual([DELAY]);
    expect(odpt.requests).toHaveLength(2);

    const limited = await s.request("/v1/japan/disruptions?limit=1");
    expect(limited.body.data.disruptions).toEqual([SUSPENSION]);
  });

  it("answers an empty list without claiming service is normal", async () => {
    const odpt = fakeOdpt({ ...odptNetwork(1), information: {} });
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}` });
    const { status, body } = await s.request("/v1/japan/disruptions");

    expect(status).toBe(200);
    expect(body.data).toEqual({ disruptions: [] });
    expect(JSON.stringify(body)).not.toMatch(/normal|on time|no disruptions/iu);
  });

  it("rejects lines it does not cover and malformed input", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}` });

    const unknown = await s.request("/v1/japan/disruptions?line=odpt.Railway:Nope.Line");
    expect(unknown.status).toBe(404);
    expect(unknown.body.error.code).toBe("line_not_found");
    expect((await s.request("/v1/japan/disruptions?line=bad%20line")).body.error.code).toBe("invalid_line");
    expect((await s.request("/v1/japan/disruptions?limit=0")).body.error.code).toBe("invalid_limit");
    expect((await s.request("/v1/japan/disruptions?station=Tokyo")).body.error.code).toBe("unsupported_parameter");
    expect(odpt.requests).toHaveLength(0);
  });

  it("is not configured without the credential, and says so without naming it", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, token: null });
    const result = await s.request("/v1/japan/disruptions");

    expect(result.status).toBe(503);
    expect(result.body).toMatchObject({ provider_id: "japan", status: "missingCredential", error: { code: "missing_credential" } });
    expect(result.text).not.toMatch(/ODPT_CONSUMER_KEY|consumer/iu);
    expect(odpt.requests).toHaveLength(0);
  });

  it("is switched off, without touching the feed, until a publishable licence is declared", async () => {
    for (const license of ["", "odpt-challenge", "unknown-terms"]) {
      const odpt = lineStatus();
      const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, license });
      const result = await s.request("/v1/japan/disruptions");

      expect(result.status, license).toBe(503);
      expect(result.body.error, license).toMatchObject({ code: "line_status_unavailable", retryAfterSeconds: 300 });
      expect(odpt.requests, license).toHaveLength(0);
    }
  });

  it("is unavailable when the railway list is malformed", async () => {
    const s = await scenario({ railways: "Tokaido", fetcher: lineStatus().fetcher });
    expect((await s.request("/v1/japan/disruptions")).body.error.code).toBe("line_status_unavailable");
  });

  it("guards the upstream with the shared limiter", async () => {
    const odpt = lineStatus();
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}`, upstreamAllowed: false });
    const result = await s.request("/v1/japan/disruptions");

    expect(result.status).toBe(429);
    expect(result.body.error).toMatchObject({ code: "provider_budget_exhausted", retryAfterSeconds: 60 });
    expect(result.response.headers.get("retry-after")).toBe("60");
    expect(odpt.requests).toHaveLength(0);
  });

  it.each([
    ["throttling", 429, 429, "upstream_rate_limited"],
    ["a server error", 500, 503, "upstream_unavailable"],
    ["a rejected credential", 403, 503, "credential_rejected"]
  ])("maps upstream %s to a compact public error", async (_name, upstream, expected, code) => {
    const odpt = lineStatus({ status: () => upstream });
    const s = await scenario({ fetcher: odpt.fetcher, railways: `${ALPHA},${BETA}` });
    const result = await s.request("/v1/japan/disruptions");

    expect(result.status).toBe(expected);
    expect(result.body.error.code).toBe(code);
    expect(result.text).not.toContain(TOKEN);
    expect(result.text).not.toContain("api.odpt.org");
  });
});

// ---------------------------------------------------------------------------
// Health
// ---------------------------------------------------------------------------

function run(overrides: Partial<LastRunRecord>): { value: string } {
  return {
    value: JSON.stringify({
      outcome: "upstream_failed",
      startedAt: "2026-10-08T18:10:00.000Z",
      finishedAt: "2026-10-08T18:11:00.000Z",
      ...overrides
    })
  };
}

describe("GET /v1/health/providers", () => {
  const japan = async (options: Parameters<typeof scenario>[0] = {}) => {
    const s = await scenario(options);
    const { body } = await s.request("/v1/health/providers");
    return { s, body, japan: body.providers[1] as Json };
  };

  it("keeps the NS entry first and adds a Japan entry", async () => {
    const { body } = await japan();
    expect(body.providers.map((provider: Json) => provider.id)).toEqual(["ns", "japan"]);
    expect(body.providers[0]).toMatchObject({ id: "ns", region: "NL" });
  });

  it("reports a fresh snapshot as ok, with its coverage", async () => {
    const { japan: entry } = await japan();
    expect(entry).toEqual({
      id: "japan",
      region: "JP",
      configured: true,
      status: "ok",
      capabilities: ["stationSearch", "schedule", "serviceAlerts"],
      cache: { staticFeed: "fresh", updatedAt: "2026-10-07T18:10:00.000Z" },
      checkedAt: null,
      message: "Timetable snapshot covers 2026-10-07 through 2026-10-21."
    });
  });

  it("shows when the last refresh ran", async () => {
    const kv = new FakeKV();
    await seed(kv);
    kv.values.set(LAST_RUN_KEY, run({ outcome: "published", finishedAt: "2026-10-07T18:11:00.000Z" }));
    const { japan: entry } = await japan({ kv, seeded: false });
    expect(entry).toMatchObject({ status: "ok", checkedAt: "2026-10-07T18:11:00.000Z" });
    expect(entry.message).not.toContain("did not publish");
  });

  it("calls a snapshot over 36 hours old stale", async () => {
    const { japan: entry } = await japan({ now: () => new Date("2026-10-09T07:00:00Z") });
    expect(entry).toMatchObject({ status: "stale", cache: { staticFeed: "stale" } });
    expect(entry.message).toContain("more than 36 hours old");
  });

  it("says when a later refresh failed to publish", async () => {
    const kv = new FakeKV();
    await seed(kv);
    kv.values.set(LAST_RUN_KEY, run({ outcome: "upstream_failed", finishedAt: "2026-10-08T00:00:00.000Z" }));
    const { japan: entry } = await japan({ kv, seeded: false });
    expect(entry.status).toBe("ok");
    expect(entry.message).toMatch(/The latest refresh did not publish\.$/u);
  });

  it("is unsupported where the storage binding is absent", async () => {
    const { japan: entry } = await japan({ kv: null });
    expect(entry).toMatchObject({
      configured: false,
      status: "unsupported",
      capabilities: [],
      cache: { staticFeed: "missing", updatedAt: null },
      message: "Japan timetable data is not offered by this proxy."
    });
  });

  it("is unsupported, and stops serving, while no publishable licence is declared", async () => {
    const { japan: entry, s } = await japan({ license: "" });
    expect(entry).toMatchObject({ configured: false, status: "unsupported", capabilities: [] });
    expect(entry.message).toMatch(/licence/u);

    const stations = await s.request("/v1/japan/stations?query=tokyo");
    expect(stations.status).toBe(503);
    expect(stations.body.error.code).toBe("snapshot_unavailable");
  });

  it("reports a missing credential and still serves the snapshot it has", async () => {
    const empty = await japan({ token: null, seeded: false });
    expect(empty.japan).toMatchObject({ configured: false, status: "missingCredential", capabilities: [] });

    const seeded = await japan({ token: null });
    expect(seeded.japan).toMatchObject({ configured: false, status: "ok", capabilities: ["stationSearch", "schedule"] });
    expect(seeded.japan.message).toContain("Refreshing is not configured.");
  });

  it("waits for a first snapshot before it can say more", async () => {
    const { japan: entry } = await japan({ seeded: false });
    expect(entry).toMatchObject({ configured: true, status: "unknown", capabilities: ["serviceAlerts"], checkedAt: null });
    expect(entry.message).toBe("Waiting for the first timetable snapshot.");
  });

  it.each([
    ["no_data", "unsupported"],
    ["license_blocked", "unsupported"],
    ["upstream_failed", "offline"],
    ["storage_failed", "offline"],
    ["internal_error", "offline"],
    ["too_many_rejected", "offline"],
    ["regression", "offline"],
    ["not_configured", "unknown"]
  ] as const)("maps a first run that ended %s to %s", async (outcome, status) => {
    const kv = new FakeKV();
    kv.values.set(LAST_RUN_KEY, run({ outcome }));
    const { japan: entry } = await japan({ kv, seeded: false });
    expect(entry.status).toBe(status);
    expect(entry.checkedAt).toBe("2026-10-08T18:11:00.000Z");
  });

  it("survives a damaged snapshot and run record", async () => {
    const kv = new FakeKV();
    kv.values.set(MANIFEST_KEY, { value: "{\"schema\":99}" });
    kv.values.set(LAST_RUN_KEY, { value: "not json" });
    const { japan: entry } = await japan({ kv, seeded: false });
    expect(entry.status).toBe("unknown");
  });

  it("never reveals credentials or configuration values", async () => {
    const { s, body } = await japan();
    const serialized = JSON.stringify(body);
    expect(serialized).not.toContain(TOKEN);
    expect(serialized).not.toContain("odpt-basic");
    expect(serialized).not.toContain("JAPAN_");
    expect(s.records.every((record) => !JSON.stringify(record).includes(TOKEN))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Resilience of the read path
// ---------------------------------------------------------------------------

describe("when the snapshot is missing or unreadable", () => {
  const routes = [
    "/v1/japan/stations?query=tokyo",
    `${TOKYO_TO_OSAKA}&date=2026-10-08`,
    `/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`
  ];

  it.each([
    ["no storage binding", { kv: null }],
    ["nothing published yet", { seeded: false }]
  ] as const)("answers 503 with a long retry hint for %s", async (_name, options) => {
    const s = await scenario(options);
    for (const path of routes) {
      const result = await s.request(path);
      expect(result.status, path).toBe(503);
      expect(result.body, path).toMatchObject({
        provider_id: "japan",
        status: "offline",
        error: { code: "snapshot_unavailable", message: "Japan timetable data is not available yet.", retryAfterSeconds: 300 }
      });
      expect(result.response.headers.get("retry-after")).toBe("300");
    }
  });

  it("answers 503 with a short retry hint when storage cannot be read", async () => {
    const s = await scenario();
    s.kv!.failGet = () => true;
    for (const path of routes) {
      const result = await s.request(path);
      expect(result.status, path).toBe(503);
      expect(result.body.error, path).toMatchObject({ code: "snapshot_unavailable", retryAfterSeconds: 60 });
    }
  });

  it("answers 503 for a manifest in a format this Worker does not write", async () => {
    const s = await scenario({ seeded: false });
    s.kv!.values.set(MANIFEST_KEY, { value: JSON.stringify({ schema: 2, snapshotId: "future" }) });
    const result = await s.request(routes[0]!);
    expect(result.status).toBe(503);
    expect(result.body.error.code).toBe("snapshot_unavailable");
  });

  it("answers 503 when the manifest names a shard storage does not have", async () => {
    const s = await scenario();
    s.kv!.values.delete("japan/v1/snap/snap-fixture/stations");
    for (const path of [routes[0]!, `${TOKYO_TO_OSAKA}&date=2026-10-08`]) {
      expect((await s.request(path)).body.error.code, path).toBe("snapshot_unavailable");
    }

    const trips = await scenario();
    trips.kv!.values.delete(`japan/v1/snap/snap-fixture/${ALPHA_SLUG}~Weekday`);
    expect((await trips.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`)).status).toBe(503);
    expect((await trips.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`)).status).toBe(503);
    // A different day does not need the missing shard.
    expect((await trips.request(`${TOKYO_TO_OSAKA}&date=2026-10-10`)).status).toBe(200);
  });

  it("answers 503 for a structurally damaged shard rather than crashing", async () => {
    const damaged = [
      { schema: 1, line: ALPHA_SLUG, calendar: "Weekday", stations: [TOKYO], trips: [{ id: "x" }] },
      { schema: 1, line: ALPHA_SLUG, calendar: "Weekday", stations: [TOKYO], trips: [{ id: "a", trainNumber: "1", operator: "o", lines: ["l"], validUntil: "2026-10-21", stops: [[5, null, 1], [0, null, 2]] }] },
      { schema: 7, line: ALPHA_SLUG, calendar: "Weekday", stations: [], trips: [] },
      "plain text",
      null
    ];
    for (const shard of damaged) {
      const s = await scenario();
      s.kv!.values.set(`japan/v1/snap/snap-fixture/${ALPHA_SLUG}~Weekday`, { value: JSON.stringify(shard) });
      const result = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
      expect(result.status, JSON.stringify(shard)).toBe(503);
      expect(result.body.error.code).toBe("snapshot_unavailable");
    }
  });
});

describe("read-path caching", () => {
  it("reads the manifest and each shard once per isolate, not once per request", async () => {
    const s = await scenario();
    await s.request("/v1/japan/stations?query=tokyo");
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`);

    expect(s.kv!.gets(MANIFEST_KEY)).toBe(1);
    expect(s.kv!.gets("japan/v1/snap/snap-fixture/stations")).toBe(1);
    expect(s.kv!.gets(`japan/v1/snap/snap-fixture/${ALPHA_SLUG}~Weekday`)).toBe(1);
  });

  it("asks KV to cache edge reads: a minute for the manifest, an hour for immutable shards", async () => {
    const s = await scenario();
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    const options = (key: string) => s.kv!.operations.find((operation) => operation.op === "get" && operation.key === key)?.options;

    expect(options(MANIFEST_KEY)).toEqual({ type: "json", cacheTtl: 60 });
    expect(options("japan/v1/snap/snap-fixture/stations")).toEqual({ type: "json", cacheTtl: 3_600 });
    expect(options(`japan/v1/snap/snap-fixture/${ALPHA_SLUG}~Weekday`)).toEqual({ type: "json", cacheTtl: 3_600 });
  });

  it("re-reads the manifest after 30 seconds and moves to a newly published snapshot", async () => {
    let current = NOW;
    const s = await scenario({ now: () => current });
    const manifestReads = () => s.kv!.operations.filter((operation) =>
      operation.op === "get" && operation.key === MANIFEST_KEY && operation.options !== undefined).length;
    expect((await s.request("/v1/japan/stations?query=tokyo")).body.meta.snapshotId).toBe("snap-fixture");

    await seed(s.kv!, fixtureFeed(), { snapshotId: "snap-next", generatedAt: new Date("2026-10-08T18:10:00Z") });
    current = new Date(NOW.getTime() + 29_000);
    expect((await s.request("/v1/japan/stations?query=tokyo")).body.meta.snapshotId).toBe("snap-fixture");
    expect(manifestReads()).toBe(1);

    current = new Date(NOW.getTime() + 31_000);
    const moved = await s.request("/v1/japan/stations?query=tokyo");
    expect(moved.body.meta.snapshotId).toBe("snap-next");
    expect(manifestReads()).toBe(2);
  });

  it("keeps serving shards already in memory if storage later fails", async () => {
    const s = await scenario();
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    s.kv!.failGet = () => true;
    const result = await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    expect(result.status).toBe(200);
  });
});

// ---------------------------------------------------------------------------
// Request handling shared with the NS routes
// ---------------------------------------------------------------------------

describe("request handling", () => {
  it("never calls the upstream source for timetable questions", async () => {
    const fetcher = vi.fn(async () => new Response("[]")) as unknown as typeof fetch;
    const s = await scenario({ fetcher });
    await s.request("/v1/japan/stations?query=tokyo");
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`);

    expect(fetcher).not.toHaveBeenCalled();
    expect(s.env.UPSTREAM_RATE_LIMITER.limit).not.toHaveBeenCalled();
  });

  it("applies the per-client limiter before any storage access", async () => {
    const s = await scenario({ clientAllowed: false });
    const operationsBefore = s.kv!.operations.length;
    const result = await s.request("/v1/japan/stations?query=tokyo");

    expect(result.status).toBe(429);
    expect(result.body).toMatchObject({ provider_id: "japan", error: { code: "client_rate_limited", retryAfterSeconds: 60 } });
    expect(s.env.CLIENT_RATE_LIMITER.limit).toHaveBeenCalledWith({ key: "local:japan-stations" });
    expect(s.kv!.operations.length).toBe(operationsBefore);
  });

  it("limits each route separately", async () => {
    const s = await scenario();
    await s.request("/v1/japan/stations?query=tokyo", { headers: { "cf-connecting-ip": "203.0.113.9" } });
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`, { headers: { "cf-connecting-ip": "203.0.113.9" } });
    await s.request(`/v1/japan/trips/${ID("Weekday", "1")}`, { headers: { "cf-connecting-ip": "203.0.113.9" } });

    const calls = (s.env.CLIENT_RATE_LIMITER.limit as unknown as ReturnType<typeof vi.fn>).mock.calls.map(([argument]) => argument.key);
    expect(calls).toEqual(["203.0.113.9:japan-stations", "203.0.113.9:japan-trips", "203.0.113.9:japan-trip"]);
  });

  it("only answers GET, and names the Japan provider in the error", async () => {
    const s = await scenario();
    for (const method of ["POST", "PUT", "DELETE", "PATCH"]) {
      const result = await s.request("/v1/japan/stations?query=tokyo", { method });
      expect(result.status, method).toBe(405);
      expect(result.body).toMatchObject({ provider_id: "japan", error: { code: "method_not_allowed" } });
      expect(result.response.headers.get("allow")).toBe("GET");
    }
  });

  it("answers an unknown Japan path with 404 from the Japan provider", async () => {
    const s = await scenario();
    const result = await s.request("/v1/japan/nowhere");
    expect(result.status).toBe(404);
    expect(result.body).toMatchObject({ provider_id: "japan", error: { code: "not_found" } });
  });

  it("logs the route and outcome but never rider input, ids, or storage keys", async () => {
    const s = await scenario();
    await s.request(`/v1/japan/stations?query=${q("東京")}`);
    await s.request(`${TOKYO_TO_OSAKA}&date=2026-10-08`);
    await s.request(`/v1/japan/trips/${ID("Weekday", "1")}?date=2026-10-08`);
    await s.request("/v1/japan/disruptions", {});

    expect(s.records.map((record) => [record.provider, record.route, record.status])).toEqual([
      ["japan", "japan-stations", 200],
      ["japan", "japan-trips", 200],
      ["japan", "japan-trip", 200],
      ["japan", "japan-disruptions", 200]
    ]);
    expect(s.records[0]).toEqual({
      event: "provider_proxy_request",
      requestId: "request-fixture",
      provider: "japan",
      route: "japan-stations",
      method: "GET",
      status: 200,
      cacheStatus: "hit",
      duration: "under-100ms",
      errorCode: "none"
    });
    const serialized = JSON.stringify(s.records);
    for (const forbidden of ["東京", "Tokyo", TOKYO, SHIN_OSAKA, "Nozomi", "snap-fixture", "japan/v1", "2026-10-08", TOKEN]) {
      expect(serialized).not.toContain(forbidden);
    }
  });

  it("keeps the NS routes attributed to NS", async () => {
    const s = await scenario();
    const result = await s.request("/v1/ns/stations?query=ut", { method: "POST" });
    expect(result.body.provider_id).toBe("ns");
    expect(s.records[0]).toMatchObject({ provider: "ns", route: "station-search" });
  });
});
