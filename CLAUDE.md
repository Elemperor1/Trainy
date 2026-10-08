# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Trainy is a Flighty-style train tracking app scoped first to Japan Shinkansen journeys, with a browser prototype and native SwiftUI iOS app. The architecture follows a modular provider pattern with source provenance tracking.

## Architecture

### Core Components

**TrainStore** (`Sources/TrainyCore/TrainStore.swift`) - The central state manager:

- Owns tracked trips, selected trip, search query/filter, live routes/results, load state
- Persists to UserDefaults with data-scope migration support
- Depends on `ProviderRegistry` for provider abstraction

**Provider System** (`Sources/TrainyCore/Providers/`):

- `TrainProvider` protocol - Base provider interface with identity, capabilities, availability
- `ScheduleFeedProvider` - Routes, stations, scheduled trips
- `RealtimeFeedProvider` - Trip updates, vehicle positions, alerts
- `ProviderRegistry` - Registry of active and planned providers with capabilities-based filtering
- Capabilities: `.schedule`, `.realtimeTripUpdates`, `.serviceAlerts`, `.stationBoard`, `.journeyPlanning`, `.vehiclePositions`

**ShinkansenTrainProvider** - Primary provider implementation:

- Attempts ODPT API when `ODPT_CONSUMER_KEY` is configured; ODPT is not expected to publish Shinkansen timetables (see `docs/japan-data-decision-record.md`), so a configured build reports no live trips instead of substituting starter data
- Uses the curated starter catalog without a key
- The JR East HTML scraper was removed; the planned live path is the Worker's `/v1/japan/*` timetable routes (`provider-proxy/src/japan/`), which are built but switched off until a source licence is declared. The Swift provider does not call them yet
- Implements both `ScheduleFeedProvider` and `RealtimeFeedProvider`

**NSTrainProvider** - Station-board provider implementation:

- Calls only Trainy's normalized provider proxy; never the NS upstream API
- Implements station search, departure boards, and service alerts
- Is rider-available only when a validated proxy base URL is configured
- Preserves truthful source and stale/fresh metadata from the proxy

**Models** (`Sources/TrainyCore/TrainModels.swift`):

- `TrainTrip` - Main UI model with `SourceProvenance` tracking
- `SourceProvenance` - Structured source metadata (provider, kind, confidence, freshness)
- `SourceKind` - `.starterCatalog`, `.officialTimetable`, `.realtimePrediction`, `.vehiclePosition`, `.alertFeed`, `.inferred`
- `FreshnessState` - `.fresh`, `.stale`, `.expired`, `.unknown`
- `FactProvenance` - Per-field confidence tracking for schedule, platform, route, etc.

**Normalized Models** (`Sources/TrainyCore/RailNormalizedModels.swift`):

- `RailProviderID`, `RailRegion`, `RailSource`, `RailStation`, `RailRoute`
- `ScheduledRailTrip`, `RealtimeTripOverlay`, `RailVehiclePosition`, `RailServiceAlert`
- `RailBoardEntry`, `RailTripCandidate` - Foundation for global provider expansion

**ContentView** (`Sources/TrainyCore/ContentView.swift`) and **Screens** (`Sources/TrainyCore/Screens/`):

- Five-tab SwiftUI interface: Trips, Search, Stations, History, Settings
- `ContentView.swift` is only the root: the tab shell, first-run sheet routing, and the persisted interface preferences it injects
- Each tab has its own folder under `Screens/`, next to `FirstRun/`, `TrainDetail/`, and `Support/` (presentation-only `TrainStore` and `TrainTrip` extensions shared by several screens)
- Uses `RailDesign` system for styling (see `RailDesignSystem.swift`)

### Provider Directory Structure

```
Providers/
├── TrainProvider.swift          # Protocol definitions
├── ProviderRegistry.swift       # Provider catalog and capability model
├── ProviderCapabilities.swift   # ProviderCapability, ProviderAvailability, ProviderAuthStrategy, ProviderRequirement
├── ProviderErrors.swift         # TrainDataProviderError
├── ProviderTextUtilities.swift  # Text utilities
├── ODPT/
│   ├── ODPTClient.swift           # ODPT API client
│   └── ODPTModels.swift           # ODPT JSON models
├── Shinkansen/
│   ├── ShinkansenTrainProvider.swift        # Main provider composition
│   ├── ShinkansenRouteCatalog.swift         # Route metadata and coordinates
│   ├── ShinkansenStarterCatalog.swift       # Curated fallback trips
│   └── ShinkansenTrainTripMapper.swift        # Trip mapping and conversion
└── NS/
    ├── NSClient.swift                         # Credential-free proxy client
    ├── NSModels.swift                         # Normalized proxy response models
    ├── NSRiderViewModels.swift                # Search/board state machines
    └── NSTrainProvider.swift                  # NS provider adapter
```

## Development Commands

### Build

```bash
# Inspect the SwiftPM package
swift package describe

# Build the SwiftPM library for iOS Simulator
SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
swift build --triple arm64-apple-ios26.0-simulator --sdk "$SDKROOT"
swift build --build-tests --triple arm64-apple-ios26.0-simulator --sdk "$SDKROOT"

# Build the iOS app
scripts/build-ios.sh

# Requires Xcode 26.5+ configured at /Applications/Xcode-26.5.0.app
# For sandbox environments: DEVELOPER_DIR and ODPT_ENV_FILE can be overridden
```

### Smoke Tests

```bash
# Verify ODPT integration (requires ODPT_CONSUMER_KEY configured)
scripts/smoke-odpt.sh

# Verify Shinkansen provider specifically
scripts/smoke-shinkansen-provider.sh

# Verify provider registry
scripts/smoke-provider-registry.sh

# Verify source provenance
scripts/smoke-source-provenance.sh

# Verify the credential-neutral Worker contract
npm run check --prefix provider-proxy

# Verify authorized live NS data through the local proxy
scripts/smoke-ns-proxy.sh

# Verify env parsing, loopback bounds, and effective build-secret detection
scripts/test-provider-smoke-pattern.sh
python3 scripts/test-provider-secret-boundary.py
```

### Configuration

```bash
# Set up ODPT credentials
cp TrainyIOS/Config/odpt.env.example TrainyIOS/Config/odpt.env
chmod 600 TrainyIOS/Config/odpt.env
# Edit TrainyIOS/Config/odpt.env with your key from https://developer.odpt.org/
```

### Static Checks

```bash
# JavaScript syntax check (browser prototype)
node --check app.js

# Shell syntax checks
bash -n scripts/build-ios.sh
bash -n scripts/smoke-odpt.sh
bash -n scripts/lib/odpt-env.sh
```

### Continuous Integration

GitHub Actions workflow at `.github/workflows/swift.yml`:

- Runs on push to main/master and pull requests
- Uses the macOS 26 runner and repository-pinned Xcode 26.5 toolchain with `CODE_SIGNING_ALLOWED=NO`
- Cancels superseded runs on the same branch or pull request
- Pins the Node 24 checkout action and setup-node to reviewed immutable commit SHAs, configures Node 24 for proxy gates, and keeps read-only contents permission with checkout credential persistence disabled
- Runs the credential-neutral Workerd contract/type/bundle gate
- Scans the built app for provider-secret values and NS upstream-only markers

The CodeQL workflow keeps full Swift analysis on main/master pushes and the weekly schedule. On pull requests, its expensive manual Xcode trace runs only when Swift, Xcode-project, package, workflow, or canonical build inputs changed; the stable `Analyze (swift)` check still reports success when the trace is intentionally skipped.

## Key Concepts

### Source Provenance

Every user-visible fact must carry provenance metadata indicating whether the data is confirmed (official source), estimated (prediction), inferred (catalog matching), or unknown. This is critical for trust transparency.

### Capability Model

Providers declare their capabilities; the UI adapts accordingly. A provider may support schedule but not realtime, or alerts but not station boards.

### Fallback Behavior

The Shinkansen provider demonstrates the pattern: ODPT live → starter catalog without a key. A configured build never silently substitutes starter data for missing live data. All providers should degrade gracefully and say plainly what source a fact came from.

### Provider Regions

Japan is the initial region; planned providers span Taiwan, Hong Kong, Germany, Switzerland, UK, Australia/NSW, US (MTA), Netherlands, South Korea, and France.

### Clock Seam and Stable Ids

`RailClock` (`Sources/TrainyCore/RailClock.swift`) is the one place Trainy reads the wall clock. Stores and providers take `clock: RailClock = .system` at their initializer, read `clock.now` once per operation (after any network response the result describes, not before the request), and pass the resulting `Date` into pure functions such as `ShinkansenTrainProvider.statusText(for:now:)` and `RailStopTime.state(at:)`. Tests pin time with `RailClock.fixed(_:)`. New time-dependent code should follow that shape instead of calling `Date()` inline. The NS view models keep their own `now` closure, which has the same shape.

`StationStop` and `TrainAlert` derive `id` from their content (`name|time`, and `title|detail|tone`), so identities survive decoding and refreshes. Persisted JSON does not carry an `id` key.

### Credential Safety

No production provider secret may ship in a distribution binary. The legacy ODPT developer path can inject a local development key, so CI and release-proof builds must set `ODPT_ENV_FILE=/dev/null` until ODPT also moves behind a production credential boundary. That boundary now exists in the Worker (`ODPT_CONSUMER_KEY` is a Worker secret, unset today and never sent to the app), but the app keeps the legacy path until the Swift provider calls `/v1/japan/*`. NS is stricter: `scripts/build-ios.sh` never loads `ns.env`, the app knows only an HTTPS proxy base URL, and `NS_SUBSCRIPTION_KEY` stays in Worker secret storage or the ignored mode-600 local smoke file.

## Data Flow

1. **Provider Selection** → `TrainStore` resolves provider via `ProviderRegistry`
2. **Search Query** → Provider's `fetchTrips(matching:knownRoutes:)` returns `[TrainTrip]`
3. **Trip Refresh** → Provider's `refresh(trip:knownRoutes:)` returns updated `TrainTrip?`
4. **Persistence** → `TrainStore` saves tracked trip IDs and full payloads to UserDefaults
5. **UI Rendering** → `TrainTrip` with `SourceProvenance` drives trip cards, detail views, and source badges

## Planned Provider Architecture

See `docs/global-provider-roadmap.md` for the full roadmap. Key principles:

- Preserve Japan/Shinkansen as flagship first-run experience
- Never overclaim live vehicle position for schedule-only sources
- Prefer official direct feeds; use aggregators only when licensed
- Put provenance on every user-visible fact
- No production secrets in app binary
