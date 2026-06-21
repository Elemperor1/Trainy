# review-design-system

**Purpose:** Review UI changes to ensure they route through Trainy's unified
Design System library with no bypassing. Use this skill whenever reviewing or
authoring UI (SwiftUI screens or the web prototype).

## When to run

- Before merging any change that touches `Sources/TrainyCore/ContentView.swift`,
  `Sources/TrainyCore/DesignSystem/`, `Sources/TrainyCore/RailComponents.swift`,
  `Sources/TrainyCore/RailDesignSystem.swift`, or the web `app.js` / `styles.css` /
  `components.js`.
- When a contributor adds a new screen, card, pill, row, badge, or panel.

## The Design System

The library is the single source of truth for styling and reusable controls:

| Layer | iOS | Web |
| --- | --- | --- |
| Tokens | `RailDesign` enum in `RailDesignSystem.swift` (`Palette`, `Spacing`, `Radius`, `Elevation`, `Typography`, `Motion`) | `:root` custom properties in `styles.css` (+ dark theme) |
| Primitives / components | `RailComponents.swift` + `DesignSystem/RailDesignLibrary.swift` (`GlassPanel`, `railLiquidGlass`, `ServiceStatusPill`, `SourceBadge`, `SectionHeader`, `MiniStat`, `InfoLine`, `DelayBar`, `SettingsGroup`/rows, `RailSegmentedPicker`, …) | `components.js` → `window.TrainyUI` (`tripCard`, `miniPill`, `timelineRow`, `alertItem`, `networkRow`, `car`, `emptyState`, …) |
| Screens | `ContentView.swift` consumes the library only | `app.js` calls `TrainyUI.*` only |

## Review checklist

1. **Run the guardrail.**
   ```bash
   ./scripts/check-design-system-bypass.sh
   ```
   It must exit `0`. If it fails, every reported line must either be fixed or
   carry an audited `// ds-allow: <reason>` exception (iOS canvas primitives
   only — never for ordinary screens).

2. **No new hand-rolled components.** A new screen must not define a private
   `struct` that duplicates an existing library component. If a reusable control
   is needed, add it to `DesignSystem/RailDesignLibrary.swift` (iOS) or
   `components.js` (web) and consume it from the screen.

3. **Tokens, not literals.**
   - iOS: colors via `RailDesign.Palette.*` (use semantic roles `success` /
     `warning` / `danger` / `info` for status); radii via `RailDesign.Radius.*`;
     spacing via `RailDesign.Spacing.*`; fonts via `RailDesign.Typography.*`.
     No `Color(red:)`, `UIColor(red:)`, `Color.black/white/gray`, or
     `RoundedRectangle(cornerRadius: <number>)` outside the library.
   - Web: colors/spacing/radius/typography via the CSS custom properties in
     `:root`. No hardcoded hex/rgba outside the token layer.

4. **No direct glass / bespoke surfaces.** iOS must use `railLiquidGlass()` /
   `GlassPanel` / `railPanelShadow()`, never `.glassEffect(` directly.

5. **Web markup comes from the library.** `app.js` must not build component
   HTML inline (`class="trip-card"`, `mini-pill`, `timeline-row`, `alert-item`,
   `network-row`, `car`, `empty-state`). All dynamic markup is produced by
   `TrainyUI.*` factories in `components.js`.

6. **Verify, don't assume.** After changes:
   ```bash
   # iOS
   export DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer
   SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
   swift build --triple arm64-apple-ios26.0-simulator --sdk "$SDKROOT"
   # Web (end-to-end)
   python3 -m http.server 8765 --bind 127.0.0.1 &
   # then drive http://127.0.0.1:8765/index.html in a browser: type in
   # #trip-search, click a .trip-card, click #refresh-button, confirm state
   # changes and the console is error-free.
   ```

## Red flags that block review

- A new `private struct` in `ContentView.swift` that reimplements a pill, badge,
  row, tile, or section header.
- Inline `style="..."` or hardcoded CSS values in web components.
- Status colors chosen by raw hex/RGB instead of semantic tokens.
- A screen that calls `.glassEffect(` or constructs `RoundedRectangle` with a
  numeric radius.

Resolve all red flags before approving.
