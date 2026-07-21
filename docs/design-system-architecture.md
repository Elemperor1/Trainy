# Trainy Design System Architecture

Date: 2026-06-24

Trainy has one UI library. All reusable SwiftUI styling, interaction behavior,
state presentation, and domain-facing UI components live in:

`Sources/TrainyCore/DesignSystem/`

Screens compose the library. They do not define new tokens, styles, button
styles, modifiers, or reusable controls locally.

## Layers

| Layer | Owner | Responsibility |
| --- | --- | --- |
| Tokens and semantic assets | `RailDesignSystem.swift` | Palette, spacing, semantic layout measurements, radius, typography, elevation, motion, status semantics, screen chrome, glass fallback |
| Interface inputs | `RailInterfacePreferences.swift` | Root-injected time, unit, and source-label preferences; no component-owned persistence |
| Primitives | `RailDesignPrimitives.swift` | Surfaces, badges, icon badges, dividers, value rows, navigation cards, actions, search fields, segmented controls, list-row policy |
| Patterns | `RailDesignLibrary.swift` | Section headers, metrics, trip tools, settings groups and rows, shared press behavior |
| Domain adapters and states | `RailComponents.swift` | Trip, station, source, timeline, loading, empty, offline, success, and error UI built from the lower layers |
| Screens | `ContentView.swift`, `RailJourneyMap.swift` | Feature composition, routing, local UI state, and feature-specific map geometry |

Dependency direction is one way:

`tokens + interface inputs -> primitives -> patterns/domain adapters -> screens`

## Ownership rules

- Only files under `DesignSystem/` may define `RailDesign` tokens, reusable
  `ViewModifier` or `ButtonStyle` types, or components shared by screens.
- Components do not read `@AppStorage`, `UserDefaults`, notifications, or
  `TrainStore`. `ContentView` owns persisted interface preferences and injects
  `RailInterfacePreferences`; Settings is the only editor.
- Feature enums such as tabs, sheets, and trip buckets stay in feature code.
  Generic controls accept options and bindings instead.
- Navigation events stay outside the Design System.
- MapKit drawing geometry may remain feature-local, but general controls,
  surfaces, badges, type, color, elevation, and motion still route through the
  library.
- Reduced Motion and Reduced Transparency are respected by the component that
  owns the effect. Callers do not duplicate accessibility branches.

## Component selection

| Need | Use |
| --- | --- |
| Panel, inset, semantic tint, or material surface | `RailSurface` |
| Compact semantic label | `RailBadge` |
| Icon treatment | `RailIconBadge` |
| Key/value metadata | `RailValueRow` (`compact` or `stacked`) |
| Primary/secondary action | `RailActionButton` |
| Multi-option selection | `RailSegmentedControl` |
| Search text plus explicit submit action | `RailSearchField` |
| Navigation affordance inside a surface | `RailNavigationCard` |
| Loading content | `LoadingSkeletonView` |
| Empty, offline, success, or error state | `EmptyStateView`, `OfflineBanner`, `SuccessBanner`, `ErrorBanner` |
| Stale or rate-limited provider state | `StaleDataBanner`, `RateLimitBanner` |
| Provider source/freshness disclosure | `RailSourceDisclosure` |
| Settings composition | `SettingsGroup` and standardized settings rows |

If none fits, add or extend a component in `DesignSystem/` first, then consume
it from the screen. Do not prototype a reusable visual pattern in a screen.

## Enforcement

Run:

```bash
bash scripts/check-design-system-bypass.sh --self-test
bash scripts/check-design-system-bypass.sh
```

The guardrail blocks:

- raw colors, non-zero numeric spacing, numeric radii, raw fonts, shadows,
  materials, glass, and motion in screen code;
- legacy decorative palette names in every Swift source, including the design
  system itself; provider state must use semantic success/warning/danger/info;
- token namespaces and custom styles outside the library;
- redefinition of library-owned components;
- component-owned persistent interface state;
- persistence, navigation, store, and MapKit dependencies inside the library;
- inline web component markup and hardcoded web colors outside token
  declarations.

The fixture suite intentionally attempts each bypass so the guardrail itself is
tested rather than trusted.

## Review gate

Use the repository skill at:

`.agents/skills/review-design-system/SKILL.md`

It requires architecture inspection, guardrail and credential-neutral builds,
runtime interaction checks, accessibility settings, and a Before/After review
table before approval.

## NS completion review — 2026-07-20

The NS station-search and departure-board slice uses `RailSearchField`,
`RailNavigationCard`, `RailSurface`, `StaleDataBanner`, `OfflineBanner`,
`RateLimitBanner`, `ErrorBanner`, and `RailSourceDisclosure`; no screen-local
visual system was added. Provider-supplied station, destination, alert, source,
and attribution strings use verbatim text initializers so Markdown-like input
cannot alter presentation or accessibility semantics.

The 25-case guard self-test and the 28-file repository scan passed. Runtime
inspection on iPhone 17 / iOS 26.5 covered Light and Dark Mode and AX2XL as
separate states. Search, station rows, departures, stale banners, and source
disclosure remained readable and scrollable; search/back actions measured 44
points, tabs 54 points, and station rows at least 81 points. With VoiceOver
enabled, the simulator AX tree exposed logical headings/order, labelled
fields/actions, station names plus codes, and source/freshness text. The
simulator was restored to Large text, Dark Mode, VoiceOver off, AX overlay off,
and normal contrast after the review.
