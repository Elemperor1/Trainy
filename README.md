# Trainy

Trainy is a Flighty-style train tracking app, scoped first to Shinkansen trips in Japan.

This workspace now contains three development surfaces:

- `Package.swift`: Swift Package Manager workspace for reusable Trainy code.
- `TrainyIOS/`: thin native SwiftUI iOS app wrapper for signing, app resources, and packaging.
- Root `index.html`: self-contained browser prototype with no external dependencies.

## OpenAI Build Week judge quick start

Trainy is an iOS rail companion built with Codex and GPT-5.6. The Build Week
work focused on trustworthy provider status, deterministic simulator coverage,
accessible first-run guidance, and a repeatable privacy and distribution audit.

The fastest credential-neutral review path is the iPhone 17 simulator. It uses
the production NS proxy URL and leaves the optional ODPT developer credential
empty:

```bash
ODPT_ENV_FILE=/dev/null \
TRAINY_PROVIDER_PROXY_BASE_URL='https://trainy-ns-provider-proxy.trainy-jacob.workers.dev' \
CODE_SIGNING_ALLOWED=NO \
scripts/build-ios.sh
```

Open `TrainyIOS/Trainy.xcodeproj`, select the `Trainy` scheme and an iPhone 17
simulator, then run. First launch presents onboarding that explains Trainy's
starter, scheduled, and realtime labels. No provider credential is required to
review the Shinkansen starter experience or the production-backed Netherlands
station-board path.

For deterministic review of onboarding, search, provider truth, NS departures,
failure recovery, Light/Dark Mode, and AX2XL behavior, run the `TrainyUITests`
group documented in
[`docs/simulator-ui-automation.md`](docs/simulator-ui-automation.md). The
release archive, privacy manifests, secret boundary, and signing evidence are
owned by
[`docs/distribution-readiness-2026-07-21.md`](docs/distribution-readiness-2026-07-21.md).

## What it does

- Tracks multiple Shinkansen journeys with live-style status, route progress, platforms, next stop, ETA, and speed.
- Shows a station timeline, platform/car positioning, alerts, connection risk, and signal confidence.
- Supports search, trip filters, pinned trains, notification toggles, compact mode, refresh, and share-copy behavior.

## Japan-first data scope

The current native app is scoped to Shinkansen service instead of the previous US live-feed prototype. It includes representative Tokaido, Sanyo-Kyushu, Tohoku, Hokuriku, Joetsu, Hokkaido, Akita, and Yamagata Shinkansen trips with station coordinates, route search, persisted tracked trips, and a data-scope migration that resets stale non-Japan saved trips.

The native app now attempts ODPT first when an ODPT consumer key is configured. If ODPT exposes route metadata but no `odpt:TrainTimetable` rows for a Shinkansen railway, Trainy falls back to official JR timetable pages for real schedule/platform data. With no key, it uses the curated Shinkansen starter catalog. Timetable data is treated as schedule data, not guaranteed live vehicle position.

To configure ODPT locally:

```bash
cp TrainyIOS/Config/odpt.env.example TrainyIOS/Config/odpt.env
chmod 600 TrainyIOS/Config/odpt.env
```

Then register at `https://developer.odpt.org/`, paste the issued key into `TrainyIOS/Config/odpt.env`, and build with `scripts/build-ios.sh`. The build script parses only `ODPT_CONSUMER_KEY=...` from that file, so the local secret file is not executed as shell code. The key is passed to Xcode through the process environment rather than as an echoed command-line build setting. The secret env file is ignored by git.

Run the ODPT smoke check after setting the key:

```bash
scripts/smoke-odpt.sh
```

The smoke compiles Trainy's provider code and verifies that `Tokyo to Shin-Osaka` and `JR East` searches return real ODPT-backed or official timetable trips instead of starter data.

Other credentialed-provider env files, including `ns.env`, are developer smoke inputs only. `scripts/build-ios.sh` does not load or pass those keys to Xcode. Netherlands NS station search, departure boards, service alerts, and recovery states are implemented through Trainy's narrow provider proxy. The authenticated NS quota/product-page review, production Worker rollout, public contract checks, credential boundary, and iPhone 17 rider path are verified at `https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`; NS is now rider-active in provider metadata. The URL remains an explicit release build setting rather than a source-controlled default. Production receives the NS credential only through the Worker secret binding; the authorized local smoke copy remains ignored and never enters Xcode.

## Provider Proxy

Cloudflare Workers is the selected production proxy path for credentialed or heavy providers. The app reads only the proxy base URL from `TRAINY_PROVIDER_PROXY_BASE_URL` or `TrainyProviderProxyBaseURL` in the app `Info.plist`; production provider keys stay in Worker secrets or equivalent backend secret storage.

Settings > Providers shows the proxy state and, when configured, can fetch compact health from `GET /v1/health/providers`. That response is intentionally app-safe provider status and cache metadata, not rider trip details or raw upstream/provider debug output.

The implemented NS contract is deliberately small: `GET /v1/ns/stations`, `GET /v1/ns/departures`, and `GET /v1/ns/disruptions`. Inputs, upstream operations, timeouts, response sizes, caches, rate limits, and normalized fields are fixed by the Worker; it is not a general NS relay. For credential-neutral checks and the authorized local path:

```bash
npm ci --prefix provider-proxy
npm run check --prefix provider-proxy
scripts/smoke-ns-proxy.sh
```

Run `scripts/dev-ns-proxy.sh`, then build with `TRAINY_PROVIDER_PROXY_BASE_URL=http://127.0.0.1:8787` to exercise the simulator-only development path locally. URL validation accepts only loopback HTTP and requires HTTPS for every non-loopback proxy. The shipped Release plist contains no ATS exception and pins only the public HTTPS production Worker. Production configuration, rotation, failure behavior, and the approval-gated rollout are documented in `provider-proxy/README.md`.

## Swift Package and VS Code

The native app code is package-first now:

- `Sources/TrainyCore/`: reusable models, provider logic, store, SwiftUI views, and utilities.
- `Tests/TrainyCoreTests/`: offline provider-safety unit tests.
- `TrainyIOS/Trainy/`: Xcode-only app wrapper with `TrainyApp.swift`, `Info.plist`, asset catalogs, app icon, launch-screen settings, and preview assets.

Open the repository root in VS Code so the official Swift extension can read `Package.swift`. The package defines the `TrainyCore` library target and `TrainyCoreTests` test target, with iOS 26.0 as the supported app platform. The app wrapper pins Firebase iOS SDK 12.15.0 for `FirebaseCore` and `FirebaseCrashlytics`; TrainyCore also links the Apple platform frameworks used by the app UI (`MapKit`, `SwiftUI`, and `UIKit`).

Useful commands:

```bash
swift package describe
scripts/build-ios.sh
```

VS Code tasks are available under `.vscode/tasks.json` for package describe and the Xcode app-wrapper build/test loop. Because Trainy is an iOS-only app that uses UIKit and iOS MapKit, `scripts/build-ios.sh` and the Xcode wrapper tasks are the reliable compile gates. Plain host `swift build` / `swift test` target macOS by default and are expected to fail with `No such module 'UIKit'`; they are not app validation commands for this repo.

## Run it

Open `index.html` in a browser, or serve the folder with any static file server.

```bash
python3 -m http.server 4173
```

Then visit `http://localhost:4173`.

## Run on iOS Simulator

If the goal is to launch Trainy in the iPhone Simulator, the path is Xcode + `scripts/build-ios.sh`. Plain host `swift build` / `swift test` target macOS and fail with `No such module 'UIKit'`, so they are not a way to run the iOS app.

Before the first build, the non-App-Store Xcode install at `/Applications/Xcode-26.5.0.app` needs the iOS 26.5 Simulator runtime and an accepted license:

```bash
sudo xcode-select -s /Applications/Xcode-26.5.0.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

Then open the Xcode project, pick an iPhone simulator, and run the `Trainy` scheme:

```bash
open TrainyIOS/Trainy.xcodeproj
# In Xcode: Product > Run (⌘R) with an iPhone simulator destination
```

From the command line, the wrapper script builds the `Trainy` scheme against the generic iOS Simulator destination and produces an app bundle under `/private/tmp/trainy-derived`:

```bash
scripts/build-ios.sh
```

To boot a specific simulator, install the freshly built `Trainy.app`, and launch it headlessly with `simctl`:

```bash
DEVICE='iPhone 17'
UDID=$(xcrun simctl list devices available | awk -v d="$DEVICE" -F'[()]' '/\(/ && $0 ~ d {gsub(/^ +| +$/,"",$2); print $2; exit}')
xcrun simctl boot "$UDID" || true
open -a Simulator
xcrun simctl install "$UDID" /private/tmp/trainy-derived/Build/Products/Debug-iphonesimulator/Trainy.app
xcrun simctl launch "$UDID" com.jacobcyber.Trainy
```

`xcodebuild -downloadPlatform iOS` is only required once per Xcode install. After that, `scripts/build-ios.sh` plus the optional `simctl install`/`launch` pair above is enough to get Trainy running on a simulator.

If `xcrun simctl` errors with `CoreSimulatorService connection became invalid`, restart Simulator.app or run `xcrun simctl shutdown all` and then `open -a Simulator` to revive the service.

## Distribution archive audit

Trainy's production-equivalent, non-uploading archive workflow is owned by
`scripts/archive-ios.sh`. It forces Release, the generic iOS destination, the
approved public NS proxy, an empty ODPT value, isolated temporary outputs, and
Crashlytics validation-only mode. It defaults to unsigned operation so a local
audit cannot silently upload symbols or impersonate distribution signing.

Use fresh output paths, then audit the complete archive and build outputs:

```bash
ARCHIVE_PATH=/private/tmp/trainy-distribution/Trainy.xcarchive \
RESULT_BUNDLE_PATH=/private/tmp/trainy-distribution/Trainy.xcresult \
DERIVED_DATA_PATH=/private/tmp/trainy-distribution/DerivedData \
CODE_SIGNING_ALLOWED=NO \
scripts/archive-ios.sh

scripts/audit-ios-archive.py \
  /private/tmp/trainy-distribution/Trainy.xcarchive \
  --result-bundle /private/tmp/trainy-distribution/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/DerivedData \
  --json-output /private/tmp/trainy-distribution/audit.json
```

If the ignored fillable credential form is present, add
`--credential-pdf docs/trainy_api_credentials_fillable_form.pdf`; the scanner
requires `pdftotext` and never prints a value. The full 2026-07-21 archive
identity, commands, privacy/SDK manifest inventory, finding dispositions, and
signing limitation are recorded in
[`docs/distribution-readiness-2026-07-21.md`](docs/distribution-readiness-2026-07-21.md).

## Tests

Trainy's package tests live in `Tests/TrainyCoreTests`. The Xcode `TrainyTests` scheme points at the same test source so the iOS app wrapper and package code are tested together:

```bash
xcodebuild test \
  -project TrainyIOS/Trainy.xcodeproj \
  -scheme TrainyTests \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/trainy-derived \
  -clonedSourcePackagesDirPath /private/tmp/trainy-source-packages \
  -packageCachePath /private/tmp/trainy-swiftpm-cache \
  CODE_SIGNING_ALLOWED=NO \
  TRAINY_SOURCE_PACKAGES_DIR=/private/tmp/trainy-source-packages
```

`TrainyTests` does not require provider credentials or live network access. It covers source provenance mapping, fallback behavior, route matching, station normalization, time parsing across midnight, persistence migration by `dataScope`, proxy health/config wiring, NS proxy adapter and view-model states, provider response-contract validation, native response size/deadline enforcement, provider error-to-message mapping, NS fixtures, and design-system contracts. The Workerd suite separately covers the public contract, input rejection, normalization, stale fallback, upstream failures, whole-response deadlines, field/body bounds, same-key request coalescing, rate limiting, health isolation, and credential-safe output. Keep `TRAINY_SOURCE_PACKAGES_DIR` equal to `-clonedSourcePackagesDirPath` so the Crashlytics build phase resolves the same Swift package checkout.

The same scheme also contains the deterministic `TrainyUITests` simulator group
for critical search, provider-status, NS, appearance, and AX2XL behavior. See
[`docs/simulator-ui-automation.md`](docs/simulator-ui-automation.md) for the
focused no-retry command, the three-run stability check, fixture contract, and
the CI-equivalent full-suite command.

After a credential-neutral build, `scripts/check-provider-secret-boundary.py` scans versionable files, Trainy-generated artifacts, temporary proxy logs, simulator logs, test products, and the app bundle for any authorized local provider credential value. It also rejects NS upstream-only host/header/secret markers in shipping app files; Xcode-injected `.xctest` plug-ins remain in the exact-value scan but are excluded from that public-marker check because the tests intentionally contain the forbidden strings they assert against.

Current 2026-07-20 verification: 58/58 credential-neutral iOS tests and 35/35 Workerd contract tests passed. The authorized loopback proxy smoke returned 5 Utrecht station matches and 20 fresh departures without printing or persisting the credential. The canonical build also succeeded with ODPT empty and only the public HTTPS proxy base URL configured. The four-case secret-boundary regression suite, provider-smoke parser/host/port suite, 25-case design-system guard self-test, 28-file repository design-system scan, and final boundary scan passed. The expanded final scan checked 58,811 repository/generated/log files plus 122 shipping app files. It found and removed one earlier Xcode DerivedData cache whose private build-command attachments retained an authorized local credential; the clean rerun found neither authorized local provider value nor an NS upstream-only marker in the shipping app.

The 2026-07-21 distribution pass produced a fresh Release xcarchive and passed
66/66 Xcode tests, 35/35 Workerd contract tests, 27 design-system guard
fixtures, the 29-file design-system repository scan, and a 44-check final
archive audit with zero failures. The audit is content-complete but explicitly
unsigned. A separate Release-configured iPhoneOS app passed strict signature
verification with the installed one-device Personal Team development profile;
that is device-demo proof, not App Store or TestFlight distribution. See the
owning distribution-readiness record above.

The iPhone 17 / iOS 26.5 runtime pass exercised live Utrecht search and departure results, source-backed no-match, automatic stale copy, forced offline fallback, and recovery after the loopback Worker restarted. Light and Dark Mode and AX2XL reflow were inspected separately. With VoiceOver actually enabled, the simulator accessibility tree exposed headings, the labelled station field and 44-by-44-point submit action, station-name/code buttons, source/freshness text, and 54-point tabs in logical order. The simulator was restored to standard Large text, Dark Mode, VoiceOver off, and normal contrast afterward.

The owner approved the free Cloudflare hostname and one-time migration bridge on 2026-07-20. The byte-identical bridge version `65f469e7-ef2b-4acf-8503-e6f3793be5a2` applied the SQLite Durable Object lifecycle migration without changing the public contract. After its public checks passed, hardened version `0ece40b0-b27a-43aa-a865-55445909a2a1` was inspected and promoted to 100%; final deployment `46a26a6a-8abe-4091-9b19-3c32b20ccefa` serves only `https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`. Repeated edge checks returned exact station code `UT` first, a fresh Amsterdam cache miss proved the global quota path can reach NS, and a persistent-client probe received normalized `429` then recovered. Rejected `POST` and unknown routes remained `405` and `404`. A canonical simulator candidate opened a fresh Utrecht board with current departures, a current alert, and separate truthful source disclosures. Preview URLs remain disabled, no custom domain or schedule exists, and the free hostname still lacks an owner-controlled zone WAF layer.

The standalone smoke harnesses remain useful for focused script checks:

```bash
scripts/smoke-source-provenance.sh
scripts/smoke-provider-registry.sh
scripts/smoke-shinkansen-provider.sh
```

`scripts/smoke-odpt.sh` is the credentialed live-data smoke and should only be run after configuring `ODPT_CONSUMER_KEY`.

## Design System

The native UI has one component library under
`Sources/TrainyCore/DesignSystem/`. Tokens, interface preferences, primitives,
patterns, domain UI, loading/empty/error states, and interaction behavior are
owned there; screens only compose them.

Architecture and contribution rules are documented in
`docs/design-system-architecture.md`.

Run both policy checks before submitting UI work:

```bash
bash scripts/check-design-system-bypass.sh --self-test
bash scripts/check-design-system-bypass.sh
```

The first command proves the guardrail catches deliberate bypass fixtures. The
second checks the real iOS and web sources. The repository review workflow is
available at `.agents/skills/review-design-system/SKILL.md`.

Additional credentialed provider smokes are documented in `TrainyIOS/README.md`. They use provider-specific ignored env files with strict key whitelists; do not create or use a combined provider env file unless its parser keeps the same reject-by-default behavior.

## Xcode Without Mac App Store

The helper script at `scripts/install-xcode-non-appstore.sh` uses Apple Developer Downloads through the prebuilt `xcodes` CLI instead of the Mac App Store. Apple still requires Developer web authentication for the Xcode `.xip`.

Xcode 26.5 is currently installed at `/Applications/Xcode-26.5.0.app`. Accept the Xcode license once, then run the native build helper:

```bash
sudo DEVELOPER_DIR="/Applications/Xcode-26.5.0.app/Contents/Developer" xcodebuild -license accept
scripts/build-ios.sh
```
