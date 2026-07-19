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
| Primitives | `RailDesignPrimitives.swift` | Surfaces, badges, icon badges, dividers, value rows, navigation cards, actions, segmented controls, list-row policy |
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
| Navigation affordance inside a surface | `RailNavigationCard` |
| Loading content | `LoadingSkeletonView` |
| Empty, offline, success, or error state | `EmptyStateView`, `OfflineBanner`, `SuccessBanner`, `ErrorBanner` |
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
