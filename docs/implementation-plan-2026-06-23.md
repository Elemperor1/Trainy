# Implementation Plan

Date: 2026-06-23
Companion to `docs/design-audit-2026-06-23.md`, `docs/design-system-2026-06-23.md`, `docs/screen-redesign-2026-06-23.md`.

This is the execution order. Items 1-4 are the critical path. Items 5-7 are the polish that turns the redesign into Linear/Stripe-quality. Items 8-10 are guardrails that lock the work in.

Each phase has a single acceptance signal: the visible output (browser screenshot / Xcode build) matches the spec, and the existing test + guardrail suite still passes.

---

## Phase 1 — Design tokens land (1-2 hours)

Goal: every screen routes through the new tokens. Nothing looks different yet, but the foundation is in place.

### 1.1 Web: rewrite `:root` in `styles.css`

Add `--space-{1,2,3,4,6,8,12,16}`, `--radius-{control,card,panel,pill,station}`, `--ink-{strong,default,muted,disabled}`, `--surface-{canvas,panel,elevated,inset}`, `--status-{success,warning,danger,info}` plus their `-soft` variants, `--line`, `--elev-1`, `--elev-2`. Keep `--ink`, `--muted`, `--subtle`, `--paper`, `--panel`, `--line`, `--line-strong`, `--green`, `--red`, `--amber`, `--blue`, `--teal`, `--charcoal`, `--success`, `--warning`, `--danger`, `--info` as aliases during migration so existing CSS still parses. (They will be deleted at the end of Phase 7.)

### 1.2 iOS: rewrite `RailDesign.Spacing` and `RailDesign.Radius` in `RailDesignSystem.swift`

Replace `xxs/xs/s/l/xl/xxl` with the new scale. Replace `xs/sm/chip/control/panel/hero` with the new scale. Keep the type aliases (`Spacing.m`, `Radius.panel`) compiling by giving the new tokens the same names.

### 1.3 iOS: collapse `RailDesign.Palette`

Remove the decorative `marine`, `violet`, `copper`, `amber` colors. Keep `background`, `panel`, `inset`, `ink`, `secondaryText`, `accent`, `success`, `warning`, `danger`, `info`, `hairline`. Add `inkStrong` and `inkMuted`. Add `-soft` variants of every status color.

### 1.4 iOS: collapse `RailDesign.Typography`

Replace `largeTitle / title / metricValue / routeTitle / headline / body / callout / compactLabel / caption / micro` with the new `display / h1 / h2 / h3 / body / small / caption`. Keep `body` as an alias so existing call sites compile.

### 1.5 Guardrail: extend `scripts/check-design-system-bypass.sh`

Deferred with the web migration: add a rule so any new CSS rule outside `:root` containing a numeric `padding`/`margin`/`gap`/`border-radius` value must reference a `--space-*` or `--radius-*` token. The repository records this boundary, but enforcement remains dormant while the legacy web prototype is out of scope.

### Acceptance

- Deferred acceptance item: migrate web spacing/radius values, enable the dormant rule, and then require `bash scripts/check-design-system-bypass.sh` to pass with that rule active.
- `node --check app.js` passes.
- Web app renders identically (we changed names, not values yet).

---

## Phase 2 — Critical iOS issues (2-3 hours)

Goal: the Trip detail stops being a glass tower.

### 2.1 Rewrite `TrainDetailView`

Replace the 12-section vertical stack with a 4-section layout:
- Section 1 — Hero (24-pt panel): `Display` time, `H1` station, `H3` train + status pill.
- Section 2 — 2-column body (using `HStack` with `.frame(maxWidth: .infinity)`): left = metrics (Next stop, ETA, Platform, Speed), right = map (`RailJourneyMapPanel(style: .detail)`).
- Section 3 — Stops (single flat list, no inner glass).
- Section 4 — Source (single flat list, no inner glass).

Add a sticky footer with "Open rail map" (primary) + "Share" (secondary).

### 2.2 Remove the duplicate `StatusSummaryPanel`

The active-trip summary on Trips already shows Status/Platform/Updated. Delete the redundant `StatusSummaryPanel` (and its `ViewThatFits`) entirely.

### 2.3 Strip `railLiquidGlass` from inner controls

`StationBadge`, `SourceBadge`, `SummaryIconLabel`, `TripOpenCue`, `RailMapControls` buttons — remove `railLiquidGlass` and use a flat `--surface-inset` background with a 1-pt border.

### 2.4 Stop calling `EmptyStateView`'s icon a glass disc

Replace the 64-pt `railLiquidGlass(cornerRadius: 32)` with a flat 48-pt tinted circle using `--accent` at 12% alpha and an SF Symbol at `.large` weight.

### Acceptance

- `xcodebuild build ...` for the iOS Simulator destination succeeds.
- `bash scripts/check-design-system-bypass.sh` passes.
- The trip-detail screen visually drops from ~8 nested panels to 4.

---

## Phase 3 — Critical web issues (1-2 hours)

Goal: the web prototype loses the AI-generated signals.

### 3.1 Replace single-letter icons with inline SVG

Replace `<span aria-hidden="true">R</span>` etc. with `<svg>` paths for `rotate-cw`, `more-horizontal`, `magnifying-glass`, etc. Inline; no library.

### 3.2 Calmer top bar

Drop the 1-pt hairline border. Use `--elev-1` shadow only. Drop the 2-px pseudo-element magnifier; replace with a single inline SVG.

### 3.3 Live panel hero

Drop the 4.2-rem hero headline. Replace with `H2` (28-px) "JR Central · Tokaido Shinkansen" + `H1` (28-px) "Nozomi 231" + status pill on the right.

### 3.4 Metric row collapses to one line

Replace the 4-cell `.metric-row` with a single horizontal rule: "Next stop Nagoya · ETA 10:58 · Platform 18 · Speed 258 km/h". Each fact is a `<span>` with optional dot separator.

### 3.5 Intelligence panel: drop the dark `.next-action` panel

Replace with an accent-tinted soft-fill panel. Use `--status-info` (or `--accent`) at 8% alpha.

### 3.6 Remove the dashed-border empty state

Replace with a flat `--surface-panel` card with a 48-px tinted circle icon + `H2` title + `Body` message + a single 36-pt primary CTA "Add trip".

### Acceptance

- `bash scripts/check-design-system-bypass.sh` passes.
- The web app no longer shows single-letter icons.

---

## Phase 4 — First-run experience (1 hour)

Goal: the first-run sheet has one CTA, not three.

### 4.1 iOS: rewrite `FirstRunExperienceSheet`

Collapse to: hero (`H1` "Welcome to Trainy", `Body` "Japan Shinkansen is ready."), one primary CTA "Start with Shinkansen", one secondary link "Explore planned regions". The data-scope panel stays but with no glass; the amber warning panel stays but with no glass.

### 4.2 iOS: kill the redundant `FirstRunDefaultProviderCard`

The active provider is shown in Settings already. The first-run card adds visual weight to a screen that should be inviting. Keep the data-scope card; drop the provider card.

### Acceptance

- `xcodebuild build ...` succeeds.
- First-run shows one primary CTA.

---

## Phase 5 — Settings consolidation (1-2 hours)

Goal: settings fits on one screen.

### 5.1 iOS: collapse `SettingsScreen`

Drop the hero panel. Drop the "Privacy", "Support", "Developer" groups. Keep "Notifications" (2 rows), "Display" (3 rows), "Providers" (1 row linking to detail). The Providers detail is `SupportedRegionsScreen`, which is also rewritten (see Phase 6).

### 5.2 iOS: rewrite `SupportedRegionsScreen`

Replace the 318-pt MKMapView globe with a vertical list of regions. Each row: region name + status pill + optional "Coming soon" caption.

### Acceptance

- Settings fits on a 6.3-inch iPhone screen with no scrolling.
- The supported regions screen has no MKMapView.

---

## Phase 6 — Stations and History consolidation (1 hour)

Goal: the dashboard stops being a metric pile.

### 6.1 iOS: rewrite `HistoryScreen`

Drop the 6-tile metric grid. Replace with a single line: "X trips · Y stations visited · Z operators used". The "Journey highlights" section collapses to a single `H2` + 3 lines.

### 6.2 iOS: collapse `StationOverviewPanel` and `StationCard`

Drop the 2-stat strip. Show only the station count + status pill.

### Acceptance

- History screen scrolls once (or not at all).
- Stations screen scrolls naturally.

---

## Phase 7 — Typography & spacing pass (1-2 hours)

Goal: every screen snaps to the new grid.

### 7.1 iOS: walk every `GlassPanel` and `Text`

Replace `Font.system(.largeTitle, design: .rounded).weight(.bold)` with `RailDesign.Typography.h1` etc. Replace ad-hoc `padding(14)` etc. with `padding(RailDesign.Spacing.m)` etc.

### 7.2 Web: walk every component rule in `styles.css`

Replace `padding: 14px` with `padding: var(--space-3)`, etc. Remove every `font-size: 0.78rem` literal; use `var(--fs-caption)`.

### 7.3 Web: delete the legacy tokens

Once every CSS rule references the new tokens, delete `--ink`, `--muted`, `--subtle`, `--paper`, `--panel`, `--line`, `--line-strong`, `--green`, `--red`, `--amber`, `--blue`, `--teal`, `--charcoal`, `--success`, `--warning`, `--danger`, `--info`, `--success-bg`, `--warning-bg`, `--danger-bg`, `--info-ring`, `--overlay`, `--overlay-soft`, `--overlay-lift`, `--overlay-faint`, `--overlay-hairline`, `--shadow-sm`, `--shadow`, `--shadow-lg`, `--radius-sm`, `--radius`, `--radius-lg`, `--radius-pill`, `--space-1..6`, `--fs-eyebrow`, `--fs-body`, `--fs-title`, `--dur-fast`, `--dur`, `--dur-slow`, `--ease`. The guardrail fails if any rule still references them.

### Acceptance

- `bash scripts/check-design-system-bypass.sh` passes.
- Grep for `0.78rem`, `14px`, `clamp(1.8rem` etc. returns nothing in `styles.css`.

---

## Phase 8 — Motion (1 hour)

Goal: motion exists where it helps comprehension; nowhere else.

### 8.1 iOS: standardize on a single timing curve

`Animation.timingCurve(0.2, 0, 0, 1, duration: 0.18)` for micro. Spring `response:0.36, damping:0.86` for sheet presentations. No more `RailDesign.Motion.soft` references outside the library.

### 8.2 iOS: stagger list-item entrances

For each `List` / `LazyVStack`, wrap `ForEach` in `.animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: store.trips.count)` and use a 40-ms × index delay via `.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))`.

### 8.3 Web: add `cubic-bezier(0.2, 0, 0, 1)` to `:root`

Use it on every transition. Add a 1.4-s linear shimmer for skeletons. Honor `prefers-reduced-motion`.

### Acceptance

- All transitions use the new timing curve.
- Skeleton shimmer uses linear easing.

---

## Phase 9 — Iconography (1 hour)

Goal: icons match the typography scale.

### 9.1 iOS: standardize SF Symbol scales

For chips/pills: `.imageScale(.small)`. For card icons: `.imageScale(.medium)`. For hero icons: `.imageScale(.large)`. The `font(.system(size: 46))` and `font(.system(size: 54))` calls in `FirstRunHeader` and `SettingsScreen` become `font(.largeTitle)`.

### 9.2 Web: standardize inline SVG sizing

`<svg width="16" height="16" stroke-width="1.75">` for chips, `20` for card icons, `24` for hero icons. All use `currentColor`.

### Acceptance

- No more `font(.system(size: NN))` outside the design system.

---

## Phase 10 — Accessibility pass (1 hour)

Goal: WCAG AA throughout, focus visible everywhere.

### 10.1 Web: add `:focus-visible` ring

```css
:focus-visible {
  outline: 2px solid var(--status-info);
  outline-offset: 2px;
  border-radius: var(--radius-control);
}
```

### 10.2 Web: extend hit areas

Every visible icon smaller than 40x40 extends with `::before` 40x40 hit area.

### 10.3 iOS: ensure 44x44 hit areas

`SummaryIconLabel`, `TripOpenCue`, `RailMapControls` buttons use `.frame(minWidth: 44, minHeight: 44)` and `.contentShape(Rectangle())`.

### 10.4 iOS: ensure 4.5:1 contrast for `--ink-muted` on `--surface-panel`

Verify by running `xcrun simctl` with the simulator's contrast settings on. Adjust `--ink-muted` if it falls below 4.5:1.

### Acceptance

- VoiceOver reads every status pill as "On time, scheduled, fresh".
- Keyboard tab order on web matches visual order.
- 4.5:1 contrast verified for all text.

---

## Phase 11 — Verification (1-2 hours)

Goal: prove the redesign works.

### 11.1 iOS: build for simulator

`xcodebuild -project TrainyIOS/Trainy.xcodeproj -scheme Trainy -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /private/tmp/trainy-derived ... CODE_SIGNING_ALLOWED=NO build`

### 11.2 Web: build the preview

`python3 -m http.server 4173`. Open in Chrome at 1440×900 and 390×844.

### 11.3 Capture screenshots

Use `npx playwright` to capture:
- web/1440/desktop.png
- web/390/mobile.png
- iOS/iPhone-17-Trips.png (if the simulator is available)
- iOS/iPhone-17-Detail.png

### 11.4 Run the guardrails

```bash
bash scripts/check-design-system-bypass.sh
bash -n scripts/build-ios.sh
bash -n scripts/smoke-odpt.sh
node --check app.js
```

### Acceptance

- All four scripts pass.
- Screenshots match the spec.

---

## Phase 12 — Documentation & handoff (1 hour)

### 12.1 Update `docs/design-audit-2026-06-23.md` with the "Done" section

Append a section listing what changed, with file:line references for each fix.

### 12.2 Update `docs/design-system-2026-06-23.md` with examples

Add a "Usage examples" section showing how to use each token in iOS and web.

### 12.3 Update `docs/Provider_Status.md` with a note about the visual refresh

Add a single sentence to the top: "Visual design refreshed 2026-06-23. The provider status matrix is unchanged."

### Acceptance

- Every doc updated.
- `git diff --check` passes.

---

## Risks and mitigations

- **Token renames break call sites.** Mitigation: Phase 1 keeps type aliases and CSS variables under both old and new names.
- **`xcodebuild` for simulator may not run in the sandbox.** Mitigation: rely on `node --check`, `bash -n`, and the Playwright web preview. Document that the iOS build is verified in the user's local environment.
- **The redesign touches 3,400 lines of `ContentView.swift`.** Mitigation: do it in the 4-section rewrite (Phase 2.1) instead of incremental refactors.
- **`scripts/check-design-system-bypass.sh` was designed for the old tokens.** Mitigation: extend the rule before deleting the old tokens.

---

## Phase 16 — Runtime correction and final simulator polish (completed 2026-06-24)

Goal: close the gap between code-level polish and the product as it actually behaves on an iPhone.

### Completed

| Before | After |
| --- | --- |
| Redesigned app failed to compile in `StationsScreen` | Station navigation expression simplified; app builds and launches |
| Root screens used empty large-title chrome | Root screens use compact inline titles |
| Trips duplicated the selected active trip and pinned its section header | One active hero, non-pinned "More active journeys" section |
| Active journey used separate hero and tools surfaces | One panel with a divider and compact 44-pt horizontal actions |
| Compact source badge included `Unk` | Unknown freshness omitted in compact presentation |
| Stations used three metric cards per row | Single metadata line per station |
| History had no action | Recent journeys navigate to detail |
| Trip Detail embedded an interactive map inside its scroll | Map navigation card opens the dedicated map screen |
| Pushed screens kept the tab bar | Detail destinations hide the tab bar |
| Supported Regions was a repetitive flat list | Registry-backed globe, Available Now rows, and planned-region disclosure |
| Onboarding symbol rendered blank | Valid `checkmark.seal.fill` symbol |

### Verification evidence

```text
XcodeBuildMCP build_run_sim: SUCCEEDED
Simulator: iPhone 17
Bundle: com.jacobcyber.Trainy

XcodeBuildMCP test_sim (TrainyTests):
27 passed, 0 failed, 0 skipped

bash scripts/check-design-system-bypass.sh:
passed

git diff --check:
passed
```

Runtime screens inspected:

- First-run sheet
- Trips at top and scrolled list states
- Search discovery and results
- Stations list and station detail
- History
- Settings
- Supported regions
- Trip detail
- Full rail map

The earlier simulator-unavailable risk is resolved for this phase; the app was built, launched, interacted with, and captured in the simulator.
