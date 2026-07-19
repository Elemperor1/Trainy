---
name: review-accessibility
description: Review Trainy changes for web and iOS accessibility, responsive layout, keyboard operation, low-vision support, font scaling, semantics, and assistive-technology regressions. Use when asked to audit, QA, approve, or report on the current Trainy worktree, UI changes, responsive behavior, accessibility compliance, Dynamic Type, VoiceOver, focus handling, or cross-device usability.
---

# Review Trainy Accessibility

Review read-only unless the user explicitly asks for fixes. Preserve unrelated work in the dirty worktree. Base every conclusion on the current checkout and runtime evidence; do not substitute a stale file list or prior screenshots.

## Establish the review surface

1. Confirm the requested base and scope. If none is given, compare the current worktree with `HEAD` and state that assumption.
2. Inspect tracked, staged, and untracked work:

   ```bash
   git status --short
   git diff --stat
   git diff
   git diff --cached
   git ls-files --others --exclude-standard
   ```

3. Read every changed UI file and follow affected shared components, styles, tokens, navigation, state, and consumers. Include untracked files explicitly.
4. Discover the current run and test commands from `README.md`, `package.json`, Xcode project files, and repository scripts. Do not assume old commands still apply.
5. Identify affected user journeys and states before testing: initial, loading, populated, empty, error, disabled, selected, modal, validation, offline, and reduced-motion states as relevant.

## Inspect implementation semantics

Review the changed surface and its dependencies for:

- Correct landmarks, headings, lists, controls, labels, descriptions, form associations, validation messages, status announcements, and document or navigation structure.
- Native elements before custom roles; valid names, roles, values, states, and relationships when custom controls are necessary.
- Logical reading and focus order, focus restoration, modal focus containment, skip or bypass mechanisms, and no keyboard traps.
- Meaningful image alternatives; decorative images, icons, and duplicate text hidden from assistive technology.
- Instructions and state that do not depend only on color, shape, position, hover, drag, motion, or sound.
- Text and non-text contrast, visible focus indicators, target size, spacing, truncation, clipping, overlap, and horizontal overflow.
- Reduced motion and transparency behavior, animation pause or dismissal where applicable, and no seizure-risk flashing.
- SwiftUI labels, values, hints, traits, grouping, sort priority, adjustable actions, dynamic layout, and decorative accessibility hiding.

Use browser accessibility-tree or inspector output and platform accessibility tooling when available. Source inspection alone is not proof that rendered semantics or interaction order are correct.

## Validate browser behavior

Serve the current repository using its documented command. Exercise the affected journeys at all three viewport classes:

| Class | Required representative viewport |
| --- | --- |
| Desktop | `1440x900` |
| Tablet | `768x1024` |
| Phone | `390x844` |

Use equivalent available device presets only when exact dimensions are unavailable, and record the actual dimensions. At each viewport:

1. Reload from a clean entry state and exercise every affected interaction and relevant state.
2. Check wrapping, reflow, order, fixed or sticky elements, overlays, touch targets, content loss, and both-axis overflow.
3. Verify that orientation or a second breakpoint does not reveal a suspected defect when the changed layout is breakpoint-sensitive.
4. Inspect the browser console and accessibility tree. Capture screenshots or equivalent evidence for defects and successful critical paths.

### Complete a keyboard-only pass

Put the pointer aside and operate each affected journey using only the keyboard:

- Reach all interactive controls in a logical order with `Tab` and `Shift+Tab`.
- Confirm focus is always visible and is not obscured by sticky content.
- Activate controls with their expected keys, including `Enter` and `Space`.
- Operate menus, tabs, lists, dialogs, disclosures, and composite widgets with conventional arrow, `Escape`, and Home/End behavior where applicable.
- Confirm dialogs receive focus, contain it while open, close predictably, and restore focus to the invoker.
- Confirm hover-only, drag-only, or pointer-only actions have equivalent keyboard paths.

Document the exact path exercised and the first failing step for every defect.

### Complete low-vision and font-scaling passes

At minimum:

1. Test browser zoom at `200%`.
2. Test increased default text or font size at approximately `200%` where tooling permits.
3. Test narrow reflow equivalent to `320 CSS px` without losing content or requiring two-dimensional scrolling, except for genuinely two-dimensional content.
4. Check text spacing overrides, high-contrast or forced-colors behavior when supported, dark and light appearances, and reduced motion.
5. Verify that labels, errors, controls, and status content remain visible, understandable, and operable without clipping or overlap.

Record any unavailable mode and the strongest substitute check. Do not report an unavailable check as passed.

## Validate iOS when relevant

Treat iOS simulator validation as required when the worktree changes SwiftUI, shared content or interaction behavior, navigation, design-system components, or user-facing state also rendered by the app. State why iOS is not relevant when skipping it.

Use the current `README.md` and available simulator tooling. Prefer `scripts/build-ios.sh` and the Xcode `TrainyTests` path; do not use host `swift build` or `swift test` as the iOS app gate.

On an appropriate iPhone simulator:

1. Build, install, and launch the current worktree.
2. Exercise affected journeys and states with touch and, when relevant, a hardware keyboard.
3. Test light and dark appearance, portrait and landscape when layout-sensitive, Reduce Motion, Increase Contrast, and Reduce Transparency as relevant.
4. Test at least one large Dynamic Type size and one Accessibility Dynamic Type size.
5. Inspect VoiceOver names, values, traits, grouping, reading order, adjustable controls, and focus movement using VoiceOver or Accessibility Inspector when available.
6. Capture screenshots, inspector evidence, console errors, and the simulator/device details used.

If simulator or accessibility tooling is unavailable, report the exact command, error, and unverified scenarios. Do not infer an iOS pass from a successful compile.

## Rank and document findings

Lead with findings, ordered by user impact:

- **Critical**: blocks a core journey for an affected user, creates an inescapable trap, or makes essential information unavailable.
- **High**: prevents independent completion of an important task or causes major content or control loss at a required viewport or accessibility setting.
- **Medium**: materially impairs understanding or operation but has a practical workaround.
- **Low**: localized friction, inconsistency, or standards gap with limited task impact.

For every finding include:

1. **Issue**: severity and concise title.
2. **Evidence**: exact `path:line`, viewport or simulator setting, reproduction steps, and runtime artifact.
3. **Impact**: affected users and blocked or degraded task.
4. **Fix**: smallest concrete remediation that preserves the current architecture.
5. **Risk**: regression surface, uncertainty, and checks required after the fix.

Refresh line numbers immediately before reporting. Separate confirmed findings from hypotheses and residual risks. If no defects are confirmed, say **No findings** and still report coverage and limitations.

## Include the Before/After table

Always compare the review base with the current worktree. For a new untracked surface, use “Not present” as Before. Do not describe a recommended future fix as if it already exists.

| Area or journey | Before (base/`HEAD`) | After (current worktree) | Evidence | Verdict |
| --- | --- | --- | --- | --- |
| Affected behavior | Prior rendered or source behavior | Current rendered or source behavior | `path:line`, command, viewport, simulator, or artifact | Improved, unchanged, regressed, or blocked |

## Completion standard

Do not call the review complete until the final report contains:

- The base, current-worktree scope, changed and untracked surfaces, and affected journeys.
- Desktop, tablet, and phone browser results with actual viewport dimensions.
- Keyboard-only paths and low-vision or font-scaling results.
- Semantic and accessibility-tree or inspector evidence.
- Relevant iOS simulator, Dynamic Type, and VoiceOver or Accessibility Inspector results, or an explicit relevance decision and exact blockers.
- Severity-ranked findings with Issue, Evidence, Impact, Fix, and Risk.
- The Before/After table.
- Commands run, pass/fail/blocked status, artifacts captured, untested scenarios, and residual risk.

Blocked checks are acceptable only when clearly identified with exact failure evidence. They remain residual risk and must not be summarized as passing.
