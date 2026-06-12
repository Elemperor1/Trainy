# Trainy iOS

Native SwiftUI version of Trainy, a Flighty-style rail tracking app now scoped first to Shinkansen trips in Japan.

## Open

Open `Trainy.xcodeproj` in Xcode, select an iPhone simulator, then run the `Trainy` scheme.

## Current scope

- Shinkansen starter data for Tokaido, Sanyo-Kyushu, Tohoku, Hokuriku, Joetsu, Hokkaido, Akita, and Yamagata services.
- Live-style train cards with search, filters, persisted tracked trains, persisted pins, and persisted notification toggles.
- Native train finder sheet for discovering and adding Shinkansen services to the tracked list.
- Selected train dashboard with platform, ETA, route progress, speed, next stop, station timeline, car positioning, alerts, signal confidence, and rail network pulse.
- Journey Guard panel for connection risk, backup-route status, platform watch, and exit-car cues.
- Lock-screen style live activity preview card for the selected train.
- Share sheet support for the selected trip summary.

## Data provider direction

`TrainDataProvider.swift` now contains the Shinkansen-first provider boundary. When `ODPT_CONSUMER_KEY` is configured, Trainy requests ODPT `odpt:TrainTimetable` and `odpt:TrainInformation` data for mapped Shinkansen railways and converts those records into `TrainTrip` cards. If ODPT exposes route metadata but no timetable rows for a Shinkansen railway, Trainy uses official JR timetable pages for real schedule/platform data. Without a key, it falls back to the curated starter catalog with route/station coordinates.

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

The smoke compiles the Trainy provider code and requires both `Tokyo to Shin-Osaka` and `JR East` searches to return ODPT-backed or official timetable trips instead of starter data.

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
