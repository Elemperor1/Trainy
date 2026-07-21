# Deterministic simulator UI automation

`TrainyUITests` is the simulator test group for the critical rider flows that
previously required hands-on verification. It is a separate XCUITest target in
the existing `TrainyTests` scheme, so the normal local command and Swift CI
both execute it.

## Coverage

- Shinkansen tracked-service search, no-match copy, and recovery.
- Credential-neutral starter-catalog fallback and truthful provider-status
  grouping.
- NS station lookup, exact station semantics, source disclosure, and departure
  results.
- NS loading state plus unavailable-to-retry recovery.
- Light Mode, Dark Mode, and AX2XL interaction/semantics on the NS search flow.

The tests launch the ordinary app screens. They set a documented launch
configuration only to inject `TrainyAutomationScenario` dependencies: an
ephemeral `UserDefaults` store and in-memory provider/proxy fixtures. The
fixtures implement the same production provider protocols, never create a
network request, and contain no credentials. They are not an alternate UI or a
test-only screen branch.

Stable identifiers are reserved for automation seams such as
`stations.nsDepartures`, `ns.stationSearch.field`, `ns.station.UT`, and
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
