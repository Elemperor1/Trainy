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
- Proxy-backed Netherlands NS station search, current departure boards, service alerts, truthful freshness/source disclosure, and retryable stale/offline/rate-limit states when a provider proxy base URL is configured.

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

The NS rider flow calls only the proxy's fixed station-search, departure-board, and disruption routes. It never contains the NS host, auth header, or credential. For local verification, start the loopback Worker and build the app with only its base URL:

```bash
scripts/dev-ns-proxy.sh
TRAINY_PROVIDER_PROXY_BASE_URL=http://127.0.0.1:8787 ODPT_ENV_FILE=/dev/null scripts/build-ios.sh
```

Loopback HTTP is accepted for local development through the app's narrowly scoped ATS local-network permission; all other proxy URLs must be HTTPS. Do not point the app at the NS API directly.

Both proxy health and NS data clients stream responses under an absolute
eight-second deadline. Health is capped at 64 KiB and NS data at 1 MiB before
decoding. Decoded responses must match Trainy's fixed NS provider/source/
attribution metadata, freshness interval, item counts, station-code shape, and
per-field bounds before any value reaches a view model. Board and alert
provenance are kept separately, and each is re-evaluated at `validUntil` so a
screen cannot continue to describe an expired response as current.

## Credentialed provider smoke checks

Future-provider smoke scripts use strict env-file parsing: each script accepts only its provider's expected keys, exits `2` when credentials are missing, exits `1` for provider/network failures, and prints only provider, query, and result count on success.

Local env files are ignored by git. There is intentionally no combined `TrainyIOS/Config/providers.env.example` yet: each current smoke script whitelists only its provider's expected keys, so a shared multi-provider env file would be rejected by the strict parser. Keep using provider-specific env files until a combined file has an equally strict parser contract.

Local env files are parsed as data, not executed as shell code. The loaders accept only one `KEY=value` assignment for each expected key, reject duplicates, unsupported keys, malformed quoting, command substitution, and other executable shell syntax, and validate the complete file before exporting anything. The NS loopback scripts additionally accept only `127.0.0.1` or `localhost` and ports `1...65535`. They never replay raw Wrangler output. Keep local secret files at mode `600`.

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
scripts/smoke-ns-proxy.sh
scripts/smoke-tdx.sh
scripts/smoke-tfnsw.sh
scripts/smoke-swiss-gtfs-rt.sh
scripts/smoke-france-sncf.sh
```

| Smoke command | Local env file | Required keys | Signup path |
| --- | --- | --- | --- |
| `scripts/smoke-odpt.sh` | `TrainyIOS/Config/odpt.env` | `ODPT_CONSUMER_KEY` | `https://developer.odpt.org/` |
| `scripts/smoke-ns.sh` | `TrainyIOS/Config/ns.env` | `NS_SUBSCRIPTION_KEY` | `https://apiportal.ns.nl/` |
| `scripts/smoke-ns-proxy.sh` | `TrainyIOS/Config/ns.env` | `NS_SUBSCRIPTION_KEY` | Local end-to-end NS proxy contract |
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

Production credentials belong only in the dedicated Cloudflare Worker `trainy-ns-provider-proxy` as Worker secrets or equivalent backend secret storage. Do not upload this NS-only contract to the pre-existing shared `trainy-provider-proxy` service. Local `.env` files are for developer smoke checks only and must not be copied into the iOS app bundle or committed.

`scripts/build-ios.sh` intentionally loads only the existing ODPT app-development key. It never loads `ns.env` or passes `NS_SUBSCRIPTION_KEY` to Xcode. The NS proxy-backed UI and production path are verified at the approved free HTTPS endpoint `https://trainy-ns-provider-proxy.trainy-jacob.workers.dev`, and NS is rider-active in provider metadata. The endpoint was explicitly injected into the canonical simulator candidate and verified in that app's `Info.plist`; it is still not a source-controlled default release setting. A build without the endpoint remains honestly unavailable and never falls back to a client-side NS credential.

Verification on 2026-07-20 used iPhone 17 / iOS 26.5: the canonical
credential-neutral build succeeded, 58/58 iOS tests and 35/35 Workerd contract
tests passed, and the authorized loopback smoke returned 5 Utrecht station
matches and 20 fresh departures without exposing the credential. The runtime
path covered station results, departures, no-match, automatic stale copy,
forced offline fallback, and recovery after the Worker restarted. Light and
Dark Mode and AX2XL were inspected independently. With VoiceOver enabled, the
simulator AX tree exposed logical headings/order, labelled search and retry
actions, station name/code buttons, source/freshness copy, 44-point controls,
and 54-point tabs. The simulator was restored to Large text, Dark Mode,
VoiceOver off, and normal contrast after the review. The existing reviewed
Worker is publicly reachable only at the owner-approved free `workers.dev`
hostname; preview URLs, custom domains, and schedules remain disabled or
absent. The approved bridge applied the SQLite Durable Object migration, and
hardened version `0ece40b0-b27a-43aa-a865-55445909a2a1` is now the sole 100%
deployment. Public health/search/departure/disruption, method/route rejection,
security headers, exact-code ranking, a fresh cache-miss fetch, normalized
client `429`, and recovery passed. No distributed or source-default release
build was changed. Earlier runtime coverage exercised unavailable, retry,
no-match, stale/expired, offline, and recovery states; the post-promotion
simulator pass opened a fresh Utrecht board with current departures, a current
alert, and separate board/alert source disclosures.

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
