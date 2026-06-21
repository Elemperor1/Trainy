# Phase 0 Baseline And Repo Hygiene

Date: 2026-06-13  
Timezone: Asia/Tokyo  
Milestone: Phase 0, know what is true before changing the app

## Working Tree

- Initial `git status --short`: clean, no output.
- Repo state at start: tracked repository with a clean working tree, not a fully untracked repo.
- No unrelated user edits were present in files needed for Phase 0.
- After verification, an untracked `.vscode/settings.json` exists with only `markdown.validate.enabled: true`; it was not reset, deleted, or overwritten.

## Verification Baseline

- `node --check app.js`: passed.
- `bash -n scripts/build-ios.sh`: passed.
- `bash -n scripts/smoke-odpt.sh`: passed.
- `bash -n scripts/lib/odpt-env.sh`: passed.
- `xcodebuild -version`: Xcode 26.5, build 17F42.
- `scripts/build-ios.sh`: initial sandbox run failed because CoreSimulator services and user Library simulator logs were unavailable inside the restricted sandbox. Rerun outside the sandbox with a non-secret placeholder `ODPT_CONSUMER_KEY=present-redacted` and `ODPT_ENV_FILE=/private/tmp/trainy-no-odpt.env`: passed, `BUILD SUCCEEDED`.
- `scripts/smoke-odpt.sh`: passed with local credentials configured. It returned real timetable trips for `Tokyo to Shin-Osaka` and `JR East`.

## Credential State

- Shell environment `ODPT_CONSUMER_KEY`: missing.
- Local ignored config `TrainyIOS/Config/odpt.env`: present.
- Local ODPT key status: present, not printed, not recorded.
- Local ODPT env file permissions: `600`.
- Credential-dependent verification gap: none on this machine for Phase 0, because the ODPT smoke passed. On machines without `ODPT_CONSUMER_KEY` or `TrainyIOS/Config/odpt.env`, `scripts/smoke-odpt.sh` should be recorded as credential missing, not provider broken.

## Current App Architecture

- Root app surface: `README.md` describes Trainy as a Flighty-style rail tracker scoped first to Japanese Shinkansen journeys, with a browser prototype and native SwiftUI iOS app.
- iOS scope: `TrainyIOS/README.md` documents Trips, Search, Stations, History, Settings, trip detail, journey map, share, pins, notification toggles, and local persistence.
- Data provider: `TrainDataProvider.swift` owns the current Shinkansen-first provider boundary.
- Provider order: ODPT when configured, official JR timetable pages when ODPT route metadata exists but timetable rows are missing, curated Shinkansen starter catalog without a key.
- Store: `TrainStore.swift` owns tracked trips, selected trip, search query/filter, live routes/results, load state, last refresh, pins, notifications, and data-scope migration.
- Models: `TrainModels.swift` defines `TrainTrip`, `StationPoint`, `StationStop`, `TrainAlert`, `TripFilter`, `TrainStatusTone`, and the current `dataSource` string.
- UI surfaces: `ContentView.swift` is a five-tab app: Trips, Search, Stations, History, Settings. Detail screens include route header, status summary, rail map, stop timeline, transfer warning, carriage/platform, notes, alerts, and share.
- Map expectations: `RailJourneyMap.swift` renders a MapKit route with completed/upcoming polylines, train pin, station pins, disruption markers, stop rail, recenter control, and route/stops/alerts modes. It uses known Shinkansen station coordinates and falls back to origin/destination interpolation for unknown stops.
- Reusable components: `RailComponents.swift` contains shared cards, status pills, platform chips, station badges, trip cards, timeline rows, disruption/offline banners, loading skeletons, empty states, and common source/status-adjacent placement.

## XCTest Target Check

- `rg --files | rg '(Tests|Test|XCTest|\\.xctest|project\\.pbxproj|Package\\.swift)'`: only `TrainyIOS/Trainy.xcodeproj/project.pbxproj` matched.
- `rg -n "XCTest|Tests|PBXNativeTarget|productType = \"com\\.apple\\.product-type\\.bundle\\.unit-test\"" TrainyIOS/Trainy.xcodeproj/project.pbxproj TrainyIOS`: found only the single native target named `Trainy`.
- Conclusion: no existing XCTest target or test bundle is present.

## Provider Source Links Observed

- ODPT developer portal: `https://developer.odpt.org/`
- ODPT API base URL in provider code: `https://api.odpt.org/api/v4`
- ODPT resources in provider code: `odpt:TrainTimetable`, `odpt:TrainInformation`, using `acl:consumerKey`.
- JR East official timetable pages in provider code:
  - `https://timetables.jreast.co.jp/en/2607/timetable/tt1039/1039010.html`
  - `https://timetables.jreast.co.jp/en/2607/timetable/tt1039/1039020.html`
  - `https://timetables.jreast.co.jp/en/2607/timetable/tt1039/1039050.html`
  - `https://timetables.jreast.co.jp/en/2607/timetable/tt1039/1039060.html`

## Done State

- Baseline commands are recorded.
- Current app architecture is understood.
- Credential-dependent verification status is explicitly labeled.
