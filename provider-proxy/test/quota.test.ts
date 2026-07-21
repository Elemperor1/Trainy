import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import {
  NS_QUOTA_MAX_REQUESTS,
  NS_QUOTA_WINDOW_MILLISECONDS
} from "../src/quota";

describe("NS subscription-wide quota", () => {
  it("enforces the rolling five-minute budget globally", async () => {
    const quota = env.NS_UPSTREAM_QUOTA.getByName("rolling-window-test");
    const now = Date.parse("2026-07-20T18:00:00Z");

    for (let index = 0; index < NS_QUOTA_MAX_REQUESTS; index += 1) {
      await expect(quota.reserve(now)).resolves.toEqual({
        allowed: true,
        retryAfterSeconds: 0
      });
    }

    await expect(quota.reserve(now)).resolves.toEqual({
      allowed: false,
      retryAfterSeconds: 300
    });
    await expect(quota.reserve(now + NS_QUOTA_WINDOW_MILLISECONDS - 1_000)).resolves.toEqual({
      allowed: false,
      retryAfterSeconds: 1
    });
    await expect(quota.reserve(now + NS_QUOTA_WINDOW_MILLISECONDS)).resolves.toEqual({
      allowed: true,
      retryAfterSeconds: 0
    });
  });

  it("fails closed for invalid internal timestamps without changing the budget", async () => {
    const quota = env.NS_UPSTREAM_QUOTA.getByName("invalid-time-test");

    await expect(quota.reserve(Number.NaN)).resolves.toEqual({
      allowed: false,
      retryAfterSeconds: 300
    });
    await expect(quota.reserve(-1)).resolves.toEqual({
      allowed: false,
      retryAfterSeconds: 300
    });
    await expect(quota.reserve(Date.parse("2026-07-20T18:00:00Z"))).resolves.toEqual({
      allowed: true,
      retryAfterSeconds: 0
    });
  });
});
