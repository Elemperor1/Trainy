# Trainy NS provider proxy

This Cloudflare Worker is Trainy's credential boundary for the Netherlands NS
MVP. It is deliberately not a generic relay: callers can only use the fixed
`GET` routes below, and every upstream host, path, method, header, input,
response field, timeout, and cache policy is owned by the Worker.

It also hosts the Japan timetable service (`/v1/japan/*`, described in
[Japan timetable routes](#japan-timetable-routes-odpt)). The service keeps its
NS-only name because renaming a Worker would change its endpoint and strand its
Durable Object state. The Japan service is built but switched off until a
source licence is declared.

## Trust boundary

```text
Trainy iOS app
  -> HTTPS Trainy proxy URL (no provider credential)
  -> validated /v1/ns/* operation
  -> fixed gateway.apiportal.ns.nl operation (Worker secret added here only)
  -> normalized Trainy JSON (raw NS payload and headers stop here)
```

The Japan routes follow the same rule with a different shape: the Worker reads
ODPT on a schedule, validates and stores a timetable snapshot in Workers KV, and
answers app requests from that snapshot. The app never contacts ODPT and never
sees `ODPT_CONSUMER_KEY`.

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
guard. A missing, blank, or unresolved credential fails before either upstream
guard, so configuration failures cannot consume the shared provider allowance.

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

## Japan timetable routes (ODPT)

**Status: built and switched off.** The Worker ships with no source licence
declared and no ODPT key. Every Japan route then answers a retryable `503`, the
Cron Trigger records `not_configured` and does nothing else, and
`GET /v1/health/providers` reports `japan` as `unsupported`. The NS routes are
unaffected.

Public ODPT documentation indicates that ODPT carries no Shinkansen timetables
and that JR East's data is limited to the Challenge contest (see
[the decision record](../docs/japan-data-decision-record.md)). This service is
therefore built to answer that question with a real run, to refuse data it may
not publish, and to take a licensed source later without changing the routes.

### Routes

| Route | Validated input | Response |
| --- | --- | --- |
| `GET /v1/japan/stations?query=…&limit=…` | 2–80 visible characters; limit 1–25 (default 20) | stations: id, Japanese and English name, coordinates, code, line ids |
| `GET /v1/japan/trips?from=…&to=…&date=…&after=…&limit=…` | two different station ids; `date` as `YYYY-MM-DD`; `after` as `HH:MM` from `00:00` to `29:59`; limit 1–25 (default 10) | scheduled trains that call at both stations in that order, with times |
| `GET /v1/japan/trips/{id}?date=…` | an id from trip search | the train and every stop |
| `GET /v1/japan/disruptions?line=…&limit=…` | optional line id (an `odpt.Railway:` id); limit 1–25 (default 10) | line-level operator notices |

- **Times** are `YYYY-MM-DDTHH:MM:00+09:00` and come only from the published
  timetable. They are scheduled times: no delays, no platform changes, and no
  vehicle positions.
- **Service date.** The Japanese service day runs from 04:00 to 03:59, so a
  train that leaves at 00:30 belongs to the previous date. A `date` names a
  service date, a stop after midnight carries the next calendar day in its
  timestamp, and leaving `date` out means the service date in effect now.
- **Calendars.** Each train runs on weekdays, Saturdays, Sundays and holidays,
  or on dates the source lists. Japanese national holidays (including
  substitute and citizens' holidays) are computed from the statutory rules for
  2022 through 2099.
- **`meta`** names the provider, source, attribution text, licence,
  `snapshotId`, `fetchedAt`, `expiresAt` (`fetchedAt` plus 36 hours),
  `freshness` (`fresh`, or `stale` after 36 hours), `cacheStatus` (`hit` or
  `stale-fallback`) and `coverage` (`from` and `until` service dates). A stale
  snapshot still answers for the dates it covers. A date outside `coverage`
  gets `400 date_out_of_range`.
- **Line status** (`disruptions`) reads the operator feed itself through a
  60-second fresh and 10-minute stale cache. It does not depend on a timetable
  snapshot. Notices are per line, not per train, and an empty list means no
  notice was published, not that service is normal.
- **Errors** use the NS shape with `provider_id: "japan"`: `400` for invalid
  input and `date_out_of_range`; `404` for `station_not_found`,
  `trip_not_found`, `trip_not_running` and `line_not_found`; `429` for the
  client or upstream limiters; `503` for `snapshot_unavailable` (retry hint 300
  seconds when nothing is published, 60 when storage cannot be read),
  `line_status_unavailable`, `missing_credential` and upstream outages.

### How timetable data gets in

A Cron Trigger (`10 18 * * *`, which is 03:10 in Japan) runs the ingestion
once a night. It never throws, and every outcome leaves a record.

1. **Check configuration.** It needs the `JAPAN_DATA` namespace, the key, and a
   publishable licence declaration. `JAPAN_SOURCE_LICENSE` must be
   `odpt-basic`, `commercial-agreement` or `cc-by-4.0`. An empty value, an
   unknown value, or `odpt-challenge` (the contest licence, which forbids
   passing data to third parties) stops the run before any request is made.
2. **Fetch.** One request for calendars, then a railway and a station request
   per configured railway, then one timetable request per railway, one at a
   time to bound memory. Requests are fixed `GET`s to
   `api.odpt.org/api/v4` with redirects off, a 30-second deadline and an
   8 MiB body ceiling.
3. **Validate.** Each timetable must name a known railway, operator, train
   number and calendar, have at least two stops at known stations, and have
   times that rise (a time that falls is read as crossing midnight; anything
   under 04:00 is read as after midnight; gaps over 12 hours or spans over 30
   hours are rejected).
4. **Guard.** The run is held back, and the served snapshot left alone, when
   more than 25% of fetched timetables are rejected (`too_many_rejected`),
   when fewer than 10 trips remain (`no_data`), or when the new snapshot has
   under half the trips of the one being served (`regression`).
5. **Build and publish.** Trips are grouped into shards by line and calendar.
   A through train that runs on several lines is stored on each. The job
   writes every shard, waits 65 seconds for Workers KV to propagate them, then
   points the manifest at the new snapshot. Readers see the whole old snapshot
   or the whole new one.

| KV key | Content | Lifetime |
| --- | --- | --- |
| `japan/v1/manifest` | the served snapshot's index: source, licence, coverage, calendars, shard keys | until replaced |
| `japan/v1/manifest-previous` | the snapshot served before it | until replaced |
| `japan/v1/snap/<snapshotId>/stations` | stations that appear in a trip | days to coverage end plus 8, between 3 and 60 |
| `japan/v1/snap/<snapshotId>/<line>~<calendar>` | trips of one line on one calendar | same |
| `japan/v1/last-run` | outcome, code, counts and per-railway report of the latest run | 30 days |

Two snapshots are kept. After a publish, the snapshot that fell out of the
window is deleted; a failed cleanup is left to expire. Shards are never
modified, so a reader holding an older manifest still finds its shards.
Readers cache the manifest for 30 seconds and each parsed shard for the life
of the isolate.

Outcomes recorded in `last-run` and in the `japan_ingest` event:
`published`, `not_configured`, `license_blocked`, `no_data`,
`too_many_rejected`, `regression`, `upstream_failed`, `storage_failed` and
`internal_error`. Only `published` changes what riders see.

### Cost and plan requirements

A run for the default ten Shinkansen railways makes 31 ODPT requests. Each KV
read, write and delete is also a subrequest, so in the busiest run of the cycle
(the one that also retires the oldest snapshot) the test fixture's ten lines
with two calendars each come to 48 KV operations and 79 subrequests in all.
Workers Free allows 10 ms of CPU and 50 subrequests per invocation, including
Cron Triggers, and parsing multi-megabyte timetables cannot fit in 10 ms.
**Running ingestion needs the Workers Paid plan.** The production account is on
Free with zero Cron Triggers today. Without Paid, nothing breaks: the job
simply cannot complete, and the routes stay switched off.

Line status costs up to one request per configured railway (ten by default) per
cache refresh, at most once a minute while riders ask, behind the shared
`UPSTREAM_RATE_LIMITER` under its own `japan:odpt` key.

### Configuration

| Name | Kind | Meaning | Shipped value |
| --- | --- | --- | --- |
| `ODPT_CONSUMER_KEY` | Worker secret | ODPT API key. Sent only to `api.odpt.org`. | not set |
| `JAPAN_SOURCE_LICENSE` | variable in `wrangler.jsonc` | licence the key's data may be republished under (list above) | `""` |
| `JAPAN_ODPT_RAILWAYS` | variable in `wrangler.jsonc` | comma-separated `odpt.Railway:` ids (up to 40) replacing the default ten Shinkansen railways | `""` |
| `JAPAN_DATA` | KV namespace binding | snapshots and run records | provisioned by Wrangler on the first upload that includes it |

`ODPT_CONSUMER_KEY` is deliberately not in `secrets.required`. A required secret
blocks every upload until it exists, and this Worker must keep deploying NS
changes before anyone has an ODPT key. Two consequences: use the
`versions upload` and `versions deploy` flow this README already requires,
which keeps existing secrets, and do not run a plain `wrangler deploy`, which
may drop an undeclared secret. For local runs, a secret that is not declared is
read from `.dev.vars` only if a variable of the same name is also supplied (see
below).

### Operator steps

#### 1. Check what ODPT returns, locally

This needs only an ODPT consumer key and deploys nothing. It answers whether
ODPT has any Shinkansen timetable data, which is the open question in the
decision record.

1. Register at https://developer.odpt.org/ and request a consumer key. Read the
   terms that apply to it before you declare a licence (step 3 under
   [Put it in production](#2-put-it-in-production)).
2. Install the pinned tools once, with Node 24 as in CI:
   `npm ci --prefix provider-proxy`.
3. Create `provider-proxy/.dev.vars` at mode `600` (it is git-ignored):

   ```text
   NS_SUBSCRIPTION_KEY=local-unused
   ODPT_CONSUMER_KEY=<your consumer key>
   ```

4. Start the Worker in test-scheduled mode. The `--var` values are a licence
   needed only to let the local simulator run (it republishes nothing, since
   nobody can reach the simulator) and a placeholder that makes Wrangler load
   the real key from `.dev.vars`. They are not a production declaration:

   ```bash
   cd provider-proxy
   npx wrangler dev --test-scheduled \
     --var JAPAN_SOURCE_LICENSE:odpt-basic \
     --var ODPT_CONSUMER_KEY:from-dev-vars
   ```

5. In a second terminal, trigger a run and read the result:

   ```bash
   curl -s "http://127.0.0.1:8787/__scheduled?cron=10+18+*+*+*"
   # wait about two minutes: the run pauses 65 seconds before publishing
   curl -s http://127.0.0.1:8787/v1/health/providers
   ```

   The Wrangler console prints one `japan_ingest` line and one
   `japan_ingest_railway` line per railway. In each, `found` says whether ODPT
   knows the railway, and `stations`, `timetables`, `trips` and `rejected` are
   counts. If `timetables` is `0` for every Shinkansen railway, ODPT has no
   Shinkansen timetables for this key. That is the expected result, and the
   health status will read `unsupported`. If timetables exist, `trips` and
   `rejected` show how many survived validation, and the same simulator serves
   `/v1/japan/stations?query=tokyo` and the other routes once the run publishes.

6. Delete `.dev.vars` and the `.wrangler` state when finished.

#### 2. Put it in production

Only if step 1 found usable data **and** the key's terms allow a paid app to
republish it. Each step below is a production change that needs the owner's
approval.

1. Move the account to Workers Paid.
2. Add the key without printing it:
   `npx wrangler versions secret put ODPT_CONSUMER_KEY --name trainy-ns-provider-proxy`.
3. Set `JAPAN_SOURCE_LICENSE` in `wrangler.jsonc` to the licence that applies
   (`odpt-basic` or `commercial-agreement`) and add the attribution wording the
   terms require to `ODPT_ATTRIBUTION` in `src/japan/odpt.ts`. Do not set it
   until the terms are read; it is the switch that turns serving on.
4. Review, then ship through the reviewed `versions upload` and
   `versions deploy` flow below. The first upload that includes `JAPAN_DATA`
   makes Wrangler provision the namespace.
5. The next 03:10 (Japan) run publishes. Check `GET /v1/health/providers`:
   `ok` means a fresh snapshot is served.

### Operating it

| Health status (`japan`) | Meaning |
| --- | --- |
| `ok` | a snapshot under 36 hours old is served; the message gives its coverage |
| `stale` | the snapshot is over 36 hours old but still answers for its covered dates |
| `offline` | the latest run failed and no snapshot is published |
| `missingCredential` | no `ODPT_CONSUMER_KEY` |
| `unsupported` | no storage, no publishable licence declared, or the source published no usable data |
| `unknown` | configured, waiting for the first run |

- **Read a run.** `japan/v1/last-run` holds the outcome and the per-railway
  report. Find the namespace id with `npx wrangler kv namespace list`, then
  `npx wrangler kv key get japan/v1/last-run --namespace-id <id> --remote`.
  Workers Logs carry the same counts as `japan_ingest` events.
- **Turn it off.** Set `JAPAN_SOURCE_LICENSE` back to `""` and ship that
  version. Timetable and line-status routes answer `503` immediately and health
  reads `unsupported`. Stored shards stay until they expire; to remove them
  sooner, delete the keys under `japan/`.
- **Undo a bad snapshot.** While `manifest-previous` still names the last good
  snapshot, copy its value over `japan/v1/manifest`. The next nightly run
  replaces it again, so fix the cause first.
- **Each February,** compare `nationalHolidays` in `src/japan/calendar.ts`
  with the Cabinet Office list for the coming year. The rules cover the
  statutory holidays; a one-off special holiday is not predicted.
- **Keep the Cron Trigger after 03:00 and before 04:00 Japan time.** Coverage
  starts at the service date in effect when the snapshot is generated, so a
  rider asking at 03:30 still finds the previous service day.

### Known limits

- ODPT gives each railway its own station ids, so a station served by two
  railways has two ids and no merging is attempted. A through train appears on
  each line it runs on.
- Year-end and New Year service, and other special days, are covered only when
  the source publishes explicit calendars.
- The attribution text is a placeholder until the licence text is read (gap G2
  in the decision record).
- ODPT's per-key rate limit is undocumented (gap G4). A nightly run and one
  line-status refresh a minute are small, but confirm before marketing.
- There are no vehicle positions, delays, or train-level status.

## Credential-safe observability

Persisted automatic invocation logs are disabled. One custom structured request
event records only:

- event name and random request ID;
- provider and fixed route family;
- request method, public status, cache status, and latency bucket;
- normalized error code.

The Japan ingestion job adds two events, both limited to counts and configured
railway ids: `japan_ingest` (outcome, code, duration, and trip, station, line,
and rejected-timetable counts) and `japan_ingest_railway` (railway id, whether
the source knew it, and its station, timetable, trip, and rejected counts).
ODPT carries its key in the request URL, so the Worker never logs an upstream
URL and never reports upstream error text.

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

The Japan tests run in the same gate. They use an in-memory KV that enforces
the real KV limits, plus one file that runs against the Workers KV simulator and
the shipped configuration. Running a Japan ingestion locally is covered in
[Check what ODPT returns, locally](#1-check-what-odpt-returns-locally).

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

Verification record (2026-07-20): the credential-neutral gate passed 35/35
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

Japan verification record (2026-10-07): the credential-neutral gate passed
294/294 Workerd tests, which is the 35 NS tests unchanged plus 259 Japan tests,
and the dry-run bundle (103.19 KiB, 26.19 KiB gzip) lists the `JAPAN_DATA`
binding and the two empty Japan variables. The Japan tests cover the calendar
and holiday rules, ODPT normalization and rejection, snapshot building, the
ingestion guards and the order of their writes, every route, and a publish and
read cycle against the Workers KV simulator with the shipped configuration. The
local scheduled run from "Check what ODPT returns, locally" was exercised with a
placeholder key from a sandbox that could not reach `api.odpt.org`: Wrangler
loaded the key from `.dev.vars` through the placeholder variable, the run
recorded `upstream_failed` with `upstream_network_error`, health reported
`japan` as `offline`, and neither the key nor an ODPT URL appeared in the
console output. No real ODPT response has been observed yet, so gaps G1 to G4 in
the decision record are still open. Nothing was deployed, and the production
Worker is unchanged.

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
