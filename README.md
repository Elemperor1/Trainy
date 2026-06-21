# Trainy

Trainy is a Flighty-style train tracking app, scoped first to Shinkansen trips in Japan.

This workspace now contains three development surfaces:

- `Package.swift`: Swift Package Manager workspace for reusable Trainy code.
- `TrainyIOS/`: thin native SwiftUI iOS app wrapper for signing, app resources, and packaging.
- Root `index.html`: self-contained browser prototype with no external dependencies.

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

## Provider Proxy

Cloudflare Workers is the selected production proxy path for credentialed or heavy providers. The app reads only the proxy base URL from `TRAINY_PROVIDER_PROXY_BASE_URL` or `TrainyProviderProxyBaseURL` in the app `Info.plist`; production provider keys stay in Worker secrets or equivalent backend secret storage.

Settings > Providers shows the proxy state and, when configured, can fetch compact health from `GET /v1/health/providers`. That response is intentionally app-safe provider status and cache metadata, not rider trip details or raw upstream/provider debug output.

## Swift Package and VS Code

The native app code is package-first now:

- `Sources/TrainyCore/`: reusable models, provider logic, store, SwiftUI views, and utilities.
- `Tests/TrainyCoreTests/`: offline provider-safety unit tests.
- `TrainyIOS/Trainy/`: Xcode-only app wrapper with `TrainyApp.swift`, `Info.plist`, asset catalogs, app icon, launch-screen settings, and preview assets.

Open the repository root in VS Code so the official Swift extension can read `Package.swift`. The package defines the `TrainyCore` library target and `TrainyCoreTests` test target, with iOS 26.0 as the supported app platform. No external Swift package dependencies were present in the Xcode project; the package links Apple platform frameworks used by the app UI (`MapKit`, `SwiftUI`, and `UIKit`).

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
  CODE_SIGNING_ALLOWED=NO
```

`TrainyTests` does not require ODPT credentials or live network access. It covers source provenance mapping, fallback behavior, route matching, station normalization, time parsing across midnight, persistence migration by `dataScope`, proxy health/config wiring, and provider error to user-message mapping.

The standalone smoke harnesses remain useful for focused script checks:

```bash
scripts/smoke-source-provenance.sh
scripts/smoke-provider-registry.sh
scripts/smoke-shinkansen-provider.sh
```

`scripts/smoke-odpt.sh` is the credentialed live-data smoke and should only be run after configuring `ODPT_CONSUMER_KEY`.

Additional credentialed provider smokes are documented in `TrainyIOS/README.md`. They use provider-specific ignored env files with strict key whitelists; do not create or use a combined provider env file unless its parser keeps the same reject-by-default behavior.

## Xcode Without Mac App Store

The helper script at `scripts/install-xcode-non-appstore.sh` uses Apple Developer Downloads through the prebuilt `xcodes` CLI instead of the Mac App Store. Apple still requires Developer web authentication for the Xcode `.xip`.

Xcode 26.5 is currently installed at `/Applications/Xcode-26.5.0.app`. Accept the Xcode license once, then run the native build helper:

```bash
sudo DEVELOPER_DIR="/Applications/Xcode-26.5.0.app/Contents/Developer" xcodebuild -license accept
scripts/build-ios.sh
```
