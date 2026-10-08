// Japan-specific bindings and settings, read defensively.
//
// `ODPT_CONSUMER_KEY` is deliberately not in `secrets.required`: the Worker must
// still deploy and serve NS without it. The other names come from wrangler.jsonc
// (`kv_namespaces`, `vars`). Every field may therefore be absent at runtime, and
// the generated `Env` types (which show vars as literal strings) are not trusted.

export interface JapanEnv {
  kv: KVNamespace | undefined;
  /** The ODPT consumer key, or undefined when absent or an unresolved placeholder. */
  token: string | undefined;
  /** The declared source licence id, lower-cased; empty when none is declared. */
  license: string;
  /** Comma-separated odpt.Railway ids overriding the built-in list; empty for the default. */
  railways: string;
}

function isKVNamespace(value: unknown): value is KVNamespace {
  return typeof value === "object" && value !== null
    && typeof (value as { get?: unknown }).get === "function"
    && typeof (value as { put?: unknown }).put === "function";
}

export function cleanToken(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const token = value.trim();
  if (!token || token.length > 256 || token.startsWith("$(") || /\s/u.test(token)) return undefined;
  return token;
}

export function japanEnv(env: Env): JapanEnv {
  const raw = env as unknown as Record<string, unknown>;
  return {
    kv: isKVNamespace(raw.JAPAN_DATA) ? raw.JAPAN_DATA : undefined,
    token: cleanToken(raw.ODPT_CONSUMER_KEY),
    license: typeof raw.JAPAN_SOURCE_LICENSE === "string" ? raw.JAPAN_SOURCE_LICENSE.trim().toLowerCase() : "",
    railways: typeof raw.JAPAN_ODPT_RAILWAYS === "string" ? raw.JAPAN_ODPT_RAILWAYS : ""
  };
}
