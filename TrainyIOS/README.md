# Trainy iOS

Native SwiftUI version of Trainy, a Flighty-style rail tracking app now scoped first to Shinkansen trips in Japan.

## Open

Open `Trainy.xcodeproj` in Xcode, select an iPhone simulator, then run the `Trainy` scheme.

## Current scope

- Shinkansen starter data for Tokaido, Sanyo-Kyushu, Tohoku, Hokuriku, Joetsu, Hokkaido, Akita, and Yamagata services.
- Source-labeled train cards with search, filters, persisted tracked trains, persisted pins, and persisted notification toggles.
- Native train finder sheet for discovering and adding Shinkansen services to the tracked list.
- Selected train dashboard with platform, ETA, route progress, speed, next stop, station timeline, car positioning, alerts, signal confidence, and rail network pulse.
- Journey Guard panel for connection risk, backup-route status, platform watch, and exit-car cues.
- Lock-screen style activity preview card for the selected train.
- Share sheet support for the selected trip summary.

## Data provider direction

`TrainDataProvider.swift` now contains the Shinkansen-first provider boundary. When `ODPT_CONSUMER_KEY` is configured, Trainy requests ODPT `odpt:TrainTimetable` and `odpt:TrainInformation` data for mapped Shinkansen railways and converts those records into scheduled `TrainTrip` cards. If ODPT exposes route metadata but no timetable rows for a Shinkansen railway, Trainy uses official JR timetable pages for scheduled times and platform data. Without a key, it falls back to the curated starter catalog with route/station coordinates.

The ODPT key is read from either the app `Info.plist` value `ODPTConsumerKey` or the `ODPT_CONSUMER_KEY` environment/build setting. For local builds:

```bash
cp TrainyIOS/Config/odpt.env.example TrainyIOS/Config/odpt.env
chmod 600 TrainyIOS/Config/odpt.env
```

Paste the key issued by `https://developer.odpt.org/` into `TrainyIOS/Config/odpt.env`, then run:

```bash
scripts/build-ios.sh
```

`scripts/build-ios.sh` parses only `ODPT_CONSUMER_KEY=...` from the local env file and passes that value into the app build setting. Do not commit `TrainyIOS/Config/odpt.env`; it is intentionally ignored.

For a repeatable ODPT-backed search check:

```bash
scripts/smoke-odpt.sh
```

The smoke compiles the Trainy provider code and requires both `Tokyo to Shin-Osaka` and `JR East` searches to return ODPT-backed or scheduled timetable trips instead of starter data.

## Provider proxy configuration

Cloudflare Workers is the selected production provider proxy. The iOS app reads only a proxy base URL from `TRAINY_PROVIDER_PROXY_BASE_URL` or the app `Info.plist` value `TrainyProviderProxyBaseURL`; production provider secrets must remain in Worker secrets or equivalent backend secret storage.

When a base URL is configured, Settings > Providers can check `GET /v1/health/providers` and render compact provider health. The health payload must stay app-safe: provider IDs, configuration/health state, cache freshness, timestamps, and rider-safe messages only. Do not include raw provider URLs, auth headers, searched stations, rider trip IDs, device IDs, or upstream payloads.

## Credentialed provider smoke checks

Future-provider smoke scripts use strict env-file parsing: each script accepts only its provider's expected keys, exits `2` when credentials are missing, exits `1` for provider/network failures, and prints only provider, query, and result count on success.

Local env files are ignored by git. There is intentionally no combined `TrainyIOS/Config/providers.env.example` yet: each current smoke script whitelists only its provider's expected keys, so a shared multi-provider env file would be rejected by the strict parser. Keep using provider-specific env files until a combined file has an equally strict parser contract.

Local env files are parsed as data, not executed as shell code. The loaders accept only `KEY=value` lines for the expected keys, reject unsupported keys and command substitution syntax, and warn if a secret file is readable by group or others. Keep local secret files at mode `600`.

Copy only the examples you need:

```bash
cp TrainyIOS/Config/ns.env.example TrainyIOS/Config/ns.env
cp TrainyIOS/Config/tdx.env.example TrainyIOS/Config/tdx.env
cp TrainyIOS/Config/tfnsw.env.example TrainyIOS/Config/tfnsw.env
cp TrainyIOS/Config/swiss.env.example TrainyIOS/Config/swiss.env
cp TrainyIOS/Config/france-sncf.env.example TrainyIOS/Config/france-sncf.env
chmod 600 TrainyIOS/Config/*.env
```

Run the checks from the repository root:

```bash
scripts/smoke-ns.sh
scripts/smoke-tdx.sh
scripts/smoke-tfnsw.sh
scripts/smoke-swiss-gtfs-rt.sh
scripts/smoke-france-sncf.sh
```

| Smoke command | Local env file | Required keys | Signup path |
| --- | --- | --- | --- |
| `scripts/smoke-odpt.sh` | `TrainyIOS/Config/odpt.env` | `ODPT_CONSUMER_KEY` | `https://developer.odpt.org/` |
| `scripts/smoke-ns.sh` | `TrainyIOS/Config/ns.env` | `NS_SUBSCRIPTION_KEY` | `https://apiportal.ns.nl/` |
| `scripts/smoke-tdx.sh` | `TrainyIOS/Config/tdx.env` | `TDX_CLIENT_ID`, `TDX_CLIENT_SECRET` | `https://tdx.transportdata.tw/` |
| `scripts/smoke-tfnsw.sh` | `TrainyIOS/Config/tfnsw.env` | `TFNSW_API_KEY` | `https://opendata.transport.nsw.gov.au/` |
| `scripts/smoke-swiss-gtfs-rt.sh` | `TrainyIOS/Config/swiss.env` | `SWISS_GTFS_RT_API_KEY` | `https://opentransportdata.swiss/en/` |
| `scripts/smoke-france-sncf.sh` | `TrainyIOS/Config/france-sncf.env` | `TRANSPORT_DATA_GOUV_FR_TOKEN`; optional `SNCF_API_TOKEN` is parsed but not required by the current metadata smoke | `https://transport.data.gouv.fr/`, `https://data.sncf.com/` |

Future-only provider credentials are documented without implying local keys exist:

| Provider area | Local status | Signup path |
| --- | --- | --- |
| UK National Rail Darwin | `TrainyIOS/Config/uk-rail.env.example` is a placeholder for a backend worker/Kafka path; there is no current local smoke command. | `https://opendata.nationalrail.co.uk/` |
| MTA | No current local env file or smoke command. Production proxy support should add secrets only after a provider slice exists. | `https://bustime.mta.info/developers` |
| Deutsche Bahn | No current local env file or smoke command. Production proxy support should add secrets only after a provider slice exists. | `https://developers.deutschebahn.com/db-api-marketplace/apis/` |
| South Korea TAGO/TOPIS | No current local env file or smoke command; provider access remains blocked/partnership-required in the roadmap. | `https://www.data.go.kr/` |

Production credentials belong in the Cloudflare Worker `trainy-provider-proxy` as Worker secrets or equivalent backend secret storage. Local `.env` files are for developer smoke checks only and must not be copied into the iOS app bundle or committed.

`scripts/build-ios.sh` intentionally loads only the existing ODPT app-development key. It never loads `ns.env` or passes `NS_SUBSCRIPTION_KEY` to Xcode. The NS adapter and fixtures are available for developer verification, but the iOS coverage UI must keep NS in the adapter-ready state until a proxy-backed station-board surface is implemented.

The shared pattern verifier does not call live providers:

```bash
scripts/test-provider-smoke-pattern.sh
```

## Firebase Crashlytics

Crashlytics is configured through the Firebase project `trainy-ios-20260621` and iOS app `1:421696672177:ios:9a998e2c26068742752d90` for bundle ID `com.jacobcyber.Trainy`.

`Trainy/GoogleService-Info.plist` was generated with:

```bash
npx -y firebase-tools@latest apps:sdkconfig IOS 1:421696672177:ios:9a998e2c26068742752d90 --project trainy-ios-20260621
```

The app target initializes Firebase in `TrainyApp.init()` before SwiftUI content is created. The Xcode project links `FirebaseCore` and `FirebaseCrashlytics`, includes the config plist in the app resources, sets `DWARF with dSYM File`, and has a Crashlytics dSYM upload run script. The Firebase plist is app configuration, not a production provider secret; provider API credentials still belong only in the Cloudflare Worker or local ignored smoke env files.

## Local tooling note

This workspace is set up for the non-App-Store Xcode 26.5 install at `/Applications/Xcode-26.5.0.app`:

```bash
sudo xcode-select -s /Applications/Xcode-26.5.0.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
```

The `xcodebuild -downloadPlatform iOS` step installs the iOS 26.5 Simulator runtime that Xcode needs before it can resolve iOS Simulator destinations. Then build Trainy from the repository root:

```bash
scripts/build-ios.sh
```

To build for a generic iOS device instead of Simulator:

```bash
DESTINATION='generic/platform=iOS' scripts/build-ios.sh
```

## Non-App-Store Xcode install

Use the repository helper if you do not want to sign into the Mac App Store:

```bash
scripts/install-xcode-non-appstore.sh
```

This downloads the prebuilt `xcodes` CLI from GitHub, verifies its SHA-256, then uses Apple Developer Downloads for Xcode 26.5. Apple blocks unauthenticated `.xip` downloads, so this path may still ask for an Apple Developer web sign-in. It does not use the Mac App Store.
