import { describe, expect, it, vi } from "vitest";
import { handleRequest, type RuntimeDependencies } from "../src/handler";

class MemoryCache {
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

function harness(options: {
  fetcher?: typeof fetch;
  clientAllowed?: boolean;
  upstreamAllowed?: boolean;
  providerBudget?: { allowed: boolean; retryAfterSeconds: number };
  providerBudgetError?: boolean;
  credential?: string;
  cache?: MemoryCache;
  now?: () => Date;
} = {}) {
  const waits: Promise<unknown>[] = [];
  const records: Array<Record<string, string | number>> = [];
  const reserveProviderBudget = vi.fn(async () => {
    if (options.providerBudgetError) throw new Error("fixture quota failure");
    return options.providerBudget ?? { allowed: true, retryAfterSeconds: 0 };
  });
  const env = {
    NS_SUBSCRIPTION_KEY: options.credential ?? "fixture-credential",
    CLIENT_RATE_LIMITER: {
      limit: vi.fn(async () => ({ success: options.clientAllowed ?? true }))
    },
    UPSTREAM_RATE_LIMITER: {
      limit: vi.fn(async () => ({ success: options.upstreamAllowed ?? true }))
    }
  } as unknown as Env;
  const context = {
    waitUntil(promise: Promise<unknown>) { waits.push(promise); },
    passThroughOnException() {},
    props: {}
  } as ExecutionContext;
  const cache = options.cache ?? new MemoryCache();
  const dependencies: Partial<RuntimeDependencies> = {
    fetcher: options.fetcher ?? vi.fn(async () => new Response("{}")) as typeof fetch,
    cache: cache as unknown as Cache,
    now: options.now ?? (() => new Date("2026-07-19T12:00:00Z")),
    requestID: () => "request-fixture",
    log: (record) => records.push(record),
    reserveProviderBudget
  };
  return {
    env,
    context,
    dependencies,
    records,
    reserveProviderBudget,
    cache,
    drain: async () => Promise.all(waits)
  };
}

describe("Trainy NS provider proxy contract", () => {
  it("searches a cached station catalog without forwarding rider search text", async () => {
    const fetcher = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = new URL(String(input));
      expect(url.pathname).toBe("/reisinformatie-api/api/v2/stations");
      expect(url.search).toBe("");
      expect(init?.headers).toMatchObject({ "ocp-apim-subscription-key": "fixture-credential" });
      return new Response(JSON.stringify([
        { code: "UT", namen: { lang: "Utrecht Centraal", kort: "Utrecht C." }, land: "NL", lat: 52.09, lng: 5.11 },
        { code: "RTD", namen: { lang: "Rotterdam Centraal", kort: "Rotterdam C." }, land: "NL" }
      ]), { status: 200, headers: { "content-type": "application/json" } });
    }) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/stations?query=Utrecht&limit=5"),
      h.env,
      h.context,
      h.dependencies
    );
    await h.drain();

    expect(response.status).toBe(200);
    const body = await response.json() as { data: { stations: Array<{ code: string; name: string }> }; meta: { freshness: string } };
    expect(body.data.stations).toEqual([{ code: "UT", name: "Utrecht Centraal", shortName: "Utrecht C.", countryCode: "NL", latitude: 52.09, longitude: 5.11 }]);
    expect(body.meta.freshness).toBe("fresh");
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(JSON.stringify(h.records)).not.toContain("Utrecht");
    expect(JSON.stringify(body)).not.toContain("fixture-credential");
  });

  it("ranks an exact station code ahead of unrelated substring matches", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify([
      { code: "GL", namen: { lang: "Geleen-Lutterade" }, land: "NL" },
      { code: "UTG", namen: { lang: "Uitgeest" }, land: "NL" },
      { code: "UT", namen: { lang: "Utrecht Centraal", kort: "Utrecht C." }, land: "NL" },
      { code: "HOUT", namen: { lang: "Houten" }, land: "NL" }
    ]), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });

    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/stations?query=UT&limit=4"),
      h.env,
      h.context,
      h.dependencies
    );
    const body = await response.json() as { data: { stations: Array<{ code: string }> } };

    expect(response.status).toBe(200);
    expect(body.data.stations.map((station) => station.code)).toEqual([
      "UT",
      "UTG",
      "GL",
      "HOUT"
    ]);
  });

  it("rejects invalid and unknown inputs before provider access", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({ fetcher });
    const shortQuery = await handleRequest(
      new Request("https://proxy.example/v1/ns/stations?query=U"), h.env, h.context, h.dependencies
    );
    const unknownParameter = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT&url=https://example.com"), h.env, h.context, h.dependencies
    );
    const duplicateParameter = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT&station=ASD"), h.env, h.context, h.dependencies
    );
    const controlCharacter = await handleRequest(
      new Request("https://proxy.example/v1/ns/stations?query=Utrecht%0AAmsterdam"), h.env, h.context, h.dependencies
    );
    const unknownRoute = await handleRequest(
      new Request("https://proxy.example/v1/ns/relay?path=v2/departures"), h.env, h.context, h.dependencies
    );

    expect(shortQuery.status).toBe(400);
    expect(unknownParameter.status).toBe(400);
    expect(duplicateParameter.status).toBe(400);
    expect(controlCharacter.status).toBe(400);
    expect(unknownRoute.status).toBe(404);
    expect(fetcher).not.toHaveBeenCalled();
  });

  const malformedCollections = [
    {
      label: "stations missing collection",
      url: "https://proxy.example/v1/ns/stations?query=Utrecht",
      body: {}
    },
    {
      label: "stations wrong collection type",
      url: "https://proxy.example/v1/ns/stations?query=Utrecht",
      body: { payload: { stations: {} } }
    },
    {
      label: "stations all records invalid",
      url: "https://proxy.example/v1/ns/stations?query=Utrecht",
      body: { payload: { stations: [{ code: "not a code", namen: {} }] } }
    },
    {
      label: "departures missing collection",
      url: "https://proxy.example/v1/ns/departures?station=UT",
      body: { payload: {} }
    },
    {
      label: "departures wrong collection type",
      url: "https://proxy.example/v1/ns/departures?station=UT",
      body: { payload: { departures: "none" } }
    },
    {
      label: "departures all records invalid",
      url: "https://proxy.example/v1/ns/departures?station=UT",
      body: { payload: { departures: [{ direction: "Enschede", plannedDateTime: "not-a-time" }] } }
    },
    {
      label: "disruptions missing collection",
      url: "https://proxy.example/v1/ns/disruptions",
      body: { payload: {} }
    },
    {
      label: "disruptions wrong collection type",
      url: "https://proxy.example/v1/ns/disruptions",
      body: { payload: { disruptions: false } }
    },
    {
      label: "disruptions all records invalid",
      url: "https://proxy.example/v1/ns/disruptions",
      body: [{ id: "missing-title" }]
    }
  ] as const;

  for (const scenario of malformedCollections) {
    it(`rejects ${scenario.label} as an upstream failure`, async () => {
      const fetcher = vi.fn(async () => new Response(JSON.stringify(scenario.body), { status: 200 })) as typeof fetch;
      const h = harness({ fetcher });
      const response = await handleRequest(new Request(scenario.url), h.env, h.context, h.dependencies);
      await h.drain();
      const body = await response.text();

      expect(response.status).toBe(502);
      expect(body).toContain('"status":"offline"');
      expect(body).toContain('"code":"invalid_upstream_response"');
      expect(body).not.toContain(JSON.stringify(scenario.body));
    });
  }

  it("preserves explicit empty collections as fresh empty results", async () => {
    const scenarios = [
      {
        url: "https://proxy.example/v1/ns/stations?query=Utrecht",
        upstream: { payload: { stations: [] } },
        result: (body: any) => body.data.stations
      },
      {
        url: "https://proxy.example/v1/ns/departures?station=UT",
        upstream: { payload: { departures: [] } },
        result: (body: any) => body.data.departures
      },
      {
        url: "https://proxy.example/v1/ns/disruptions",
        upstream: [],
        result: (body: any) => body.data.disruptions
      }
    ];

    for (const scenario of scenarios) {
      const fetcher = vi.fn(async () => new Response(JSON.stringify(scenario.upstream), { status: 200 })) as typeof fetch;
      const h = harness({ fetcher });
      const response = await handleRequest(new Request(scenario.url), h.env, h.context, h.dependencies);
      const body = await response.json() as { meta: { freshness: string } };

      expect(response.status).toBe(200);
      expect(scenario.result(body)).toEqual([]);
      expect(body.meta.freshness).toBe("fresh");
    }
  });

  it("keeps valid records from partially malformed collections", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      payload: {
        stations: [
          { code: "bad code", namen: {} },
          { code: "UT", namen: { lang: "Utrecht Centraal" }, land: "NL" }
        ]
      }
    }), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/stations?query=Utrecht"), h.env, h.context, h.dependencies
    );
    const body = await response.json() as { data: { stations: Array<{ code: string }> } };

    expect(response.status).toBe(200);
    expect(body.data.stations.map((station) => station.code)).toEqual(["UT"]);
  });

  it("normalizes departures and never returns provider headers or raw payload fields", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      payload: {
        departures: [{
          direction: "Enschede",
          name: "Intercity 1735",
          plannedDateTime: "2026-07-19T14:37:00+0200",
          actualDateTime: "2026-07-19T14:44:00+0200",
          plannedTrack: "8",
          actualTrack: "9",
          departureStatus: "ON_STATION",
          product: { number: "1735", shortCategoryName: "IC" },
          routeStations: [{ name: "raw field must not pass through" }]
        }]
      }
    }), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=ut&limit=1"), h.env, h.context, h.dependencies
    );
    const bodyText = await response.text();

    expect(response.status).toBe(200);
    expect(bodyText).toContain('"destination":"Enschede"');
    expect(bodyText).toContain('"scheduledAt":"2026-07-19T12:37:00.000Z"');
    expect(bodyText).toContain('"expectedAt":"2026-07-19T12:44:00.000Z"');
    expect(bodyText).toContain('"status":"atPlatform"');
    expect(bodyText).not.toContain("routeStations");
    expect(bodyText).not.toContain("ocp-apim");
    expect(bodyText).not.toContain("fixture-credential");
  });

  it("coalesces concurrent refreshes for the same cache key", async () => {
    let releaseFetch: (() => void) | undefined;
    const fetchGate = new Promise<void>((resolve) => { releaseFetch = resolve; });
    const fetcher = vi.fn(async () => {
      await fetchGate;
      return new Response(JSON.stringify({ payload: { departures: [{
        direction: "Amsterdam Centraal",
        name: "Intercity 1234",
        plannedDateTime: "2026-07-19T14:37:00+0200",
        departureStatus: "BOARDING"
      }] } }), { status: 200 });
    }) as typeof fetch;
    const h = harness({ fetcher });
    const requests = Array.from({ length: 12 }, (_, index) => handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT", {
        headers: { "cf-connecting-ip": `198.51.100.${index + 1}` }
      }),
      h.env,
      h.context,
      h.dependencies
    ));

    await vi.waitFor(() => expect(fetcher).toHaveBeenCalled());
    await vi.waitFor(() => expect(h.env.CLIENT_RATE_LIMITER.limit).toHaveBeenCalledTimes(12));
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(h.env.UPSTREAM_RATE_LIMITER.limit).toHaveBeenCalledTimes(1);
    expect(h.env.UPSTREAM_RATE_LIMITER.limit).toHaveBeenCalledWith({ key: "ns:shared" });
    expect(h.reserveProviderBudget).toHaveBeenCalledTimes(1);

    releaseFetch?.();
    const responses = await Promise.all(requests);
    await h.drain();
    expect(responses.every((response) => response.status === 200)).toBe(true);
    expect(responses.every((response) => response.headers.get("x-trainy-cache") === "miss")).toBe(true);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it("rejects a nonempty collection when every provider record violates the public contract", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      payload: {
        departures: [{
          direction: `Utrecht-${"X".repeat(200_000)}`,
          name: "Intercity 1735",
          plannedDateTime: "2026-07-19T14:37:00+0200",
          departureStatus: "ON_STATION",
          product: { number: "1735" }
        }]
      }
    }), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT&limit=1"),
      h.env,
      h.context,
      h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(502);
    expect(body).toContain('"code":"invalid_upstream_response"');
  });

  it("derives departure timing only from validated instants", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify({
      payload: {
        departures: [
          {
            direction: "Scheduled destination",
            name: "Sprinter 1",
            plannedDateTime: "2026-07-19T14:37:00+0200"
          },
          {
            direction: "On-time destination",
            name: "Sprinter 2",
            plannedDateTime: "2026-07-19T14:38:00+02:00",
            actualDateTime: "2026-07-19T14:38:00+02:00"
          },
          {
            direction: "Delayed destination",
            name: "Intercity 3",
            plannedDateTime: "2026-07-19T14:39:00+02:00",
            actualDateTime: "2026-07-19T14:44:00+02:00"
          },
          {
            direction: "Malformed destination",
            name: "Intercity 4",
            plannedDateTime: "2026-02-30T14:39:00+02:00"
          }
        ]
      }
    }), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.json() as {
      data: { departures: Array<{ destination: string; scheduledAt: string; status: string }> };
    };

    expect(response.status).toBe(200);
    expect(body.data.departures.map((departure) => departure.status)).toEqual(["scheduled", "onTime", "delayed"]);
    expect(body.data.departures.map((departure) => departure.destination)).not.toContain("Malformed destination");
    expect(body.data.departures[0]?.scheduledAt).toBe("2026-07-19T12:37:00.000Z");
  });

  it("maps provider throttling to a compact credential-safe 429", async () => {
    const fetcher = vi.fn(async () => new Response(
      JSON.stringify({ debug: "raw upstream quota detail" }),
      { status: 429, headers: { "x-provider-quota": "do-not-return" } }
    )) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(body).toContain('"status":"rateLimited"');
    expect(body).not.toContain("quota detail");
    expect(body).not.toContain("x-provider-quota");
  });

  it("rejects upstream redirects without following or exposing their location", async () => {
    const fetcher = vi.fn(async () => new Response(null, {
      status: 302,
      headers: { location: "https://untrusted.example/relay" }
    })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(502);
    expect(body).toContain('"code":"upstream_redirected"');
    expect(body).not.toContain("untrusted.example");
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it("normalizes transport failures without returning exception detail", async () => {
    const fetcher = vi.fn(async () => {
      throw new Error("raw network detail must stay server-side");
    }) as unknown as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(503);
    expect(body).toContain('"code":"upstream_network_error"');
    expect(body).not.toContain("raw network detail");
    expect(JSON.stringify(h.records)).not.toContain("raw network detail");
  });

  it("keeps the upstream deadline active until the response body completes", async () => {
    let abortObserved = false;
    const fetcher = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const signal = init?.signal;
      const body = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new TextEncoder().encode('{"payload":'));
          signal?.addEventListener("abort", () => {
            abortObserved = true;
            controller.error(new DOMException("aborted", "AbortError"));
          }, { once: true });
        }
      });
      return new Response(body, { status: 200, headers: { "content-type": "application/json" } });
    }) as typeof fetch;
    const h = harness({ fetcher });
    const startedAt = Date.now();
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"),
      h.env,
      h.context,
      h.dependencies
    );
    const elapsed = Date.now() - startedAt;
    const body = await response.text();

    expect(response.status).toBe(503);
    expect(body).toContain('"code":"upstream_timeout"');
    expect(abortObserved).toBe(true);
    expect(elapsed).toBeGreaterThanOrEqual(5_400);
    expect(elapsed).toBeLessThan(7_000);
  }, 8_000);

  it("maps an unknown upstream station to a request error without poisoning shared health", async () => {
    const fetcher = vi.fn(async () => new Response("{}", { status: 404 })) as typeof fetch;
    const h = harness({ fetcher });
    const departure = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=ZZZZZZZZ"),
      h.env,
      h.context,
      h.dependencies
    );
    await h.drain();
    const health = await handleRequest(
      new Request("https://proxy.example/v1/health/providers"),
      h.env,
      h.context,
      h.dependencies
    );
    const departureBody = await departure.text();
    const healthBody = await health.text();

    expect(departure.status).toBe(400);
    expect(departureBody).toContain('"code":"unknown_station"');
    expect(healthBody).toContain('"status":"unknown"');
    expect(healthBody).not.toContain('"status":"offline"');
  });

  it("rejects oversized upstream bodies and hardens the public response", async () => {
    const fetcher = vi.fn(async () => new Response("{}", {
      status: 200,
      headers: { "content-length": String(2 * 1_024 * 1_024 + 1) }
    })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );

    expect(response.status).toBe(502);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(response.headers.get("content-security-policy")).toContain("default-src 'none'");
    expect(response.headers.get("cross-origin-resource-policy")).toBe("same-origin");
    expect(response.headers.has("access-control-allow-origin")).toBe(false);
  });

  it("normalizes root-array disruptions and strips filtering-only station codes", async () => {
    const fetcher = vi.fn(async () => new Response(JSON.stringify([{
      id: "fixture-disruption",
      title: "Reduced service",
      impact: { value: 3 },
      timespans: [{ situation: { label: "Fewer trains" }, cause: { label: "Maintenance" } }],
      publicationSections: [{
        section: { stations: [{ stationCode: "UT" }] },
        consequence: { level: "NO_TRAINS" }
      }]
    }]), { status: 200 })) as typeof fetch;
    const h = harness({ fetcher });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/disruptions?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(200);
    expect(body).toContain('"title":"Reduced service"');
    expect(body).toContain('"severity":"major"');
    expect(body).toContain('"detail":"Fewer trains. Cause: Maintenance."');
    expect(body).not.toContain("..");
    expect(body).not.toContain("affectedStationCodes");
  });

  it("serves bounded stale departures when a refresh fails", async () => {
    let now = new Date("2026-07-19T12:00:00Z");
    let requestCount = 0;
    const fetcher = vi.fn(async () => {
      requestCount += 1;
      if (requestCount > 1) throw new Error("offline");
      return new Response(JSON.stringify({ payload: { departures: [{
        direction: "Amsterdam Centraal",
        name: "Intercity 1234",
        plannedDateTime: "2026-07-19T14:37:00+0200",
        departureStatus: "BOARDING"
      }] } }), { status: 200 });
    }) as typeof fetch;
    const cache = new MemoryCache();
    const h = harness({ fetcher, cache, now: () => now });

    const first = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    await h.drain();
    expect(first.status).toBe(200);
    now = new Date("2026-07-19T12:00:30Z");
    const second = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await second.json() as { meta: { freshness: string; cacheStatus: string } };

    expect(second.status).toBe(200);
    expect(body.meta).toMatchObject({ freshness: "stale", cacheStatus: "stale-fallback" });
  });

  it("keeps stale departures and degrades health when a refresh is structurally invalid", async () => {
    let now = new Date("2026-07-19T12:00:00Z");
    let requestCount = 0;
    const fetcher = vi.fn(async () => {
      requestCount += 1;
      const payload = requestCount === 1
        ? { payload: { departures: [{
          direction: "Amsterdam Centraal",
          name: "Intercity 1234",
          plannedDateTime: "2026-07-19T14:37:00+0200"
        }] } }
        : { payload: { departures: [{ direction: "Unreadable", plannedDateTime: "invalid" }] } };
      return new Response(JSON.stringify(payload), { status: 200 });
    }) as typeof fetch;
    const cache = new MemoryCache();
    const h = harness({ fetcher, cache, now: () => now });

    const first = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    await h.drain();
    expect(first.status).toBe(200);

    now = new Date("2026-07-19T12:00:30Z");
    const fallback = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    await h.drain();
    const fallbackBody = await fallback.json() as {
      data: { departures: Array<{ destination: string }> };
      meta: { freshness: string; cacheStatus: string };
    };
    const health = await handleRequest(
      new Request("https://proxy.example/v1/health/providers"), h.env, h.context, h.dependencies
    );
    const healthBody = await health.json() as { providers: Array<{ status: string }> };

    expect(fallback.status).toBe(200);
    expect(fallbackBody.data.departures[0]?.destination).toBe("Amsterdam Centraal");
    expect(fallbackBody.meta).toMatchObject({ freshness: "stale", cacheStatus: "stale-fallback" });
    expect(healthBody.providers[0]?.status).toBe("offline");
  });

  it("applies the client limiter before route work", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({ fetcher, clientAllowed: false });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );

    expect(response.status).toBe(429);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("rejects blank and unresolved credentials before either upstream budget guard", async () => {
    for (const credential of [" ", "$(NS_SUBSCRIPTION_KEY)"]) {
      const fetcher = vi.fn() as unknown as typeof fetch;
      const h = harness({ fetcher, credential });
      const response = await handleRequest(
        new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
      );
      const body = await response.json() as { error: { code: string } };

      expect(response.status).toBe(503);
      expect(body.error.code).toBe("missing_credential");
      expect(h.env.CLIENT_RATE_LIMITER.limit).toHaveBeenCalledTimes(1);
      expect(h.env.UPSTREAM_RATE_LIMITER.limit).not.toHaveBeenCalled();
      expect(h.reserveProviderBudget).not.toHaveBeenCalled();
      expect(fetcher).not.toHaveBeenCalled();
    }
  });

  it("uses a shared fast limiter before reserving the global provider budget", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({ fetcher, upstreamAllowed: false });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(h.env.UPSTREAM_RATE_LIMITER.limit).toHaveBeenCalledWith({ key: "ns:shared" });
    expect(h.reserveProviderBudget).not.toHaveBeenCalled();
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("honors the subscription-wide rolling budget and its retry interval", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({
      fetcher,
      providerBudget: { allowed: false, retryAfterSeconds: 257 }
    });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/disruptions"), h.env, h.context, h.dependencies
    );
    const body = await response.json() as { error: { code: string; retryAfterSeconds: number } };

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("257");
    expect(body.error).toEqual({
      code: "provider_budget_exhausted",
      message: "NS is busy. Try again shortly.",
      retryAfterSeconds: 257
    });
    expect(h.reserveProviderBudget).toHaveBeenCalledTimes(1);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("fails closed when the global provider budget cannot be checked", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({ fetcher, providerBudgetError: true });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/ns/departures?station=UT"), h.env, h.context, h.dependencies
    );
    const body = await response.json() as { error: { code: string } };

    expect(response.status).toBe(503);
    expect(response.headers.get("retry-after")).toBe("30");
    expect(body.error.code).toBe("provider_budget_unavailable");
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("reports credential absence without probing or disclosing configuration", async () => {
    const fetcher = vi.fn() as unknown as typeof fetch;
    const h = harness({ fetcher, credential: " " });
    const response = await handleRequest(
      new Request("https://proxy.example/v1/health/providers"), h.env, h.context, h.dependencies
    );
    const body = await response.text();

    expect(response.status).toBe(200);
    expect(body).toContain('"status":"missingCredential"');
    expect(body).not.toContain("NS_SUBSCRIPTION_KEY");
    expect(fetcher).not.toHaveBeenCalled();
  });
});
