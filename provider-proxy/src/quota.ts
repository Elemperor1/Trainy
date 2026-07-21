import { DurableObject } from "cloudflare:workers";

export const NS_QUOTA_WINDOW_MILLISECONDS = 5 * 60 * 1_000;
export const NS_QUOTA_MAX_REQUESTS = 240;

export interface NSQuotaDecision {
  allowed: boolean;
  retryAfterSeconds: number;
}

/**
 * Coordinates the one subscription-wide NS upstream budget.
 *
 * The public Worker only calls this object for cache misses, so a single
 * coordination atom remains far below Durable Object throughput limits while
 * providing the global consistency that Cloudflare's location-local rate
 * limiting binding intentionally does not provide.
 */
export class NSUpstreamQuota extends DurableObject<Env> {
  constructor(context: DurableObjectState, environment: Env) {
    super(context, environment);
    void context.blockConcurrencyWhile(async () => {
      this.migrate();
    });
  }

  reserve(nowEpochMilliseconds: number): NSQuotaDecision {
    if (
      !Number.isSafeInteger(nowEpochMilliseconds)
      || nowEpochMilliseconds < 0
    ) {
      return { allowed: false, retryAfterSeconds: 300 };
    }

    const cutoff = nowEpochMilliseconds - NS_QUOTA_WINDOW_MILLISECONDS;
    this.ctx.storage.sql.exec(
      "DELETE FROM reservations WHERE used_at <= ?",
      cutoff
    );

    const usage = this.ctx.storage.sql.exec<{ count: number; oldest: number | null }>(
      "SELECT COUNT(*) AS count, MIN(used_at) AS oldest FROM reservations"
    ).one();

    if (usage.count >= NS_QUOTA_MAX_REQUESTS) {
      const oldest = usage.oldest ?? nowEpochMilliseconds;
      return {
        allowed: false,
        retryAfterSeconds: Math.max(
          1,
          Math.ceil(
            (oldest + NS_QUOTA_WINDOW_MILLISECONDS - nowEpochMilliseconds) / 1_000
          )
        )
      };
    }

    this.ctx.storage.sql.exec(
      "INSERT INTO reservations (used_at) VALUES (?)",
      nowEpochMilliseconds
    );
    return { allowed: true, retryAfterSeconds: 0 };
  }

  private migrate(): void {
    this.ctx.storage.sql.exec(`
      CREATE TABLE IF NOT EXISTS _sql_schema_migrations (
        id INTEGER PRIMARY KEY,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `);
    const version = this.ctx.storage.sql.exec<{ version: number }>(
      "SELECT COALESCE(MAX(id), 0) AS version FROM _sql_schema_migrations"
    ).one().version;

    if (version < 1) {
      this.ctx.storage.sql.exec(`
        CREATE TABLE IF NOT EXISTS reservations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          used_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS reservations_used_at ON reservations(used_at);
        INSERT INTO _sql_schema_migrations (id) VALUES (1);
      `);
    }
  }
}
