// These tests use the real Workers KV simulator and the Worker's shipped
// configuration (wrangler.jsonc), which the in-memory fake in support.ts cannot
// vouch for: option validation, deletes, listing, expirations, and the vars the
// Worker deploys with.

import { env, exports } from "cloudflare:workers";
import { afterEach, describe, expect, it } from "vitest";
import { handleRequest } from "../../src/handler";
import worker from "../../src/index";
import { runIngest } from "../../src/japan/ingest";
import { LAST_RUN_KEY, MANIFEST_KEY, PREVIOUS_MANIFEST_KEY } from "../../src/japan/store";
import {
  fakeOdpt,
  type FakeOdptData,
  GENERATED_AT,
  harness,
  MemoryCache,
  NETWORK_RAILWAYS,
  NOW,
  odptNetwork,
  TOKEN
} from "./support";

/** A distinct object per test: the read path memoizes per KV object, so tests must not share one. */
function freshKV(): KVNamespace {
  const real = env.JAPAN_DATA;
  return new Proxy(real, {
    get(target, property) {
      const value = Reflect.get(target, property, target) as unknown;
      return typeof value === "function" ? value.bind(target) : value;
    }
  });
}

async function wipe(): Promise<void> {
  const listed = await env.JAPAN_DATA.list({ prefix: "japan/" });
  await Promise.all(listed.keys.map((key) => env.JAPAN_DATA.delete(key.name)));
}

afterEach(wipe);

function configured(kv: KVNamespace, overrides: Record<string, unknown> = {}): Env {
  return {
    JAPAN_DATA: kv,
    ODPT_CONSUMER_KEY: TOKEN,
    JAPAN_SOURCE_LICENSE: "odpt-basic",
    JAPAN_ODPT_RAILWAYS: NETWORK_RAILWAYS,
    NS_SUBSCRIPTION_KEY: "fixture-credential",
    CLIENT_RATE_LIMITER: { limit: async () => ({ success: true }) },
    UPSTREAM_RATE_LIMITER: { limit: async () => ({ success: true }) },
    ...overrides
  } as unknown as Env;
}

async function ingest(kv: KVNamespace, id: string, data: FakeOdptData = odptNetwork(12)) {
  return runIngest(configured(kv), {
    fetcher: fakeOdpt(data).fetcher,
    now: () => GENERATED_AT,
    sleep: async () => undefined,
    log: () => undefined,
    snapshotId: () => id,
    settleMilliseconds: 0
  });
}

describe("the KV simulator behaves the way the test fake assumes", () => {
  it("is bound as JAPAN_DATA by the shipped configuration", async () => {
    await env.JAPAN_DATA.put("japan/probe", "1", { expirationTtl: 60 });
    expect(await env.JAPAN_DATA.get("japan/probe")).toBe("1");
  });

  it("rejects an expiration under 60 seconds and a cacheTtl under 30", async () => {
    await expect(env.JAPAN_DATA.put("japan/probe", "1", { expirationTtl: 30 })).rejects.toThrow();
    await expect(env.JAPAN_DATA.get("japan/probe", { type: "json", cacheTtl: 10 })).rejects.toThrow();
    await expect(env.JAPAN_DATA.get("japan/probe", { type: "json", cacheTtl: 30 })).resolves.toBeNull();
  });

  it("rejects a key longer than 512 bytes", async () => {
    await expect(env.JAPAN_DATA.put(`japan/${"k".repeat(520)}`, "1")).rejects.toThrow();
  });
});

describe("the shipped configuration", () => {
  it("declares no source licence, so Japan data stays off until someone confirms the terms", () => {
    // Changing this default publishes ODPT-derived data under an unconfirmed licence.
    // Do it deliberately, together with docs/japan-data-decision-record.md.
    expect(env.JAPAN_SOURCE_LICENSE).toBe("");
    expect(env.JAPAN_ODPT_RAILWAYS).toBe("");
  });

  it("serves NS health and reports Japan as off, through the real entry point", async () => {
    const response = await exports.default.fetch(new Request("https://proxy.example/v1/health/providers"));
    const body = await response.json() as { providers: Array<{ id: string; status: string; configured: boolean; message: string }> };

    expect(response.status).toBe(200);
    expect(body.providers.map((provider) => provider.id)).toEqual(["ns", "japan"]);
    expect(body.providers[1]).toMatchObject({ id: "japan", status: "unsupported", configured: false });
    expect(body.providers[1]!.message).toMatch(/licence/u);
  });

  it("answers Japan routes with a retryable 503 rather than data", async () => {
    for (const path of ["/v1/japan/stations?query=tokyo", "/v1/japan/disruptions"]) {
      const response = await exports.default.fetch(new Request(`https://proxy.example${path}`));
      const body = await response.json() as { provider_id: string; error: { code: string } };
      expect(response.status, path).toBe(503);
      expect(body.provider_id).toBe("japan");
      expect(response.headers.get("retry-after")).toBe("300");
    }
  });

  it("runs its Cron Trigger without a credential and records why nothing happened", async () => {
    const h = harness({ kv: null });
    worker.scheduled({ cron: "10 18 * * *", scheduledTime: Date.now(), type: "scheduled" } as unknown as ScheduledController, env, h.context);
    await h.drain();

    const run = await env.JAPAN_DATA.get(LAST_RUN_KEY, "json") as { outcome: string; code: string } | null;
    expect(run).toMatchObject({ outcome: "not_configured", code: "credential_missing" });
  });
});

describe("ingestion and serving with real KV", () => {
  it("publishes a snapshot that the routes then serve", async () => {
    const kv = freshKV();
    const report = await ingest(kv, "real-1");
    expect(report.outcome).toBe("published");

    const h = harness({ kv: null, now: () => NOW, cache: new MemoryCache() });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/japan/trips?from=odpt.Station:Test-Central.AlphaShinkansen.Tokyo&to=odpt.Station:Test-Central.AlphaShinkansen.ShinOsaka&date=2026-10-08&limit=3"),
      configured(kv), h.context, h.dependencies
    );
    const body = await response.json() as { data: { trips: Array<{ trainNumber: string; from: { departureAt: string } }> }; meta: { snapshotId: string; freshness: string } };

    expect(response.status).toBe(200);
    expect(body.meta).toMatchObject({ snapshotId: "real-1", freshness: "fresh" });
    expect(body.data.trips.map((trip) => [trip.trainNumber, trip.from.departureAt])).toEqual([
      ["1", "2026-10-08T06:00:00+09:00"],
      ["3", "2026-10-08T07:00:00+09:00"],
      ["5", "2026-10-08T08:00:00+09:00"]
    ]);
  });

  it("gives shards an expiry, the manifests none, and the run record thirty days", async () => {
    await ingest(freshKV(), "real-1");
    const nowSeconds = Math.floor(Date.now() / 1_000);

    const shards = await env.JAPAN_DATA.list({ prefix: "japan/v1/snap/real-1/" });
    expect(shards.keys).toHaveLength(3);
    for (const key of shards.keys) expect(key.expiration! - nowSeconds).toBeGreaterThan(21 * 86_400 - 60);

    const manifest = await env.JAPAN_DATA.list({ prefix: MANIFEST_KEY });
    expect(manifest.keys.map((key) => [key.name, key.expiration])).toEqual([[MANIFEST_KEY, undefined]]);
    const run = await env.JAPAN_DATA.list({ prefix: LAST_RUN_KEY });
    expect(run.keys[0]!.expiration! - nowSeconds).toBeGreaterThan(30 * 86_400 - 60);
  });

  it("keeps the previous snapshot and deletes the one before it", async () => {
    const kv = freshKV();
    await ingest(kv, "real-1");
    await ingest(kv, "real-2");
    expect((await env.JAPAN_DATA.list({ prefix: "japan/v1/snap/real-1/" })).keys).toHaveLength(3);
    expect(JSON.parse((await env.JAPAN_DATA.get(PREVIOUS_MANIFEST_KEY))!).snapshotId).toBe("real-1");

    await ingest(kv, "real-3");
    expect((await env.JAPAN_DATA.list({ prefix: "japan/v1/snap/real-1/" })).keys).toEqual([]);
    expect((await env.JAPAN_DATA.list({ prefix: "japan/v1/snap/real-2/" })).keys).toHaveLength(3);
    expect(JSON.parse((await env.JAPAN_DATA.get(MANIFEST_KEY))!).snapshotId).toBe("real-3");
  });

  it("leaves the served snapshot alone when a later run finds nothing", async () => {
    const kv = freshKV();
    await ingest(kv, "real-1");
    const served = await env.JAPAN_DATA.get(MANIFEST_KEY);

    const report = await ingest(kv, "real-2", {});
    expect(report).toMatchObject({ outcome: "no_data", code: "insufficient_trips" });
    expect(await env.JAPAN_DATA.get(MANIFEST_KEY)).toBe(served);
    expect(JSON.parse((await env.JAPAN_DATA.get(LAST_RUN_KEY))!)).toMatchObject({ outcome: "no_data" });
  });

  it("serves the snapshot's detail route end to end", async () => {
    const kv = freshKV();
    await ingest(kv, "real-1");
    const h = harness({ kv: null, now: () => NOW, cache: new MemoryCache() });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/japan/trips/Test-Central.AlphaShinkansen~Weekday~1?date=2026-10-08"),
      configured(kv), h.context, h.dependencies
    );
    const body = await response.json() as { data: { trip: { stops: unknown[]; lines: Array<{ id: string }> } } };

    expect(response.status).toBe(200);
    expect(body.data.trip.stops).toHaveLength(3);
    expect(body.data.trip.lines.map((line) => line.id)).toEqual(["odpt.Railway:Test-Central.AlphaShinkansen"]);
  });
});
