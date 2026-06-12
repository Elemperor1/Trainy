# Trainy Polish And Global Provider Roadmap

Status: implementation-ready planning draft  
Date: 2026-06-12  
Scope: polish the current Japan/Shinkansen-first app, then expand Trainy to the top 10 implementable global rail provider integrations without breaking ODPT or the curated Shinkansen starter catalog.

## Executive Decision

Keep Trainy Shinkansen-first while turning the current single-provider app into a provider-capability platform. The current app should not try to add 10 providers by copy-pasting 10 `ShinkansenTrainProvider` variants. It should first split provider contracts, normalized rail models, credentials, provenance, and fixture tests, then add providers in ranked slices.

The top 10 provider integrations to roadmap after the existing ODPT/Japan anchor are:

1. Taiwan TDX: Taiwan Railway, THSR, metro rail APIs.
2. Hong Kong MTR via DATA.GOV.HK.
3. Deutsche Bahn: Timetables/RIS APIs.
4. Switzerland opentransportdata.swiss/OJP.
5. UK National Rail/Network Rail/Darwin via Rail Data Marketplace or National Rail Data Portal.
6. Transport for NSW.
7. MTA LIRR + Metro-North.
8. Netherlands NS API.
9. South Korea TAGO + Seoul TOPIS.
10. France SNCF + transport.data.gouv.fr.

India and China are strategic watchlist markets, not near-term implementation targets, because the current research found official customer-facing web/app surfaces but no stable public official developer rail feed suitable for Trainy without partnership.

## Evidence Inspected

Local repo:

- `README.md` and `TrainyIOS/README.md`
- `TrainyIOS/Trainy/TrainDataProvider.swift`
- `TrainyIOS/Trainy/TrainStore.swift`
- `TrainyIOS/Trainy/TrainModels.swift`
- `TrainyIOS/Trainy/ContentView.swift`
- `scripts/build-ios.sh`
- `scripts/smoke-odpt.sh`
- `scripts/lib/odpt-env.sh`
- `scripts/ODPTSmoke.swift`

Verification run while preparing this roadmap:

- `node --check app.js`: passed.
- `bash -n scripts/build-ios.sh`: passed.
- `bash -n scripts/smoke-odpt.sh`: passed.
- `bash -n scripts/lib/odpt-env.sh`: passed.

Credential note: `TrainyIOS/Config/odpt.env` exists locally and is mode `600`; this roadmap did not print or inspect the secret.

Current verification gap: there are no XCTest, Swift package, or UI test targets in the repo. The ODPT smoke exists, but authenticated live behavior still depends on local provider credentials and network availability.

## Current App Assessment

### UX

Trainy already has a rich SwiftUI shell: Trips, Search, Stations, History, Settings, trip detail, journey map, share links, pins, notification toggles, live-style cards, offline banners, empty states, and skeleton loading. The polish work should tighten credibility and reduce dead controls rather than add broad new screens.

Near-term UX gaps:

- No first-run explanation of the Japan-first data scope, starter data, ODPT, or source freshness.
- Settings toggles are mostly local UI state, not actual notification, calendar, unit, or provider behavior.
- Search copy says "live and saved services," but the actual live scope is provider-dependent.
- Provider/source details are buried in card copy rather than exposed as a consistent trust surface.
- Manual trip creation shows a notice but is not connected.
- No provider selector, region selector, credential status, or data availability view.

### Reliability

The app handles local fallback well for the current scope: without ODPT it uses the curated Shinkansen starter catalog. `TrainStore.LiveLoadState` distinguishes loading, loaded, empty, and offline. Persistence has a data-scope migration so stale non-Japan trips are not reused.

Reliability gaps:

- `TrainStore` owns one concrete `ShinkansenTrainProvider`, so provider failure semantics cannot vary per provider.
- Error messages are Shinkansen-specific.
- ODPT, official timetable HTML parsing, catalog data, route mapping, decoders, and trip-card conversion all live in one large provider file.
- The JR East timetable fallback scrapes HTML and should be isolated behind a brittle-source adapter with fixtures and clear source warnings.
- No cache expiry model, retry policy, freshness age, provider health, or per-field confidence.

### Data Model

`TrainTrip` is tuned to the current card UI: train name, operator, service, origin, destination, status, platform, next stop, ETA, speed, progress, car/seat cues, alerts, vehicle coordinates, and `dataSource`. This is good for UI rendering but too specific to be the ingestion model for global providers.

Data model gaps:

- No normalized `Provider`, `Source`, `Route`, `Station`, `ScheduledTrip`, `RealtimeOverlay`, `VehiclePosition`, `ServiceAlert`, or `FacilityStatus` layer.
- `providerID`, `routeID`, and `liveTripID` exist, but there is no provider registry or global ID namespace.
- Provenance is a string (`dataSource`) instead of structured source metadata.
- No first-class freshness, license, attribution, language, time zone, or confidence fields.

### Provider Abstraction

Current shape:

- `TrainyAPIConfig` reads `ODPT_CONSUMER_KEY` from env or `Info.plist`.
- `ShinkansenTrainProvider` exposes `fetchRoutes`, `fetchTrips`, and `refresh`.
- ODPT client uses `acl:consumerKey` with `odpt:TrainTimetable` and `odpt:TrainInformation`.
- If ODPT is configured but no trips are found, JR East official timetable pages may provide schedule/platform data.
- Without ODPT, the provider returns curated starter trips.

Provider abstraction gaps:

- `TrainStore` depends on `ShinkansenTrainProvider`, not a protocol.
- No capability model for schedule-only, realtime-only, alerts-only, station-board-only, or journey-planning providers.
- No way to hide unavailable providers or explain credential requirements.
- Secret-bearing provider APIs would leak keys if shipped directly in the app. A thin backend/proxy is needed for production credentials.

### Onboarding

There is no explicit onboarding. The first screen opens into trips and bootstraps live data. This is fine for a prototype, but global provider support needs an initial region/provider story.

Needed:

- First-run region selection with Japan preselected.
- Data-source explainer: "official timetable," "realtime prediction," "starter fallback," "unverified/unavailable."
- Optional provider credentials status for developer builds.
- A "try a sample journey" path that does not require keys.

### Settings

Settings are visually complete but mostly not wired to platform behavior. Good polish targets:

- Provider/region settings.
- Source attribution and licenses.
- Units/time format/language as actual preferences.
- Notification permission flow and per-trip alert preferences.
- Diagnostics opt-in with explicit provider and no personal trip details.

### Error States And Offline

The current offline banner and load states are a solid start. Global support needs more precise states:

- Provider not configured.
- Provider credentials invalid.
- Provider quota/rate limited.
- Provider source temporarily unavailable.
- Realtime unavailable, schedule still available.
- Schedule available, platform unknown.
- Data stale beyond threshold.
- Source license blocks commercial/public release until approved.

### Offline/Fallback Behavior

The curated Shinkansen catalog is valuable and should remain. Extend the pattern:

- Every provider gets a small fixture catalog for demo/offline search.
- Live provider data overlays fixture/schedule data only when source and freshness are known.
- Cached static schedule feeds should be versioned by provider, feed version/date, and license.
- Saved trips should keep the last known card state with a visible stale badge.

### Testing

Current test coverage is script-based:

- JS syntax check is available via `node --check`.
- Shell syntax checks work.
- `scripts/smoke-odpt.sh` compiles provider code plus `ODPTSmoke.swift` and verifies two authenticated search paths when ODPT is configured.

Missing:

- XCTest unit tests for provider matching, time parsing, station normalization, persistence migration, and fallback behavior.
- Fixture tests for ODPT, JR timetable HTML, GTFS static, GTFS-RT, and each new provider.
- UI tests for first run, search, offline, provider unavailable, and source labels.
- Secret-safety tests that ensure provider keys never ship in logs or committed files.

### Docs And Release Readiness

Docs are current for ODPT setup and fallback behavior. Release readiness is not there yet because there is no privacy/attribution matrix, provider licensing checklist, App Store credential strategy, or automated test target.

## Roadmap Principles

- Preserve Japan/Shinkansen as the flagship first-run experience.
- Do not overclaim live vehicle position when a source only provides timetable or prediction data.
- Prefer official direct feeds. Use aggregators for discovery or normalization only when source license allows it.
- Treat GTFS Schedule + GTFS Realtime as the default global format.
- Treat NeTEx/SIRI as the richer European format, likely normalized server-side.
- Keep ODPT, Darwin, DB RIS, TDX, NS, and other provider-specific APIs behind adapters.
- Put provenance on every user-visible fact: confirmed, estimated, inferred, unknown.
- Never ship production provider secrets inside the app binary.

## Polish Plan

### Polish Milestone 1: Trust And Source Clarity

User-facing outcome: a rider knows whether a card is official timetable, realtime prediction, curated starter data, or stale saved data.

Acceptance criteria:

- Every trip card and detail screen shows a compact source badge.
- Source detail sheet lists provider, feed type, updated time, freshness, and attribution.
- Starter data says "starter catalog" everywhere it appears.
- ODPT and official timetable copy never implies live train location unless a source proves it.

Engineering scope:

- Replace `dataSource: String?` with a `SourceProvenance` model while preserving decode compatibility.
- Add `FreshnessState` and `ConfidenceLevel`.
- Add source-label view components reused by trip cards, search results, and detail pages.

### Polish Milestone 2: Real Preferences

User-facing outcome: Settings controls either do something or clearly become read-only information.

Acceptance criteria:

- Units/time format apply across cards, station boards, and history.
- Notification toggles trigger the iOS permission flow or are labeled as local prototypes.
- Calendar sync is hidden or implemented as a ticket with no misleading toggle.
- Provider/region settings exist with Japan selected.

Engineering scope:

- Add `TrainySettingsStore`.
- Persist region, units, time format, source-label verbosity, and diagnostics consent.
- Audit Settings strings for unimplemented claims.

### Polish Milestone 3: Provider Health And Empty States

User-facing outcome: failed searches explain whether no train exists, provider auth is missing, quota is hit, or live data is unavailable.

Acceptance criteria:

- Search empty state differentiates "no matches" from "provider unavailable."
- ODPT missing key has a developer-readable but rider-safe message.
- Offline saved trips show last updated time and data source.
- Provider health appears in Settings for developer builds.

Engineering scope:

- Add `ProviderAvailability` and `ProviderError`.
- Add user-safe error mapping and developer debug details.
- Keep `scripts/smoke-odpt.sh` as an authenticated gate.

### Polish Milestone 4: Test Harness

User-facing outcome: provider changes stop breaking search, persistence, and source claims.

Acceptance criteria:

- Unit tests cover route matching, trip conversion, time parsing, persistence migration, fallback, source labels, and provider errors.
- Fixture tests exist for ODPT sample JSON and JR East timetable HTML.
- CI or local script runs syntax checks, unit tests, and build.

Engineering scope:

- Add TrainyTests target.
- Move provider parsing helpers into testable internal types.
- Add fixture files under `TrainyIOS/TrainyTests/Fixtures`.

## Global Provider Expansion Strategy

### Selection Criteria

Providers were ranked by:

- Rider value and coverage.
- Official or primary-source data availability.
- Timetable quality.
- Realtime availability.
- Auth/key feasibility.
- Licensing and attribution clarity.
- Swift/client implementation complexity.
- Fit with Trainy's current route/card/search model.
- Geographic diversity.
- Ability to keep a graceful fallback.

### Top 10 Provider Dossiers

#### 1. Taiwan TDX: THSR, Taiwan Railway, Metro Rail

Why it belongs: best post-Japan strategic fit. It covers Taiwan rail with official APIs, timetable/status value, high-speed rail relevance, and an ODPT-like REST shape.

Sources:

- TDX portal: https://tdx.transportdata.tw/
- TDX rail OpenAPI example: https://tdx.transportdata.tw/webapi/File/Swagger/V3/268fc230-2e04-471b-a728-a726167c1cfc

Data:

- THSR timetable, stations, seats/fares, alerts.
- Taiwan Railway schedules and live-board style endpoints.
- Metro rail endpoints depending on operator/source.

Auth:

- TDX membership with client ID/secret.
- OAuth/client-credentials style flow.
- Guest/basic usage is too limited for production.

Licensing/terms:

- Attribution required.
- Some datasets may require additional approval.

Implementation notes:

- Build behind a backend token proxy.
- Start with THSR timetable/search and Taiwan Railway station board.
- Normalize Chinese/English names and Asia/Taipei time zone.

Risks:

- Key management.
- Mixed endpoint maturity by rail mode.
- Some live semantics differ from Trainy's current trip-card model.

#### 2. Hong Kong MTR via DATA.GOV.HK

Why it belongs: fastest official live rail win. Simple JSON, no key found in official dataset page, high rider density, and clear next-train behavior.

Sources:

- MTR next train dataset: https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data
- DATA.GOV.HK terms: https://data.gov.hk/en/terms-and-conditions

Data:

- Next four train arrivals for major MTR lines.
- Updated frequently by station/line.
- Station and line dictionaries available through MTR open data.

Auth:

- No key or quota found in the official dataset page during research.

Licensing/terms:

- DATA.GOV.HK permits reuse with attribution and disclaimer obligations.

Implementation notes:

- Good first "live board" adapter.
- Map station/line codes to normalized `Station` and `Route`.
- Represent it as station-board realtime, not full journey planning.

Risks:

- Not a full timetable feed.
- Urban metro semantics differ from intercity Shinkansen trips.

#### 3. Deutsche Bahn Timetables/RIS

Why it belongs: high-value European rail market with official APIs, station-board utility, disruption data, and manageable REST endpoints.

Sources:

- DB API Marketplace: https://developers.deutschebahn.com/db-api-marketplace/apis/
- DB product catalog/RIS APIs: https://developers.deutschebahn.com/db-api-marketplace/apis/product
- DB getting started: https://developers.deutschebahn.com/db-api-marketplace/apis/start
- DB marketplace terms: https://developers.deutschebahn.com/db-api-marketplace/apis/nutzungsbedingungen

Data:

- Timetable slices, current deviations, station boards, journeys, disruptions, stations, connections, and vehicle composition through RIS-family products.

Auth:

- DB Marketplace registration.
- `DB-Client-Id` and `DB-Api-Key` headers for many APIs.

Licensing/terms:

- Product-specific license; subagent research found Timetables API under CC BY 4.0.
- Marketplace terms require registration and separate license compliance.

Implementation notes:

- Start with station board/departure detail, not full journey planning.
- Use backend proxy for API key.
- Add German station ID mapping and Europe/Berlin time zone handling.

Risks:

- Rate limits and license vary by product.
- API catalog changes and German-only docs in places.

#### 4. Switzerland opentransportdata.swiss / OJP

Why it belongs: excellent official nationwide data stack with rail, station boards, journey planning, GTFS, GTFS-RT, SIRI, NeTEx/HRDF, and clear data-cookbook detail.

Sources:

- Swiss open transport platform: https://opentransportdata.swiss/en/
- Swiss GTFS cookbook: https://opentransportdata.swiss/en/cookbook/gtfs/
- API manager: https://api-manager.opentransportdata.swiss/

Data:

- GTFS static for Swiss public transport.
- GTFS-RT delays/alerts.
- SIRI/OJP interfaces for realtime and trip planning.
- Countrywide rail coverage including SBB and other operators.

Auth:

- Bearer API key for managed interfaces.
- Subagent research found OJP free-tier limits and GTFS-RT request limits.

Licensing/terms:

- Requires source citation and regular updates of raw data.
- Dataset-specific rules must be checked before app release.

Implementation notes:

- Treat as a server-side normalization candidate because OJP/SIRI XML is heavier than the current app should parse directly.
- Start with a cached station-board or Zurich-Bern/Geneva sample flow.

Risks:

- XML complexity.
- Large feeds and update cadence.
- Attribution and freshness obligations.

#### 5. UK National Rail / Network Rail / Darwin

Why it belongs: GB-wide rail status is strategically important, with official realtime/timetable feeds and strong rider value.

Sources:

- National Rail developer Darwin feeds: https://www.nationalrail.co.uk/developers/darwin-data-feeds/
- Network Rail open data feeds: https://www.networkrail.co.uk/who-we-are/transparency-and-ethics/transparency/open-data-feeds/
- Network Rail data feed licence: https://www.networkrail.co.uk/who-we-are/transparency-and-ethics/transparency/open-data-feeds/network-rail-infrastructure-limited-data-feeds-licence/
- Rail Data Marketplace: https://www.raildata.org.uk/
- National Rail Data Portal: https://opendata.nationalrail.co.uk/

Data:

- Darwin predictions, platforms, delays, schedule changes, cancellations, timetable/push feeds.
- Network Rail operational feeds and reference/timetable data.

Auth:

- Account/subscription access through current GB rail data portals.
- Some products may be free; some API usage may have charges or limits.

Licensing/terms:

- Attribution and branding restrictions.
- Do not call Trainy "official" or use protected branding without approval.

Implementation notes:

- Backend-first. The direct feed shape is not a simple mobile REST API.
- Start with station boards and disruption messages.
- Keep UI language as "National Rail/Network Rail data source" only where license allows.

Risks:

- Access portal transition/history between NRDP and Rail Data Marketplace.
- Feed complexity and no mobile-client-friendly shape.
- Branding restrictions.

#### 6. Transport for NSW

Why it belongs: best Oceania anchor with complete GTFS plus realtime trip updates and vehicle positions for Sydney/NSW rail networks.

Sources:

- Complete GTFS: https://opendata.transport.nsw.gov.au/dataset/timetables-complete-gtfs
- Realtime trip updates: https://opendata.transport.nsw.gov.au/dataset/public-transport-realtime-trip-update-v2
- Realtime vehicle positions: https://opendata.transport.nsw.gov.au/dataset/public-transport-realtime-vehicle-positions-v2
- API key guide: https://opendata.transport.nsw.gov.au/developers/userguide
- Data licence: https://opendata.transport.nsw.gov.au/datalicence

Data:

- GTFS static schedules.
- GTFS-RT trip updates and vehicle positions.
- Regional/intercity and metropolitan coverage depending on feed.

Auth:

- API key, usually sent as `Authorization: apikey TOKEN`.

Licensing/terms:

- CC BY 4.0 by default, plus TfNSW terms/acceptable use.

Implementation notes:

- Build a reusable GTFS static + GTFS-RT parser before this.
- Start with Sydney Trains station-board flow and one intercity route.
- Cache static GTFS, fetch realtime overlays.

Risks:

- Large static feed.
- Daily-changing IDs and GTFS-RT reconciliation.
- Provider-specific quirks.

#### 7. MTA LIRR + Metro-North

Why it belongs: high-value North American commuter rail market with official GTFS/GTFS-RT feeds.

Sources:

- MTA Developer Portal: https://api.mta.info/
- MTA terms: https://new.mta.info/developers/terms-and-conditions
- LIRR realtime feed: https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/lirr%2Fgtfs-lirr
- Metro-North realtime feed: https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/mnr%2Fgtfs-mnr

Data:

- GTFS static schedules.
- GTFS-RT for LIRR and Metro-North.
- Alerts through MTA sources.

Auth:

- MTA access key flow exists.
- Numeric public rate limit was not confirmed in accessible official text.

Licensing/terms:

- MTA Data Feed Agreement/terms apply.
- Keys can be deactivated for violations.

Implementation notes:

- Implement after GTFS/GTFS-RT foundation.
- Use for commuter-rail trip cards, not subway-first product positioning.
- Normalize America/New_York time zone and route branch names.

Risks:

- Feed docs are less tidy than MBTA.
- GTFS-RT reconciliation and branch naming.

#### 8. Netherlands NS API

Why it belongs: strong national rail operator with an official API portal and clear key/subscription flow. Good compact European provider after the abstraction is ready.

Sources:

- NS API portal: https://apiportal.ns.nl/
- NS starter guide: https://apiportal.ns.nl/startersguide
- NS APIs list: https://apiportal.ns.nl/apis

Data:

- NS states that it has data such as timetables, works, and station information.
- Detailed API docs require login.

Auth:

- Account registration required.
- Product subscription key sent with each request.
- Some subscriptions may require approval.

Licensing/terms:

- Product-specific conditions may apply; must be accepted in the portal before use.

Implementation notes:

- Good candidate once Trainy has provider credential status.
- Start with station departures and disruptions.
- Keep Dutch/English localization and Europe/Amsterdam time zone support.

Risks:

- API detail hidden until login.
- Approval and terms vary by product.

#### 9. South Korea TAGO + Seoul TOPIS

Why it belongs: strong Asia rail value if treated as two adapters: intercity/KTX timetable through TAGO and Seoul subway realtime through TOPIS.

Sources:

- TAGO/data.go.kr train API: https://www.data.go.kr/data/15098552/openapi.do
- Seoul subway realtime arrival: https://data.seoul.go.kr/dataList/OA-12764/F/1/datasetView.do
- Seoul subway train position: https://data.seoul.go.kr/dataList/OA-12601/A/1/datasetView.do
- Seoul data use guide: https://data.seoul.go.kr/together/guide/useGuide.do

Data:

- TAGO train timetable/departure-arrival data.
- Seoul subway realtime arrivals and train positions.

Auth:

- data.go.kr service key.
- Seoul Open Data key.
- Subagent research found documented development/day limits.

Licensing/terms:

- TAGO subagent finding: unrestricted use in checked source.
- Seoul data allows attribution/commercial modification under its open-data terms.

Implementation notes:

- Medium-high complexity because this is multiple agencies and data models.
- Start with KTX timetable city-pair search, then Seoul station realtime.
- Add Korean station-name normalization and bilingual display.

Risks:

- Encoding/language.
- Multiple keys and quota models.
- Realtime latency warnings.

#### 10. France SNCF + transport.data.gouv.fr

Why it belongs: France is a must-have rail market, but implementation should be backend-first because the source landscape is a catalog of datasets rather than one simple API.

Sources:

- SNCF Open Data: https://data.sncf.com/
- SNCF API console: https://data.sncf.com/api/explore/v2.1/console
- SNCF ODbL/licence page: https://data.sncf.com/pages/licence/
- France national access point: https://transport.data.gouv.fr/

Data:

- GTFS, GTFS-RT, NeTEx, SIRI, JSON/CSV vary by producer.
- SNCF datasets and API access through OpenDataSoft-backed portal.

Auth:

- Catalog API availability varies.
- Dataset/API-specific access must be verified before implementation.

Licensing/terms:

- Commonly Licence Ouverte or ODbL, but dataset-specific.
- SNCF portal links ODbL/FAQ material.

Implementation notes:

- Start with one specific SNCF-supported GTFS/GTFS-RT dataset, not all France.
- Backend should ingest, validate, and expose compact JSON for Trainy.

Risks:

- Dataset fragmentation.
- License differences.
- Heavy feeds and multiple formats.

## Watchlist And Exclusions

### Existing Anchor: Japan ODPT/Shinkansen

Keep and harden. ODPT is already wired through `ODPT_CONSUMER_KEY`, `Info.plist`, `scripts/build-ios.sh`, and `scripts/smoke-odpt.sh`. The starter catalog remains mandatory fallback.

Source:

- ODPT developer portal: https://developer.odpt.org/

### Norway Entur

Very strong clean-API pilot, even if smaller than the top-10 markets. Consider substituting it for a riskier provider if the team needs a fast European success.

Sources:

- Entur developer portal: https://developer.entur.org/
- Entur realtime intro: https://developer.entur.org/pages-real-time-intro
- Entur Journey Planner: https://developer.entur.org/pages-journeyplanner-journeyplanner

### MBTA

Excellent North American pilot because the API is clean JSON and developer-friendly. It is slightly less globally strategic than MTA LIRR/Metro-North, but likely easier.

Sources:

- MBTA V3 API: https://www.mbta.com/developers/v3-api
- MBTA GTFS: https://www.mbta.com/developers/gtfs

### Public Transport Victoria

Strong second Oceania provider after TfNSW.

Sources:

- PTV Timetable API Swagger: https://timetableapi.ptv.vic.gov.au/swagger/docs/v3
- PTV API dataset: https://discover.data.vic.gov.au/dataset/ptv-timetable-api
- Victoria GTFS schedule: https://discover.data.vic.gov.au/dataset/gtfs-schedule

### Singapore LTA DataMall

Good alerts/crowding support layer, but not a full train timetable/arrival source for Trainy's core card model.

Sources:

- LTA dynamic data: https://datamall.lta.gov.sg/content/datamall/en/dynamic-data.html
- LTA API terms: https://datamall.lta.gov.sg/content/datamall/en/api-terms-of-service.html

### Indian Railways NTES/CRIS

Business top-10, engineering hold. Official public UI exists, but no public official developer API/feed was verified.

Source:

- NTES: https://enquiry.indianrail.gov.in/mntes/

### China Railway 12306

Business top-10, engineering hold. Official ticketing/search UI exists, but no public official developer API/feed was verified.

Sources:

- 12306 English site: https://www.12306.cn/en/index.html
- 12306 left-ticket search: https://www.12306.cn/en/left-ticket.html

## Technical Architecture

### Target Provider Layer

Add a provider architecture under `TrainyIOS/Trainy/Providers/`:

- `TrainProvider`: identity, display name, supported regions, capabilities, auth strategy, attribution, and data scope.
- `ScheduleFeedProvider`: routes, stations, scheduled trips, station departures.
- `RealtimeFeedProvider`: trip updates, vehicle positions, alerts, platform changes.
- `JourneyPlanningProvider`: optional point-to-point plans.
- `ProviderRegistry`: available providers, selected region, feature gating.
- `ProviderCredentialStore`: developer/local credentials and production proxy config.
- `ProviderHealth`: configured, unauthenticated, rate limited, offline, stale, unsupported.

Capabilities should include:

- routes
- stations
- stationDepartures
- scheduleTrips
- realtimeTripUpdates
- vehiclePositions
- alerts
- platforms
- facilities
- fares
- journeyPlanning
- seatOrCarPosition

Formats should include:

- odpt
- officialHtml
- gtfsSchedule
- gtfsRealtime
- netex
- siri
- darwin
- dbApi
- restJson
- graphql

### Normalized Model Layer

Add normalized ingestion models before UI card conversion:

- `RailProviderID`
- `RailRegion`
- `RailSource`
- `SourceAttribution`
- `LicenseNotice`
- `RailStation`
- `RailRoute`
- `RailStopTime`
- `ScheduledRailTrip`
- `RealtimeTripOverlay`
- `RailVehiclePosition`
- `RailServiceAlert`
- `RailFacilityStatus`
- `RailBoardEntry`
- `RailTripCandidate`

Then map to existing `TrainTrip` through `TrainTripMapper`.

This keeps `TrainTrip` as a UI surface while allowing provider-specific ingestion to evolve.

### ODPT Migration Path

Do not delete `ShinkansenTrainProvider`. Instead:

1. Wrap it behind `TrainProvider`.
2. Move ODPT client code into `Providers/ODPT/ODPTClient.swift`.
3. Move JR East HTML parsing into `Providers/JREast/JREastTimetableClient.swift`.
4. Move curated starter data into `Providers/Shinkansen/ShinkansenStarterCatalog.swift`.
5. Keep `providerID = "shinkansen"` and `dataScope = "japan-shinkansen-v2"` until a migration is needed.
6. Preserve existing persisted trip decoding.

### Secret Strategy

Development:

- Keep `TrainyIOS/Config/odpt.env` for local ODPT smoke.
- Add `TrainyIOS/Config/providers.env.example` for future local keys, but do not execute arbitrary env files.

Production:

- Do not ship provider API keys in the iOS app.
- Use a thin server/proxy for secret-bearing providers: ODPT, TDX, DB, NS, TfNSW, MTA, South Korea, and possibly Switzerland.
- Cache static feeds server-side.
- Expose compact Trainy JSON to the app.
- Log provider health without storing personal journey data.

### Backend Threshold

Build direct-to-app only when all are true:

- No secret key required, or key is safe for public client use.
- Terms allow public client calls.
- Payload is small enough for mobile.
- Source format is JSON or compact protobuf.
- No heavy static feed joins are required.

Use backend normalization when any are true:

- API secret must be protected.
- Feed is large GTFS/NeTEx/SIRI/XML.
- Terms require controlled access.
- App needs caching, quota protection, or cross-feed joins.

## Data Normalization Plan

### Common Concepts

Trainy should normalize to:

- Provider: official source, auth strategy, source links, attribution, license.
- Region: country/metro/time zone/language/currency.
- Station: name, localized names, codes, parent station, platform/track hints, coordinates.
- Route: public name, mode, operator, color, origin/destination families.
- Scheduled trip: provider trip ID, train number/name, service day, stop times, platform, operating calendar.
- Realtime overlay: delay, prediction, cancellation, platform change, vehicle position, last update.
- Alert: affected routes/stations/trips, severity, cause/effect, multilingual text, active period.
- Facility: elevator/escalator/accessibility status where provider supports it.

### Provenance Labels

Use these labels throughout the UI:

- confirmed: official source directly states the value.
- estimated: provider prediction or Trainy computed value from official data.
- inferred: Trainy derived value from schedule/catalog matching.
- unknown: unavailable or not supported by the provider.

Examples:

- Platform from ODPT or JR timetable: confirmed.
- ETA from GTFS-RT trip update: estimated.
- Best car from starter catalog: inferred.
- Vehicle speed from a schedule-only provider: unknown.

### Freshness

Every provider response should carry:

- fetchedAt
- sourcePublishedAt when available
- feedVersion when available
- validFrom/validUntil for schedules
- freshnessState: fresh, aging, stale, expired, unknown
- refreshPolicy: userRefresh, backgroundRefresh, staticFeedRefresh

### Localization

Normalize:

- Time zones per provider/region.
- 12/24-hour user preference.
- Distance/speed units.
- Localized station/operator names.
- Script variants for Japanese, Chinese, Korean, and Romanized names.
- Provider-specific station codes.

## Product UX Plan

### First Run

Default story:

- Start with "Japan Shinkansen" selected.
- Show one compact data note: "Trainy uses official timetable feeds where configured and starter data when live access is unavailable."
- Offer "Search Shinkansen" and "Explore other regions."

### Provider And Region Selection

Add a Region section:

- Japan Shinkansen
- Taiwan
- Hong Kong
- Germany
- Switzerland
- United Kingdom
- Australia/NSW
- New York commuter rail
- Netherlands
- South Korea
- France

Each row shows:

- available now, in beta, needs key, or planned.
- schedule/realtime/alerts capability chips.
- last provider health.

### Search

Search should route by selected region first, then global matches later.

States:

- Suggested services from curated catalog.
- Matching official timetable trips.
- Matching realtime station board.
- Provider not configured.
- Realtime unavailable, showing schedule.
- No matching trains.

### Trip Cards

Add source/freshness display:

- "ODPT timetable - updated 09:12"
- "Starter catalog - not live"
- "GTFS-RT prediction - 45s ago"
- "Provider unavailable - saved 2h ago"

### Detail

Add source detail sheet:

- Provider.
- Feed.
- License/attribution.
- Last updated.
- What is confirmed vs estimated/inferred.
- Link to provider source docs.

### Empty/Error Copy

Recommended copy examples:

- Missing key: "Official data is not configured for this provider in this build. Showing saved or starter journeys where available."
- Quota: "The provider is rate limited right now. Saved journeys are still available."
- Schedule-only: "This provider gives timetable data, not live train location."
- Realtime unavailable: "Realtime updates are unavailable. Times below are scheduled."

## Test And Verification Plan

### Current Gates

Keep:

- `node --check app.js`
- `bash -n scripts/build-ios.sh`
- `bash -n scripts/smoke-odpt.sh`
- `bash -n scripts/lib/odpt-env.sh`
- `scripts/build-ios.sh`
- `scripts/smoke-odpt.sh` after setting an ODPT key

### Add Unit Tests

Target: `TrainyTests`

Coverage:

- `TrainyAPIConfig.cleanODPTKey`.
- ODPT route matching.
- Station normalization.
- Time parsing across midnight.
- `TrainStore` persistence migration by data scope.
- Fallback selection when provider is unavailable.
- Source provenance mapping.
- Provider error to user message mapping.

### Add Fixture Tests

Fixtures:

- ODPT timetable JSON.
- ODPT train information JSON.
- JR East timetable HTML.
- GTFS static minimal feed.
- GTFS-RT trip update protobuf.
- TDX station board JSON.
- MTR next train JSON.
- DB timetable response.

Done criteria:

- Tests pass without network.
- Fixture source metadata is documented.
- Each fixture has at least one expected `TrainTrip` or normalized model output.

### Add Authenticated Smoke Tests

Each secret-bearing provider should get a smoke script that:

- Loads only allowed keys from a provider-specific env file.
- Prints no secret.
- Verifies one known station/route query.
- Requires source-backed data, not starter data.
- Exits with clear code for missing credential.

### Add UI Smoke

Use XCTest UI or a lightweight simulator smoke:

- First-run opens with Japan selected.
- Search for "Tokyo to Shin-Osaka" shows a source badge.
- Missing provider credentials show provider unavailable copy.
- Offline saved trip still opens detail.
- Settings provider list renders without overlap.

## Sequenced Milestones

### 0-30 Days: Polish And Provider Foundation

Outcome: Trainy becomes trustworthy and testable before global expansion.

Tickets:

1. Add `SourceProvenance`, `FreshnessState`, and `ConfidenceLevel`.
   - Dependencies: none.
   - Done: cards/detail/search show source and freshness without changing ODPT behavior.

2. Create provider protocols and wrap `ShinkansenTrainProvider`.
   - Dependencies: source model.
   - Done: `TrainStore` depends on protocol/registry; ODPT and starter catalog still work.

3. Split provider file.
   - Dependencies: protocol wrapper.
   - Done: ODPT client, JR East client, starter catalog, mapper, and provider registry are separate.

4. Add unit/fixture test target.
   - Dependencies: provider helpers made testable.
   - Done: local test command covers route matching, fallback, source labels, and ODPT fixtures.

5. Wire real settings for units/time/source verbosity.
   - Dependencies: settings store.
   - Done: toggles either work or are converted to info rows.

6. Add provider/region settings UI.
   - Dependencies: provider registry.
   - Done: Japan appears as active; planned providers appear disabled with accurate requirements.

### 31-60 Days: First New Provider And Shared Feed Stack

Outcome: one new official provider ships behind the new architecture, while shared feed work begins.

Recommended first provider: Taiwan TDX.

Parallel implementation tracks:

1. TDX credential/proxy spike.
   - Dependencies: backend/proxy decision.
   - Done: app can query a compact Trainy JSON endpoint without storing TDX secret.

2. TDX rail adapter.
   - Dependencies: normalized models.
   - Done: THSR timetable and one Taiwan Railway station board map to `TrainTrip` or `RailBoardEntry`.

3. Hong Kong MTR quick live-board adapter.
   - Dependencies: provider registry.
   - Done: no-secret station next-train board renders with source label.

4. GTFS static parser foundation.
   - Dependencies: normalized models.
   - Done: minimal fixture feed produces stations/routes/trips.

5. GTFS-RT parser foundation.
   - Dependencies: SwiftProtobuf or server-side parser decision.
   - Done: fixture trip update overlays a scheduled trip.

### 61-90 Days: Scale To Top-10 Batch

Outcome: Trainy can add provider integrations repeatedly with a known checklist.

Batch sequence:

1. Deutsche Bahn station boards.
2. Switzerland station board or OJP trip-info slice.
3. Transport for NSW GTFS + GTFS-RT slice.
4. MTA LIRR/Metro-North GTFS-RT slice.
5. UK National Rail/Darwin backend spike.
6. NS departures/disruptions after portal access.
7. South Korea TAGO/TOPIS after key setup.
8. France one SNCF-backed dataset through backend ingestion.

Done criteria for each provider:

- Source links and license/attribution in docs.
- Credential path documented.
- Offline fixture.
- One live smoke path if credentials exist.
- Clear unsupported-data copy.
- Source badges visible in UI.
- No production key in app binary.

## Engineering Ticket Backlog

| Ticket | Scope | Dependencies | Done Criteria |
| --- | --- | --- | --- |
| Provider protocol extraction | `TrainProvider`, `ScheduleFeedProvider`, `RealtimeFeedProvider` | none | `TrainStore` no longer requires concrete `ShinkansenTrainProvider` |
| Source provenance model | structured source/freshness/confidence | none | every trip has source label and decode compatibility |
| ODPT adapter split | move ODPT client/decoders | protocol extraction | ODPT smoke still passes with key |
| Starter catalog split | move curated Shinkansen data | protocol extraction | no-key app still shows starter trips |
| JR East HTML fixture tests | isolate brittle HTML parser | test target | parser covered by checked-in HTML fixture |
| Provider registry UI | region/provider list | provider registry | Japan active, planned providers disabled with requirements |
| Key-safe proxy decision | choose Cloudflare/Vercel/local dev proxy | provider auth model | secrets not shipped in release build |
| GTFS parser | static schedule import | normalized models | minimal feed fixture produces trips |
| GTFS-RT parser | trip updates/alerts/vehicles | GTFS parser | protobuf fixture overlays schedule |
| TDX provider | first global provider | proxy + normalized models | Taiwan sample search returns official source-backed cards |
| MTR provider | quick live-board provider | normalized board model | Hong Kong station next-train board renders |
| Provider smoke framework | scripts for credentialed checks | provider registry | missing key exits 2, live pass exits 0 |
| UI source labels | card/detail/search components | source model | no trip card lacks source/freshness |
| Settings cleanup | wire or demote unimplemented controls | settings store | no misleading settings remain |

## Final Recommendation

Add Taiwan TDX first after ODPT as the strategic provider, because it is geographically adjacent to the current Japan focus, has high-speed and conventional rail value, and maps closely to Trainy's existing official-API-plus-fallback architecture.

Smallest safe implementation slice:

1. Add provider protocols and source provenance.
2. Keep `ShinkansenTrainProvider` working through the new registry.
3. Add a backend/proxy stub for TDX OAuth credentials.
4. Implement one TDX THSR timetable search and one Taiwan Railway station-board query.
5. Render those as source-labeled `TrainTrip`/station-board results.
6. Add fixtures and an authenticated smoke that exits clearly when TDX credentials are missing.

Fastest visible live-data bonus after that: Hong Kong MTR next-train board, because it is simple JSON and can prove the provider registry UI without a heavy static-feed pipeline.
