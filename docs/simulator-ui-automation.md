# Deterministic simulator UI automation

`TrainyUITests` is the simulator test group for the critical rider flows that
previously required hands-on verification. It is a separate XCUITest target in
the existing `TrainyTests` scheme, so the normal local command and Swift CI
both execute it.

## Coverage

- First-launch data-scope onboarding, AX2XL layout, completion, and Settings
  replay.
- Shinkansen tracked-service search, no-match copy, and recovery.
- Credential-neutral starter-catalog fallback and truthful provider-status
  grouping.
- NS station lookup, exact station semantics, source disclosure, and departure
  results.
- NS loading state plus unavailable-to-retry recovery.
- Light Mode, Dark Mode, and AX2XL interaction/semantics on the NS search flow.
- Apple's accessibility audit on the screens riders reach first, plus the rail
  map's VoiceOver structure (see [Accessibility audit](#accessibility-audit)).

The tests launch the ordinary app screens. They set a documented launch
configuration only to inject `TrainyAutomationScenario` dependencies: an
ephemeral `UserDefaults` store and in-memory provider/proxy fixtures. The
fixtures implement the same production provider protocols, never create a
network request, and contain no credentials. They are not an alternate UI or a
test-only screen branch.

Stable identifiers are reserved for automation seams such as
`onboarding.screen`, `onboarding.start`, `stations.nsDepartures`,
`ns.stationSearch.field`, `ns.station.UT`, and
`ns.departure.fixture-sprinter-7400`. The suite uses semantic labels only for
native controls whose identifier is owned by the system search field or where
the rider-facing accessibility text itself is the contract.

## Run locally

Run the focused group without retries:

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
ODPT_CONSUMER_KEY= \
xcodebuild test \
  -project TrainyIOS/Trainy.xcodeproj \
  -scheme TrainyTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath /private/tmp/trainy-derived \
  -clonedSourcePackagesDirPath /private/tmp/trainy-source-packages \
  -packageCachePath /private/tmp/trainy-swiftpm-cache \
  -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO \
  -only-testing:TrainyUITests \
  CODE_SIGNING_ALLOWED=NO \
  TRAINY_SOURCE_PACKAGES_DIR=/private/tmp/trainy-source-packages
```

For a release-readiness stability check, execute that command three times in
sequence. Do not add `-retry-tests-on-failure`; every launch creates fresh
automation defaults and its own fixture provider state, so the group has no
test-order dependency.

## CI-equivalent full suite

Swift CI runs the same shared scheme after the credential-neutral build. Run
the full local equivalent with the same setup but without `-only-testing`:

```bash
DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
ODPT_CONSUMER_KEY= \
xcodebuild test \
  -project TrainyIOS/Trainy.xcodeproj \
  -scheme TrainyTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath /private/tmp/trainy-derived \
  -clonedSourcePackagesDirPath /private/tmp/trainy-source-packages \
  -packageCachePath /private/tmp/trainy-swiftpm-cache \
  -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  TRAINY_SOURCE_PACKAGES_DIR=/private/tmp/trainy-source-packages
```

## Accessibility audit

`TrainyAccessibilityAuditUITests` runs Apple's automated accessibility audit
(`performAccessibilityAudit`) on the screens riders reach first: Trips, Search
(empty and with results), Stations, NS station search, NS departures, History,
Settings, onboarding, trip detail, and the rail map. The audit reports contrast,
small hit regions, clipped text, Dynamic Type, traits, and elements without a
description. It runs in the same `TrainyTests` scheme as the other UI tests, so
Swift CI executes it on every pull request.

### Known findings

The app had findings when the audit was added. They are listed in
`TrainyIOS/TrainyUITests/TrainyAccessibilityAuditBaseline.swift` as
`screen | audit type | element`, grouped by screen. The audit fails on any
finding that is **not** listed there, so a new screen or a regression cannot add
problems silently while the old ones are fixed.

- The element is its accessibility identifier when it has one. Otherwise it is
  its label with counts, clock times, months, AM/PM, and "updated ... ago" text
  masked (`Hayabusa #`, `#:# <am/pm>`), cut at 80 characters.
- When a screen is fixed, delete its entries. Each audit test attaches a
  **Fixed accessibility findings** note to the result bundle that lists entries
  the audit no longer reproduces, so stale entries are easy to spot. They do not
  fail the test.
- A new finding fails with a message like
  `search | contrast | Fast station search` plus the audit's own text. Fix the
  screen first. Add the key to the baseline only when the finding comes from
  the system (for example the search field's Clear button) or the design
  trade-off is deliberate, and say why in a comment next to it.
- Swift CI prints every failed test's messages in the **Report test failures**
  step and in the job summary, so the keys can be copied from there without
  downloading the result bundle. A navigation step that cannot find its element
  fails with the visible accessibility hierarchy in the message.
- To run only the audit locally, use the command above with
  `-only-testing:TrainyUITests/TrainyAccessibilityAuditUITests`.
- To cover a new screen, add a test that navigates to it and calls
  `audit("<screen>")`. Its first run lists the screen's findings; fix them or
  copy their keys into the baseline.

### Rail map VoiceOver structure

`testRailMapExposesLabelledStopsAndControls` opens the rail map from the active
trip and asserts the structure VoiceOver relies on, on top of the audit:

- the origin and destination stops are separate elements labelled
  `<stop>, platform <platform>, <state>`;
- the recenter control is a button named **Center map**;
- the map marker is named **Route marker**, and nothing on the screen calls
  itself a **Vehicle position**, because the starter catalog is schedule-only
  and the app must not claim a live position it does not have.

### Reduce Motion

XCUITest cannot switch Reduce Motion on, so the suite does not test it. A static
review on 2026-10-07 found every animation, transition, and shimmer under
`Sources/TrainyCore` either skipped or replaced when `accessibilityReduceMotion`
is on. To repeat the review after changing the UI, list the sites and check that
each one reads `reduceMotion`:

```bash
grep -rnE 'withAnimation|\.animation\(|\.transition\(|matchedGeometryEffect|repeatForever' Sources/TrainyCore
```

Then check by hand before a release:

1. On a simulator or device, turn on Settings > Accessibility > Motion >
   Reduce Motion.
2. Re-center the rail map, switch between Upcoming, Active, and Past on Trips,
   type in the Search field, and watch a loading skeleton.
3. Nothing should slide, spring, or shimmer. Fades are fine.

### What the audit cannot cover

The audit finds structural problems. It does not read screens the way VoiceOver
does, so it cannot judge reading order, phrasing, Rotor behavior, Switch
Control, or whether a custom control announces its state well. Check those by
hand with VoiceOver on a device before a release.
