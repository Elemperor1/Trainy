import { describe, expect, it } from "vitest";
import { addDays } from "../../src/japan/calendar";
import type { SnapshotManifest, StationsShard, TripShard } from "../../src/japan/contracts";
import { IngestFailure } from "../../src/japan/contracts";
import { buildSnapshot, DEFAULT_HORIZON_DAYS, slugOf } from "../../src/japan/snapshot";
import type { NormalizedFeed } from "../../src/japan/snapshot";
import {
  ALPHA,
  BETA,
  CALENDARS,
  fixtureFeed,
  GENERATED_AT,
  HAKATA,
  NAGOYA,
  SATURDAY_HOLIDAY,
  SHIN_OSAKA,
  SPECIFIC,
  stop,
  TOKYO,
  trip,
  WEEKDAY
} from "./support";

const OPTIONS = { snapshotId: "snap-1", generatedAt: GENERATED_AT };
const ALPHA_SLUG = "Test-Central.AlphaShinkansen";
const BETA_SLUG = "Test-West.BetaShinkansen";

function parsed(built: ReturnType<typeof buildSnapshot>) {
  const byKey = new Map(built.shards.map((shard) => [shard.key, JSON.parse(shard.body) as unknown]));
  const stations = byKey.get(built.manifest.stationsKey) as StationsShard;
  const tripShard = (line: string, calendar: string) => {
    const key = built.manifest.lines.find((entry) => entry.slug === line)?.shards[calendar]?.key;
    return key === undefined ? undefined : byKey.get(key) as TripShard;
  };
  return { stations, tripShard, byKey };
}

function feedWith(trips: NormalizedFeed["trips"], overrides: Partial<NormalizedFeed> = {}): NormalizedFeed {
  return { ...fixtureFeed(), trips, ...overrides };
}

const twoStops = (id = "1") => trip({ trainNumber: id, stops: [stop(TOKYO, null, "09:00"), stop(SHIN_OSAKA, "11:30", null)] });

describe("snapshot builder", () => {
  it("writes a manifest, a stations shard, and one trip shard per line and calendar", () => {
    const built = buildSnapshot(fixtureFeed(), OPTIONS);
    const { manifest } = built;

    expect(manifest).toMatchObject({
      schema: 1,
      snapshotId: "snap-1",
      generatedAt: "2026-10-07T18:10:00.000Z",
      coverage: { from: "2026-10-07", until: "2026-10-21" },
      counts: { stations: 4, lines: 2, trips: 8 },
      stationsKey: "japan/v1/snap/snap-1/stations"
    });
    expect(manifest.lines.map((line) => line.id)).toEqual([ALPHA, BETA]);
    expect(manifest.lines[0]).toMatchObject({ slug: ALPHA_SLUG, operator: "odpt.Operator:Test-Central", name: { ja: "アルファ新幹線", en: "Alpha Shinkansen" } });
    expect(Object.keys(manifest.lines[0]!.shards).sort()).toEqual(["SaturdayHoliday", "Specific.Test.Extra", "Weekday"]);
    expect(Object.keys(manifest.lines[1]!.shards)).toEqual(["Weekday"]);
    expect(manifest.lines[0]!.shards.Weekday).toEqual({ key: `japan/v1/snap/snap-1/${ALPHA_SLUG}~Weekday`, trips: 5 });
    expect(manifest.calendars).toEqual({
      Weekday: CALENDARS[WEEKDAY],
      SaturdayHoliday: { kind: "days", dayClasses: ["holiday", "saturday"] },
      "Specific.Test.Extra": CALENDARS[SPECIFIC]
    });
    // 1 stations shard + 4 trip shards, and nothing else.
    expect(built.shards.map((shard) => shard.key).sort()).toEqual([
      "japan/v1/snap/snap-1/Test-Central.AlphaShinkansen~SaturdayHoliday",
      "japan/v1/snap/snap-1/Test-Central.AlphaShinkansen~Specific.Test.Extra",
      "japan/v1/snap/snap-1/Test-Central.AlphaShinkansen~Weekday",
      "japan/v1/snap/snap-1/Test-West.BetaShinkansen~Weekday",
      "japan/v1/snap/snap-1/stations"
    ]);
    expect(built.expiredTrips).toBe(0);
  });

  it("stores trips compactly with station indexes into a per-shard table", () => {
    const { tripShard } = parsed(buildSnapshot(fixtureFeed(), OPTIONS));
    const shard = tripShard(ALPHA_SLUG, "Weekday")!;

    expect(shard.schema).toBe(1);
    expect(shard.stations).toEqual([TOKYO, NAGOYA, SHIN_OSAKA, HAKATA]);
    const first = shard.trips.find((candidate) => candidate.id === `${ALPHA_SLUG}~Weekday~1`)!;
    expect(first).toEqual({
      id: `${ALPHA_SLUG}~Weekday~1`,
      trainNumber: "1",
      name: { ja: "のぞみ", en: "Nozomi" },
      category: "Nozomi",
      operator: "odpt.Operator:Test-Central",
      lines: [ALPHA_SLUG],
      validUntil: "2026-10-21",
      stops: [
        [0, null, 360, "14"],
        [1, 456, 457, "16"],
        [2, 510, null, "25"]
      ]
    });
    // A stop without a platform has no fourth element at all.
    const kodama = shard.trips.find((candidate) => candidate.trainNumber === "101")!;
    expect(kodama.stops[0]).toEqual([0, null, 390]);
  });

  it("orders trips in a shard by first departure, then train number", () => {
    const { tripShard } = parsed(buildSnapshot(fixtureFeed(), OPTIONS));
    expect(tripShard(ALPHA_SLUG, "Weekday")!.trips.map((candidate) => candidate.trainNumber)).toEqual(["1", "101", "3", "301", "99"]);
  });

  it("writes a through train into every line it touches under one id", () => {
    const { tripShard } = parsed(buildSnapshot(fixtureFeed(), OPTIONS));
    const onAlpha = tripShard(ALPHA_SLUG, "Weekday")!.trips.find((candidate) => candidate.trainNumber === "301")!;
    const onBeta = tripShard(BETA_SLUG, "Weekday")!.trips.find((candidate) => candidate.trainNumber === "301")!;

    expect(onAlpha.id).toBe(`${ALPHA_SLUG}~Weekday~301`);
    expect(onBeta.id).toBe(onAlpha.id);
    expect(onAlpha.lines).toEqual([ALPHA_SLUG, BETA_SLUG]);
    expect(onBeta.lines).toEqual([ALPHA_SLUG, BETA_SLUG]);
  });

  it("lists on each station every line whose shards hold a trip that calls there", () => {
    const { stations } = parsed(buildSnapshot(fixtureFeed(), OPTIONS));
    const linesAt = (id: string) => stations.stations.find((station) => station.id === id)?.lines;

    // The through train is stored on both lines, so a lookup from any of its stops must read both.
    expect(linesAt(TOKYO)).toEqual([ALPHA_SLUG, BETA_SLUG]);
    expect(linesAt(SHIN_OSAKA)).toEqual([ALPHA_SLUG, BETA_SLUG]);
    expect(linesAt(HAKATA)).toEqual([ALPHA_SLUG, BETA_SLUG]);
  });

  it("records a station's own line when the source names it, and omits it otherwise", () => {
    const { stations } = parsed(buildSnapshot(fixtureFeed(), OPTIONS));
    const station = (id: string) => stations.stations.find((candidate) => candidate.id === id)!;

    expect(station(TOKYO)).toMatchObject({
      name: { ja: "東京", en: "Tokyo" }, latitude: 35.681, longitude: 139.767, code: "TK01", railway: ALPHA_SLUG
    });
    expect(station(HAKATA).railway).toBe(BETA_SLUG);
    expect(station(NAGOYA)).not.toHaveProperty("code");

    const feed = fixtureFeed();
    const anonymous: NormalizedFeed = {
      ...feed,
      stations: feed.stations.map(({ railway: _railway, ...rest }) => rest)
    };
    expect(parsed(buildSnapshot(anonymous, OPTIONS)).stations.stations.every((candidate) => !("railway" in candidate))).toBe(true);

    const unknown: NormalizedFeed = {
      ...feed,
      stations: feed.stations.map((candidate) => ({ ...candidate, railway: "odpt.Railway:Nope" }))
    };
    expect(parsed(buildSnapshot(unknown, OPTIONS)).stations.stations.every((candidate) => !("railway" in candidate))).toBe(true);
  });

  it("builds the same bytes whatever order the source lists things in", () => {
    const feed = fixtureFeed();
    const shuffled: NormalizedFeed = {
      ...feed,
      lines: [...feed.lines].reverse(),
      stations: [...feed.stations].reverse(),
      trips: [...feed.trips].reverse(),
      calendars: Object.fromEntries(Object.entries(feed.calendars).reverse())
    };
    const left = buildSnapshot(feed, OPTIONS);
    const right = buildSnapshot(shuffled, OPTIONS);

    expect(right.manifest).toEqual(left.manifest);
    expect(right.shards).toEqual(left.shards);
  });

  it("claims only the default horizon when the source declares no validity", () => {
    const built = buildSnapshot(fixtureFeed(), OPTIONS);
    expect(addDays("2026-10-07", DEFAULT_HORIZON_DAYS)).toBe("2026-10-21");
    expect(built.manifest.coverage).toEqual({ from: "2026-10-07", until: "2026-10-21" });
  });

  it("starts coverage on the service date in effect when the snapshot was generated", () => {
    // 04:00 JST on October 8 is the first moment that belongs to service date 2026-10-08.
    const afterRollover = buildSnapshot(fixtureFeed(), { snapshotId: "s", generatedAt: new Date("2026-10-07T19:00:00Z") });
    expect(afterRollover.manifest.coverage.from).toBe("2026-10-08");
  });

  it("extends coverage to the latest validity a source declares, never beyond 400 days", () => {
    const declared = buildSnapshot(feedWith([
      twoStops("1"),
      { ...twoStops("3"), validUntil: "2026-12-31" }
    ]), OPTIONS);
    expect(declared.manifest.coverage.until).toBe("2026-12-31");

    const capped = buildSnapshot(feedWith([{ ...twoStops("1"), validUntil: "2099-12-31" }]), OPTIONS);
    expect(capped.manifest.coverage.until).toBe(addDays("2026-10-07", 400));
    const { tripShard } = parsed(capped);
    expect(tripShard(ALPHA_SLUG, "Weekday")!.trips[0]!.validUntil).toBe(addDays("2026-10-07", 400));
  });

  it("keeps each trip's own validity so a short-lived trip stops matching early", () => {
    const built = buildSnapshot(feedWith([
      twoStops("1"),
      { ...twoStops("3"), validUntil: "2026-10-09" }
    ]), OPTIONS);
    const trips = parsed(built).tripShard(ALPHA_SLUG, "Weekday")!.trips;

    expect(trips.map((candidate) => [candidate.trainNumber, candidate.validUntil])).toEqual([
      ["1", "2026-10-21"],
      ["3", "2026-10-09"]
    ]);
  });

  it("drops and counts trips that ended before the coverage window", () => {
    const built = buildSnapshot(feedWith([
      twoStops("1"),
      { ...twoStops("3"), validUntil: "2026-10-06" },
      { ...twoStops("5"), validUntil: "2026-10-07" }
    ]), OPTIONS);

    expect(built.expiredTrips).toBe(1);
    expect(built.manifest.counts.trips).toBe(2);
  });

  it("ignores a declared validity it cannot use and falls back to the default horizon", () => {
    const built = buildSnapshot(feedWith([{ ...twoStops("1"), validUntil: "2026-02-30" }]), OPTIONS);
    expect(built.manifest.coverage.until).toBe("2026-10-21");
  });

  it("drops trips that reference lines, calendars, or stations the feed does not define", () => {
    const unknownLine = trip({ trainNumber: "10", lineIds: ["odpt.Railway:Nope"], stops: twoStops().stops });
    const unknownCalendar = trip({ trainNumber: "11", calendar: "odpt.Calendar:Nope", stops: twoStops().stops });
    const unknownStation = trip({ trainNumber: "12", stops: [stop(TOKYO, null, "09:00"), stop("odpt.Station:Nope", "10:00", null)] });
    const oneStop = trip({ trainNumber: "13", stops: [stop(TOKYO, null, "09:00")] });
    const noLines = trip({ trainNumber: "14", lineIds: [], stops: twoStops().stops });
    const built = buildSnapshot(feedWith([twoStops("1"), unknownLine, unknownCalendar, unknownStation, oneStop, noLines]), OPTIONS);

    expect(built.manifest.counts.trips).toBe(1);
    expect(parsed(built).tripShard(ALPHA_SLUG, "Weekday")!.trips.map((candidate) => candidate.trainNumber)).toEqual(["1"]);
  });

  it("drops calendars that carry no usable rule and the trips that depend on them", () => {
    const feed = feedWith([
      twoStops("1"),
      trip({ trainNumber: "2", calendar: "odpt.Calendar:Empty", stops: twoStops().stops }),
      trip({ trainNumber: "3", calendar: "odpt.Calendar:BadDates", stops: twoStops().stops })
    ], {
      calendars: {
        ...CALENDARS,
        "odpt.Calendar:Empty": { kind: "days", dayClasses: [] },
        "odpt.Calendar:BadDates": { kind: "dates", dates: ["2026-02-30", "1999-01-01"] }
      }
    });
    const built = buildSnapshot(feed, OPTIONS);

    expect(built.manifest.counts.trips).toBe(1);
    expect(Object.keys(built.manifest.calendars)).toEqual(["Weekday"]);
  });

  it("keeps only the calendars that trips actually use", () => {
    const built = buildSnapshot(feedWith([twoStops("1")]), OPTIONS);
    expect(Object.keys(built.manifest.calendars)).toEqual(["Weekday"]);
    expect(built.manifest.lines).toHaveLength(1);
    expect(built.manifest.lines[0]!.id).toBe(ALPHA);
    expect(built.manifest.counts).toEqual({ stations: 2, lines: 1, trips: 1 });
  });

  it("normalizes explicit date lists: supported, unique, sorted", () => {
    const feed = feedWith([trip({ trainNumber: "1", calendar: SPECIFIC, stops: twoStops().stops })], {
      calendars: { [SPECIFIC]: { kind: "dates", dates: ["2026-10-10", "2026-10-09", "2026-10-09", "2026-13-01"] } }
    });
    expect(buildSnapshot(feed, OPTIONS).manifest.calendars["Specific.Test.Extra"]).toEqual({
      kind: "dates",
      dates: ["2026-10-09", "2026-10-10"]
    });
  });

  it("keeps trip ids unique when train numbers repeat within a line and calendar", () => {
    const built = buildSnapshot(feedWith([
      trip({ trainNumber: "7", sourceId: "b", stops: [stop(TOKYO, null, "09:00"), stop(SHIN_OSAKA, "11:30", null)] }),
      trip({ trainNumber: "7", sourceId: "a", stops: [stop(TOKYO, null, "08:00"), stop(SHIN_OSAKA, "10:30", null)] })
    ]), OPTIONS);
    const ids = parsed(built).tripShard(ALPHA_SLUG, "Weekday")!.trips.map((candidate) => [candidate.id, candidate.stops[0]![2]]);

    // The earlier departure keeps the plain id, so it stays stable when a later duplicate appears.
    expect(ids).toEqual([
      [`${ALPHA_SLUG}~Weekday~7`, 480],
      [`${ALPHA_SLUG}~Weekday~7-2`, 540]
    ]);
  });

  it("keeps ids URL-safe even for unusual train numbers", () => {
    const built = buildSnapshot(feedWith([
      trip({ trainNumber: "はやぶさ 1/A", stops: twoStops().stops })
    ]), OPTIONS);
    const id = parsed(built).tripShard(ALPHA_SLUG, "Weekday")!.trips[0]!.id;
    expect(id).toMatch(/^[A-Za-z0-9._~-]+$/u);
    expect(id.startsWith(`${ALPHA_SLUG}~Weekday~`)).toBe(true);
  });

  it("separates line and calendar slugs that would otherwise collide", () => {
    const first = "odpt.Railway:Test.Line A";
    const second = "odpt.Railway:Test.Line_A";
    const feed = feedWith([
      trip({ trainNumber: "1", lineIds: [first], stops: twoStops().stops }),
      trip({ trainNumber: "2", lineIds: [second], stops: twoStops().stops })
    ], {
      lines: [
        { id: first, name: { ja: "A線" }, operator: "odpt.Operator:Test" },
        { id: second, name: { ja: "A線2" }, operator: "odpt.Operator:Test" }
      ]
    });
    const built = buildSnapshot(feed, OPTIONS);

    expect(built.manifest.lines.map((line) => line.slug)).toEqual(["Test.Line_A", "Test.Line_A-2"]);
    expect(new Set(built.shards.map((shard) => shard.key)).size).toBe(built.shards.length);
  });

  it("fails with no_data when nothing current survives", () => {
    const failure = (() => {
      try {
        buildSnapshot(feedWith([{ ...twoStops("1"), validUntil: "2026-10-01" }]), OPTIONS);
      } catch (error) {
        return error;
      }
      return undefined;
    })();

    expect(failure).toBeInstanceOf(IngestFailure);
    expect(failure).toMatchObject({ outcome: "no_data", code: "no_current_trips" });
    expect(() => buildSnapshot(feedWith([]), OPTIONS)).toThrow(IngestFailure);
  });

  it("refuses a shard larger than the storage ceiling", () => {
    // One 21 MiB train number makes a single shard exceed the 20 MiB ceiling.
    const huge = trip({ trainNumber: "9".repeat(21 * 1_024 * 1_024), stops: twoStops().stops });
    let failure: unknown;
    try {
      buildSnapshot(feedWith([huge]), OPTIONS);
    } catch (error) {
      failure = error;
    }
    expect(failure).toMatchObject({ outcome: "storage_failed", code: "shard_too_large" });
  });

  it("leaves a line out of the manifest when it has no trips", () => {
    const built = buildSnapshot(feedWith([twoStops("1")]), OPTIONS);
    const manifest: SnapshotManifest = built.manifest;
    expect(manifest.lines.some((line) => line.id === BETA)).toBe(false);
  });
});

describe("slugOf", () => {
  it("keeps the part after the scheme and replaces anything unsafe", () => {
    expect(slugOf("odpt.Railway:JR-Central.TokaidoShinkansen", 60)).toBe("JR-Central.TokaidoShinkansen");
    expect(slugOf("odpt.Calendar:Specific.A B/C", 60)).toBe("Specific.A_B_C");
    expect(slugOf("no-scheme", 60)).toBe("no-scheme");
  });

  it("trims separators, bounds the length, and never returns an empty slug", () => {
    expect(slugOf("odpt.Station:__.-A-.__", 60)).toBe("A");
    expect(slugOf("odpt.Station:abcdefghij", 4)).toBe("abcd");
    expect(slugOf("odpt.Station:***", 60)).toBe("x");
    expect(slugOf("", 60)).toBe("x");
  });
});
