---
name: review-design-system
description: Review Trainy UI and unified Design System changes for architectural consistency, token or component bypasses, guardrail coverage, accessibility, and runtime regressions. Use when asked to review, audit, QA, assess, or approve SwiftUI screens, reusable UI components, design tokens, visual polish, or the web prototype.
---

# Review Trainy Design System

Review read-only unless the user explicitly asks for fixes. Preserve unrelated work in the dirty worktree.

## Establish the review target

1. Confirm the requested base and scope. If none is given, review the current working tree and state that assumption.
2. Inspect both tracked and untracked changes:

   ```bash
   git status --short
   git diff --stat
   git diff -- Sources/TrainyCore TrainyIOS index.html styles.css app.js components.js scripts/check-design-system-bypass.sh
   ```

3. Identify every affected screen, state, shared component, token, modifier, and guardrail. Follow consumers beyond the edited files.

## Map the current architecture

Discover the current structure instead of trusting a stale component list:

```bash
rg -n "^(enum|struct|extension) |static (let|func)|func [A-Za-z]|var body" \
  Sources/TrainyCore/DesignSystem \
  Sources/TrainyCore/ContentView.swift
rg -n "TrainyUI|function |--[a-z0-9-]+:" components.js app.js styles.css
sed -n '1,280p' scripts/check-design-system-bypass.sh
```

Verify that dependency direction remains:

- iOS `DesignSystem/RailDesignSystem.swift` tokens and modifiers →
  `DesignSystem/` primitives and components → screens.
- Web CSS tokens and component factories → application rendering.

Check project/package wiring when files move or new library files appear. Read the current design-system docs only as intent; resolve conflicts in favor of executable code, current guardrails, and the user’s stated scope.

## Detect bypasses

Inspect the diff and nearby code for:

- Raw colors, spacing, radii, typography, shadows, materials, animation values, or status styling outside the token layer.
- Direct platform effects or bespoke panels where a shared modifier or component exists.
- Screen-local controls that duplicate an existing component or should become reusable.
- Shared components implemented in screen files, or screens reaching into token internals.
- Web markup assembled outside the component factories or style literals outside the token layer.
- New `ds-allow` exceptions without a narrow primitive-level reason.
- Guardrail blind spots, including new paths, file types, aliases, or patterns the script does not scan.
- Lost accessibility semantics, insufficient hit areas, clipped Dynamic Type, contrast problems, or motion/transparency behavior that ignores system settings.

A passing grep guardrail is necessary, not sufficient. Trace representative consumers and inspect rendered behavior.

## Run verification

Run the smallest relevant set, then broaden for shared-token or shared-component changes:

```bash
bash scripts/check-design-system-bypass.sh
ODPT_ENV_FILE=/dev/null NS_ENV_FILE=/dev/null \
  ODPT_CONSUMER_KEY= NS_SUBSCRIPTION_KEY= scripts/build-ios.sh
```

Keep design-only builds credential-neutral so build logs cannot expose local provider keys. Run the current `TrainyTests` command documented in `README.md`; do not use host `swift build` or `swift test` as the iOS app gate. Add focused smoke commands when the changed UI depends on provider, provenance, persistence, or fallback behavior.

For iOS runtime verification:

1. Build, install, and launch the app on an available iPhone simulator using the repository README or available simulator tooling.
2. Exercise every affected interaction and relevant loading, empty, error, offline, selected, and disabled state.
3. Inspect light and dark appearance. For shared primitives, also inspect larger Dynamic Type and reduced motion/transparency.
4. Capture screenshots or equivalent runtime evidence and check the runtime console for errors.

If web files are in scope, serve the repository locally, exercise affected interactions at desktop and mobile widths, inspect light/dark and reduced-motion behavior, and check the browser console.

If runtime tooling is unavailable, include the exact failed command and error. Report the strongest substitute evidence without claiming runtime verification.

## Report findings

Lead with findings ordered by severity. For each finding include:

- Severity and concise title.
- Exact `path:line` reference.
- Evidence and affected runtime behavior.
- Why it violates the architecture or user experience.
- Smallest compliant recommendation.

Use `nl -ba`, `rg -n`, or equivalent to refresh line numbers before reporting.

Always include a Before/After table. Compare the review base with the proposed change; if no historical base exists, clearly label “After” as the expected compliant state.

| Area | Before | After | Evidence |
| --- | --- | --- | --- |
| Component or behavior | Base/current behavior | Changed or expected compliant behavior | `path:line`, command, or runtime proof |

Finish with:

- Verification commands and pass/fail/blocked results.
- Runtime scenarios actually exercised.
- Guardrail gaps or residual risks.
- An explicit “No findings” statement when appropriate; do not invent issues to populate the report.
