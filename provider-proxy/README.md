# Trainy NS provider proxy

This Cloudflare Worker is Trainy's credential boundary for the Netherlands NS
MVP. It is deliberately not a generic relay: callers can only use the four
fixed `GET` routes below, and every upstream host, path, method, header, input,
response field, timeout, and cache policy is owned by the Worker.

## Trust boundary

```text
Trainy iOS app
  -> HTTPS Trainy proxy URL (no provider credential)
  -> validated /v1/ns/* operation
  -> fixed gateway.apiportal.ns.nl operation (Worker secret added here only)
  -> normalized Trainy JSON (raw NS payload and headers stop here)
```

The app receives a proxy base URL, normalized rail facts, freshness metadata,
public attribution, and compact errors. `NS_SUBSCRIPTION_KEY` exists only as a
Worker secret or as an ignored, mode-600 local smoke input. The Worker never
returns or logs the key, auth header, raw upstream body, raw upstream URL,
station search text, trip identifiers, device identifiers, or rider itinerary.
There is no CORS opt-in because the supported client is the native app.

## Public contract

| Route | Validated input | Upstream behavior | Response |
| --- | --- | --- | --- |
| `GET /v1/health/providers` | no query parameters | never probes NS; reports the last bounded cache/provider outcome | app-safe provider and cache health |
| `GET /v1/ns/stations?query=…&limit=…` | 2–80 visible characters; limit 1–25 | fetches a fixed station catalog; search text is filtered only inside the Worker | station code/name/coordinates |
| `GET /v1/ns/departures?station=…&limit=…` | `[A-Z0-9]{1,8}`; limit 1–25 | fixed NS departures operation | normalized departures |
| `GET /v1/ns/disruptions?station=…&limit=…` | optional validated station code; limit 1–25 | fixed active-disruptions operation | normalized rider alerts |

Unknown routes, methods, and query parameters are rejected before provider
access. Upstream redirects are not followed. Upstream responses have a 5.5
second absolute deadline that remains active through body consumption and a 2
MiB streamed body ceiling. Required provider fields are length-bounded and
validated before they enter a cached normalized record; oversized optional
alert detail falls back to safe copy. Public responses are `no-store`, omit
CORS, and include defensive content/security headers.

Each upstream route must expose its expected collection shape. A missing or
wrong-shaped collection, or a non-empty collection in which every record is
invalid, is a normalized `invalid_upstream_response` failure and cannot replace
a good cache entry with fresh emptiness. Explicit empty collections remain
valid. Provider timestamps must be calendar-valid ISO-8601 values with an
explicit `Z`, `+HHMM`, or `+HH:MM` offset; accepted values are canonicalized to
UTC before caching. Departure status must agree with scheduled/actual timing.

## Caching, limits, and failure behavior

| Data | Fresh TTL | Stale fallback |
| --- | ---: | ---: |
| Station catalog | 1 hour | 24 hours |
| Departures | 20 seconds | 5 minutes |
| Active disruptions | 60 seconds | 10 minutes |

The Worker applies a 60-request/minute client-and-route guard. Before an actual
NS cache-miss fetch, it also applies a fast 48-request/minute location-local
guard shared by all NS operations and reserves one request from a single
subscription-wide Durable Object. That object enforces at most 240 attempted NS
requests in any rolling five-minute window. The authenticated `Ns-App`
Reisinformatie API page was reviewed on 2026-07-20 and publishes a limit of 300
requests per five minutes for external non-paying users, so the global budget
keeps 20% (60 requests) as operational headroom. Reservations happen before the
fetch and are not refunded on failure. Cache hits consume neither upstream
guard.

Cloudflare documents its Rate Limiting binding as location-local, permissive,
and unsuitable for accurate accounting. It is therefore only a fast abuse
backstop; the Durable Object is the authoritative subscription budget. A quota
check has a 1.5-second deadline and fails closed with a compact retryable `503`
if global coordination is unavailable or malformed. An exhausted budget
returns a bounded `429` and the rolling window's next safe retry time. The one
global coordination object receives only cache misses and its maximum sustained
rate is below one request per second, so its deliberate singleton scope remains
well below the documented Durable Object throughput guidance.

Namespace IDs `1001` and `1002` were unused across the target account's
existing Worker bindings during the 2026-07-20 preflight. The owner selected
the free `workers.dev` hostname, and the account has no DNS zone, so a
selected-zone WAF/rate rule is unavailable. The global quota protects the NS
subscription across Cloudflare locations, but the public route still lacks the
additional zone-level abuse filtering and emergency rules a custom domain could
provide. The per-client IP guard is only a coarse anonymous-client backstop;
monitor shared-mobile-network false positives after launch.

Concurrent same-key misses are coalesced inside each Worker isolate before NS
is called. This limits local fan-out but is not a distributed lock; the global
quota remains the cross-location accounting boundary. Rejected input and an
upstream unknown-station response never poison the shared provider-health
record.

When a refresh fails inside the stale window, the Worker returns the last safe
normalized value with `meta.freshness = "stale"` and
`meta.cacheStatus = "stale-fallback"`. Otherwise it returns only a compact,
stable error:

- `400 invalidRequest` for rejected input.
- `404 notFound` for an unknown route.
- `429 rateLimited` with a bounded `Retry-After` value.
- `502/503 offline` for unreadable, redirected, timed-out, or unavailable NS
  responses.
- `503 missingCredential` for absent or rejected proxy configuration.

The app preserves the last same-query station results or same-board departures
when possible, labels stale data, and presents offline, rate-limit, empty,
no-match, and retry states without implying live availability.

## Credential-safe observability

Persisted automatic invocation logs are disabled. One custom structured request
event records only:

- event name and random request ID;
- provider and fixed route family;
- request method, public status, cache status, and latency bucket;
- normalized error code.

Do not add request URLs, query strings, arbitrary headers, response bodies, or
exception messages to custom logs. Automatic traces are disabled because span
metadata can exceed this allowlist. Safe custom events are sampled at 100%
until post-launch volume is reviewed. The dedicated Worker dashboard was
checked on 2026-07-20: Workers Logs are enabled at 100% sampling, traces are
disabled, and the checked-in configuration keeps persisted automatic
invocation logs disabled while authoring the allowlisted application event
above. An authorized real-time Tail check showed that Tail's transient
Cloudflare envelope still includes the request URL, headers/IP, and `cf`
metadata while the Tail session is active. Tail is therefore an incident-only,
query-sensitive diagnostic surface; the custom event allowlist does not mean
Cloudflare never processes request metadata. The account is on Workers Free,
whose dashboard limits are 100,000 Worker
requests/day, 10 ms CPU/request, and 200,000 log events/day; Cloudflare
documents three days of Workers Logs retention for this tier. Exactly one
active account member was visible, which is the current log-viewer boundary.
The account has no zone and therefore no zone request-logging layer. Re-review
membership, sampling, retention, and any newly added zone/gateway rules before
production changes.

## Local development and verification

Install and run the credential-neutral gate:

```bash
npm ci --prefix provider-proxy
npm run check --prefix provider-proxy
```

The gate supplies a literal non-secret fixture binding, runs generated-type
validation, both TypeScript checks, Workerd contract tests, and a Wrangler
dry-run bundle. CI never needs an NS credential.

For the authorized local live path, keep the existing key only in
`TrainyIOS/Config/ns.env` at mode `600`, then run:

```bash
scripts/smoke-ns.sh
scripts/smoke-ns-proxy.sh
```

The proxy smoke starts Workerd on loopback, validates station search and a
departure board, prints counts/freshness only, scans all captured output for the
credential value and upstream-only markers, and deletes temporary responses,
logs, and registry state. `scripts/dev-ns-proxy.sh` provides a longer-running
loopback server. The loader rejects duplicate assignments, malformed quoting,
unsupported keys, substitution syntax, non-loopback hosts, and ports outside
`1...65535`; it validates the whole env file before exporting any value. The
scripts never replay raw Wrangler output, create `.dev.vars`, or place the
credential on the command line.

Verification record (2026-07-20): the credential-neutral gate passed 34/34
Workerd tests. Coverage includes same-key coalescing, the whole-response
deadline, per-field bounds, unknown-station health isolation, strict collection
shapes, all-invalid versus explicit-empty responses, calendar-valid timestamp
normalization, stale preservation on structurally invalid refresh, the shared
fast guard, the 240-request rolling global budget and retry transition,
fail-closed quota coordination, exact-code station ranking, rate limits, and
credential-safe errors. The
authorized proxy smoke queried `UT`, returned 5 station matches with exact code
`UT` first, and returned 20 fresh Utrecht departures with NS provenance; it printed neither
the credential nor raw Wrangler output. The iOS suite passed 58/58 tests,
including strict native timestamps, independent board/alert ordering,
superseded-load protection, and deterministic UI state renders.

The iPhone 17 / iOS 26.5 runtime pass exercised live station/board success,
source-backed no-match, automatic stale copy, forced offline fallback, and
recovery after the Worker restarted. Light and Dark Mode and AX2XL were checked
separately. With VoiceOver enabled, the simulator accessibility tree exposed
logical headings/order, labelled fields/actions, station names plus codes,
source/freshness text, 44-point search/back targets, 54-point tabs, and station
rows at least 81 points high. The expanded repository, generated-product,
temporary-log, and simulator-log scan first caught an authorized value retained
only in an older Xcode DerivedData build-command attachment; that generated
cache was removed. The clean rerun checked both authorized local provider
values across 58,811 files and checked 122 shipping app files for upstream-only
markers. Neither credential remained, and the shipping app contained no NS
upstream host, auth-header name, or secret marker.

A canonical simulator candidate injected only the public HTTPS Worker URL. Its
first pre-promotion Utrecht request displayed the rider-safe unavailable state;
the visible retry recovered to one source-backed Utrecht station and a
20-service departure board. The board automatically changed to explicit
stale/expired copy at `validUntil`, a later refresh restored fresh data, and the
bottom of the scroll exposed active disruption notices plus separate
board/alert source cards with the exact attribution. A nonsense query produced
the no-match state and a valid query recovered. That pass found exact code `UT`
sorted behind generic substring matches and drove the exact-code regression.
After the fixed candidate reached production, the final simulator pass rendered
one `UT` station, two current departures, one current alert, and separate fresh
board/alert source disclosures from the production Worker.

Bootstrap record (2026-07-20): after explicit approval, the dedicated
`trainy-ns-provider-proxy` service was created as version
`37bdadd5-3652-4c54-8ee8-e0cba777c6c2`. Wrangler reported `No targets deployed`.
Independent account API checks found one 100% deployment record but confirmed
`workers.dev` disabled, preview URLs disabled, zero custom domains, zero cron
triggers, and zero account zones. The version has one `fetch` handler, only the
reviewed `CLIENT_RATE_LIMITER`, `UPSTREAM_RATE_LIMITER`, and secret-text
`NS_SUBSCRIPTION_KEY` bindings, and no returned secret value. Invocation logs
and traces remain disabled. At bootstrap the Worker was not publicly reachable,
and the bootstrap did not make NS rider-live.

Free-hostname activation record (2026-07-20): after the owner selected the free
route, `workers_dev` was changed to `true` in the source-of-truth config while
`preview_urls` remained `false`. The exact Worker subdomain API attached the
unchanged reviewed version to
`https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`; it did not upload
code, replace bindings, or return the NS secret. Public smoke reported the
credential configured, then returned 5 Utrecht station matches, 20 fresh
departures, and 2 active disruptions. `POST` and unknown-route probes returned
`405` and `404`; health recovered to `ok` with a fresh station cache. Public
responses retained `private, no-store` and the reviewed security headers. The
credential boundary rerun passed. The URL is not a source-controlled app
default; a later canonical simulator candidate explicitly injected and verified
it without changing any distributed build. At this hostname-attachment stage,
NS correctly remained adapter-ready because the hardened quota path had not yet
been deployed.

Authenticated product and account review (2026-07-20): under the active
`Trainy` subscription, the `Ns-App` Reisinformatie API page published the
external non-paying limit of 300 requests per five minutes and instructed
clients to honor `Retry-After` on `429`. The authenticated product/API pages
displayed no separate cache-duration, attribution, license, or reuse clause.
The starter guide says product conditions must be accepted only when a terms
link or checkbox is shown, and says that when no such control is visible no
product conditions are established; the active product page showed none.
Trainy therefore continues to follow the public NS conditions and disclaimer.
Its text attribution is a conservative provenance disclosure, and its bounded
cache windows are engineering choices for freshness and responsible capacity
use, not NS-prescribed wording or TTLs.

The same review confirmed the Workers Free plan, three-day log retention,
100,000 requests/day, 10 ms CPU/request, 200,000 log events/day, Workers Logs
enabled at 100%, traces disabled, and one active account member. In response to
the numeric NS quota, the hardened production version uses the shared
48/minute fast guard plus the global rolling 240-per-five-minute Durable Object
budget described above.

## Production deployment record and operating guardrails

The approved one-time migration bridge used the byte-identical serving Worker
bundle (SHA-256
`5242b151c5d2ff393a3efa5c1ff33b46342daeea27fa802d23708c464e1ad727`),
compatibility date `2026-07-19`, and the existing 60/minute client plus
120/minute upstream bindings. It added only the otherwise-unused
`NSUpstreamQuota` export/binding and SQLite migration tag `v1`. Bridge version
`65f469e7-ef2b-4acf-8503-e6f3793be5a2` became deployment
`f9f5f96a-21da-4db9-bb5f-e87538361f37`; health, station search, departures,
disruptions, `405`, `404`, headers, configuration, and credential-boundary
checks passed before the hardened upload continued.

Hardened candidate `0ece40b0-b27a-43aa-a865-55445909a2a1` was uploaded without
traffic, inspected, and dry-run before promotion. It uses compatibility date
`2026-07-20`, tag `ns-quota-v1`, the same SQLite namespace, 60/minute client
limiter, one shared 48/minute fast guard, one global rolling 240/5-minute
budget, hidden NS secret binding, previews off, persisted invocation logs off,
and traces off. Deployment `46a26a6a-8abe-4091-9b19-3c32b20ccefa` promotes
that version to 100%. The downloaded active script is 37,522 bytes with
SHA-256 `76866b72d9c41dde9c0d9402f3da56b34becf76893c4792153cb35d591cf1767`.

The first request immediately after promotion briefly observed bridge ordering
during edge propagation. The active-script check, three repeated edge requests,
and canonical smoke then returned exact code `UT` first. Final public checks
also proved a fresh Amsterdam cache miss through the global quota path, a fresh
disruption response, normalized client `429` plus recovery, health,
method/route rejection, reviewed security/no-store headers, and no credential
in output. The global budget transition is covered deterministically rather
than by consuming the production NS allowance. A final iPhone 17 pass rendered
current Utrecht departures, one current alert, and separate fresh source
disclosures. Provider metadata became active only after these checks and the
full build/test/secret-boundary gates passed.

The checked-in target remains the dedicated NS-only Worker
`trainy-ns-provider-proxy`. Never upload this contract to the pre-existing
shared `trainy-provider-proxy` service, and retain an explicit `--name` guard in
operator commands. Preserve one global `NS_UPSTREAM_QUOTA` object; do not add
operation-specific budgets that can sum beyond the subscription allowance.
Re-review the 300/5-minute provider limit after any NS subscription/product
change.

The owner-approved endpoint is
`https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`; preview URLs remain
disabled. The account has no zone, so this free route has no selected-zone WAF
or emergency rules. Monitor volume and shared-network false positives, and
require separate approval for a custom-domain migration. Persisted invocation
logs and traces must stay off. Keep the custom event allowlisted, treat
real-time Tail as query-sensitive, and re-check account membership, sampling,
retention, and any new gateway/zone logging before traffic changes.

The bridge version is the post-migration rollback baseline. Original version
`37bdadd5-3652-4c54-8ee8-e0cba777c6c2` cannot be used across the Durable Object
lifecycle boundary. During an incident, roll back to bridge version
`65f469e7-ef2b-4acf-8503-e6f3793be5a2`, ship a forward fix that preserves the
migrated class, or disable the route. Never delete the migration or state.

The temporary Wrangler OAuth session was logged out after verification, and
its local mode-600 plaintext fallback file was removed. Future changes require
a new short-lived authorization with account `Workers Scripts Write` plus only
the minimum read permission needed for verification. Before any change, run
`npm ci --prefix provider-proxy` and `npm run check --prefix provider-proxy`,
inspect bindings without reading the secret, dry-run traffic changes, repeat
public checks, and rerun the app/log/artifact secret boundary.

Cloudflare configuration remains source-controlled in `wrangler.jsonc`.
Relevant primary references: [Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/),
[Rate Limiting bindings](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/),
[zone-level WAF rate limiting](https://developers.cloudflare.com/waf/rate-limiting-rules/create-api/),
[API token templates](https://developers.cloudflare.com/fundamentals/api/reference/template/),
[Workers Logs retention](https://developers.cloudflare.com/workers/observability/logs/workers-logs/),
[Cache API](https://developers.cloudflare.com/workers/runtime-apis/cache/), and
[versions/deployments](https://developers.cloudflare.com/workers/versions-and-deployments/),
[Durable Object migrations](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/),
and [rollback limits](https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/).

## Rotation and emergency response

For a planned key rotation, create/authorize the replacement in the NS portal
and first validate it through the credential-safe loopback smoke. Then use
`npx wrangler versions secret put NS_SUBSCRIPTION_KEY --name
trainy-ns-provider-proxy` to create a non-serving Worker version, inspect its
unchanged code/bindings with the secret value hidden, dry-run the traffic
change, and deploy it with `npx wrangler versions deploy --name
trainy-ns-provider-proxy`. Verify normalized public results and the allowlisted
custom log, then revoke the old subscription. If public validation fails before
the old key is revoked, restore the preceding post-migration version. Never
overlap keys longer than the verification window.

For suspected exposure, disable the affected NS subscription first, expect the
app to show cached stale data and then a recoverable unavailable state, rotate
the Worker secret, review only the allowlisted custom event (using real-time
Tail only when its query-sensitive metadata is justified), and verify recovery.
Do not weaken missing-credential behavior or temporarily ship a key in the app.
