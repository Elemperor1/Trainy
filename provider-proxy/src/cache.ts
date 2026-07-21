import type { CachedEnvelope, CacheStatus, Freshness, ResponseMeta } from "./contracts";
import { PROVIDER_ATTRIBUTION, PROVIDER_ID, PROVIDER_SOURCE, ProxyFault } from "./contracts";

const CACHE_ORIGIN = "https://trainy-cache.invalid";
const inFlightLoads = new WeakMap<object, Map<string, Promise<LoadedValue<unknown>>>>();

export interface CacheRead<T> {
  envelope: CachedEnvelope<T>;
  freshness: Freshness;
}

export interface LoadedValue<T> extends CacheRead<T> {
  cacheStatus: CacheStatus;
}

export function cacheRequest(key: string): Request {
  return new Request(`${CACHE_ORIGIN}/${encodeURIComponent(key)}`);
}

export async function readCached<T>(cache: Cache, key: string, now: Date): Promise<CacheRead<T> | null> {
  const response = await cache.match(cacheRequest(key));
  if (!response) return null;

  try {
    const envelope = (await response.json()) as CachedEnvelope<T>;
    const staleUntil = Date.parse(envelope.staleUntil);
    if (!Number.isFinite(staleUntil) || staleUntil <= now.getTime()) {
      await cache.delete(cacheRequest(key));
      return null;
    }
    const freshUntil = Date.parse(envelope.freshUntil);
    return {
      envelope,
      freshness: Number.isFinite(freshUntil) && freshUntil > now.getTime() ? "fresh" : "stale"
    };
  } catch {
    await cache.delete(cacheRequest(key));
    return null;
  }
}

export function writeCached<T>(
  cache: Cache,
  key: string,
  value: T,
  now: Date,
  freshSeconds: number,
  staleSeconds: number,
  context: ExecutionContext
): CachedEnvelope<T> {
  const envelope: CachedEnvelope<T> = {
    value,
    fetchedAt: now.toISOString(),
    freshUntil: new Date(now.getTime() + freshSeconds * 1_000).toISOString(),
    staleUntil: new Date(now.getTime() + staleSeconds * 1_000).toISOString()
  };
  const response = new Response(JSON.stringify(envelope), {
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": `max-age=${staleSeconds}`
    }
  });
  context.waitUntil(cache.put(cacheRequest(key), response));
  return envelope;
}

export async function loadWithCache<T>(options: {
  cache: Cache;
  key: string;
  now: Date;
  freshSeconds: number;
  staleSeconds: number;
  context: ExecutionContext;
  load: () => Promise<T>;
  onLoadResult: (fault?: ProxyFault) => void;
}): Promise<LoadedValue<T>> {
  const cached = await readCached<T>(options.cache, options.key, options.now);
  if (cached?.freshness === "fresh") {
    return { ...cached, cacheStatus: "hit" };
  }

  const cacheIdentity = options.cache as unknown as object;
  let cacheLoads = inFlightLoads.get(cacheIdentity);
  if (!cacheLoads) {
    cacheLoads = new Map();
    inFlightLoads.set(cacheIdentity, cacheLoads);
  }
  const existing = cacheLoads.get(options.key) as Promise<LoadedValue<T>> | undefined;
  if (existing) return existing;

  const refresh = refreshCachedValue(options, cached);
  cacheLoads.set(options.key, refresh as Promise<LoadedValue<unknown>>);
  try {
    return await refresh;
  } finally {
    if (cacheLoads.get(options.key) === refresh) {
      cacheLoads.delete(options.key);
      if (cacheLoads.size === 0) inFlightLoads.delete(cacheIdentity);
    }
  }
}

async function refreshCachedValue<T>(
  options: {
    cache: Cache;
    key: string;
    now: Date;
    freshSeconds: number;
    staleSeconds: number;
    context: ExecutionContext;
    load: () => Promise<T>;
    onLoadResult: (fault?: ProxyFault) => void;
  },
  cached: CacheRead<T> | null
): Promise<LoadedValue<T>> {
  try {
    const value = await options.load();
    const envelope = writeCached(
      options.cache,
      options.key,
      value,
      options.now,
      options.freshSeconds,
      options.staleSeconds,
      options.context
    );
    options.onLoadResult();
    return { envelope, freshness: "fresh", cacheStatus: "miss" };
  } catch (error) {
    const fault = error instanceof ProxyFault
      ? error
      : new ProxyFault("upstream_unavailable", "offline", 503, "NS data is temporarily unavailable.");
    options.onLoadResult(fault);
    if (fault.publicStatus === "invalidRequest") throw fault;
    if (cached) {
      return { ...cached, freshness: "stale", cacheStatus: "stale-fallback" };
    }
    throw fault;
  }
}

export function responseMeta<T>(loaded: LoadedValue<T>): ResponseMeta {
  return {
    provider: PROVIDER_ID,
    source: PROVIDER_SOURCE,
    attribution: PROVIDER_ATTRIBUTION,
    fetchedAt: loaded.envelope.fetchedAt,
    expiresAt: loaded.envelope.freshUntil,
    freshness: loaded.freshness,
    cacheStatus: loaded.cacheStatus
  };
}
