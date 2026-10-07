# Trainy engineering plan — 2026-10-07

This is the plan for the work still to be done inside the app and its backend
before Trainy is a product people would pay for. Apple-account, legal, and store
listing logistics live in [`app-store-launch-plan.md`](app-store-launch-plan.md).
The two documents share one release order, summarized in
[Release train](#release-train).

## How to read this

- **Tags:** `[Launch]` is needed for a truthful free 1.0. `[Plus]` is needed for
  a paid tier (1.1). `[Growth]` is worth doing after that.
- **Size** describes scope, not calendar time:
  **S** is one focused change in a few files plus tests. **M** is a feature
  across several files or screens with new tests. **L** is a subsystem or a
  contract change that touches both the app and the Worker. **XL** is a new
  backend service or a new app target with ongoing operating cost.
- **Evidence** is cited as `file:line` against `master` at commit `127aecd`.
  Everything cited was read in the source, not inferred from documentation.

## Where the app stands

### Solid, and worth protecting

These are the parts of the codebase that are already production-grade. The plan
builds on them and adds guard tests where a change could weaken them.

- **Provenance model.** Every trip carries `SourceProvenance` and per-fact
  `FactProvenance`; the UI labels starter, scheduled, and realtime data
  separately.
- **NS path.** App to fixed Worker routes to NS, with strict response
  validation, freshness windows, stale fallback, rate-limit recovery, and 17 NS
  tests plus Workerd contract tests (35 pass).
- **Secret boundary.** No provider secret ships in the binary, enforced by
  `scripts/check-provider-secret-boundary.py` and `scripts/audit-ios-archive.py`.
- **Privacy posture.** No tracking, privacy manifest present, crash reporting
  off until the rider opts in.
- **Design system and accessibility.** A guarded design system, Dynamic Type
  coverage to AX2XL, and deterministic simulator UI tests.

### Hollow, and what that means

The app looks complete, but several of its central behaviors are static
fixtures presented as live trip state. This is the main body of work.

| # | Finding | Evidence |
| --- | --- | --- |
| E1 | **Trips have no real time.** `TrainTrip` is a display model of strings (`eta`, `duration`, `status`, `updated`, `origin.time` as `"09:21"`) with no service date and no absolute `Date`. Nothing can be scheduled, ordered across days, aged out, or counted down. | `TrainModels.swift:671-705` |
| E2 | **Trip state is hard-coded.** Starter trips ship fixed `status: "On time"` / `"Boarding"`, a fixed `progress`, and stop notes `"Departed"` / `"Next stop"` regardless of the clock. | `ShinkansenStarterCatalog.swift:28-46` |
| E3 | **Refresh fabricates movement.** Refreshing a starter trip sets `updated = "just now"` and adds 0.01 to `progress`. | `TrainStore.swift:586-591` |
| E4 | **Upcoming / Active / Past is driven by that stored progress**, not by time. | `ContentView.swift:257-261` |
| E5 | **The alerts bell does nothing.** It flips a flag in `UserDefaults`; no notification is requested or scheduled; the UI says "Alerts enabled". | `TrainStore.swift:550`, `ContentView.swift:705` |
| E6 | **A reserved seat is invented for every rider.** Boarding shows "Car 7, Seat 12A" from the catalog, plus a "signal confidence" score and "pulse" text with no source. | `ShinkansenStarterCatalog.swift:32,40`, `ContentView.swift:2637-2639` |
| E7 | **Production Japan data is the starter catalog.** With no ODPT key (by policy) there is no timetable path at all; the JR East HTML fallback only runs when a key exists. | `ShinkansenTrainProvider.swift:104-113` |
| E8 | **New users start with sample trips already "tracked".** Four are preloaded and first launch tops up to five. | `TrainStore.swift:367-376`, `ShinkansenTrainProvider.swift:66` |
| E9 | **Developer copy is shown to riders.** Settings says "Add an ODPT consumer key in the developer configuration"; trip alerts say "Tokaido route data is loaded for Japan-first validation" and "This trip validates JR West to JR Kyushu handoff behavior". | `ContentView.swift:1564,2076`, `ShinkansenStarterCatalog.swift:46,78,90` |
| E10 | **History is not history.** It summarizes whatever is currently tracked; "Most-used route" is the literal string "Japan Shinkansen" whenever any trip exists; nothing is archived. | `ContentView.swift:1435-1509` (`:1476`) |
| E11 | **Favorites are not persisted.** The station star is `@State` while its accessibility hint promises quick access; the "Favorite stations" strip is the first six stations of tracked trips; "Try a search" rows use a recents icon but are static examples. | `ContentView.swift:1280,1301,780,915` |
| E12 | **Visible stubs.** "Manual trip creation is not connected in this build"; station notes say accessibility and facilities are "not connected yet"; Trips header is hard-coded "Japan Shinkansen"; pull-to-refresh on Trips re-runs search rather than refreshing trips. | `ContentView.swift:829-833,1326-1327,496,400-402` |
| E13 | **Persistence fails silently.** A stored payload that cannot be decoded is dropped with `try?` and the app falls back to defaults. There is no schema version beyond a data-scope string. | `TrainStore.swift:619-622,640` |
| E14 | **A large, finished normalized model is unused.** `RailNormalizedModels.swift` (796 lines: `ScheduledRailTrip`, `RailStopTime`, `RealtimeTripOverlay`, `RailBoardEntry`, and more) is referenced by no other source or test file. It already has the absolute-time shape E1 needs. | `RailNormalizedModels.swift` |
| E15 | **NS is a separate island.** Boards only: no train number, route, or stop list; nothing can be tracked, reminded, or archived. Boards never reload on their own, and there is no foreground refresh anywhere. `JourneyPlanningProvider` has no implementation. | `NSModels.swift:129-151`, `NSRiderViewModels.swift:188-199` |
| E16 | **Map geometry is partly invented.** Station coordinates are a hand-written table and route lines are smoothed curves between stations. They are labeled "route marker", which is honest, but they are not real track geometry. | `RailJourneyMap.swift:426-481` |
| E17 | **Platform gaps.** No size-class or split-view handling (iPad is targeted but untested); no localization resources; no `os.Logger`; no background tasks, widgets, App Intents, or sync. | repo-wide search |
| E18 | **CI never compiles Release.** `scripts/build-ios.sh` builds Debug; `#if DEBUG` boundaries (automation scenarios) are first exercised at manual archive time. | `scripts/build-ios.sh`, `README.md` build path |
| E19 | **The Worker is open and shared.** Public, unauthenticated, free `workers.dev`; one NS budget (240 per 5 minutes) for all riders; Cache API entries are per data center. | `provider-proxy/wrangler.jsonc`, `Provider_Status.md` |

## Decisions that shape the plan

Defaults are what the plan assumes if you do not say otherwise. Each can be
changed before the item that depends on it starts.

| Decision | Default | Affects |
| --- | --- | --- |
| iPad in 1.0 | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) | 6.1 |
| Alerts in 1.0 | **Local timetable-based reminders**, no server | 3.1 |
| Japan data path | **Ingest on the Worker nightly**, serve normalized JSON | 2.2 |
| Storage | **SwiftData in an App Group container** (so widgets later need no second migration) | 1.4, 3.3 |
| Starter catalog | **Debug-only "Sample data" mode**; not offered to riders in Release | 1.5, 2.3 |
| Free vs Plus split | Free: track a few trips, schedule view, NS boards. Plus: unlimited trips, reminders, widgets and Live Activities, history. | 5.2 |
| Server push | **Defer** until Plus has paying users | 3.4 |
| Languages | English first; Japanese and Dutch in 1.1 | 6.2 |

## Release train

| Release | Contents |
| --- | --- |
| **1.0 (free)** | Phases 0, 1, 2, 3.1, 4.2, 4.5, 6.1, 6.3, 6.6, 7.1 to 7.5 |
| **1.1 (Plus)** | Phase 5, 3.2, 3.3, 4.1, 4.3, 6.2, 6.4 |
| **1.2** | 4.4, 8.1, 8.2 |
| **2.0** | 3.4, 8.3 to 8.6 |

### Critical path

```
2.1 data spike ─► 2.2 Worker ingestion ─► 2.3 app provider ─┐
0.5 clock/ids ─► 1.1 domain model ─► 1.2 phases ─► 3.1 reminders ─► 5.x Plus
                  └► 1.3 remove fabrication, 1.4 persistence v2 ─► 3.3 widgets
Apple Developer enrollment ─► 7.2 App Attest, 7.4 signed release pipeline
```

2.1 needs your ODPT account and terms review, and 7.2 and 7.4 need the paid
Apple team, so those three are the ones to start early.

## Phase 0 — Safety net

Small items that make every later change cheaper and safer.

- **0.1 Land PR #20 and prove CI. `[Launch]` S.** The first full `Swift CI` run
  after the audit fix has not been seen on Apple tooling yet. Fix whatever the
  build or tests reveal, then require the checks before merge.
- **0.2 Compile Release in CI. `[Launch]` S.** Add a job on `master` and tags that
  builds the Release configuration unsigned and runs `scripts/archive-ios.sh` and
  `scripts/audit-ios-archive.py`. Today Release first compiles when someone
  archives by hand (E18).
- **0.3 Structured logging. `[Launch]` S.** `os.Logger` with categories
  (provider, persistence, notifications, purchases, proxy), search text and
  station codes marked private. TestFlight triage depends on it.
- **0.4 Split `ContentView.swift`. `[Launch]` M.** It is 2,763 lines and about 40
  types. Move each screen to its own file under `Screens/`. No behavior change.
  The design-system guard treats `ContentView.swift` as the owner of persistent
  interface preferences (`scripts/check-design-system-bypass.sh:29,91,195`), so
  update the script and its fixtures in the same change.
- **0.5 Inject the clock and stabilize ids. `[Launch]` S.** Introduce a `Clock`
  seam used by every time-dependent calculation (`RailStopTime.state` calls
  `Date()` directly). Replace `let id = UUID()` on `StationStop` and
  `TrainAlert`, which changes on every decode (`TrainModels.swift:558,659`), with
  stable derived ids.
- **0.6 Repo hygiene. `[Launch]` S.** Remove the unreferenced root
  `GoogleService-Info.plist`; move the browser prototype (`index.html`,
  `app.js`, `components.js`, `styles.css`) under `prototype/` or retire it so it
  stops looking like part of the product.

## Phase 1 — A truthful trip core

Everything user-visible depends on trips having real time. This phase replaces
fixtures-as-state with derived state.

- **1.1 Domain model on absolute time. `[Launch]` L.** Adopt the existing
  normalized layer (E14) as the persisted core: `ScheduledRailTrip` with a service
  date and per-stop `Date` plus time zone, and `RealtimeTripOverlay` for delay,
  platform change, and cancellation with `fetchedAt` and `validUntil`.
  `TrainTrip` becomes a presentation projection built from
  `(scheduled, overlay, now)`. Every string that is stored today (`eta`,
  `duration`, `status`, `updated`, `progress`) is computed. Keep the provenance
  types; they already fit.
- **1.2 Real trip phase. `[Launch]` M.** Derive upcoming, boarding, active,
  arrived, and past from the clock and overlay. Rebuild the Trips buckets on it
  (E4). Progress is schedule interpolation and is labeled as such, never as a
  vehicle position. Auto-move trips between buckets while the app is open.
- **1.3 Remove fabricated facts. `[Launch]` M.** Delete stored status and progress
  from the catalog, the fake refresh (E3), the invented seat, carriage, "signal"
  score, and "pulse" text (E6). With no overlay the status reads "Scheduled", not
  "On time".
- **1.4 Persistence v2. `[Launch]` M.** Versioned SwiftData store in an App Group
  container, with an explicit migration from the v1 `UserDefaults` payload
  (`trainy.trackedTripsPayload`), recovery that keeps an undecodable store
  instead of dropping it (E13), and tables for favorites, recents, and a
  completed-journey archive. Fixture-based migration tests for every shipped
  schema.
- **1.5 First run starts empty. `[Launch]` S.** Replace the preloaded sample trips
  (E8) with an empty state and an "Add your first trip" action. Offer a demo trip
  only in a clearly labeled Sample data mode. Update the simulator automation
  scenarios and launch-film flows that assume preloaded trips.
- **1.6 Search by date, and rider-entered ticket details. `[Launch]` M.** Date
  picker (today, tomorrow, pick), departure window, and a structured
  origin/destination search in place of free-text substring matching. A "My
  ticket" form for car and seat, entered by the rider.
- **1.7 Rider-facing copy and stub cleanup. `[Launch]` S.** Fix every item in
  E9, E11, and E12: rewrite the Settings and trip-alert copy, implement or remove
  manual trip entry, show real favorites and recents, make the station star
  persist, replace placeholder station notes, derive the Trips header from the
  active provider, and make Trips pull-to-refresh refresh trips.
- **1.8 Make History real, or fold it into Trips. `[Launch]` M.** Archive journeys
  when they complete (1.4) and compute the stats from the archive. If that does
  not fit 1.0, remove the tab and show Past under Trips rather than ship a
  summary of current trips under the title History (E10).

## Phase 2 — Real Japan data

- **2.1 Data and terms spike. `[Launch]` S.** Establish what ODPT and JR actually
  expose for Shinkansen: timetables by service day, line-level operation
  information, station and line geometry, and whether any per-train realtime
  exists. Establish the commercial-use, attribution, caching, and rate-limit
  terms. Output is a short decision record in `docs/`. This blocks 2.2 to 2.8,
  and needs your ODPT account. If no per-train realtime feed exists, the app's
  honest promise is timetable plus line-level disruption, and the copy and
  store listing should say so.
- **2.2 Timetable ingestion on the Worker. `[Launch]` L.** A scheduled job pulls
  and normalizes Shinkansen timetables and stations into the Trainy contract,
  stores them (R2 or KV), and the Worker serves bounded routes such as
  `/v1/japan/trips`, `/v1/japan/trips/{id}`, and `/v1/japan/disruptions`. Static
  data should not pass through to the upstream API on every request: ingestion
  protects the ODPT quota, is fast, and gives the app an offline snapshot. Follow
  the NS pattern in `contracts.ts`, `upstream.ts`, and `handler.ts`, with the same
  style of Workerd contract tests.
- **2.3 App provider rewrite. `[Launch]` L.** Rebuild `ShinkansenTrainProvider` as
  a proxy client modeled on `NSClient` (bounded size and time, strict validation,
  provenance). Remove the local-key path from Release, including the
  `ODPTConsumerKey` Info.plist entry and `TrainyAPIConfig.odptConsumerKey`.
- **2.4 Offline schedule. `[Launch]` M.** Persist the tracked trip's full schedule
  so it works underground and offline, and show the age of the data.
- **2.5 Stations and geometry. `[Launch]` M.** Replace the hand-written coordinate
  table and synthetic curves (E16) with data from 2.1, keeping the existing
  "route marker" honesty labels.
- **2.6 Disruption information. `[Launch]` M.** Show line-level operation status
  on affected tracked trips, labeled as line-level and not train-specific.
- **2.7 JR East HTML fallback. `[Launch]` S.** Remove `JREastTimetableClient` and
  its fixtures unless JR East grants permission; scraping a third-party site in a
  commercial app is an App Review risk (guideline 5.2.2).
- **2.8 Realtime, only if 2.1 finds a feed. `[Plus]` M.** Feed the overlay model;
  until then do not use the word "live" for Japan anywhere.

## Phase 3 — Alerts that work

- **3.1 Local reminders. `[Launch]` M.** Request notification permission at the
  first alerts toggle, not at launch. Schedule per trip from the domain model with
  lead times (for example 60, 30, and 10 minutes before departure, and approaching
  arrival), cancel on untrack, reschedule when the overlay changes, handle time
  zones and daylight saving, and word every notification as timetable-based. Put
  `UNUserNotificationCenter` behind a protocol so a planner can be unit-tested.
  Settings shows permission state and links to system settings when denied.
  Replace `toggleNotification` and the `notifiedIDs` flag set (E5). Hide the bell
  until this ships.
- **3.2 Background refresh. `[Plus]` M.** `BGAppRefreshTask` re-fetches tracked
  trips, detects platform change, delay, and cancellation, and posts a local
  notification. Copy must say iOS decides when this runs.
- **3.3 Widgets and Live Activities. `[Plus]` L.** A "next trip" widget (home and
  lock screen) and a Live Activity for the active trip, schedule-driven at first.
  This adds app extension targets, so update `scripts/audit-ios-archive.py`, which
  currently asserts the archive has no extensions, and add the App Group entries
  to the privacy review.
- **3.4 Remote push. `[Growth]` XL.** The real-time alerting product: an opt-in
  server that tracks subscribed trips, diffs the upstream feeds, and sends APNs
  pushes and Live Activity updates. Needs a token registry with retention limits,
  a polling or queue job, an APNs signing key as a Worker secret, and abuse
  limits. This is the strongest reason to pay and also the largest ongoing cost
  and privacy commitment; decide after Plus has paying users.

## Phase 4 — Netherlands depth and the stations experience

- **4.1 Favorites and recents for NS. `[Plus]` S.** Persist searched and starred
  stations (1.4) and show them on the Stations tab.
- **4.2 Auto-refresh and foreground refresh. `[Launch]` S.** Reload an open board
  on a cadence matched to the Worker's 20-second fresh window, back off on `429`,
  pause when backgrounded, and refresh on return to foreground. Today boards only
  relabel themselves as stale (E15).
- **4.3 Departure detail and tracking. `[Plus]` L.** Extend the proxy contract
  with train number, destination, via stations, and the stop list, then let the
  rider track a departure so it becomes a normal domain trip (1.1) with
  reminders, history, and widgets. This removes the NS island.
- **4.4 NS journey planning. `[Growth]` L.** Implement the existing
  `JourneyPlanningProvider` protocol through the proxy: origin to destination with
  transfers and platforms.
- **4.5 One Stations tab. `[Launch]` M.** A provider-neutral directory with search,
  favorites, and boards. Retire `StationSnapshot`, which derives stations from
  whatever trips are tracked (`ContentView.swift:2364`).

## Phase 5 — Monetization (Plus)

Plan the code to be ready when the pricing decision is made. Nothing here
requires a paid tier to be switched on in 1.0.

- **5.1 Entitlements core. `[Plus]` M.** StoreKit 2: products, purchase, restore,
  a `Transaction.updates` listener started at launch, verified results only, all
  behind an injectable protocol. A local StoreKit configuration file and
  `StoreKitTest` cases cover purchase, renewal, refund, and restore.
- **5.2 Feature gating. `[Plus]` S.** A `Feature` enum and one `isUnlocked(_:)`
  choke point. When an entitlement lapses, features lock but riders keep their
  data.
- **5.3 Paywall and management. `[Plus]` M.** Design-system paywall sheet with the
  App Store-displayed price, renewal terms, Restore Purchases, links to Terms of
  Use and Privacy Policy, subscription management, and offer-code redemption.
  AX2XL UI tests using the StoreKit configuration.
- **5.4 Server-side receipts. `[Growth]` L.** App Store Server Notifications V2 for
  cross-device entitlement. Needed only if 3.4 ships.
- **5.5 Compliance deltas. `[Plus]` S.** Re-run the privacy manifest, App Privacy
  label, and archive audit after StoreKit, notifications, and extensions arrive.

## Phase 6 — Platform fit and polish

- **6.1 iPad. `[Launch]` S or L.** Default: set `TARGETED_DEVICE_FAMILY = 1`.
  Supporting iPad properly means adaptive layouts with `NavigationSplitView` and
  size classes (none exist today), iPad UI tests, and screenshots.
- **6.2 Localization. `[Plus]` L.** Create a String Catalog (there are no
  localization resources today), extract all strings including interpolated and
  `String`-typed ones, add Japanese and Dutch, use ODPT's localized station names,
  and add a pseudo-locale UI test.
- **6.3 Accessibility audit automation. `[Launch]` S.** Add
  `performAccessibilityAudit()` to the core UI tests, and verify map VoiceOver
  behavior and Reduce Motion.
- **6.4 Performance pass. `[Plus]` M.** Instruments on launch time, list scrolling,
  and map overlays; set budgets and add `XCTMetric` tests. Resize `HeroTrain.png`
  (1.9 MB).
- **6.5 Icon variants. `[Growth]` S.** Layered icon with dark and tinted variants.
- **6.6 In-app legal and support. `[Launch]` S.** Settings rows for Privacy Policy,
  Terms of Use, Support, data-source attributions (NS text-only, ODPT), open-source
  licenses, version and build, and "Delete all my data".

## Phase 7 — Quality, release engineering, operations

- **7.1 Test expansion. `[Launch]` M.** Highest value first:
  - `TrainStore` behavior: tracking, bucket changes with an injected clock,
    provider switching, and the unstructured refresh `Task` that can race
    (`TrainStore.swift:461`). None of this is covered today.
  - Persistence migrations from fixtures of every shipped schema.
  - Notification planner and entitlement store with fakes.
  - Contract tests that run the Worker's real JSON through the Swift decoders.
  - Snapshot tests of core screens at standard and AX sizes.
  - Split into a fast unit test plan and a slower UI plan; publish coverage in CI.
- **7.2 Worker authentication with App Attest. `[Launch]` L.** The app attests a
  key, the Worker verifies it, stores key id and counter in a Durable Object, and
  issues a short-lived token required on every data route; unsupported devices get a
  stricter limit. This is what stops one script from spending the shared NS budget
  (E19). It needs the paid Apple team and adds an entitlement, so
  `audit-ios-archive.py`'s no-entitlements assumption changes.
- **7.3 Worker operations. `[Launch]` M.** Custom domain with WAF rules, the paid
  Workers plan, per-route quota so one route cannot starve the others,
  Analytics Engine metrics without personal data, alert thresholds, an uptime
  check, a staging Worker with nightly contract smoke tests, a secret-rotation
  runbook, and a remote kill switch for a degraded provider.
- **7.4 Release pipeline. `[Launch]` M.** Signed archive in CI (Xcode Cloud or
  GitHub Actions with an App Store Connect API key), automatic build numbers,
  dSYM upload check, TestFlight upload, release notes, and the existing archive
  audit run against the signed export as a hard gate.
- **7.5 Dependency hygiene. `[Launch]` S.** Group Dependabot updates for dev
  tooling, stop the repeating failed `undici` update runs, and set the npm audit
  policy (production dependencies fail on high, dev tooling on critical with a
  documented allowlist). Define the Firebase update cadence.
- **7.6 Security review. `[Launch]` S.** A written threat model for the Worker and
  app, a review of the final diff before submission, and restriction of the
  Firebase API key to the app's bundle ID.

## Phase 8 — After launch

- **8.1 More regions through the Worker.** Hong Kong MTR first (no credential
  needed), then Taiwan high-speed rail and Sydney, per
  [`global-provider-roadmap.md`](global-provider-roadmap.md).
- **8.2 iCloud sync.** SwiftData with CloudKit so trips follow the rider across
  devices; a natural Plus feature.
- **8.3 Ticket and calendar import.** Add trips from confirmation emails, Wallet
  passes, or calendar events, with a privacy review.
- **8.4 App Intents and Siri.** "When is my next train".
- **8.5 Apple Watch.** Next-departure complication.
- **8.6 Share extension.** Share a trip as a link.

## Risks

| Risk | Mitigation |
| --- | --- |
| ODPT or JR terms do not permit a commercial app, or expose no useful Shinkansen data | 2.1 happens first and gates the Japan investment; fall back to NS-led positioning or another Japan source |
| The domain-model change (1.1) ripples through every screen | 0.4 and 0.5 first; migrate screen by screen behind the projection so `TrainTrip` consumers keep compiling |
| No Apple tooling in the cloud session | Every Swift change relies on the macOS CI run; keep changes small and CI-checked, and run simulator tests locally before release |
| Single shared NS quota caps growth | 7.2 and 7.3 before marketing; ask NS about higher quota; consider more cache sharing through a Durable Object |
| Push (3.4) creates ongoing privacy and cost obligations | Defer behind Plus revenue; ship local reminders and background refresh first |
| Scope: this plan is large for one developer | The 1.0 column is the real scope; Plus and Growth items are optional and can move |

## What this plan deliberately does not do

- It does not replace the provenance model, the design system, or the NS
  hardening; those are the product's differentiators.
- It does not add providers beyond Japan and the Netherlands before 1.0.
- It does not start any work that needs the Apple account, App Store Connect, or
  provider credentials; those are called out as dependencies instead.
