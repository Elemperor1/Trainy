# Trainy Design Audit

Date: 2026-06-23
Reviewer: Senior product designer pass (no implementation yet)

Scope: Trainy iOS app (`Sources/TrainyCore/`, `TrainyIOS/`) and the root web prototype (`index.html`, `styles.css`, `components.js`, `app.js`). Audit applies to the **functional state shipped today**, not the polished screenshots in `docs/`.

---

## How I Read This Product

Trainy is the kind of app I want to live inside for three weeks in Japan, and the bones are already here. The Shinkansen-first scoping, the source-provenance honesty (`SourceKind`, `FreshnessState`, `ConfidenceLevel`), the MapKit journey map, the OAuth/proxy-aware provider registry: these are real engineering strengths, not afterthoughts. The visual layer, however, reads like the first commit of a competent AI-assisted generator: every screen is a stack of `GlassPanel` cards in different tints, the same `railLiquidGlass` modifier is welded onto every container, and there is no single moment where the eye lands and breathes. It does not feel like Stripe, Linear, Arc, or Apple. It feels like the obvious SwiftUI template, with a thin layer of Liquid Glass applied across every surface.

My job in this audit is not to remove the polish the team has built. It is to enforce **less-but-better**: keep the source-provenance rigor, keep the iOS 26 glass language, but stop using the modifier as a substitute for hierarchy.

---

## Top-Line Verdicts

| Area | Verdict |
| --- | --- |
| Web prototype (`index.html`/`styles.css`/`app.js`) | Looks like a polished early-2020s SaaS dashboard. Functional but visually dated, with too many borders, dashed empty states, and color-coded cards. Strong bones; needs typographic refinement, real iconography, and a calmer color story. |
| iOS native (`ContentView.swift`/`RailComponents.swift`/`RailJourneyMap.swift`) | Liquid Glass is the entire visual language. Every panel, card, button, source badge, station badge, status pill, segmented picker, and the trip-card chevron cue is `railLiquidGlass`. That is not a system; it is a single repeated stroke. |
| Information hierarchy | Web dashboard does a better job than the iOS app. iOS detail screens stack 7+ `GlassPanel`s with eyebrow/subtitle strings that nobody reads; user must scroll to find the next stop. |
| Typography | Web uses Inter at three sizes (eyebrow / body / title) plus `clamp()` on hero. iOS uses seven `RailDesign.Typography` members but applies them inconsistently. |
| Spacing | Web uses `4 / 8 / 12 / 16 / 20 / 24` (off-by-one `20`). iOS uses `4 / 8 / 12 / 16 / 20 / 28 / 36` (skips 24 and 32). Required scale `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64` is not enforced anywhere. |
| Color | Web has 8 brand colors plus 5 surface tokens. iOS has 11 colors routed through 4 semantic aliases (`success`/`warning`/`danger`/`info`). Both are oversaturated; too many hero panels use `violet`, `copper`, `marine` tints that compete with the actual `accent`. |
| Iconography | Web uses single-letter glyphs inside "icon buttons" (`R`, `C`, `T`). iOS uses SF Symbols correctly but stacks 2-3 different icons in the same row (`bell`, `bell.fill`, `bell.slash`) and inconsistently sized circles. |
| Motion | Web has one transition (`transform: translateY(-1px)` on hover) and one for the toast. iOS has only the spring `Motion.soft`. No staggered entrances, no skeleton shimmer, no per-element exit. |
| Empty / loading states | iOS has dedicated `EmptyStateView` and `LoadingSkeletonView`, both look correct but are over-styled with their own nested `GlassPanel`. Web has a single dashed-border empty card. |

---

## Critical Findings

### C1. iOS detail screen stacks 8 separate glass panels in one scroll
**Where:** `TrainDetailView` (`ContentView.swift:2098-2230`): `RouteHeaderPanel`, `StatusSummaryPanel`, `SourceProvenancePanel`, `RailJourneyMapPanel`, `JourneyProgressPanel`, the timeline panel, the transfer warning, the carriage/platform panel, the notes panel, the alerts panel.

Each panel is its own `GlassPanel { VStack { ... } }`. The screen reads as a glass tower. There is no visible primary action, no header-vs-body rhythm, and the actual rider-critical fact (next stop, ETA, platform) is buried in the active-trip summary card on the Trips tab, not in the detail screen it ostensibly belongs in.

**Why it matters:** Linear, Stripe, Notion, Apple, Arc: none of them put eight translucent cards in a vertical stack. They use a clear **header / hero / 2-column body / footer** rhythm. This screen violates every one of those.

### C2. iOS `railLiquidGlass` is applied to almost every container
**Where:** 67 occurrences across `ContentView.swift`, `RailComponents.swift`, `RailJourneyMap.swift`, `DesignSystem/RailDesignLibrary.swift`. `EmptyStateView` puts glass inside glass (`GlassPanel` wraps a `FloatingGlassButton` that itself wraps `railLiquidGlass`). `StationBadge` and `SourceBadge` are glass. The trip-card chevron is glass. The map recenter button is glass.

**Why it matters:** Liquid Glass on iOS 26 is meant for **distinct surfaces**: a navigation bar, a sheet, a hero. When everything is glass, nothing is glass. The eye cannot find a hierarchy, and the device's blur pass becomes expensive.

### C3. Web "icon buttons" are single uppercase letters
**Where:** `index.html:23-32`, `styles.css`. The refresh button shows `R`. The compact-mode button shows `C`. The brand mark shows `T`. Aria labels exist but the rendered output is a single letter, the strongest signal of an unfinished prototype.

### C4. iOS `StatusSummaryPanel` is duplicated
**Where:** `ContentView.swift:2289-2322` defines `StatusSummaryPanel`, but the same information is also rendered inside `ActiveTripSummary` (`ContentView.swift:640-790`) and `RouteHeaderPanel` (`ContentView.swift:2222-2262`). When the trip detail opens, the user sees Status/Platform/Updated a second time, in a different visual treatment.

### C5. iOS `TrainDetailView` has no visible primary action
**Where:** `ContentView.swift:2098-2230`. The hero `RouteHeaderPanel` declares `HStack { ServiceStatusPill }` but no "Open Map", no "Refresh", no "Track". The primary action only appears as a single `ShareLink` near the bottom. The detail screen exists to act; currently it only describes.

---

## High Findings

### H1. Spacing scale skips 24, 32, 48, 64
**Where:** `RailDesign.Spacing` in `RailDesignSystem.swift`. Values are `4 / 8 / 12 / 16 / 20 / 28 / 36`. The required scale is `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64`. The web scale is `4 / 8 / 12 / 16 / 20 / 24`: closer but still wrong, and the off-by-one `20` is everywhere.

### H2. Typography scale is non-standard
**Where:** `RailDesign.Typography` defines `largeTitle / title / metricValue / routeTitle / headline / body / callout / compactLabel / caption / micro`. The required scale is `Display / H1 / H2 / H3 / Body / Small / Caption`. iOS uses `Font.system(.title3, design: .rounded)` for `routeTitle`, which is a font, not a size step, so two screens rendering "the same" `routeTitle` can look different if the system font changes.

### H3. Color palette is over-broad
**Where:** `RailDesign.Palette` exposes 8 brand colors (`accent / marine / violet / copper / mint / amber / red / blue`) and 4 semantic aliases. Most screens pick a random tint per `GlassPanel`. The user's eye cannot tell which panels belong to the active provider vs. trip data vs. settings.

### H4. Status pill colors do not match status text
**Where:** `RailDesign.Palette.success = mint` (green), `warning = amber` (yellow), `danger = red` (red). Correct. But the trip-card status pill on web (`status-pill.late`) uses solid `--danger` red text on red background: contrast passes only because both are on white. The `live-dot` uses the same mint for both on-time and boarding; the dot cannot distinguish them.

### H5. Web hero heading scales to 4.2rem
**Where:** `styles.css:.status-strip h2`. `font-size: clamp(1.8rem, 4.2vw, 4.2rem)`. At 1440px the headline is ~60px, while body is 14px (`--fs-body = 0.86rem`). The contrast is jarring; the hero overpowers the panels around it.

### H6. iOS `ActiveTripSummary` (Trips tab) is a wall of nested glass
**Where:** `ContentView.swift:640-790`. One outer `GlassPanel(cornerRadius: 30)` contains a `railLiquidGlass(cornerRadius: 22)` for the progress card, three `ControlMetricTile`s (each its own glass), a button row of `SummaryIconLabel`s (each its own glass), and a chevron glass. Six layers of glass in one card.

### H7. Web `.live-panel` background mixes two gradients with a 42-px repeating line
**Where:** `styles.css`. The grid lines visually clash with the panel borders above and below the live panel.

### H8. iOS settings are 7 nested `SettingsGroup`s + active-provider summary + provider-proxy status + provider directory list + provider region picker
**Where:** `SettingsScreen` (`ContentView.swift:1493-1602`). The Provider group alone contains a summary, divider, proxy status, divider, navigation row, divider, region picker, divider, and the full directory list. The user must scroll through ~4 screens of toggles and rows to find the active provider.

### H9. iOS station overview uses `stationCount` / `platforms` / `routes` MiniStats in triplicate
**Where:** `StationOverviewPanel` (`ContentView.swift:1264-1300`), `StationCard` (`ContentView.swift:1297-1320`), `StationDetailView` (`ContentView.swift:1319-1374`). Three separate screens show overlapping "Departures / Platforms / Routes" mini-stats. They never agree about what to highlight.

### H10. Web metric tiles use `--success-bg` rgba as background
**Where:** `styles.css`. The shared grid (`metric-row`) fills cells with `var(--line)` to draw the dividers, then `padding: var(--space-4)`. The cells do not align to the same baseline as the live-panel above; no optical alignment.

---

## Medium Findings

### M1. Web `.segmented` control uses 3-px gap, 3-px padding, hard `font-size: 0.78rem`
The segmented control is the only place on the web where the user actively chooses a filter. It is 34px tall, with a 1px border, and a 4-px shadow on the active segment. Linear's segmented control is 28px tall, no border, weight 500. Raycast's is 24px. Trainy's feels 2019.

### M2. iOS `RailSegmentedPicker` uses `Capsule()` for the indicator and `railLiquidGlass` for the track
The indicator is the same height as the buttons (44px), so the visual is two pills stacked. The active pill is darker with a 22% accent tint, readable but heavy.

### M3. Web `.next-action` is a `var(--charcoal)` panel with `--overlay-faint` text
The "Next Action" panel is the only dark card on the web. It sits in the right column among light panels and pulls focus away from the live panel. Flighty-style apps either invert the whole panel or never invert at all.

### M4. iOS `EmptyStateView` icon is a `railLiquidGlass` circle around an SF Symbol
**Where:** `RailComponents.swift:741-770`. The icon (`Image(systemName:)`) is 36pt, in a 64pt `railLiquidGlass` disc, on top of a `GlassPanel`. Three layers for one icon. The web empty state is a 1px dashed border.

### M5. iOS `TransferWarningCard` always says "Transfer watch" with an accent tint
**Where:** `RailComponents.swift:662-689`. The tone switches to amber only when `statusTone != .good`, but the title stays the same. Users with no transfers see an amber icon on a teal panel and read "Transfer watch" with an exclamation triangle.

### M6. iOS `RailMapControls` uses 9pt font for the recenter label "Map"
**Where:** `RailJourneyMap.swift:600-650`. 9pt is below readable size on iOS; Apple HIG recommends 11pt minimum. The "Route / Stops / Disruptions" buttons are 8pt.

### M7. Web `.car` cells in the platform map use 5-px border-radius
**Where:** `styles.css`. The cars live inside a `.platform-map` container with `border-radius: 8px` and `padding: 16px`. The cars are 22px wide and 44px tall; they read as more rounded than the container, but the math says `parent (8) - child (5)` is concentric only if the inner radius is `parent - padding`. Here parent `8` and inner `5` with `5px` gap is roughly right but the cars are not centered optically.

### M8. iOS `MetricsTile` (HistoryScreen) shows distance/hours/stations/operators/regions but Distance is "Not logged" for every starter trip
**Where:** `ContentView.swift:1487-1493`. The user reads the dashboard and sees "Distance: Not logged" on every first-run screen. That is a trust failure, not a polish failure.

### M9. iOS `ProviderDeveloperCredentialStatus` shows "ODPT_CONSUMER_KEY configured for this build."
**Where:** `ContentView.swift:2929-2990`. The status text leaks the environment variable name into the rider-facing UI. The credential should be referenced by its friendly name (e.g. "ODPT consumer key") not the Swift identifier.

### M10. Web `.signal-meter` uses a 3-stop gradient inside a 10-px pill
**Where:** `styles.css`. The gradient is `var(--warning), var(--success), var(--teal)`. Three brands of green at once, for a single confidence bar.

---

## Low Findings

### L1. iOS `EmptyStateView.actionTitle` and `EmptyStateView.action` are optional but the initializer requires both
**Where:** `RailComponents.swift:744-770`. Three separate init paths exist; in practice every caller supplies both or neither.

### L2. iOS `SourceFactRow.fact.fact.displayName` is an 88-px fixed-width left column
**Where:** `RailComponents.swift:251-280`. On iPad in landscape that 88px slot is 10% of the row; on iPhone 16 Pro Max it is 22%. Two different visual proportions of the same fact.

### L3. Web `.brand small` uses `margin-top: 2px` instead of `gap`
**Where:** `styles.css`. The 2-px inline spacing bypasses the spacing token system.

### L4. iOS `RailJourneyMapPanel.Style.full` (height 610) and `.detail` (height 450) coexist
**Where:** `RailJourneyMap.swift:5-30`. The map panel is full-screen inside the map screen and 450-px tall inside the detail screen. The map uses different `mapAttributionInset` and `stopRailBottomInset` between the two. It reads as two unrelated features.

### L5. Web `.toast` animation is `opacity` + `transform: translateY(18px)` on `transition`
**Where:** `styles.css`. The transform is in the entry direction (18px below) and the exit direction is the same. Standard convention is to enter from below and exit downward; here it enters from below and exits to the resting position. Works, but feels off.

### L6. iOS `BrandMark` ("T" inside a red square) is a placeholder
**Where:** `TrainyIOS/Trainy/Assets.xcassets/AppIcon.appiconset/Contents.json` references `HeroTrain` (a generated image). The web brand mark is a red square with "T" inside.

---

## Accessibility Findings

### A1. Web `.icon-button` has no `aria-label` on the rendered letter
**Where:** `index.html:23-32`. The visible `R` and `C` are wrapped in `<span aria-hidden="true">`, but the button itself has `title` and `aria-label` only. VoiceOver reads the label, good. But the visible 1-px border + 40x40 button + 1-character label is below the 40-px hit area on macOS touchpads.

### A2. iOS `.brand-mark` (web) has `aria-hidden` but no fallback
**Where:** `index.html:18-21`. Screen readers correctly skip the visual mark but a sighted user with the link visible sees only the letter T.

### A3. Web search field's left magnifier is constructed from two pseudo-elements
**Where:** `styles.css`. The `::before` and `::after` form a circle and a handle. There is no `aria-hidden` or `role="img"`. The search input is correctly labeled.

### A4. iOS `StatusSummaryPanel` uses 3-px `Divider()` between summary items
**Where:** `ContentView.swift:2290-2310`. SwiftUI `Divider()` is 0.5-pt at 60% opacity on light backgrounds, below 3:1 contrast (WCAG SC 1.4.11). Users with low vision cannot perceive the divider.

### A5. Web `.metric-row` is divided by `1px solid var(--line)`
**Where:** `styles.css`. On the white background, `var(--line) = #d9dee4` has contrast ratio 1.4:1 against `#ffffff`. WCAG minimum for non-text separators is 3:1. The dividers are decorative and arguably don't need to pass, but the user cannot perceive the cell boundaries.

### A6. iOS `railScreenChrome` applies `.toolbarBackground(.ultraThinMaterial)` globally
**Where:** `RailDesignSystem.swift`. The screen chrome is correct for navigation bars, but it forces ultraThin material on every screen, including modal sheets (`SourceDetailSheet`, `FirstRunExperienceSheet`). The sheets would feel better with a clean background or a sheet-specific tint.

---

## Mobile Usability Findings

### M1-mobile. iOS `TripsScreen` requires horizontal swipe to reach the active trip detail
**Where:** `ContentView.swift:380-560`. The trips list uses `List` with `NavigationLink` push; the user must tap a card to navigate. There is no peek/swipe-to-detail, and the `selectedTripRoute` is a `NavigationLink` inside a `Button`, which produces an empty hit area between the two gestures.

### M2-mobile. iOS `searchable(.navigationBarDrawer(.always))` permanently reserves a search row
**Where:** `SearchScreen`. The user cannot dismiss the search bar to see more of the hero. The behavior is correct for a search-first screen but is heavy when the user just wants to pick from "Suggested services."

### M3-mobile. Web `.topbar-actions .text-button` is hidden at `max-width: 520px`
**Where:** `styles.css`. On mobile, the only top-bar action is the icon button. The user can still "Share Trip", but only from inside a trip card. The Share action is also not represented on the empty state.

### M4-mobile. iOS `TripBucket` segmented control takes 72px of vertical space at the top of every Trips tab render
**Where:** `ContentView.swift:434-450`. On an iPhone 16 Pro Max, that is ~9% of the visible viewport. Linear spends 0% on a segmented control; they use a context menu.

### M5-mobile. iOS `.safeAreaInset(edge: .bottom) { Color.clear.frame(height: 104) }` reserves 104px at the bottom of every list
**Where:** `ContentView.swift:540-543`. The intent is to keep content above the tab bar, but the tab bar is already a `safeAreaInset`. The extra 104px creates a permanent gap between the last card and the tab bar.

---

## Generic AI Patterns to Remove

1. Eight glass panels stacked vertically (C1).
2. Single-letter icon buttons on web (C3).
3. Always-visible source badges on every row, even when they all read "Starter" or "Scheduled."
4. `eyebrow + headline + subtitle` headers on every panel; every panel claims importance.
5. `ViewThatFits { HStack VStack }` in `StatusSummaryPanel` (C4): the kind of clever-but-redundant fallback that screams "I used every SwiftUI modifier I could find."
6. `.task { ... await Task.sleep(for: .milliseconds(260)) ... await store.searchLiveTrips(matching: cleanQuery) }` in `SearchScreen` (debounce), but only on the search screen; the Trips tab refreshes immediately. Inconsistent.
7. `font: var(--font-sans)` with hard-coded fallbacks that include `system-ui`, `-apple-system`, `BlinkMacSystemFont`, `Segoe UI`, `sans-serif`. Five-font stack that none of the browsers actually use.
8. `railScreenChrome()` as a single global modifier that paints the gradient on every screen, including settings that should feel calm.
9. `EmptyStateView` with `railLiquidGlass` circle around an SF Symbol around a `GlassPanel` (M4): the icon-in-glass-in-glass pattern.
10. `backdrop-filter: blur(18px)` on a sticky top bar that also has `border-bottom: 1px solid var(--line)`. The line is invisible behind the blur, so it is decorative. Either remove the line or remove the blur.

---

## Where I Would Start

If I had one focused pass:

1. Delete the single-letter icons on web and replace with SF Symbols inline. Three lines of work; removes the single most "AI-generated" signal.
2. Rewrite the iOS `TrainDetailView` as a 4-section screen (hero + 2-column body + sticky footer). Removes 6 of the 8 glass panels.
3. Strip `railLiquidGlass` from any container that contains text or a small icon (`StationBadge`, `SourceBadge`, `SummaryIconLabel`, `TripOpenCue`, `RailMapControls`). The glass stays on hero panels, navigation, and the segmented picker.
4. Add a real spacing token of 24 / 32 / 48 / 64 to both `RailDesign.Spacing` and the CSS `:root`.
5. Stop calling `EmptyStateView`'s icon a glass disc. Use a flat 48-px tinted circle.

Each of these is small; together they re-shape the product.

---

## Runtime Audit Addendum — 2026-06-24

The original audit was code-led. This addendum is based on the redesigned app running on an iPhone 17 simulator and supersedes any earlier statement that simulator proof was unavailable.

### Prioritized runtime findings

| Priority | Finding | Resolution |
| --- | --- | --- |
| Critical | The redesigned Stations screen did not compile because a `Button` wrapped a `NavigationLink`, and Swift timed out type-checking the nested expression. | Replaced the nested controls with one semantic `NavigationLink`; simulator build now succeeds. |
| Critical | Trip Detail embedded a fully interactive 450-pt map inside a vertical `ScrollView`. The map captured vertical gestures, making the lower timeline, boarding, and source sections difficult to reach. | Replaced the embedded map with a focused "Open rail map" navigation card. The full interactive map remains on its dedicated screen. |
| Critical | Pushed Station, Trip, and Supported Regions screens retained the floating tab bar, which obscured empty states and lower content. | Pushed destinations now hide the tab bar. |
| High | Top-level large-title navigation left a large inert band under the Dynamic Island while custom headers repeated the screen title below. | Top-level screens now use inline navigation titles; the custom Trips header carries only scope, freshness, and Add Trip. |
| High | Trips repeated the selected active journey in both the hero and "Current Journeys", and a pinned section header collided with content while scrolling. | The selected trip appears once; additional active journeys are separated as "More active journeys", with a non-pinned section label. |
| High | Stations rendered three colored metric tiles per row, producing dashboard clutter and repeating mostly identical `1 / 1 / 1` values. | Station rows now use a single metadata line: departures, tracks, and routes. |
| High | Compact provenance badges rendered `Starter · Unk`, exposing an implementation abbreviation without helping the rider. | Unknown freshness is omitted from compact badges; full source detail and accessibility labels still report it honestly. |
| Medium | History had no useful next step and left most of the screen empty. | Added a Recent Journeys section with direct navigation to trip detail. |
| Medium | Supported Regions had become a plain status list, losing the previously requested globe and making implemented coverage less memorable. | Restored a registry-backed, non-aspirational globe with markers only for implemented regions, followed by Available Now and Planned Regions groups. |
| Medium | First-run used an invalid SF Symbol and rendered a blank tinted tile. | Replaced it with `checkmark.seal.fill`. |
| Low | Twelve-hour journey times crowded together at 40 pt. | Reduced `Display` to 36 pt and added a centered directional arrow. |

### Before / after rationale

#### Hierarchy and density

| Before | After |
| --- | --- |
| Active trip split across separate hero and tools cards | One 24-pt-radius surface with a divider between journey facts and actions |
| Three vertically stacked 64-pt icon tools | Three horizontal 44-pt action controls |
| Search hero and capability banner repeated the same scope explanation | Search scope is one compact row; capability limitations remain a separate contextual banner |
| History stopped after three highlight rows | Recent journeys provide the screen's clear next action |

#### Navigation and interaction

| Before | After |
| --- | --- |
| Large-title navigation consumed space without showing useful information | Inline navigation titles keep the top rhythm compact and predictable |
| Interactive map nested inside the detail scroll | Deliberate map navigation card; interactive gestures live on the map screen |
| Pushed screens competed with the floating tab bar | Tab bar hidden on detail destinations |
| Nested `Button` + `NavigationLink` station row | One full-width semantic `NavigationLink` with a 44-pt target |

#### Provenance and trust

| Before | After |
| --- | --- |
| `Starter · Unk` in every compact source badge | `Starter`; unknown freshness remains available in detailed and accessibility contexts |
| Rider-facing provider copy exposed `ODPT_CONSUMER_KEY` / `NS_SUBSCRIPTION_KEY` | Friendly "ODPT consumer key" / "NS subscription key" language |
| Supported coverage was a long list of "Coming soon" pills | Implemented regions lead visually; planned regions are progressively disclosed and explicitly unavailable |
