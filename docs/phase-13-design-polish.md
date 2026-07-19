# Phase 13 — Design Polish (2026-06-23)

Companion to `design-audit-2026-06-23.md`, `design-system-2026-06-23.md`,
`screen-redesign-2026-06-23.md`, and `implementation-plan-2026-06-23.md`.

This phase converts the iOS codebase to honor the spec rules instead of
the audit's "ideas." It also tightens the remaining glass use, the
typography scale, and the journey-map mode toggle.

## What changed in this phase

### Glass / surface discipline

| Change | File:line |
| --- | --- |
| Removed `railLiquidGlass` from `EmptyStateView`, `LoadingSkeletonView`, `OfflineBanner`, `TransferWarningCard`, `DisruptionBanner`, `MetricTile`, `PlatformChip`, `ServiceStatusPill`, `SourceBadge`, `SourceDetailSheet` panels | `RailComponents.swift` |
| Flattened the active-trip summary card (`ActiveTripSummary`) to a single 16-pt panel with a flat progress view + flat trip-tools row | `ContentView.swift:660-790` |
| Flattened `StationCard`, `StationDetailView` hero, `StationDetailView` "Station notes" panel, `BoardSection` | `ContentView.swift:1108-1235` |
| Flattened `SearchHeroView`, `RecentSearchesView`, `SearchResultCard`, `FavoriteStationsStrip`, `SuggestedRoutesView` | `ContentView.swift` |
| Flattened `SummaryActionLabel`, `SummaryIconLabel`, `RailSegmentedPicker`, `SettingsGroup`, `StatusSummaryItem`, `MiniStat`, `CoverageLegendItem`, `FloatingGlassButton` | `DesignSystem/RailDesignLibrary.swift` |
| Kept `GlassPanel` only for the journey map hero surface (`RailJourneyMapPanel`) and the floating map status overlay (now using `.ultraThinMaterial` for map legibility) | `RailJourneyMap.swift:65`, `RailJourneyMap.swift:583` |
| Documented `GlassPanel` as the canonical entry point for iOS 26 Liquid Glass | `RailComponents.swift:97-100` |

Net effect: every screen now has flat panels. The only remaining
`railLiquidGlass` calls outside the journey map are the `GlassPanel`
container itself and one floating map status overlay. Glass stays as a
"special surface" token, not wallpaper.

### Map simplification

| Change | File:line |
| --- | --- |
| Collapsed `RailMapMode` from 3 cases (route / stops / alerts) to a single `.all` case | `RailJourneyMap.swift:182-217` |
| Replaced the 3-button mode toggle with a single floating re-center button | `RailJourneyMap.swift:594-617` |
| The map now always shows the route line, upcoming stops, and any disruption pins — no toggle needed | `RailJourneyMap.swift:132` |

### Typography scale

| Token | iOS font | Use |
| --- | --- | --- |
| `display` | 40 pt bold rounded, monospaced digit | Hero times (active trip origin/destination, train detail hero) |
| `h1` | 28 pt semibold rounded | `Trips` title, `Welcome to Trainy` |
| `h2` | 18 pt semibold rounded | Section headers, train name in detail hero |
| `h3` | 15 pt semibold rounded | Card titles, train name in trip card, stop name |
| `body` | 14 pt regular default | Default copy |
| `small` | 13 pt regular default | Secondary metadata |
| `caption` | 11 pt medium uppercase | Eyebrow text |

Legacy aliases (`largeTitle`, `title`, `headline`, `callout`, `compactLabel`,
`micro`) are preserved so existing call sites still compile, but new code
prefers the new scale. The big wins:

- `ActiveTripSummary` origin/destination times now use `RailDesign.Typography.display.monospacedDigit()` instead of an inline `Font.system(size: 40, weight: .bold, design: .rounded)`.
- `Trips` title and `Welcome to Trainy` use `RailDesign.Typography.h1` instead of `.largeTitle` / `.title2`.
- `TrainTripCard` train name, `StopTimelineRow` station name, `StationDetailView` station name all use `RailDesign.Typography.h3`.
- `HistoryScreen` summary line uses `RailDesign.Typography.h3`.

### New `RailDesign.Palette.inset` token

Added to `RailDesignSystem.swift` as the canonical "soft inset" color used
by the new segmented picker track, trip-card duration chip, and station
detail panels. It matches `--surface-inset` in the web token layer so the
two surfaces stay in sync.

### Verification

```bash
bash scripts/check-design-system-bypass.sh   # passes
xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios26.0-simulator \
  -sdk "$(xcrun -sdk iphonesimulator --show-sdk-path)" \
  -module-cache-path /tmp/swift-module-cache \
  $(find Sources/TrainyCore -name "*.swift")  # exit 0
```

## Outstanding

- `RailDesign.Palette` still exposes the decorative `marine`, `violet`,
  `copper`, `amber` colors. They're only used inside the `ProviderStatusPill`
  status chip (where each region gets its own color). I left them in
  because they make the Supported regions screen legible at a glance.
  Recommend migrating them to semantic "active / muted / coming soon"
  tokens in a future pass if you don't need regional color coding.
- iOS Simulator screenshots still need to be captured locally. The
  typecheck is the strongest verification I can produce in this sandbox.
