# Phase 15 — Interaction polish round 2 (2026-06-23)

Companion to `phase-14-design-polish.md`.

## What changed

### Empty-state CTA wiring

- **Stations screen** ("No station found") now fires a `NotificationCenter`
  notification (`.trainyFocusStationSearch`) when the user taps the
  empty-state CTA. `SearchScreen` listens for that notification and uses
  SwiftUI's new `.searchFocused($searchFieldFocused)` binding to focus
  its searchable field. Net effect: a one-tap path from "no station found"
  to typing a station name.

### CompactSourcePanel hierarchy

- `CompactSourcePanel` now uses the new `PressableButtonStyle` for the
  "open source details" tap target.
- A divider separates the source badge / chevron row from the four
  metadata rows below, so the eye reads it as one block ("this trip's
  source") instead of five independent rows.
- All four metadata rows now share consistent left-edge alignment
  (28-pt icon column) and right-aligned value text. The previous version
  varied by row.

### New shared banner components (`RailComponents.swift`)

- `SuccessBanner(symbol:title:message:)` — tinted success strip with an icon
  + title + optional detail, used after Pin / Notify / Refresh / Share
  actions. Uses `--status-success`.
- `ErrorBanner(symbol:title:detail:retry:)` — tinted danger strip with an
  optional "Try again" affordance. Pairs with `OfflineBanner` (warning)
  and `SuccessBanner` (success) to form the full status banner family.

### Live status feedback in `ActiveTripSummary`

- Added `@State private var activeStatusMessage: LocalizedStringKey?` and a
  `showStatus(_:)` helper that flashes the message for 2.4 s.
- Every trip tool button now calls `showStatus(...)` with a contextual
  message: "Refreshed Nozomi 231", "Alerts enabled for Nozomi 231",
  "Alerts muted for Nozomi 231", "Share sheet opened for Nozomi 231".
- The SuccessBanner sits at the top of the trip-tools section, animates in
  via `.transition(.opacity.combined(with: .move(edge: .top)))`.

### Typography cleanup (continued)

- `FirstRunScopeRow` icon now uses `.headline` (was unset).
- `FirstRunScopeRow` title uses `RailDesign.Typography.h3`; detail uses
  `RailDesign.Typography.small`. Spacing between rows uses `xxs`.
- `OfflineBanner` title uses `RailDesign.Typography.small.weight(.semibold)`,
  detail uses `RailDesign.Typography.small`. Amber color routes through the
  semantic `warning` token.
- `Settings` picker detail strings lose trailing periods (Apple style).

### Verification

```bash
bash scripts/check-design-system-bypass.sh   # passes
xcrun -sdk iphonesimulator swiftc -typecheck -target arm64-apple-ios26.0-simulator \
  -sdk "$(xcrun -sdk iphonesimulator --show-sdk-path)" \
  -module-cache-path /tmp/swift-module-cache \
  $(find Sources/TrainyCore -name "*.swift")  # exit 0
```

### Outstanding

- The `searchFocused` binding uses iOS 18+ semantics. We're already targeting
  iOS 26, so this is fine, but be aware if you backport.
- `SuccessBanner` is currently only used inside `ActiveTripSummary`. Hook
  it into the Settings row for "Reset first-run" and the Supported regions
  pick in a future pass.
- `ErrorBanner` is defined but not yet wired into any screen. The next
  refresh pass should call it from `TrainStore.refreshProviderProxyHealth`
  failures.
