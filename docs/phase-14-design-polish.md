# Phase 14 — Interaction polish (2026-06-23)

Companion to `phase-13-design-polish.md`.

## What changed in this phase

### Interaction states

- New `PressableButtonStyle` in `DesignSystem/RailDesignLibrary.swift`.
  Applies `scale(0.96)` on press with `RailDesign.Motion.quick` (the make-interfaces-feel-better skill's
  recommended value of `0.96`). Honours the implicit `.animation(...)` so the press
  springs back smoothly. Wired into the Add Trip button, the trip-tools row
  (Refresh / Alerts / Share), the Open rail map CTA, and the rail-map re-center
  button. `Button(action:)` plus `PressableButtonStyle()` is the new idiom for
  custom interactive surfaces; `.buttonStyle(.plain)` is reserved for system-styled
  buttons (`.borderedProminent`, `.bordered`).

### Hit-target improvements

- Add Trip button: 48x48 → **44x44** (matches iOS HIG 44-pt minimum). Now has
  an `accessibilityHint`: "Search for a new train to track".
- Trip-tool icon buttons: now render through `TripToolButton`, a 64x72
  component with a 44x44 inset hit area and a 11-pt caption label. Each button
  has a context-aware `accessibilityLabel` ("Refresh trip", "Turn on/off alerts
  for Nozomi 231", "Share Nozomi 231").
- Recent-search list rows: now use `.contentShape(Rectangle())` on the full row
  and carry `accessibilityLabel("Search for Tokyo to Shin-Osaka")` instead of
  the bare glyph label.
- First-run Skip button: now has `frame(minHeight: 44)` and an
  `accessibilityHint`.

### Typography cleanup

- `RailJourneyMapStopCard` and `RailJourneyMapStopDetailCard` station names
  now use `RailDesign.Typography.h3` (was `.subheadline.weight(.bold)` / `.headline.weight(.bold)`).
- `RailJourneyMapStatusOverlay` "Next stop" label now uses the new
  `caption` token, the station name uses `h3`, and the platform/ETA meta line uses `small`.
- `RailJourneyMapStopRail` title uses `h3`.
- `Open rail map` CTA card uses `h3` for the title and `small` for the meta line.
- `SearchHeroView` scope text is now an uppercase caption; the description uses `small` and the ink color.
- Station detail hero favorite star icon font is `.headline.weight(.semibold)` instead of `.title3`.

### Loading shimmer

- `LoadingSkeletonView` now uses a real `LinearGradient` shimmer animation
  (1.4s linear infinite) on top of the placeholder row, layered with
  `blendMode(.plusLighter)`. Honors `accessibilityReduceMotion` by falling
  back to a static placeholder.
- `.task` modifier drives the animation so it stops when the view disappears.

### Accessibility

- `PressableButtonStyle` doesn't break VoiceOver: the underlying `Button`
  keeps its label, hint, and traits; the scale effect is purely visual.
- Removed orphan `SummaryIconLabel` (replaced by `TripToolButton`).

### Verification

```bash
bash scripts/check-design-system-bypass.sh   # passes
xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios26.0-simulator \
  -sdk "$(xcrun -sdk iphonesimulator --show-sdk-path)" \
  -module-cache-path /tmp/swift-module-cache \
  $(find Sources/TrainyCore -name "*.swift")  # exit 0
```

### Outstanding

- The `LinearGradient` shimmer is rendered through `blendMode(.plusLighter)`,
  which is supported on iOS 17+. We target iOS 26, so this is fine; older
  platforms will get a static placeholder.
- The Trips tab refresh action could rotate the icon while data is loading
  (loading state animation). Out of scope for this phase.
- Some accessibility labels in `ActiveTripSummary` could include a `value` that
  reports the actual data (e.g., "Trip Nozomi 231, On time, Platform 18,
  JR Central"). Worth a follow-up if VoiceOver testing surfaces gaps.
