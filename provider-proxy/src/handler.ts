import { loadWithCache, readCached, responseMeta, writeCached } from "./cache";
import type { DepartureSummary, DisruptionSummary, StationSummary } from "./contracts";
import {
  normalizedSearchValue,
  PROVIDER_ID,
  ProxyFault,
  rejectUnknownQueryParameters,
  validatedLimit,
  validatedSearchQuery,
  validatedStationCode
} from "./contracts";
import { fetchDepartures, fetchDisruptions, fetchStations } from "./upstream";
import type { NSQuotaDecision } from "./quota";

const STATIONS_KEY = "ns-stations-v2";
const HEALTH_KEY = "ns-health-v1";
const STATIONS_FRESH_SECONDS = 3_600;
const STATIONS_STALE_SECONDS = 86_400;
const DEPARTURES_FRESH_SECONDS = 20;
const DEPARTURES_STALE_SECONDS = 300;
const DISRUPTIONS_FRESH_SECONDS = 60;
const DISRUPTIONS_STALE_SECONDS = 600;
const UPSTREAM_QUOTA_OBJECT_NAME = "ns-subscription-budget";
const UPSTREAM_QUOTA_DEADLINE_MILLISECONDS = 1_500;

interface HealthRecord {
  status: "ok" | "rateLimited" | "offline" | "missingCredential";
  checkedAt: string;
}

export interface RuntimeDependencies {
  fetcher: typeof fetch;
  cache: Cache;
  now: () => Date;
  requestID: () => string;
  log: (record: Record<string, string | number>) => void;
  reserveProviderBudget: (env: Env, nowEpochMilliseconds: number) => Promise<NSQuotaDecision>;
}

interface RequestOutcome {
  response: Response;
  route: string;
  errorCode?: string;
}

export async function handleRequest(
  request: Request,
  env: Env,
  context: ExecutionContext,
  dependencies?: Partial<RuntimeDependencies>
): Promise<Response> {
  const runtime: RuntimeDependencies = {
    fetcher: fetch,
    cache: caches.default,
    now: () => new Date(),
    requestID: () => crypto.randomUUID(),
    log: (record) => console.log(JSON.stringify(record)),
    reserveProviderBudget,
    ...dependencies
  };
  const startedAt = runtime.now();
  const requestID = runtime.requestID();
  let route = "unmatched";
  let status = 500;
  let cacheStatus = "none";
  let errorCode = "internal_error";

  try {
    const url = new URL(request.url);
    route = routeName(url.pathname);
    if (request.method !== "GET") {
      throw new ProxyFault("method_not_allowed", "invalidRequest", 405, "Only GET requests are supported.");
    }
    if (route === "unmatched") {
      throw new ProxyFault("not_found", "notFound", 404, "The requested endpoint does not exist.");
    }

    const clientKey = `${request.headers.get("cf-connecting-ip") ?? "local"}:${route}`;
    const clientAllowance = await env.CLIENT_RATE_LIMITER.limit({ key: clientKey });
    if (!clientAllowance.success) {
      throw new ProxyFault("client_rate_limited", "rateLimited", 429, "Too many requests. Try again shortly.", 60);
    }

    const outcome = await routeRequest(url, env, context, runtime, requestID);
    status = outcome.response.status;
    cacheStatus = outcome.response.headers.get("x-trainy-cache") ?? "none";
    errorCode = outcome.errorCode ?? "none";
    return outcome.response;
  } catch (error) {
    const fault = error instanceof ProxyFault
      ? error
      : new ProxyFault("internal_error", "offline", 500, "The provider proxy could not complete the request.");
    status = fault.httpStatus;
    errorCode = fault.code;
    return errorResponse(fault, requestID);
  } finally {
    runtime.log({
      event: "provider_proxy_request",
      requestId: requestID,
      provider: PROVIDER_ID,
      route,
      method: request.method,
      status,
      cacheStatus,
      duration: durationBucket(runtime.now().getTime() - startedAt.getTime()),
      errorCode
    });
  }
}

async function routeRequest(
  url: URL,
  env: Env,
  context: ExecutionContext,
  runtime: RuntimeDependencies,
  requestID: string
): Promise<RequestOutcome> {
  switch (url.pathname) {
    case "/v1/health/providers":
      rejectUnknownQueryParameters(url, new Set());
      return { response: await healthResponse(env, runtime, requestID), route: "health" };
    case "/v1/ns/stations":
      return { response: await stationsResponse(url, env, context, runtime, requestID), route: "station-search" };
    case "/v1/ns/departures":
      return { response: await departuresResponse(url, env, context, runtime, requestID), route: "departures" };
    case "/v1/ns/disruptions":
      return { response: await disruptionsResponse(url, env, context, runtime, requestID), route: "disruptions" };
    default:
      throw new ProxyFault("not_found", "notFound", 404, "The requested endpoint does not exist.");
  }
}

async function stationsResponse(
  url: URL,
  env: Env,
  context: ExecutionContext,
  runtime: RuntimeDependencies,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["query", "limit"]));
  const query = validatedSearchQuery(url.searchParams.get("query"));
  const limit = validatedLimit(url.searchParams.get("limit"));
  const now = runtime.now();
  const loaded = await loadWithCache({
    cache: runtime.cache,
    key: STATIONS_KEY,
    now,
    freshSeconds: STATIONS_FRESH_SECONDS,
    staleSeconds: STATIONS_STALE_SECONDS,
    context,
    load: () => guardedUpstream(env, runtime, () =>
      fetchStations({ fetcher: runtime.fetcher, credential: env.NS_SUBSCRIPTION_KEY })
    ),
    onLoadResult: (fault) => recordHealth(runtime.cache, context, now, fault)
  });
  const normalizedQuery = normalizedSearchValue(query);
  const stations = loaded.envelope.value
    .filter((station) =>
      normalizedSearchValue(station.name).includes(normalizedQuery)
      || normalizedSearchValue(station.shortName ?? "").includes(normalizedQuery)
      || station.code.toLocaleLowerCase("nl-NL").includes(normalizedQuery)
    )
    .sort((left, right) => {
      const rankDifference = stationSearchRank(left, normalizedQuery)
        - stationSearchRank(right, normalizedQuery);
      return rankDifference
        || left.name.localeCompare(right.name, "nl-NL")
        || left.code.localeCompare(right.code, "nl-NL");
    })
    .slice(0, limit);

  return jsonResponse({ data: { stations }, meta: responseMeta(loaded), requestId: requestID }, 200, requestID, loaded.cacheStatus);
}

function stationSearchRank(station: StationSummary, normalizedQuery: string): number {
  const code = normalizedSearchValue(station.code);
  const name = normalizedSearchValue(station.name);
  const shortName = normalizedSearchValue(station.shortName ?? "");

  if (code === normalizedQuery) return 0;
  if (name === normalizedQuery || shortName === normalizedQuery) return 1;
  if (code.startsWith(normalizedQuery)) return 2;
  if (name.startsWith(normalizedQuery) || shortName.startsWith(normalizedQuery)) return 3;
  return 4;
}

async function departuresResponse(
  url: URL,
  env: Env,
  context: ExecutionContext,
  runtime: RuntimeDependencies,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["station", "limit"]));
  const stationCode = validatedStationCode(url.searchParams.get("station"));
  const limit = validatedLimit(url.searchParams.get("limit"));
  const now = runtime.now();
  const loaded = await loadWithCache<DepartureSummary[]>({
    cache: runtime.cache,
    key: `ns-departures-v1-${stationCode}`,
    now,
    freshSeconds: DEPARTURES_FRESH_SECONDS,
    staleSeconds: DEPARTURES_STALE_SECONDS,
    context,
    load: () => guardedUpstream(env, runtime, () =>
      fetchDepartures({ fetcher: runtime.fetcher, credential: env.NS_SUBSCRIPTION_KEY }, stationCode)
    ),
    onLoadResult: (fault) => recordHealth(runtime.cache, context, now, fault)
  });
  return jsonResponse({
    data: { station: { code: stationCode }, departures: loaded.envelope.value.slice(0, limit) },
    meta: responseMeta(loaded),
    requestId: requestID
  }, 200, requestID, loaded.cacheStatus);
}

async function disruptionsResponse(
  url: URL,
  env: Env,
  context: ExecutionContext,
  runtime: RuntimeDependencies,
  requestID: string
): Promise<Response> {
  rejectUnknownQueryParameters(url, new Set(["station", "limit"]));
  const stationValue = url.searchParams.get("station");
  const stationCode = stationValue === null ? null : validatedStationCode(stationValue);
  const limit = validatedLimit(url.searchParams.get("limit"), 6);
  const now = runtime.now();
  const loaded = await loadWithCache<DisruptionSummary[]>({
    cache: runtime.cache,
    key: "ns-disruptions-v2",
    now,
    freshSeconds: DISRUPTIONS_FRESH_SECONDS,
    staleSeconds: DISRUPTIONS_STALE_SECONDS,
    context,
    load: () => guardedUpstream(env, runtime, () =>
      fetchDisruptions({ fetcher: runtime.fetcher, credential: env.NS_SUBSCRIPTION_KEY })
    ),
    onLoadResult: (fault) => recordHealth(runtime.cache, context, now, fault)
  });
  const disruptions = loaded.envelope.value
    .filter((item) => !stationCode || item.affectedStationCodes.length === 0 || item.affectedStationCodes.includes(stationCode))
    .slice(0, limit)
    .map(({ affectedStationCodes: _, ...publicItem }) => publicItem);
  return jsonResponse({ data: { disruptions }, meta: responseMeta(loaded), requestId: requestID }, 200, requestID, loaded.cacheStatus);
}

async function guardedUpstream<T>(
  env: Env,
  runtime: RuntimeDependencies,
  load: () => Promise<T>
): Promise<T> {
  const allowance = await env.UPSTREAM_RATE_LIMITER.limit({ key: `${PROVIDER_ID}:shared` });
  if (!allowance.success) {
    throw new ProxyFault("provider_budget_exhausted", "rateLimited", 429, "NS is busy. Try again shortly.", 60);
  }

  let quota: NSQuotaDecision;
  try {
    quota = await runtime.reserveProviderBudget(env, runtime.now().getTime());
  } catch {
    throw new ProxyFault(
      "provider_budget_unavailable",
      "offline",
      503,
      "NS is temporarily unavailable. Try again shortly.",
      30
    );
  }
  if (
    typeof quota.allowed !== "boolean"
    || !Number.isInteger(quota.retryAfterSeconds)
    || quota.retryAfterSeconds < 0
    || quota.retryAfterSeconds > 300
  ) {
    throw new ProxyFault(
      "provider_budget_unavailable",
      "offline",
      503,
      "NS is temporarily unavailable. Try again shortly.",
      30
    );
  }
  if (!quota.allowed) {
    throw new ProxyFault(
      "provider_budget_exhausted",
      "rateLimited",
      429,
      "NS is busy. Try again shortly.",
      Math.max(1, quota.retryAfterSeconds)
    );
  }
  return load();
}

async function reserveProviderBudget(
  env: Env,
  nowEpochMilliseconds: number
): Promise<NSQuotaDecision> {
  const quota = env.NS_UPSTREAM_QUOTA.getByName(UPSTREAM_QUOTA_OBJECT_NAME);
  let timeout: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      quota.reserve(nowEpochMilliseconds),
      new Promise<never>((_, reject) => {
        timeout = setTimeout(
          () => reject(new Error("Provider budget deadline exceeded.")),
          UPSTREAM_QUOTA_DEADLINE_MILLISECONDS
        );
      })
    ]);
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
}

async function healthResponse(env: Env, runtime: RuntimeDependencies, requestID: string): Promise<Response> {
  const now = runtime.now();
  const configured = Boolean(env.NS_SUBSCRIPTION_KEY?.trim());
  const health = await readCached<HealthRecord>(runtime.cache, HEALTH_KEY, now);
  const stations = await readCached<StationSummary[]>(runtime.cache, STATIONS_KEY, now);
  let status: "ok" | "missingCredential" | "rateLimited" | "offline" | "stale" | "unknown" = "unknown";
  let message = "Configured; awaiting a provider request before reachability is known.";
  let checkedAt: string | null = null;

  if (!configured) {
    status = "missingCredential";
    message = "Proxy credential is not configured.";
  } else if (health) {
    checkedAt = health.envelope.value.checkedAt;
    const ageSeconds = (now.getTime() - Date.parse(checkedAt)) / 1_000;
    status = health.envelope.value.status;
    if (status === "ok" && ageSeconds > 600) status = "stale";
    message = healthMessage(status);
  }

  const staticFeed = stations?.freshness ?? "missing";
  return jsonResponse({
    generatedAt: now.toISOString(),
    providers: [{
      id: PROVIDER_ID,
      region: "NL",
      configured,
      status,
      capabilities: ["stationSearch", "stationDepartures", "serviceAlerts"],
      cache: {
        staticFeed,
        updatedAt: stations?.envelope.fetchedAt ?? null
      },
      checkedAt,
      message
    }]
  }, 200, requestID, "health");
}

function recordHealth(cache: Cache, context: ExecutionContext, now: Date, fault?: ProxyFault): void {
  if (fault?.publicStatus === "invalidRequest" || fault?.publicStatus === "notFound") return;
  const status: HealthRecord["status"] = !fault
    ? "ok"
    : fault.publicStatus === "rateLimited"
      ? "rateLimited"
      : fault.publicStatus === "missingCredential"
        ? "missingCredential"
        : "offline";
  writeCached(cache, HEALTH_KEY, { status, checkedAt: now.toISOString() }, now, 86_400, 86_400, context);
}

function jsonResponse(
  body: unknown,
  status: number,
  requestID: string,
  cacheStatus: string,
  extraHeaders: HeadersInit = {}
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "private, no-store",
      "content-security-policy": "default-src 'none'; frame-ancestors 'none'",
      "cross-origin-resource-policy": "same-origin",
      "permissions-policy": "camera=(), geolocation=(), microphone=()",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      "x-request-id": requestID,
      "x-trainy-cache": cacheStatus,
      ...extraHeaders
    }
  });
}

function errorResponse(fault: ProxyFault, requestID: string): Response {
  const retry = fault.retryAfterSeconds;
  return jsonResponse({
    provider_id: PROVIDER_ID,
    status: fault.publicStatus,
    error: {
      code: fault.code,
      message: fault.publicMessage,
      ...(retry ? { retryAfterSeconds: retry } : {})
    },
    requestId: requestID
  }, fault.httpStatus, requestID, "none", {
    ...(retry ? { "retry-after": String(retry) } : {}),
    ...(fault.httpStatus === 405 ? { allow: "GET" } : {})
  });
}

function routeName(pathname: string): string {
  switch (pathname) {
    case "/v1/health/providers": return "health";
    case "/v1/ns/stations": return "station-search";
    case "/v1/ns/departures": return "departures";
    case "/v1/ns/disruptions": return "disruptions";
    default: return "unmatched";
  }
}

function healthMessage(status: string): string {
  switch (status) {
    case "ok": return "Provider reached successfully.";
    case "stale": return "Last successful provider check is old.";
    case "rateLimited": return "Provider recently rate limited the proxy.";
    case "missingCredential": return "Proxy credential is not configured.";
    default: return "Provider was unavailable on the last request.";
  }
}

function durationBucket(milliseconds: number): string {
  if (milliseconds < 100) return "under-100ms";
  if (milliseconds < 500) return "under-500ms";
  if (milliseconds < 1_000) return "under-1s";
  if (milliseconds < 3_000) return "under-3s";
  return "3s-or-more";
}
