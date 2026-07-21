# Release-readiness tranche — 2026-07-19

## Scope and preservation

This tranche is limited to five verified improvements: the iOS build path, the
authoritative test/CI path, rider search correctness, provider-smoke
maintainability, and truthful provider availability. The working tree already
contained an in-progress design-system refactor and documentation changes when
the audit began. Those changes are treated as user-owned baseline work; this
tranche adds only the focused files and hunks recorded below. No commit, push,
pull request, merge, or deployment is part of this work.

## Pre-edit audit and ranking

| Rank | Verified candidate | User/release impact | Evidence | Regression risk | Effort | Selected |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Canonical iOS build/test path cannot finish | Critical: no release candidate can pass the owning gate | `scripts/build-ios.sh` reached the app bundle, then exited 65 because Crashlytics looked under DerivedData while `-clonedSourcePackagesDirPath` used a separate directory; XCTest failed at the same phase | Low | Low | Yes |
| 2 | Authoritative coverage is incomplete and CI does not test | Critical: 26 checked-in XCTest methods were never executed | Xcode reported 27/27 while 53 methods existed before this tranche; `NSProviderTests.swift` and `RailDesignSystemTests.swift` were absent from the test target; CI only built | Medium | Medium | Yes |
| 3 | A shipped quick-search can return a false empty state | High: core trip discovery contradicts its own suggestion | In iPhone 17 Simulator, activating “Search for Tokyo to Shin-Osaka” returned “No Japan services found” and suggested the same query because the only match was already tracked | Low | Low | Yes |
| 4 | Maintained offline provider smokes no longer compile | High: provider/provenance regressions lose their fast local gate | All three smokes failed at `TrainModels.swift` after a domain model gained a UIKit-backed `RailDesign` dependency; duplicated source lists also omitted the NS adapter | Low | Medium | Yes |
| 5 | Netherlands coverage is overclaimed | High trust risk: roadmap readiness is presented as rider availability | `NSTrainProvider` was `.active` and the Supported Regions screen placed Netherlands under “Available now,” although no rider-facing NS station-board/search surface or production proxy is connected | Medium | Medium | Yes |
| 6 | Add broader provider coverage | Potentially high, but expands product/data/licensing scope | Roadmap and checklist deliberately require release/trust work before another provider | High | High | No |

## Checkpoint record

### Baseline — before behavior changes

- Static JavaScript syntax, shell syntax, the 24-fixture design-system guardrail
  self-test, the 26-file design-system scan, and the provider-smoke security
  pattern passed.
- Credential-neutral canonical build: failed with exit 65 at the Crashlytics
  run script path.
- Credential-neutral Xcode test: blocked at the same build phase. A disposable
  DerivedData-only symlink allowed the pre-edit target to execute 27/27 tests,
  confirming the target itself omitted two checked-in test files.
- Offline source-provenance, registry, and Shinkansen smokes: all failed to
  compile at the same domain/design-system dependency.
- iPhone 17, iOS 26.5: app bundle installed and launched; Trips rendered. The
  quick-search false-empty state was reproduced through the Simulator UI.

### Checkpoint 1 — search correctness

- Added a public-seam XCTest for a matching service that is already tracked.
- Red proof: the focused iOS test failed against the previous result filtering.
- Green proof: `TrainStore.searchableResults` now retains live matches and
  deduplicates live/catalog IDs; the focused iOS test passes.

### Checkpoint 2 — build integration

- The wrapper now passes its cloned-package directory to the Crashlytics build
  phase, which retains a DerivedData fallback for ordinary Xcode use and emits a
  precise error if the tool is absent.
- Fresh credential-neutral wrapper build: `BUILD SUCCEEDED`; Crashlytics
  environment validation succeeded.

### Checkpoint 3 — authoritative tests and CI

- Added the NS and design-system XCTest files to the `TrainyTests` target.
- Expanded target result: 54 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5.
- CI now runs static/guardrail/provider smokes, the canonical wrapper, and the
  same credential-neutral iOS XCTest command.

### Checkpoint 4 — provider smoke architecture

- Moved `TrainStatusTone` color presentation out of the Foundation domain model
  and into the design system.
- Replaced the drifting offline and live ODPT source lists with one shared
  Foundation-only provider smoke manifest that includes the NS adapter and the
  store/proxy sources only where needed.
- Source provenance, provider registry, and Shinkansen provider smokes all pass.

### Checkpoint 5 — provider truth

- Added an explicit `adapter-ready` status between rider-active and planned.
- At this checkpoint, NS remained registered, mapped, attributed, and
  fixture-tested but was not included in rider-active metadata. The later
  production record in this report documents its gated promotion to active.
- Supported Regions now distinguishes “Available now,” “Adapter ready,” and
  “Planned regions”; its globe and accessibility copy count only rider-available
  regions.
- Settings-group labels can wrap at accessibility Dynamic Type sizes; the
  provider screen keeps its complete headings and status copy at AX2XL.
- Focused NS metadata tests pass.

### Follow-up PR review checkpoint

- Restored source-provenance disclosure on unsaved search matches and restored
  configured proxy health, provider/cache detail, failure copy, and retry in
  Settings > Providers.
- Removed both tracked personal Xcode `xcuserdata` files while preserving the
  shared workspace definition; `.gitignore` now prevents those local files from
  returning.
- Added the nested NS departures-envelope regression test, corrected the
  segmented-control geometry identifier, reconciled the owning design records,
  and documented PR-added Swift declarations instead of weakening the 80%
  docstring policy.
- Follow-up proof: the focused NS suite passed 14/14 and the complete
  authoritative suite passed 55/55. Simulator checks opened source details from
  Search, exercised proxy failure and Retry, and switched Upcoming/Active with
  Reduce Motion enabled. The restored flows remained readable and scrollable in
  Light/Large and Dark/AX3XL with Increase Contrast.

## Final validation (pre-NS extension checkpoint)

- Canonical wrapper: `BUILD SUCCEEDED` from
  `/private/tmp/trainy-final-ax-build`; the Crashlytics build phase found its
  cloned-package tool and reported successful environment validation.
- Authoritative XCTest: the `TrainyTests` scheme passed 55/55 tests with zero
  failures or skips on iPhone 17 / iOS 26.5. Result bundle:
  `/private/tmp/trainy-derived/Logs/Test/Test-TrainyTests-2026.07.19_13-36-41--0400.xcresult`.
- Repository gates: shell and JavaScript syntax, workflow YAML parsing, the
  24-fixture design-system guardrail self-test, the 26-file repository scan,
  provider-smoke security pattern, and all three credential-free provider
  smokes passed. Project/property-list lint and `git diff --check` also passed.
- Credentialed verification: ODPT returned 16 Tokyo–Shin-Osaka timetable trips
  plus 16 JR East timetable trips; NS returned 40 Utrecht departures. Neither
  smoke printed a credential.
- Rebuilt-app simulator smoke: Trips launched; a loading state recovered to
  current scheduled-data copy; Add Trip and Search returned the already-tracked
  Nozomi 231 match; selecting Track returned to Trips. A nonsense query showed
  the no-match state and valid provider-scoped recovery guidance, then replacing
  it with “Tokyo to Shin-Osaka” restored the matching service.
- Credential-neutral runtime smoke: the same app target showed explicit
  realtime-unavailable/starter-catalog copy and remained searchable without a
  live key. Settings described the starter fallback rather than implying live
  data.
- Provider-truth smoke: Supported Regions reported one rider-available region,
  kept Japan under “Available now,” and presented Netherlands under “Adapter
  ready” with the missing proxy/station-board work stated explicitly.
- Accessibility and appearance: the affected flows were inspected in Light
  Mode at the standard Large size and in Dark Mode at AX2XL. Headings and cards
  remained readable and scrollable, runtime accessibility snapshots exposed
  labelled tabs/buttons and full provider-status text, and no affected content
  remained truncated.
- Bundle check: `NSSubscriptionKey` is absent from the final app `Info.plist`.
  No screenshot, credential, build product, or result bundle was added to the
  repository.

## NS end-to-end extension — 2026-07-19

This extension implemented the previously deferred NS boundary and rider surface while initially preserving production provider claims. Existing Shinkansen tracking/search behavior remains intact; NS is a read-only station-search/departure-board capability rather than a replacement trip-search provider. A stored version or proxy URL alone could not promote NS, so metadata stayed `adapter-ready` until the separately approved deployment and full release evidence below passed. NS is now `active` as of the completed 2026-07-20 production record.

### Proxy and trust boundary

- Added the Cloudflare Worker under `provider-proxy/` with only four fixed `GET` routes: provider health, NS station search, station departures, and active disruptions. Unknown methods/routes/parameters, duplicate parameters, control characters, unbounded limits, and invalid station codes are rejected before provider access. Station search text is filtered against the cached station catalog inside the Worker and never forwarded to NS.
- The upstream host, operations, auth header, response allowlist, and cache keys are fixed in code. Upstream access has a 5.5-second absolute deadline that remains active through body consumption, manual redirect rejection, a 2 MiB streamed ceiling, explicit provider-field bounds, and compact error normalization. Public output cannot contain raw NS bodies, headers, redirect locations, or auth values.
- Fresh/stale windows are 1h/24h for stations, 20s/5m for departures, and 60s/10m for disruptions. A failed refresh inside the bounded stale window returns normalized data with `stale-fallback`; otherwise the app receives stable offline, missing-credential, or rate-limit errors.
- A 60/minute client-route binding protects anonymous clients. Actual cache misses then pass one shared 48/minute location-local fast guard and reserve from a SQLite Durable Object that enforces 240 attempted upstream requests in any rolling five-minute window across locations. The authenticated NS limit is 300/5 minutes, leaving 20% headroom. Reservations occur before fetch and fail closed if the 1.5-second coordination check is unavailable or malformed.
- Same-key cache misses are coalesced inside each Worker isolate. Invalid input and unknown-station responses do not overwrite shared provider health. Coalescing is not represented as a distributed lock; the global Durable Object, rather than Cloudflare's deliberately permissive location-local limiter, owns subscription accounting.
- The only persisted application log authored by Trainy is an allowlisted event containing fixed route/status/cache/error fields, random request ID, method, and a latency bucket. Persisted automatic invocation logs and traces are disabled. An authorized real-time Tail review showed that Tail's transient platform envelope still includes the full request URL, headers/IP, and Cloudflare metadata while the session is active; Tail is therefore an incident-only, query-sensitive diagnostic surface, not a query-free log channel. Local Wrangler logs/registry state are temporary and removed after verification.

Credential-neutral Worker proof: generated types and both TypeScript checks passed; Workerd passed 35/35 contract tests; Wrangler dry-run bundled successfully. The added coverage proves exact station-code ranking, missing-credential rejection before upstream allowance accounting, the shared fast guard, the rolling 240-request global boundary and retry transition, and fail-closed coordination. CI installs the pinned Node dependencies and runs this same gate without an NS credential.

### Completion hardening audit

- The sealed 2026-07-20 diff scan `16af68ff-5818-4173-88fe-d1e42adb82b7` reported one Medium effective-credential enumeration gap and five Low findings: mutable `setup-node`, malformed timestamps shown as confirmed guidance, and malformed station/departure/disruption collections becoming fresh emptiness. Each reported path was reproduced and remediated before the final gate rerun; the sealed report remains the pre-remediation evidence rather than being rewritten.
- Worker remediation covers same-key fan-out, whole-body timeout enforcement, unknown-station health poisoning, upstream/provider field limits, sentence-safe disruption normalization, strict expected collection shapes, non-empty all-invalid rejection, calendar-valid timestamp canonicalization, and preservation of good stale data when a refresh is structurally invalid.
- Native remediation replaces whole-body `URLSession.data(for:)` buffering with streamed 64 KiB health and 1 MiB NS-data ceilings under an absolute eight-second deadline. Decoders enforce the fixed provider/source/attribution contract, freshness interval, counts, station codes, coordinates, and text limits.
- The secret-boundary checker now enumerates effective process and configured/default file candidates, fails closed on ambiguous/malformed env files, scans the conservative deduplicated union without printing values, and separately rejects any resolved non-empty ODPT secret at the built-app `Info.plist` sink. CI actions are pinned to reviewed immutable commit SHAs with read-only contents permission and persisted checkout credentials disabled.
- Rider-state remediation keeps alert errors, provenance, and freshness independent from the board; alert results can publish while a slower board is pending, generation tokens prevent superseded loads from overwriting newer state, and both provenance values automatically re-evaluate at `validUntil`. Provider strings render verbatim instead of passing through localized Markdown parsing.
- Deterministic regressions cover the Worker deadline/coalescing/field/health cases, missing/wrong/all-invalid collection matrices, explicit empty controls, timestamps and stale-cache preservation, native declared-size and never-finishing-body cases, invalid normalized metadata/timestamps, independent result ordering, superseded generations, clock-driven expiry, four secret-boundary scenarios, and credential-safe smoke parsing/host/port behavior.

### App, design-system, and accessibility result

- Added a credential-free NS proxy client, normalized station/departure/disruption models, provider mapping, station-search and departure-board view models, and rider UI. The app accepts non-loopback proxy URLs only over HTTPS and rejects embedded URL credentials. `TrainDataProvider` no longer reads an NS key from process or `Info.plist` configuration.
- Search/board states cover loading, results, empty, no-match, stale, offline, rate-limit, unavailable, retry, and recovery. Same-query/same-board data remains visible when refresh fails. Alert failure and freshness remain separately labelled instead of being erased or represented as an empty success. Source UI uses `NS Reisinformatie API` and `Data from Nederlandse Spoorwegen (NS)` with freshness and fetch time. Departure rows do not add fake trackable trips or vehicle position.
- Phase 17 removed the decorative palette aliases across the Swift tree and added a guardrail fixture that prevents reintroduction. Shared semantic status colors, `RailSearchField`, `StaleDataBanner`, `RateLimitBanner`, and `RailSourceDisclosure` keep NS screen code inside the owning design system.
- Typography now uses semantic Dynamic Type roles. Navigation cards and departure status/time metadata reflow vertically at accessibility sizes; content is scrollable, retry/search targets are at least 44 pt, and the offline banner no longer caps message lines.

| Review area | Before | After and runtime proof |
| --- | --- | --- |
| Production truth | NS could become rider-active from configuration despite no deployed end-to-end path | Status is independent of URL presence: NS remained adapter-ready through bootstrap and became active only after the hardened production version, public contract, simulator path, tests, and secret boundary all passed |
| Search semantics | No rider NS station-search control | Explicit labelled text field, labelled submit action, source-backed results, no-match guidance, and recovery |
| Dynamic Type | Fixed type and horizontal navigation/status layouts compressed at AX sizes | Semantic type, AX-size card stacking, `ViewThatFits` departure metadata, and full-width wrapping at AX2XL |
| VoiceOver | No NS surface | With VoiceOver enabled, the simulator AX tree exposed logical heading/order, labelled “Find a station” and “Search NS stations” controls, station code/button labels, source/freshness text, 44-point actions, and 54-point tabs |
| Appearance/status | No NS failure matrix | Light and Dark Mode and AX2XL were exercised independently; current data, no-match, offline, stale fallback, and recovery remained readable and scrollable, while deterministic UI coverage renders rate-limit state/recovery |

### Verification evidence

- Authorized live data: the loopback proxy smoke returned 5 Utrecht station matches and 20 departures with fresh NS provenance. It printed neither the credential nor raw Wrangler output and scanned captured responses/logs for the actual value and upstream-only markers.
- Simulator: iPhone 17 / iOS 26.5 opened live NS search and fresh Utrecht boards; produced a source-backed no-match; automatically changed a board from fresh to saved/stale; showed cached results in forced offline mode; and recovered after the Worker restarted. A canonical public-URL candidate displayed a transient unavailable state, recovered through its visible retry, transitioned through stale/expired and back to fresh, and exposed separate board/alert source disclosures. After final promotion, the app rendered one exact-code `UT` station, two current departures, one current alert, and separate fresh disclosures from production. Deterministic UI coverage proves rate-limit recovery; a real persistent public client separately received normalized `429` and recovered. The simulator and shell used different Cloudflare limiter buckets, so an in-app production `429` was not falsely claimed.
- Accessibility and appearance: runtime UI and screenshots covered Light and Dark Mode plus AX2XL. Search, result, departure, stale, and source surfaces wrapped and remained scrollable. VoiceOver was enabled and its AX tree exposed headings in logical order, labelled fields/actions, station names plus codes, source/freshness text, 44-point back/search actions, 54-point tabs, and station rows at least 81 points high. VoiceOver, AX overlay, Increase Contrast, and AX2XL were then restored to their normal off/Large settings.
- Authoritative iOS suite after status promotion: 58 passed, 0 failed, 0 skipped on iPhone 17 / iOS 26.5 (build 23F77). Result bundle: `/private/tmp/trainy-derived/Logs/Test/Test-TrainyTests-2026.07.20_19-28-08--0400.xcresult`.
- Canonical public-path-configured wrapper: `BUILD SUCCEEDED` at `/private/tmp/trainy-derived/Build/Products/Debug-iphonesimulator/Trainy.app` with ODPT empty and only `https://trainy-ns-provider-proxy.trainy-jacob.workers.dev` present as the proxy base URL. This is a local simulator candidate, not a distributed build or a source-default release setting.
- Secret boundary: expanding the temporary-artifact prefixes caught one authorized provider value retained only in an older Xcode DerivedData build-command attachment. That generated cache was removed. The clean rerun scanned 58,811 repository/generated/proxy-log/simulator-log files against both authorized local provider values; neither remained, and 122 shipping app files contain no NS upstream host, upstream auth-header name, or NS secret marker. Four deterministic checker regressions also cover inherited/file candidate conflicts, malformed env input, and resolved build-sink rejection. Xcode-injected `.xctest` plug-ins remain in the exact-value scan but are excluded from the app-only marker scan because the regressions intentionally embed forbidden marker strings.
- Remaining gates passed: 25 design-system guard fixtures, 28-file design-system repository scan, shell/JavaScript syntax, workflow YAML, property lists, provider-smoke security pattern, source-provenance/registry/Shinkansen offline smokes, and `git diff --check`.

### Production deployment record

Wrangler OAuth, the dedicated bootstrap, free hostname, migration bridge,
candidate upload, and final promotion were separately authorized. Account
preflight confirmed rate-limit namespace IDs `1001` and `1002` were unused and
the account had zero zones. Every operator command named only
`trainy-ns-provider-proxy`; the pre-existing shared `trainy-provider-proxy`
service remained out of scope.

Bootstrap version `37bdadd5-3652-4c54-8ee8-e0cba777c6c2` first established the
dedicated service and stored the existing NS credential only as a hidden
server-side binding. The owner then selected
`https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`; preview URLs stayed
disabled and no custom domain or schedule was added. Basic bootstrap smoke
returned 5 stations, 20 departures, and 2 disruptions while rejected method and
route probes returned `405` and `404`.

Cloudflare rejected the first approved non-serving final-candidate upload with
API code `10211` before mutation because a new Durable Object lifecycle
migration requires an immediate deploy. The owner then approved a one-time
migration bridge. Its Worker payload was byte-identical to the serving bundle
at SHA-256 `5242b151c5d2ff393a3efa5c1ff33b46342daeea27fa802d23708c464e1ad727`;
it preserved compatibility date `2026-07-19`, the 60/minute client limiter, and
the 120/minute upstream limiter while adding only the otherwise-unused
`NSUpstreamQuota` export/binding and SQLite migration tag `v1`. Bridge version
`65f469e7-ef2b-4acf-8503-e6f3793be5a2` became deployment
`f9f5f96a-21da-4db9-bb5f-e87538361f37`. Health, station search, departures,
disruptions, method/route rejection, headers, configuration, and credential
boundary passed before rollout continued.

Hardened candidate `0ece40b0-b27a-43aa-a865-55445909a2a1` was then uploaded
without traffic and inspected: tag `ns-quota-v1`, compatibility date
`2026-07-20`, the same SQLite namespace, 60/minute client limiter, one shared
48/minute location-local fast guard, hidden NS secret binding, previews off,
persisted invocation logs off, and traces off. After a dry-run traffic review,
deployment `46a26a6a-8abe-4091-9b19-3c32b20ccefa` promoted that version to
100%. A final read-only Wrangler status check confirmed it as the sole serving
version. The downloaded active script was 37,522 bytes with SHA-256
`76866b72d9c41dde9c0d9402f3da56b34becf76893c4792153cb35d591cf1767`
and contained the expected quota class and exact-code ranking.

The first request immediately after promotion briefly observed the bridge
ordering during edge propagation. The active-script check, three repeated edge
requests, and the canonical smoke then returned exact `UT` first; this is
recorded as propagation rather than hidden. Final public proof also included a
fresh Amsterdam cache miss returning five departures through the fail-closed
global quota path, a fresh disruption response, health, `405`, `404`, all
reviewed security/no-store headers, and a persistent-client normalized `429`
followed by recovery. The global 240/5-minute transition remains deterministic
Workerd proof rather than an attempt to consume the production NS allowance.

The migration bridge is the valid rollback baseline. Original pre-migration
version `37bdadd5-3652-4c54-8ee8-e0cba777c6c2` cannot be a rollback target
across the lifecycle boundary. An incident requires bridge version
`65f469e7-ef2b-4acf-8503-e6f3793be5a2`, a forward fix using the migrated class,
or route disablement; the migration and state must not be deleted.

The free hostname still cannot receive a selected-zone WAF/rate rule because
the account has zero zones. The subscription-wide Durable Object closes the
provider-quota accounting gap, but the lack of an owner-controlled zone remains
a documented abuse-resistance limitation. A custom-domain migration is an
optional, separately approved infrastructure change. After final verification,
Wrangler logout succeeded and removed the temporary mode-600 plaintext OAuth
fallback file. Future operations require a new short-lived authorization.

Public NS conditions were reviewed on 2026-07-20. They require capacity-aware
use, allow cutoff for suspected abuse, assign responsibility to the
subscription owner, prohibit NS logo use, and prohibit misleading data
manipulation. Trainy includes no NS logo asset and keeps the NS path read-only
and source-labelled. The authenticated active `Trainy` subscription and
`Ns-App` Reisinformatie API page were then inspected: external non-paying users
receive 300 requests per five minutes and must honor `Retry-After` on `429`.
The authenticated product/API pages displayed no separate cache-duration,
attribution, license, or reuse clause. The starter guide says conditions are
accepted only when a product terms link or checkbox appears and that absence of
that control means no product conditions are established; the active page
showed none. Trainy's text attribution and cache windows remain conservative
provenance/freshness engineering choices under the public conditions, not
claims of NS-prescribed wording or TTLs.

The Cloudflare dashboard confirms Workers Free: 100,000 requests/day, 10 ms
CPU/request, and 200,000 log events/day. Cloudflare documents three days of
Workers Logs retention for Free. The dedicated Worker has Workers Logs enabled
at 100%, traces disabled, and persisted automatic invocation logs disabled;
exactly one active account member was the checked viewer boundary. Trainy's
custom event omits rider input, but real-time Tail still exposes Cloudflare's
transient request envelope while a Tail session is active. The account has zero
zones, so no zone request-logging layer exists. Wrangler logout revoked the
temporary session and removed the local plaintext fallback. Future free-route
operations require a new short-lived authorization with the explicit Worker
name as the per-service guard. Selected-zone route/WAF permissions are needed
only if the owner later approves a custom-domain migration.

## Remaining release risks and next priorities

1. NS is production-live in provider metadata and its end-to-end path is
   verified. The accepted remaining operational limitation is the free
   `workers.dev` hostname's lack of an owner-controlled zone WAF; monitor shared
   network false positives and request volume, and require separate approval
   for any custom-domain migration.
2. Distribution still needs a release/archive-specific privacy audit;
   local ODPT developer credentials must not be treated as the production data
   path.
3. The critical simulator journeys are hands-on evidence, not an automated UI
   suite. Automating search empty/recovery and provider-status assertions is the
   highest-value follow-up after the production proxy boundary.
