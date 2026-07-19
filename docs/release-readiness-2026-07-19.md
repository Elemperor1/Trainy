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
- NS remains registered, mapped, attributed, and fixture-tested, but is not
  searchable or included in rider-active metadata.
- Supported Regions now distinguishes “Available now,” “Adapter ready,” and
  “Planned regions”; its globe and accessibility copy count only rider-available
  regions.
- Settings-group labels can wrap at accessibility Dynamic Type sizes; the
  provider screen keeps its complete headings and status copy at AX2XL.
- Focused NS metadata tests pass.

## Final validation

- Canonical wrapper: `BUILD SUCCEEDED` from
  `/private/tmp/trainy-final-ax-build`; the Crashlytics build phase found its
  cloned-package tool and reported successful environment validation.
- Authoritative XCTest: the `TrainyTests` scheme passed 54/54 tests with zero
  failures or skips on iPhone 17 / iOS 26.5. Result bundle:
  `/private/tmp/trainy-final-ax-tests-pass.xcresult`.
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

## Remaining release risks and next priorities

1. NS is intentionally not rider-available. A secure production proxy,
   station-board/search surface, upstream rate-limit confirmation, and final
   product-terms review remain required before changing that status.
2. Distribution still needs a release/archive-specific secret and privacy audit;
   local ODPT developer credentials must not be treated as the production data
   path.
3. The critical simulator journeys are hands-on evidence, not an automated UI
   suite. Automating search empty/recovery and provider-status assertions is the
   highest-value follow-up after the production proxy boundary.
