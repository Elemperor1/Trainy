import { afterEach, describe, expect, it, vi } from "vitest";
import worker from "../../src/index";
import type { LastRunRecord, SnapshotManifest } from "../../src/japan/contracts";
import { PUBLISHABLE_LICENSES } from "../../src/japan/contracts";
import {
  DEFAULT_SETTLE_MILLISECONDS,
  MAX_REJECTED_RATIO,
  MIN_RETAINED_RATIO,
  MIN_TRIPS,
  runIngest,
  runScheduledIngest
} from "../../src/japan/ingest";
import type { IngestDependencies } from "../../src/japan/ingest";
import { DEFAULT_ODPT_RAILWAYS } from "../../src/japan/odpt";
import { LAST_RUN_KEY, MANIFEST_KEY, PREVIOUS_MANIFEST_KEY, readManifestUncached } from "../../src/japan/store";
import {
  ALPHA,
  asKV,
  BETA,
  fakeOdpt,
  type FakeOdptData,
  FakeKV,
  GENERATED_AT,
  harness,
  NETWORK_RAILWAYS,
  odptNetwork,
  odptRailway,
  odptStation,
  odptTimetable,
  TOKEN
} from "./support";

const SETTLE = 5_000;
const ALPHA_SHARD = "Test-Central.AlphaShinkansen~Weekday";
const BETA_SHARD = "Test-West.BetaShinkansen~Weekday";

function setup(options: { kv?: FakeKV | null; token?: string | null; license?: string; railways?: string; data?: FakeOdptData } = {}) {
  const h = harness({ kv: options.kv, token: options.token, license: options.license, railways: options.railways ?? NETWORK_RAILWAYS });
  const odpt = fakeOdpt(options.data ?? odptNetwork(12));
  const sleeps: number[] = [];
  let sequence = 0;
  const run = (overrides: Partial<IngestDependencies> = {}) => runIngest(h.env, {
    fetcher: odpt.fetcher,
    now: () => GENERATED_AT,
    sleep: async (milliseconds) => {
      sleeps.push(milliseconds);
      h.kv?.mark(`sleep:${milliseconds}`);
    },
    log: (record) => h.records.push(record),
    settleMilliseconds: SETTLE,
    snapshotId: () => `snap-${++sequence}`,
    ...overrides
  });
  return { ...h, odpt, run, sleeps };
}

const manifestOf = (kv: FakeKV) => JSON.parse(kv.values.get(MANIFEST_KEY)!.value) as SnapshotManifest;
const previousOf = (kv: FakeKV) => JSON.parse(kv.values.get(PREVIOUS_MANIFEST_KEY)!.value) as SnapshotManifest;
const lastRunOf = (kv: FakeKV) => JSON.parse(kv.values.get(LAST_RUN_KEY)!.value) as LastRunRecord;
const snapshotKeys = (kv: FakeKV, id: string) => kv.keys(`japan/v1/snap/${id}/`);

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

describe("publishing a snapshot", () => {
  it("writes every shard, waits for propagation, and only then flips the manifest", async () => {
    const s = setup();
    const report = await s.run();

    expect(report).toMatchObject({
      outcome: "published",
      snapshotId: "snap-1",
      counts: { stations: 5, lines: 2, trips: 24, rejected: 0 }
    });
    expect(report.code).toBeUndefined();

    const sequence = s.kv!.operations
      .filter((operation) => operation.op === "put" || operation.op === "mark")
      .map((operation) => operation.op === "mark" ? operation.key : `put ${operation.key}`);
    expect(sequence.slice(0, 3).sort()).toEqual([
      `put japan/v1/snap/snap-1/${ALPHA_SHARD}`,
      `put japan/v1/snap/snap-1/${BETA_SHARD}`,
      "put japan/v1/snap/snap-1/stations"
    ]);
    expect(sequence.slice(3)).toEqual([`sleep:${SETTLE}`, `put ${MANIFEST_KEY}`, `put ${LAST_RUN_KEY}`]);
    expect(s.sleeps).toEqual([SETTLE]);
  });

  it("gives shards an expiry through the coverage window plus a grace period, and the manifest none", async () => {
    const s = setup();
    await s.run();
    const kv = s.kv!;

    // Coverage ends 2026-10-21; that is 13 days after the run, plus 8 days of grace.
    for (const key of snapshotKeys(kv, "snap-1")) expect(kv.values.get(key)!.expirationTtl).toBe(21 * 86_400);
    expect(kv.values.get(MANIFEST_KEY)!.expirationTtl).toBeUndefined();
    expect(kv.values.get(LAST_RUN_KEY)!.expirationTtl).toBe(30 * 86_400);
  });

  it("publishes a manifest that points at the shards it wrote", async () => {
    const s = setup();
    await s.run();
    const kv = s.kv!;
    const manifest = manifestOf(kv);

    expect(manifest.snapshotId).toBe("snap-1");
    expect(manifest.source).toEqual({
      id: "odpt",
      name: "Public Transportation Open Data Center (ODPT)",
      attribution: "Timetable data from the Public Transportation Open Data Center (ODPT).",
      license: "odpt-basic"
    });
    const referenced = [manifest.stationsKey, ...manifest.lines.flatMap((line) => Object.values(line.shards).map((shard) => shard.key))].sort();
    expect(referenced).toEqual(snapshotKeys(kv, "snap-1"));
    expect(await readManifestUncached(asKV(kv))).toEqual(manifest);
    expect(kv.values.has(PREVIOUS_MANIFEST_KEY)).toBe(false);
  });

  it("waits the full propagation interval by default", () => {
    // Workers KV can take 60 seconds or more to show a new value in other locations.
    expect(DEFAULT_SETTLE_MILLISECONDS).toBeGreaterThanOrEqual(60_000);
  });

  it("keeps two snapshots and deletes the one that falls out of the window", async () => {
    const s = setup();
    const kv = s.kv!;

    await s.run();
    expect(snapshotKeys(kv, "snap-1")).toHaveLength(3);

    await s.run();
    expect(manifestOf(kv).snapshotId).toBe("snap-2");
    expect(previousOf(kv).snapshotId).toBe("snap-1");
    expect(snapshotKeys(kv, "snap-1")).toHaveLength(3);
    expect(snapshotKeys(kv, "snap-2")).toHaveLength(3);

    await s.run();
    expect(manifestOf(kv).snapshotId).toBe("snap-3");
    expect(previousOf(kv).snapshotId).toBe("snap-2");
    expect(snapshotKeys(kv, "snap-1")).toEqual([]);
    expect(snapshotKeys(kv, "snap-2")).toHaveLength(3);
    expect(snapshotKeys(kv, "snap-3")).toHaveLength(3);
  });

  it("never overwrites a shard that readers may still be using", async () => {
    const s = setup();
    await s.run();
    await s.run();
    const overwritten = s.kv!.operations.filter((operation) => operation.op === "put" && operation.key.includes("/snap/"));
    expect(new Set(overwritten.map((operation) => operation.key)).size).toBe(overwritten.length);
  });

  it("publishes over a manifest it cannot read", async () => {
    const kv = new FakeKV();
    kv.values.set(MANIFEST_KEY, { value: "{not json" });
    const s = setup({ kv });
    const report = await s.run();

    expect(report.outcome).toBe("published");
    expect(manifestOf(kv).snapshotId).toBe("snap-1");
  });

  it("stays well inside a paid plan's subrequest allowance for the default railways", async () => {
    const railways = [...DEFAULT_ODPT_RAILWAYS];
    const s = setup({ railways: "", data: syntheticNetwork(railways) });
    const kv = s.kv!;
    await s.run();
    await s.run();
    const before = { fetches: s.odpt.requests.length, operations: kv.operations.filter((operation) => operation.op !== "mark").length };
    const report = await s.run();

    expect(report.outcome).toBe("published");
    expect(report.counts).toMatchObject({ lines: 10, trips: 220 });
    const fetches = s.odpt.requests.length - before.fetches;
    const operations = kv.operations.filter((operation) => operation.op !== "mark").length - before.operations;
    // The third run is the busiest: it also deletes the oldest snapshot's shards.
    expect(fetches).toBe(31);
    expect(fetches + operations).toBeLessThan(120);
    expect(fetches + operations).toBeGreaterThan(50);
  });
});

describe("what a run refuses to do", () => {
  it.each([
    ["", "license_not_declared"],
    ["odpt-challenge", "license_not_permitted"],
    ["ODPT-Challenge", "license_not_permitted"],
    ["public-domain-maybe", "license_unrecognized"]
  ])("does not fetch or publish under licence %j", async (license, code) => {
    const s = setup({ license });
    const report = await s.run();

    expect(report).toMatchObject({ outcome: "license_blocked", code });
    expect(s.odpt.requests).toHaveLength(0);
    expect(s.kv!.keys()).toEqual([LAST_RUN_KEY]);
    expect(lastRunOf(s.kv!)).toMatchObject({ outcome: "license_blocked", code });
  });

  it.each([...PUBLISHABLE_LICENSES])("publishes under the %s licence and carries it on the manifest", async (license) => {
    const s = setup({ license: license.toUpperCase() });
    expect((await s.run()).outcome).toBe("published");
    expect(manifestOf(s.kv!).source.license).toBe(license);
  });

  it.each([
    ["no credential", { token: null }, "credential_missing"],
    ["an unresolved placeholder", { token: "$(ODPT_CONSUMER_KEY)" }, "credential_missing"],
    ["a credential with whitespace", { token: "two words" }, "credential_missing"],
    ["no storage binding", { kv: null }, "storage_not_bound"],
    ["a malformed railway list", { railways: "Tokaido" }, "invalid_railway_list"]
  ] as const)("reports not_configured for %s without fetching", async (_name, options, code) => {
    const s = setup(options);
    const report = await s.run();

    expect(report).toMatchObject({ outcome: "not_configured", code });
    expect(s.odpt.requests).toHaveLength(0);
    if (s.kv) expect(s.kv.keys()).toEqual([LAST_RUN_KEY]);
  });

  it("treats a source with no Shinkansen data as no_data and keeps the previous snapshot", async () => {
    const s = setup();
    const kv = s.kv!;
    await s.run();
    const before = kv.values.get(MANIFEST_KEY)!.value;

    const empty = fakeOdpt({});
    const report = await s.run({ fetcher: empty.fetcher });

    expect(report).toMatchObject({ outcome: "no_data", code: "insufficient_trips", counts: { trips: 0 } });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(before);
    expect(snapshotKeys(kv, "snap-2")).toEqual([]);
  });

  it("reports railway by railway what a source without data returned", async () => {
    // The state the first live run will show if ODPT carries no Shinkansen timetables.
    const s = setup({ railways: "", data: {} });
    const report = await s.run();
    const kv = s.kv!;

    expect(report).toMatchObject({ outcome: "no_data", code: "insufficient_trips" });
    expect(report.railways).toHaveLength(10);
    expect(report.railways!.every((railway) => !railway.railwayFound && railway.stations === 0 && railway.timetables === 0)).toBe(true);
    expect(s.odpt.requests).toHaveLength(31);
    expect(kv.keys()).toEqual([LAST_RUN_KEY]);
    expect(lastRunOf(kv).railways).toEqual(report.railways);
    expect(s.records.filter((record) => record.event === "japan_ingest_railway")).toHaveLength(10);
    expect(s.records.find((record) => record.event === "japan_ingest_railway")).toMatchObject({
      railway: DEFAULT_ODPT_RAILWAYS[0], found: 0, stations: 0, timetables: 0, trips: 0, rejected: 0
    });
  });

  it("treats fewer than the minimum number of trips as no data", async () => {
    expect(MIN_TRIPS).toBe(10);
    const tooFew = setup({ data: odptNetwork(4) }); // 8 trips
    expect(await tooFew.run()).toMatchObject({ outcome: "no_data", code: "insufficient_trips", counts: { trips: 8 } });

    const enough = setup({ data: odptNetwork(5) }); // 10 trips
    expect((await enough.run()).outcome).toBe("published");
  });

  it("fails the run when more than a quarter of the timetables are invalid", async () => {
    expect(MAX_REJECTED_RATIO).toBe(0.25);
    const withRejected = (count: number) => {
      const data = odptNetwork(12); // 24 timetables
      (data.timetables![ALPHA] as Array<Record<string, unknown>>).slice(0, count).forEach((timetable) => {
        timetable["odpt:trainNumber"] = undefined;
      });
      return data;
    };

    const atTheLimit = setup({ data: withRejected(6) });
    expect(await atTheLimit.run()).toMatchObject({ outcome: "published", counts: { trips: 18, rejected: 6 } });

    const over = setup({ data: withRejected(7) });
    const report = await over.run();
    expect(report).toMatchObject({ outcome: "too_many_rejected", code: "rejected_ratio", counts: { trips: 17, rejected: 7 } });
    expect(over.kv!.keys()).toEqual([LAST_RUN_KEY]);
    expect(report.railways![0]!.rejected).toEqual({ missing_train_number: 7 });
  });

  it("holds back a snapshot with less than half the trips of the one being served", async () => {
    expect(MIN_RETAINED_RATIO).toBe(0.5);
    const s = setup();
    const kv = s.kv!;
    await s.run(); // 24 trips
    const served = kv.values.get(MANIFEST_KEY)!.value;

    const shrunken = fakeOdpt(odptNetwork(5)); // 10 trips
    const report = await s.run({ fetcher: shrunken.fetcher });

    expect(report).toMatchObject({ outcome: "regression", code: "trip_count_dropped", counts: { trips: 10 } });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(served);
    expect(snapshotKeys(kv, "snap-2")).toEqual([]);

    const half = fakeOdpt(odptNetwork(6)); // 12 trips: exactly half
    expect((await s.run({ fetcher: half.fetcher })).outcome).toBe("published");
    expect(manifestOf(kv).counts.trips).toBe(12);
  });

  it("replaces a served manifest that is not JSON or not in this Worker's format", async () => {
    for (const unreadable of ["{truncated", JSON.stringify({ schema: "someone-else/1" })]) {
      const s = setup();
      const kv = s.kv!;
      kv.values.set(MANIFEST_KEY, { value: unreadable });

      expect(await s.run()).toMatchObject({ outcome: "published", snapshotId: "snap-1" });
      expect(manifestOf(kv).snapshotId).toBe("snap-1");
    }
  });
});

describe("failures", () => {
  it.each([
    ["a server error", () => fakeOdpt({ ...odptNetwork(12), status: (resource) => resource === "odpt:TrainTimetable" ? 500 : undefined }), "upstream_unavailable"],
    ["throttling", () => fakeOdpt({ ...odptNetwork(12), status: () => 429 }), "upstream_rate_limited"],
    ["a rejected credential", () => fakeOdpt({ ...odptNetwork(12), status: () => 401 }), "credential_rejected"]
  ])("reports upstream_failed for %s and keeps serving the previous snapshot", async (_name, failing, code) => {
    const s = setup();
    const kv = s.kv!;
    await s.run();
    const served = kv.values.get(MANIFEST_KEY)!.value;

    const report = await s.run({ fetcher: failing().fetcher });

    expect(report).toMatchObject({ outcome: "upstream_failed", code });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(served);
    expect(snapshotKeys(kv, "snap-2")).toEqual([]);
    expect(lastRunOf(kv)).toMatchObject({ outcome: "upstream_failed", code });
  });

  it("reports a network failure without the exception text", async () => {
    const s = setup();
    const report = await s.run({ fetcher: (async () => { throw new Error("connect ECONNREFUSED 10.0.0.1:443"); }) as typeof fetch });

    expect(report).toMatchObject({ outcome: "upstream_failed", code: "upstream_network_error" });
    expect(JSON.stringify([report, s.records, [...s.kv!.values.values()]])).not.toContain("ECONNREFUSED");
  });

  it("leaves the served snapshot untouched when a shard cannot be written", async () => {
    const s = setup();
    const kv = s.kv!;
    await s.run();
    const served = kv.values.get(MANIFEST_KEY)!.value;
    s.sleeps.length = 0;

    kv.failPut = (key) => key.endsWith(BETA_SHARD) && key.includes("snap-2");
    const report = await s.run();

    expect(report).toMatchObject({ outcome: "storage_failed", code: "publish_failed" });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(served);
    expect(s.sleeps).toEqual([]);
    expect(lastRunOf(kv)).toMatchObject({ outcome: "storage_failed" });
  });

  it("leaves the served snapshot untouched when the manifest cannot be flipped", async () => {
    const s = setup();
    const kv = s.kv!;
    await s.run();
    const served = kv.values.get(MANIFEST_KEY)!.value;

    kv.failPut = (key) => key === MANIFEST_KEY;
    expect(await s.run()).toMatchObject({ outcome: "storage_failed", code: "publish_failed" });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(served);
    expect(snapshotKeys(kv, "snap-1")).toHaveLength(3);
  });

  it("holds back a run that cannot read the served manifest instead of skipping the regression guard", async () => {
    const s = setup();
    const kv = s.kv!;
    await s.run(); // 24 trips are served
    const served = kv.values.get(MANIFEST_KEY)!.value;
    s.sleeps.length = 0;

    // One transient failure. Publishing reads the manifest again after the settle delay and
    // that read succeeds, so a guard that skipped itself here would let the small feed through.
    let failures = 1;
    kv.failGet = (key) => key === MANIFEST_KEY && failures-- > 0;
    const shrunken = fakeOdpt(odptNetwork(5)); // 10 trips
    const report = await s.run({ fetcher: shrunken.fetcher });

    expect(report).toMatchObject({ outcome: "storage_failed", code: "manifest_read_failed", counts: { trips: 10 } });
    expect(kv.values.get(MANIFEST_KEY)!.value).toBe(served);
    expect(snapshotKeys(kv, "snap-2")).toEqual([]);
    expect(s.sleeps).toEqual([]);
    expect(lastRunOf(kv)).toMatchObject({ outcome: "storage_failed", code: "manifest_read_failed" });

    // Once the read works again the guard decides, as it always did.
    expect(await s.run({ fetcher: shrunken.fetcher })).toMatchObject({ outcome: "regression", code: "trip_count_dropped" });
  });

  it("does not delete a snapshot that a failed flip left as both current and previous", async () => {
    const s = setup();
    const kv = s.kv!;
    await s.run(); // snap-1 is served

    // The previous-manifest copy lands, then the flip fails: both keys now name snap-1.
    kv.failPut = (key) => key === MANIFEST_KEY;
    await s.run(); // snap-2 shards are orphaned
    kv.failPut = () => false;
    expect(previousOf(kv).snapshotId).toBe("snap-1");

    await s.run(); // snap-3 published
    expect(manifestOf(kv).snapshotId).toBe("snap-3");
    expect(previousOf(kv).snapshotId).toBe("snap-1");
    expect(snapshotKeys(kv, "snap-1")).toHaveLength(3); // still referenced as "previous"

    await s.run(); // snap-4 published
    expect(previousOf(kv).snapshotId).toBe("snap-3");
    expect(snapshotKeys(kv, "snap-1")).toEqual([]);
    // The orphaned shards of the failed run are left to expire.
    expect(snapshotKeys(kv, "snap-2")).toHaveLength(3);
    for (const key of snapshotKeys(kv, "snap-2")) expect(kv.values.get(key)!.expirationTtl).toBe(21 * 86_400);
  });

  it("still reports the outcome when the run record itself cannot be stored", async () => {
    const s = setup();
    s.kv!.failPut = (key) => key === LAST_RUN_KEY;
    const report = await s.run();

    expect(report.outcome).toBe("published");
    expect(s.kv!.values.has(LAST_RUN_KEY)).toBe(false);
    expect(s.records[0]).toMatchObject({ event: "japan_ingest", outcome: "published" });
  });

  it("turns an unexpected error into a generic internal_error", async () => {
    const s = setup();
    const report = await s.run({ snapshotId: () => { throw new Error("secret detail /internal/path"); } });

    expect(report).toMatchObject({ outcome: "internal_error", code: "unexpected" });
    expect(JSON.stringify([report, s.records, [...s.kv!.values.values()]])).not.toContain("secret detail");
    expect(s.kv!.keys()).toEqual([LAST_RUN_KEY]);
  });
});

describe("reporting", () => {
  it("records the outcome and per-railway counts in KV and in structured logs", async () => {
    const s = setup();
    const report = await s.run();

    expect(lastRunOf(s.kv!)).toEqual({
      outcome: "published",
      startedAt: "2026-10-07T18:10:00.000Z",
      finishedAt: "2026-10-07T18:10:00.000Z",
      snapshotId: "snap-1",
      counts: { stations: 5, lines: 2, trips: 24, rejected: 0 },
      railways: report.railways
    });
    expect(s.records).toEqual([
      { event: "japan_ingest", outcome: "published", code: "none", duration: 0, trips: 24, stations: 5, lines: 2, rejected: 0 },
      { event: "japan_ingest_railway", railway: ALPHA, found: 1, stations: 3, timetables: 12, trips: 12, rejected: 0 },
      { event: "japan_ingest_railway", railway: BETA, found: 1, stations: 2, timetables: 12, trips: 12, rejected: 0 }
    ]);
  });

  it("never records the credential, an upstream address, or any station or train name", async () => {
    const s = setup();
    await s.run();
    const failing = fakeOdpt({ ...odptNetwork(12), status: () => 500 });
    await s.run({ fetcher: failing.fetcher });

    const everything = JSON.stringify([s.records, [...s.kv!.values.entries()].filter(([key]) => key === LAST_RUN_KEY)]);
    for (const forbidden of [TOKEN, "acl:consumerKey", "api.odpt.org", "https://", "東京", "Tokyo", "Nozomi", "のぞみ"]) {
      expect(everything).not.toContain(forbidden);
    }
  });

  it("measures its own duration", async () => {
    const s = setup();
    let tick = 0;
    const report = await s.run({ now: () => new Date(GENERATED_AT.getTime() + (tick++) * 1_500) });
    expect(report.durationMilliseconds).toBeGreaterThan(0);
    expect(s.records[0]!.duration).toBe(report.durationMilliseconds);
  });
});

describe("the Cron Trigger entry point", () => {
  const controller = { cron: "10 18 * * *", scheduledTime: GENERATED_AT.getTime(), type: "scheduled" } as unknown as ScheduledController;

  it("records a clear not_configured outcome when no credential is set", async () => {
    vi.spyOn(console, "log").mockImplementation(() => undefined);
    const h = harness({ token: null });
    worker.scheduled(controller, h.env, h.context);
    await h.drain();

    expect(JSON.parse(h.kv!.values.get(LAST_RUN_KEY)!.value)).toMatchObject({ outcome: "not_configured", code: "credential_missing" });
  });

  it("runs the whole pipeline with the real propagation delay", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);
    vi.useFakeTimers();
    vi.setSystemTime(GENERATED_AT);
    const odpt = fakeOdpt(odptNetwork(12));
    vi.stubGlobal("fetch", odpt.fetcher);

    const h = harness({ railways: NETWORK_RAILWAYS });
    worker.scheduled(controller, h.env, h.context);
    // Let every fetch and shard write finish; the run is then parked on its propagation delay.
    for (let turn = 0; turn < 25; turn += 1) await vi.advanceTimersByTimeAsync(0);
    expect(h.kv!.keys("japan/v1/snap/")).toHaveLength(3);
    expect(h.kv!.values.has(MANIFEST_KEY)).toBe(false);

    await vi.advanceTimersByTimeAsync(DEFAULT_SETTLE_MILLISECONDS - 1);
    expect(h.kv!.values.has(MANIFEST_KEY)).toBe(false);
    await vi.advanceTimersByTimeAsync(1);
    await h.drain();

    expect(manifestOf(h.kv!).counts.trips).toBe(24);
    expect(lastRunOf(h.kv!).outcome).toBe("published");
    expect(log).toHaveBeenCalledWith(expect.stringContaining('"event":"japan_ingest"'));
  });

  it("never lets an error escape the Cron Trigger", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => undefined);
    const env = {} as Env;
    Object.defineProperty(env, "ODPT_CONSUMER_KEY", {
      get() { throw new Error("binding exploded with /internal/detail"); }
    });

    await expect(runScheduledIngest(env)).resolves.toBeUndefined();
    expect(log).toHaveBeenCalledWith(JSON.stringify({ event: "japan_ingest", outcome: "internal_error", code: "unexpected" }));
    expect(JSON.stringify(log.mock.calls)).not.toContain("exploded");
  });
});

/** Ten railways with two calendars of eleven trips each, to measure a full-size run. */
function syntheticNetwork(railways: string[]): FakeOdptData {
  const railwayRecords: Record<string, unknown[]> = {};
  const stationRecords: Record<string, unknown[]> = {};
  const timetableRecords: Record<string, unknown[]> = {};
  for (const railway of railways) {
    const local = railway.slice(railway.indexOf(":") + 1);
    const operator = `odpt.Operator:${local.split(".")[0]}`;
    const first = `odpt.Station:${local}.A`;
    const second = `odpt.Station:${local}.B`;
    railwayRecords[railway] = [odptRailway(railway, operator, local, local)];
    stationRecords[railway] = [odptStation(first, railway, `${local}-A`, `${local} A`), odptStation(second, railway, `${local}-B`, `${local} B`)];
    timetableRecords[railway] = ["odpt.Calendar:Weekday", "odpt.Calendar:SaturdayHoliday"].flatMap((calendar) =>
      Array.from({ length: 11 }, (_, index) => odptTimetable({
        railway,
        number: String(index),
        calendar,
        operator,
        stops: [{ station: first, departure: `${8 + index}:00` }, { station: second, arrival: `${9 + index}:00` }]
      }))
    );
  }
  return { calendars: [], railways: railwayRecords, stations: stationRecords, timetables: timetableRecords };
}
