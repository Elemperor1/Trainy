# 001 — Replace alternating wipes with one continuous journey

- **Status**: TODO
- **Commit**: a2b6633
- **Severity**: HIGH
- **Category**: continuity and choreography
- **Estimated scope**: 3 files, approximately 500 lines replaced or removed

## Problem

The film resets its visual grammar at both the scene level and the shot level. `SceneShell` reveals every major section with the same diagonal rail wipe:

```tsx
// marketing/trainy-launch-video/src/components/SceneShell.tsx:30 — current
clipPath:
  reveal === "rail"
    ? `polygon(0 0, ${railEdge}% 0, ${Math.max(0, railEdge - 12)}% 100%, 0 100%)`
    : undefined,
```

Inside each section, `ShotLayer` repeats that same wipe from alternating sides:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:62 — current
const clipPath =
  reveal === "left"
    ? `polygon(0 0, ${edge}% 0, ${Math.max(0, edge - 8)}% 100%, 0 100%)`
    : reveal === "right"
      ? `polygon(${100 - edge}% 0, 100% 0, 100% 100%, ${Math.min(100, 108 - edge)}% 100%)`
      : undefined;
```

The root then restarts the composition nine times:

```tsx
// marketing/trainy-launch-video/src/Root.tsx:49 — current
<Sequence name="01 Signal" durationInFrames={198} premountFor={30}>
// ...
<Sequence name="09 GPT-5.6 credit" from={2580} durationInFrames={120} premountFor={30}>
```

Together these choices make the edit read as a deck of animated slides. The viewer sees a new background, a new phone position, and a new text block every two to four seconds instead of following one product through a journey.

## Target

- One `LaunchJourney` composition runs continuously from frame 0 through frame 2519.
- One persistent rail/light motif remains mounted for that full duration and changes color or curvature without disappearing.
- Remove `ShotLayer` and remove the rail `clipPath` behavior from `SceneShell`.
- Use three visual acts only: departure (0–861), discovery (862–1517), and confidence (1518–2519).
- Cross-act transitions use a 16-frame opacity blend plus at most 48 px of shared-axis translation with `Easing.bezier(0.16, 1, 0.3, 1)`.
- Within an act, preserve at least one shared anchor across every cut: the phone center, the route line, or the station dot.
- Use no decorative grid background and no alternating left/right full-canvas masks.
- Keep the silent credit as the only clean cut to black, beginning at frame 2520.

## Repo conventions to follow

- Keep all animation driven by `useCurrentFrame()` and `interpolate()`; do not use CSS transitions or timers.
- Reuse the existing `cinematicEase = Easing.bezier(0.16, 1, 0.3, 1)` token from `marketing/trainy-launch-video/src/scenes/Scenes.tsx:17`.
- Keep Remotion Studio labels with `Interactive.Div` so important surfaces remain inspectable.
- Keep the 3840×2160, 30 fps, 2700-frame composition contract in `marketing/trainy-launch-video/src/Root.tsx:107`.

## Steps

1. Replace the nine-section root timeline in `src/Root.tsx` with one 2520-frame `LaunchJourney` sequence plus one 180-frame `CreditScene` sequence.
2. Replace `ShotLayer`, `FilmShade`, and the repeated per-section background mounts in `src/scenes/Scenes.tsx` with one persistent `JourneyField` and act-local layers.
3. Keep the background rail/light identity mounted across all product transitions; interpolate its accent from Trainy teal to Japan green to Netherlands blue and back to teal.
4. Convert each product change into a matched transition: the outgoing and incoming phone share the same center and scale for the 16-frame overlap, while their opacity crossfades.
5. Delete the unused rail reveal branch from `src/components/SceneShell.tsx`, or remove the component if the simplified root no longer needs it.

## Boundaries

- Do NOT change the captured Simulator video files.
- Do NOT add generated train photography or third-party imagery.
- Do NOT change the approved music.
- Do NOT change the 90-second delivery length or final credit wording.
- Do NOT add dependencies.
- If the timeline no longer matches commit `a2b6633`, stop and re-audit the frame map before improvising.

## Verification

- **Mechanical**: run `npm run lint`, `npm run build`, and `npm run render:review` from `marketing/trainy-launch-video`; all must exit 0.
- **Feel check**: watch the 1080p review at normal speed and muted. Confirm:
  - no transition feels like a slide entering from alternating sides;
  - the rail/light or phone anchor visibly connects each adjacent beat;
  - there are no more than three perceptible full-world resets before the credit;
  - the film remains understandable without audio.
- **Done when**: a reviewer can scrub from 0:00 to 1:24 and perceive one evolving visual journey rather than a stack of scene templates.
