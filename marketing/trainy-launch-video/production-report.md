# Trainy launch film production report

## Outcome

The final 90-second true-speed cut and approved upbeat score are complete in
editable Remotion source. Every editorial line and product clip has a named
Remotion Studio sequence. Final 1080p, 4K, poster, and repository-gate evidence
is recorded below after the delivery renders complete.

## Creative direction

- 90-second, narration-free product film built around Trainy's existing dark
  palette, app mark, semantic status colors, system typography, and restrained
  rail-line geometry.
- Every capture plays at its recorded 1× speed. Interaction-led cuts replace
  long screen holds, slow motion, macro crops, and one-layout-per-scene pacing.
- A crop-safe four-pose camera, physical glass edge, controlled product aura,
  and pale mint identity resolve create depth without a fake hardware render.
- The rail line establishes the opening journey, recedes once the product is
  visible, and disappears completely for the product and identity resolves.
- Main-story copy is traveler-first. Audit counts, architecture, implementation
  details, capability taxonomies, and generic Build Week language were removed.
  One factual line—`Built with Codex + GPT‑5.6`—satisfies the
  Build Week contribution beat without interrupting the product journey.
- The simulator clock is locked to `9:21` in every final capture. Japan and
  Utrecht each use one uninterrupted recording; no recording is restarted at a
  second timestamp inside either journey.
- Dark Mode and AX2XL appear for two seconds, followed by the real default-off
  diagnostics control and its explicit opt-in. Accessibility is proven without
  becoming the dominant visual scale.
- Motion uses frame-derived interpolation with controlled easing and no CSS
  transition or keyframe animation.

## Footage

The capture script builds for iPhone 17 / iOS 26.5 and records the existing
`TrainyCriticalUITests` flows. Automation injects ordinary provider protocols,
ephemeral defaults, and in-memory credential-neutral fixtures into the normal
production UI; it does not render a parallel demo screen.

Clips used in the final cut:

- `onboarding.mp4`
- `shinkansen-search.mp4`
- `utrecht-departures.mp4`
- `failure-recovery.mp4`
- `accessibility.mp4`
- `privacy.mp4`

`provider-fallback.mp4` was captured during production but deliberately left
out of the final edit; onboarding, Starter labels, the realtime-unavailable
message, and the visible retry flow communicate the same truth without adding
another disconnected take.

## Audio

`Energetic Upbeat Future Bass Version 1` by BombinSound is the sole music bed.
The source page states that it is free for use under the Pixabay Content
License; the original MP3, source URL, license URL, processing steps, and author
are retained in `assets/ATTRIBUTION.md`. `scripts/prepare-score.mjs` produces a
90.000-second, 48 kHz stereo AAC score normalized to a -15 LUFS target. Its
natural ending is preserved and followed by silence under the final credit.
There is no narration, so Caption JSON and SRT sidecars are not applicable.

## Validation record

To be filled with exact results for:

- TypeScript and ESLint
- Remotion bundle and still renders
- Trainy build, Xcode tests, design-system guard, source provenance, provider
  boundary, and privacy checks
- Per-scene full-resolution still inspection
- 4K master, 1080p review render, and poster metadata
- Normal, muted, and audio/transitions review passes
- Secret and private-marker scans

## Limitations

- No narration was used; the film relies on readable product and editorial copy
  plus the licensed score.
- The recordings use documented deterministic fixtures for repeatability. The
  Netherlands flow exercises the same secure provider protocols and production
  UI as the public proxy path without relying on current network timing during
  the edit.
