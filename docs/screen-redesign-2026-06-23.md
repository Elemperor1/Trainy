# Screen-By-Screen Redesign Recommendations

Date: 2026-06-23
Companion to `docs/design-audit-2026-06-23.md` and `docs/design-system-2026-06-23.md`.

For every screen: what's wrong today, what's right to keep, and what changes. The goal is fewer elements, sharper hierarchy, and one obvious thing to do next.

---

## Web prototype

### Screen: top bar

| Today | Tomorrow |
| --- | --- |
| 72-pt tall, 3-column grid, 1-pt hairline border, `backdrop-filter: blur(18px)`, brand mark = red square with white "T", search icon = two pseudo-elements (circle + handle), icon buttons = single uppercase letter ("R", "C"). | 56-pt tall, no border (use `--elev-1` shadow only). Brand mark = small wordmark "Trainy" with a 16-px deep-teal square + white "T". Search field uses an inline SVG magnifier (1.75-pt stroke, currentColor). Icon buttons use inline SVGs (Lucide-style: rotate-cw for refresh, more-horizontal for menu). |

Primary action: "Add trip" (a 36-pt button on the right). Removes the need for "Share Trip" inside the top bar; share moves into the active trip card.

### Screen: tracked trains (left panel)

| Today | Tomorrow |
| --- | --- |
| `panel-heading` shows `eyebrow "Today"` + `H1 "Tracked Trains"` + 40x40 compact-mode icon button. Segmented filter with 3-pt gap. Trip cards are 116-pt tall with a 1-pt border, a `mini-pill`, and two metadata rows. The "Departure board" station-brief sits below the trip list with a 1-px divider, two stats, and a `brief-grid` of 2 cells. | Heading collapses to a single `H1` ("Trips") and an inline search field. Segmented filter becomes a pill toggle group at the top of the list, no border, `--ink-default` inactive, `--surface-canvas` active. Trip card is a 72-pt row with a 2-pt left border (`--accent` if active, `--line` if not), the train number + route on a single line, and `H3` time / destination / status. No metadata row. The station-brief is replaced with a "1 platform watched, 1 transfer at risk" inline strip with an icon. |

Primary action: tap a trip card (the whole row is the tap target). Hold reveals pin/notify actions.

### Screen: live panel (center)

| Today | Tomorrow |
| --- | --- |
| Hero status strip with a 60-px headline, a 26-pt status pill, and a `live-dot`. Route board has two `station-code` boxes (charcoal, 48-pt tall) and a `rail-line` with a 3-stop gradient. A 4-column `metric-row` with 1-pt dividers. A station timeline with manual line and circle markers. A platform map with 22x44 cells. | Hero becomes a single line: `Display` time, `H1` city, `Small` meta. Status pill is small (`H3` weight, 24-pt tall), sits on the right. Route is a horizontal pair: origin time, station, dash, station, arrival time. A single accent-tinted progress bar (4-pt tall) below. Metrics collapse to two lines: "Next stop Nagoya" and "ETA 10:58". The timeline is a 2-column row (left = time, right = station) with a 2-pt left accent on the current stop. No platform map inside the live panel; it moves to the trip detail. |

Primary action: open the trip detail (entire header is the tap target). No "Refresh" or "Share" inside the hero; share lives in the detail.

### Screen: intelligence panel (right)

| Today | Tomorrow |
| --- | --- |
| "Trainy Call" panel (charcoal, with `--overlay-hairline` text). Signal card with a 10-px `signal-meter` gradient. Alerts section with a `alert-list` of two rows. Network board with a `network-list` of all trips. | "Next move" panel (accent-tinted, `Body` copy, single primary CTA "Notify me"). Signal confidence is a single 4-pt progress bar. Alerts section is a flat list with `--status-warning` left border on actionable alerts. Network board is removed (its content overlaps the trips list). |

Primary action: "Notify me" (the call-to-action the user came here for). One button. Nothing else competes.

### Screen: trip detail (web)

Not present today; the web prototype stops at the live panel. We add a `/trip/:id` route that shows the same detail screen as iOS but in a single column. Hero, source disclosure, stop timeline, alerts. See the iOS screen-by-screen below for content.

### Screen: empty / loading / error

| Today | Tomorrow |
| --- | --- |
| Empty: dashed 1-pt border, `--ink-muted` text. Loading: full panel with three skeleton rows of varying widths. Error: a 1-px hairline `EmptyStateView` with no icon. | Empty: flat `--surface-panel` card with a 48-px tinted icon, `H2` title, `Body` message, single CTA. Loading: the same card with three skeleton rows (240×12, 320×54, 180×10) and a 1.4s linear shimmer. Error: `EmptyStateView` with a `--status-danger` icon and a "Try again" CTA. |

Primary action on every empty state: "Add trip". One CTA. The path forward is unambiguous.

---

## iOS app

### Screen: Trips (tab 1)

| Today | Tomorrow |
| --- | --- |
| `TripsScreen` is a 3-section `List`: header row + segmented picker + bucket section. `TripsHeaderRow` has a `largeTitle` "Trips", a status subtitle, and a 48-pt `+` glass button. `RailSegmentedPicker` is 44-pt tall per button. `ActiveTripSummary` is 6 layers of nested glass. `TrainTripCard` uses 24-pt corner radius. | `TripsScreen` keeps the 3-section `List` structure but the header collapses to a single `H1` with a 40-pt inline search button (icon: magnifyingglass). `RailSegmentedPicker` becomes a 32-pt pill toggle (using `.buttonStyle(.borderless)` and the system `Capsule()`). `ActiveTripSummary` becomes a single 24-pt panel with hero time + station + status + 3 metrics; no nested glass. `TrainTripCard` uses 16-pt corner radius. The chevron glass cue becomes a simple `chevron.right` SF Symbol. |

Primary action: tap a card to open detail. The `+` button in the header opens the search sheet.

### Screen: Search (tab 2)

| Today | Tomorrow |
| --- | --- |
| `SearchScreen` is a `ScrollView` with a `SearchHeroView`, a `SearchCapabilityNoticeView`, recent searches, favorite stations strip, suggested routes, and results. Hero uses a 42-pt glass-tinted panel with a `magnifyingglass.circle.fill` icon and two `ProviderStatusPill`s. The favorite-stations strip is a horizontal scroll with `StationBadge` inside a glass disc. | `SearchScreen` collapses to: `SearchHeroView` (single line: scope pill + status pill), `RecentSearchesView` (flat list, no glass), `SuggestedRoutesView` (flat list, no glass), `SearchResultsSection` (flat list of `SearchResultCard`). The hero shrinks to 56-pt; the entire content fits above the fold on iPhone 16 Pro Max. |

Primary action: type a query and tap a result. The keyboard stays open until the user picks a result or taps Cancel.

### Screen: Stations (tab 3)

| Today | Tomorrow |
| --- | --- |
| `StationsScreen` is a `List` with `StationOverviewPanel` (large, hero-tinted) + a flat list of `StationCard`s. `StationOverviewPanel` shows "Station watch / 8 stations / 4 platforms / 0 alerts". `StationCard` shows the station badge + 3 mini-stats. `StationDetailView` opens with a hero, two `MetricTile`s, two `BoardSection`s, and a "Station notes" glass panel. | `StationsScreen` keeps the `List` structure. `StationOverviewPanel` becomes a single 56-pt row with a single `H2` heading and a 12-pt inline subhead. `StationCard` shows the station badge + 1 inline stat ("12 departures tracked"). `StationDetailView` opens with a single hero (name + status pill) and a 2-column body (departures / arrivals as flat lists, no inner glass). |

Primary action: tap a station card to open detail. No plus button.

### Screen: History (tab 4)

| Today | Tomorrow |
| --- | --- |
| `HistoryScreen` opens with a `GlassPanel(cornerRadius: hero)` showing a `largeTitle` summary + a `DelayBar` + 6 `MetricTile`s in a 2-column grid + a `GlassPanel` "Journey highlights" with 4 `InfoLine`s. | `HistoryScreen` opens with a single 24-pt panel showing "X trips · Y stations visited" (single line). The 6 metrics become a 2-column grid of flat tiles with `--ink-default` value and `--ink-muted` label, no icon disc, no glass. The "Journey highlights" section collapses to a single `H2` + 3 lines. |

Primary action: scroll. There is no primary action on History.

### Screen: Settings (tab 5)

| Today | Tomorrow |
| --- | --- |
| `SettingsScreen` opens with a hero panel "Rail companion / 8 saved trips · 14 watched stations", then 7 `SettingsGroup`s (Notifications, Time & Units, Providers, Privacy, Support, Developer). The Providers group alone is 5 sub-sections. | `SettingsScreen` opens with a single 56-pt hero: `H1` "Settings" + the active provider as a small inline chip. Groups collapse to: Notifications (2 rows), Display (3 rows), Providers (1 row: active provider + chevron to detail), About (3 rows). Each group uses a single `--surface-panel` card with 0-pt internal dividers and 16-pt vertical padding. |

Primary action: tap the active provider row to open the provider detail. Every other row is secondary.

### Screen: Trip detail (push from Trips)

| Today | Tomorrow |
| --- | --- |
| `TrainDetailView` is a 12-section vertical stack: `RouteHeaderPanel`, `StatusSummaryPanel`, `SourceProvenancePanel`, `RailJourneyMapPanel`, `JourneyProgressPanel`, Stop timeline panel, `TransferWarningCard`, Carriage/platform panel, Notes panel, Alerts panel, ShareLink. | `TrainDetailView` becomes a 4-section screen. **Section 1 — Hero**: `Display` time, `H1` city, `H3` train number + status pill on the right. **Section 2 — 2-column body**: left column = Next stop, ETA, Platform, Speed; right column = the rail map (400-pt tall, single map, no second mode toggle). **Section 3 — Stops**: a single flat list with no inner glass. **Section 4 — Source**: a 4-row flat list with one "Open source" link. A sticky footer holds "Open rail map" (primary) and "Share" (secondary). |

Primary action: "Open rail map". Secondary: "Share", "Notify", "Refresh" (icon buttons in the footer).

### Screen: Rail map (push from detail)

| Today | Tomorrow |
| --- | --- |
| `RailJourneyMapScreen` opens with a 610-pt `RailJourneyMapPanel(style: .full)`, then a "Route intelligence" header, then a `LazyVStack` of `RailMapInsightCard`s and `RailMapStopDetailCard`s. | Map screen opens with a full-bleed map (1.0× screen height), a floating top-right control (a single "Re-center" icon button, no "Route/Stops/Disruptions" mode), a floating bottom-left status pill (next stop + ETA), and a sticky bottom sheet (24-pt top radius) that shows insights as a 2-column grid and stops as a single flat list. |

Primary action: scroll the bottom sheet. Re-center and the segmented control are gone.

### Screen: Source detail (modal)

| Today | Tomorrow |
| --- | --- |
| `SourceDetailSheet` opens with 3 stacked `GlassPanel`s: a hero panel (badge + source name + rider explanation + breakdown), a metadata panel (5 `SourceMetadataLine`s + optional `Link`), a "Fact Sources" panel (one `SourceFactRow` per fact). | The sheet opens with a single 24-pt panel: `H1` source name, `Body` rider explanation, 4 rows (Provider, Source type, Confidence, Freshness), one "Open source" link, and a "Fact mix" caption. No nested panels. |

Primary action: "Open source" link (or Done on the right). Single CTA.

### Screen: First-run experience (modal)

| Today | Tomorrow |
| --- | --- |
| `FirstRunExperienceSheet` is a `ScrollView` with `FirstRunHeader` (icon + 2-line title + 4-line subtitle), `FirstRunDefaultProviderCard` (hero glass), "Data scope" panel with 3 `FirstRunScopeRow`s, an amber "Planned regions are roadmap entries" panel, and a sticky `FirstRunActionBar` with "Start with Shinkansen" + "Explore planned regions" + a "Skip" toolbar button. | Sheet opens with a single hero: `H1` "Welcome to Trainy", `Body` "Japan Shinkansen is ready. We'll always show the source of every fact." A single primary CTA "Start with Shinkansen". Below that, a 3-row "What each label means" card with no glass. Skip stays in the toolbar. |

Primary action: "Start with Shinkansen". One CTA. The "Explore planned regions" button moves to a secondary "Skip for now" link inside the hero.

### Screen: Provider detail (push from Settings)

| Today | Tomorrow |
| --- | --- |
| `SupportedRegionsScreen` opens with a `GlassPanel(hero)` containing a 42-pt globe icon + 2-line title + 3-line subtitle + `SupportedRegionsMap` (318-pt MKMapView globe) + a `CoverageLegendItem` row. Below: "Search coverage" `SettingsGroup` with `SupportedRegionProviderRow`s + "Muted regions" `SettingsGroup` with a `SupportedRegionPillGrid`. | Screen opens with a single hero: `H1` "Supported regions", `Body` "Japan is the active region. Other regions appear here as their adapters, credentials, and source labels become ready." Below: a single 16-pt panel containing a vertical list of regions. Each row: region name + status pill + optional "Coming soon" caption. The MKMapView globe is replaced by a list — the map is decorative and the list is more honest. |

Primary action: scroll. There is no primary action on this screen.

### Screen: Provider directory (push from Settings)

| Today | Tomorrow |
| --- | --- |
| `ProviderDirectoryList` is a `ForEach` of `ProviderDirectoryRow`s inside `GlassPanel` with dividers. Each row has an `Image(systemName)` icon, name, capability strip, source disclosure, credential status, requirement summary, and (if applicable) "Use provider" button. | Screen opens with a single 16-pt panel containing a vertical list of providers. Each row: provider name + status pill + "Schedule + Reatime" caption. Tap to open detail. No inline credential disclosure — that lives in the detail. |

Primary action: scroll. Tap a row to open detail.

### Screen: Provider detail (push from provider directory)

| Today | Tomorrow |
| --- | --- |
| Provider detail lives inside `ProviderDirectoryRow`'s body — there is no dedicated detail screen. | Add a `ProviderDetailView` (push from the directory). Hero: provider name + status pill. Below: 4 rows (Region, Capabilities, Source, Credential). One CTA at the bottom: "Use this provider" (only when available). |

Primary action: "Use this provider". One CTA.

---

## Common patterns

### Empty state across all screens

Today: `EmptyStateView` with a glass icon, `headline` title, `subheadline` message, optional `FloatingGlassButton`. Three layers of glass for one empty state.

Tomorrow: flat 16-pt panel with a 48-px tinted icon (no glass), `H2` title, `Body` message, optional 44-pt primary button. One layer. Used identically across Trips, Search, Stations, History, Settings, Provider detail, Source detail.

### Loading state across all screens

Today: `LoadingSkeletonView` with 3 redacted `GlassPanel` rows.

Tomorrow: same shape, but the rows use `--surface-inset` and a 1.4s linear shimmer. No glass. Used identically across all data-loading screens.

### Source badge across all screens

Today: `SourceBadge` with `railLiquidGlass`, 30-pt tall, 128/164/172/220-pt wide depending on verbosity + style. Width animates as the verbosity preference changes.

Tomorrow: a 24-pt tall flat pill, 80-pt wide, `--ink-default` text on `--surface-inset`. The optional freshness dot uses `--status-success` / `--status-warning` / `--status-danger`. Single fixed width.

### Status pill across all screens

Today: `ServiceStatusPill` uses `railLiquidGlass`, 30-pt tall, 13-pt corner radius, tinted. Three different sizes for live / board / active.

Tomorrow: a 24-pt flat pill, `--status-success` / `--status-warning` / `--status-danger` solid fill or soft fill depending on context. Single size. Icon always present.

### Timeline row across all screens

Today: `StopTimelineRow` is a 28-pt circle (with a 2x44-pt connector line) + station name + platform chip + note. The connector is a manual `Rectangle().fill(LinearGradient(...))` 2-pt wide.

Tomorrow: a 16-pt vertical column with a 2-pt left accent line and a 12-pt dot at each stop. The connector is automatic (`border-left` / `border-top`) on the column.

---

## Interaction model

### Hover (web)

- Card: `--elev-1` -> `--elev-2`. No tint shift.
- Button: `--ink-strong` background -> `--ink-strong` with 95% lightness. No transform.
- Link: `--ink-default` underline appears.

### Focus

- 2-pt ring with `--status-info` at 30% alpha, 2-pt offset. Always visible on `:focus-visible`.

### Pressed

- `scale(0.96)` over 120ms ease-out. No color change.

### Loading

- Shimmer: `linear-gradient` from `--surface-inset` to `--surface-panel` and back, 1.4s linear infinite. No pulse.

### Success

- Inline checkmark + green tint for 600ms, then fade to `--ink-default` text.

### Error

- Inline `--status-danger` text and 4-pt left border for the lifetime of the error.

---

## Implemented screen outcomes — 2026-06-24

| Screen | Before | Implemented after |
| --- | --- | --- |
| Trips | Duplicate title chrome, selected trip repeated in the list, stacked cards for hero and tools | Inline title, compact scope row, concentric segmented control, one active-trip surface, additional active journeys separated below |
| Search | Dense hero copy plus duplicated capability explanation and an extra suggested-route grid | Compact scope row, contextual capability banner, "Try a search", favorite stations, then results |
| Stations | Three colored metric cards inside every station card | One scan-friendly row with station, status, and a single departures/tracks/routes line |
| History | Summary and three highlights with no primary path forward | Summary, spaced highlights, and Recent Journeys navigation |
| Settings | Correct but developer-like provider wording and no way to revisit onboarding | Friendly credential copy, provider detail as the primary row, and an Onboarding Guide action |
| Supported regions | Flat list of every region with repetitive "Coming soon" pills | Honest globe markers for implemented regions, Available Now provider rows, and a muted Planned Regions grid |
| Trip detail | Interactive map trapped vertical gestures; tab bar covered lower content | Compact map navigation card, visible stop timeline, tab bar hidden, full scroll remains responsive |
| Rail map | Low-contrast overlay materials and `Starter · Unk` source badge | Regular-material overlays, stronger platform contrast, compact `Starter` badge, dedicated full-screen map interaction |
| First run | Strong composition but invalid lead symbol rendered blank | Valid seal symbol, one clear primary action, secondary region exploration, and concise provenance guidance |

Primary-action status after implementation:

| Screen | Primary action |
| --- | --- |
| Trips | Open rail map for the active trip; Add Trip remains the creation action |
| Search | Search field / Track result |
| Stations | Open station |
| History | Open recent journey |
| Settings | Open active provider coverage |
| Supported regions | Review implemented providers and planned coverage |
| Trip detail | Open rail map |
| Rail map | Re-center and inspect route/stops |
| First run | Start with Shinkansen |
