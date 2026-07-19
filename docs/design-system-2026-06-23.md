# Trainy Design System Specification

Date: 2026-06-23
Applies to: iOS (`Sources/TrainyCore/`) + web prototype (`index.html`, `styles.css`).

The system is the single source of truth. Every screen, component, and animation must route through these tokens. The legacy `RailDesign.Spacing` and `--space-*` scales are replaced.

---

## 1. Spacing scale

Required scale: `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64`. Adopted everywhere.

| Token | Value (pt / px) | When to use |
| --- | --- | --- |
| `--space-1` | 4 | Optical nudges only (icon-to-text vertical alignment, never as standalone padding). |
| `--space-2` | 8 | Inline gap inside a chip / pill / button. |
| `--space-3` | 12 | Inter-row spacing inside a card. |
| `--space-4` | 16 | Card internal padding (default). |
| `--space-6` | 24 | Inter-card spacing in a list. |
| `--space-8` | 32 | Section spacing inside a screen. |
| `--space-12` | 48 | Screen-edge inset on the bottom of the longest scroll content. |
| `--space-16` | 64 | Hero gutter on iPad / desktop web. |

iOS: `RailDesign.Spacing` becomes `xxs = 4, xs = 8, s = 12, m = 16, l = 24, xl = 32, xxl = 48, hero = 64`. The 20/28/36 half-step values are removed; everything snaps to the new grid.

Web: `:root` exposes `--space-{1..16}` (and the numeric values for the actual steps). All margin/padding/gap declarations use these tokens; no `4px`, `8px`, etc. literals in component CSS.

---

## 2. Typography

Required scale: `Display / H1 / H2 / H3 / Body / Small / Caption`. Adopted everywhere.

| Token | iOS font | Web font / size | Use |
| --- | --- | --- | --- |
| `Display` | `.system(size: 36, weight: .bold, design: .rounded)` | `Inter Tight 600, 40/44, letter-spacing -0.02em` | Hero journey times; 36 pt preserves an optical gap between two 12-hour timestamps on iPhone |
| `H1` | `.system(.title, weight: .semibold, design: .rounded)` | `Inter 600, 28/32, letter-spacing -0.01em` | Screen titles (Trips, Search, Stations, History, Settings) |
| `H2` | `.system(.title3, weight: .semibold, design: .rounded)` | `Inter 600, 18/24, letter-spacing 0` | Section headers (rail map, journey progress) |
| `H3` | `.system(.headline, weight: .semibold, design: .rounded)` | `Inter 600, 15/20, letter-spacing 0` | Card titles, list-item titles |
| `Body` | `.system(.body, weight: .regular, design: .default)` | `Inter 400, 14/20, letter-spacing 0` | Default body copy |
| `Small` | `.system(.subheadline, weight: .regular, design: .default)` | `Inter 400, 13/18, letter-spacing 0` | Secondary metadata inside cards |
| `Caption` | `.system(.caption, weight: .medium, design: .default)` | `Inter 500, 11/14, letter-spacing 0.04em, uppercase` | Eyebrow text only ("JR Central", "Updated now", "Starter catalog") |

Rules:
- **Optical alignment**: numerals use `font-variant-numeric: tabular-nums` (web) and `.monospacedDigit()` (iOS).
- **Headings** use `text-wrap: balance` (web) and `.lineLimit(1)` with `.minimumScaleFactor(0.7)` (iOS).
- **No more than 3 type steps per screen**. Trips tab: `Display` (the time), `H2` (the city), `Small` (the meta). That is it.
- **Font smoothing**: web applies `-webkit-font-smoothing: antialiased` on `body`; iOS uses system defaults.

---

## 3. Color

Single semantic palette. Tints live behind semantic aliases; brand colors only appear when explicitly branded (active provider, brand mark).

### 3.1 Surface

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--surface-canvas` | `#F7F8FA` | `#0E1114` | Page background |
| `--surface-panel` | `#FFFFFF` | `#181B20` | Default card / panel |
| `--surface-elevated` | `#FFFFFF` | `#1F232A` | Modal / sheet |
| `--surface-inset` | `#F2F4F7` | `#15181D` | Inset regions (search field, segmented control track) |

### 3.2 Ink

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--ink-strong` | `#0E1114` | `#F2F4F7` | Headings, hero values |
| `--ink-default` | `#1F232A` | `#E1E5EA` | Body copy |
| `--ink-muted` | `#5B6371` | `#A0A8B4` | Secondary metadata |
| `--ink-disabled` | `#A0A8B4` | `#5B6371` | Disabled controls |

### 3.3 Semantic status

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `--status-success` | `#0F7A5C` | `#3FBA94` | On time, healthy proxy, fresh source |
| `--status-warning` | `#B5701A` | `#E5A445` | Boarding, stale, watch |
| `--status-danger` | `#B8382B` | `#E26659` | Delayed, canceled, disruption, expired |
| `--status-info` | `#1F5BB6` | `#7AAEEB` | Provider updates, source disclosed |

Each semantic color exposes a **strong fill** (for icons / solid pills) and a **soft fill** (`-soft`) at 12% alpha for backgrounds.

### 3.4 Brand accent

A single accent: `#0E5F4E` (deep teal). Used for the active tab, the primary CTA, the rail line on the route, and the brand mark.

### 3.5 Hairline

`--line: rgba(15,17,21,0.08)` (light) / `rgba(255,255,255,0.08)` (dark). Use only on inset regions. Prefer shadows over borders (see Section 5).

iOS: `RailDesign.Palette` collapses to `background / panel / inset / ink / secondaryText / accent / success / warning / danger / info` and their `*-soft` variants. The decorative `marine / violet / copper / copper / amber / mint / red / blue` colors are removed.

---

## 4. Radius

Required scale: `8 / 12 / 16 / 24 / full`. Adopted everywhere.

| Token | Value | Use |
| --- | --- | --- |
| `--radius-control` | 8 | Buttons, inputs, segmented control buttons |
| `--radius-card` | 16 | Default cards |
| `--radius-panel` | 24 | Hero panels, sticky CTA cards, large sheets |
| `--radius-pill` | 999 | Status pills, source badges, segmented indicator |
| `--radius-station` | 12 | Station / map pins |

Concentric rule: outer radius = inner radius + padding between them. Card padding 16 on a card with radius 16 -> inner content uses radius 0 (full bleed if needed) or 8 (when nested controls are inside).

iOS: `RailDesign.Radius` collapses to `xs = 8, sm = 12, control = 16, panel = 24, pill = 999`. The decorative `chip / hero / 28 / 30 / 34` values are removed.

---

## 5. Elevation

Two shadow levels. No decorative drop shadows on every card. Borders used only inside inset regions.

| Token | CSS | iOS | Use |
| --- | --- | --- | --- |
| `--elev-1` | `0 1px 2px rgba(15,17,21,0.06), 0 1px 0 rgba(15,17,21,0.04)` | `y:1, blur:2, opacity 0.06` | Resting cards |
| `--elev-2` | `0 6px 18px rgba(15,17,21,0.10), 0 2px 4px rgba(15,17,21,0.06)` | `y:8, blur:18, opacity 0.10` | Hovered / focused / floating buttons |

iOS: `RailDesign.Elevation.resting` and `.raised` map to the above values. The `.hero` value is removed; hero panels use `elev-2` only when interactive (e.g., the "Open rail map" CTA), otherwise they sit on the canvas with no shadow.

---

## 6. Components

### 6.1 Buttons

| Type | Use | Treatment |
| --- | --- | --- |
| Primary | One per screen. The action the user came to do. | Filled, `--ink-strong` background, `--surface-canvas` text, `--radius-control`, 44-pt minimum height. |
| Secondary | Supporting actions. | Outlined, transparent background, `--line` border, `--ink-default` text. |
| Tertiary | Inline link-style actions. | No border, no fill, `--ink-default` text, underline on hover. |
| Icon | Toolbars / list rows. | 40x40 hit area minimum (extend with pseudo-element if visible icon is smaller), `--radius-control`, `--surface-inset` fill, `--ink-default` icon. |

Press state: `scale(0.96)` over `120ms` ease-out (web and iOS). Use `transform`/`scale` only; never `transition: all`. Focus state: 2-pt ring with `--status-info` at 30% alpha.

### 6.2 Forms

Inputs are 44-pt tall, 16-pt corner radius, `--surface-panel` background, `--line` 1-pt border, `--ink-default` placeholder, 13-pt `Small` label above (not inside). Focus border switches to `--status-info`. No floating labels.

### 6.3 Cards

Default card: 16-pt corner radius, `--surface-panel` fill, `--elev-1` shadow, 16-pt internal padding. Hero card: 24-pt corner radius, no shadow, sits directly on canvas. Never nest a card inside another card; flatten or compose vertically.

### 6.4 Status pills

44-pt tall max, 24-pt corner radius (pill), single semantic color (`--status-success` / `--status-warning` / `--status-danger` / `--status-info`). Solid fill when the status is the primary information; soft fill when it accompanies other content.

### 6.5 Source badges

A content-sized pill that says "Scheduled" / "Prediction" / "Position" / "Alert" / "Starter". It may use a low-alpha source-kind tint for recognition, but never a saturated fill. Freshness is shown only when the state is meaningful; compact badges omit unknown freshness instead of leaking `Unk` into rider-facing UI.

### 6.6 Dialogs

Modal sheets use `--surface-elevated` with `--radius-panel` top corners. Detents: `.medium` for confirmations, `.large` for content-heavy sheets. Drag indicator visible. No `interactiveDismissDisabled` except on first-run.

### 6.7 Tables

The web prototype's `.trip-list` is a stack of cards, not a table. We treat it as a list with clear row rhythm: 12-pt vertical padding inside each row, 16-pt row-to-row gap, divider line omitted (the card surface itself acts as the row).

### 6.8 Loading

iOS: `LoadingSkeletonView` keeps its redacted placeholder but uses `--surface-inset` instead of nested glass. Web: same — a flat rounded block that shimmers with a single linear gradient (animation `1.4s linear infinite`). No glass.

### 6.9 Empty

Empty states use `--surface-panel` background, 48-pt flat tinted circle for the icon (no glass), `H2` title, `Body` message, single optional primary CTA below. Never use a dashed border on the web.

### 6.10 Error

Inline error below an input uses `--status-danger` text and a 4-pt left border in `--status-danger`. Banner-level errors sit on `--status-danger-soft` background with `--status-danger` border-left.

---

## 7. Navigation

iOS:
- Tab bar at 49-pt + 34-pt home indicator; ultraThin material blur, `--surface-panel` tint, `--ink-default` inactive, `--accent` active.
- Active tab uses a 5x5-pt dot above the icon (Linear-style) plus `--accent` icon. No `selected.iconColor` only.
- Navigation bar: inline title on top-level and pushed screens. Top-level content supplies its own hierarchy below the bar; this removes the empty large-title band beneath the Dynamic Island.
- No `safeAreaInset(.bottom) { Color.clear }`. Use `safeAreaInset(.bottom) { floatingButton }` for floating CTAs instead.

Web:
- Sticky top bar, 56-pt tall, no border (use `--elev-1` shadow only), brand mark + global search + 2 utility buttons.
- Three-column main grid: trips list (320-px), live panel (1fr), intelligence panel (320-px). Collapses to single column below 860-px.
- Active trip card uses `--accent` 2-pt left border instead of a tinted background.

---

## 8. Motion

- Durations: 120ms (micro), 180ms (default), 280ms (large).
- Easing: `cubic-bezier(0.2, 0, 0, 1)` everywhere (web). iOS: `Animation.timingCurve(0.2, 0, 0, 1, duration: 0.18)` for micro; spring `response:0.36, damping:0.86` only for sheet presentations.
- Transitions: opacity + transform only; never `transition: all`. iOS: `transition(.opacity.combined(with: .move(edge: .bottom)))`.
- Stagger: list-item enter animations use 40ms × index for up to 8 items, then cap.
- No decorative animation. No shimmer on static content. No rotating train icon.
- Honor `prefers-reduced-motion: reduce`: zero duration, no stagger, no parallax.

---

## 9. Iconography

- Web: inline SVGs at 16/20/24-pt, currentColor stroke at 1.75-pt. Lucide icons in the same set are not allowed (the team chose system icons for parity with iOS).
- iOS: SF Symbols. `imageScale(.medium)` for chips, `.large` for hero. `symbolRenderingMode(.hierarchical)` for accent-tinted icons.
- Optical alignment: chevron-right icons sit +1-pt below the text baseline. Caret-up and caret-down sit at the same x-height as the surrounding text.

---

## 10. Accessibility

- Contrast minimum: 4.5:1 for text on `--surface-canvas`; 3:1 for text on `--surface-panel`.
- Focus ring always visible (`:focus-visible` only). 2-pt ring with `--status-info` at 30% alpha, 2-pt offset.
- Hit area minimum 40x40-pt; extend with a pseudo-element (`::before`) on small icons.
- VoiceOver: every status pill reads as "On time, scheduled data, fresh". Every source badge reads as "Scheduled timetable source, fresh, JR Central".
- Motion: respect `prefers-reduced-motion` and `accessibilityReduceTransparency`. Glass falls back to `--surface-panel` with a 1-pt `--line` border.

---

## 11. Compliance with the existing design-system guardrail

`scripts/check-design-system-bypass.sh` already enforces:
- iOS: no raw color literals, no `.glassEffect(...)`, no `RoundedRectangle(cornerRadius: <number>)` outside the library, no `Color.black/.white/.gray`.
- Web: `app.js` may not construct component HTML inline; `styles.css` may not hardcode colors outside the `:root` token layer.

We extend the guardrail with one rule:
- Web: any new CSS file must use `--space-*` / `--radius-*` / `--ink-*` / `--status-*` tokens; numeric values trigger a violation.

This is enforced by a small extension to `scripts/check-design-system-bypass.sh` (added in Phase 13).
