# 002 — Cut to the approved score's musical phrases

- **Status**: TODO
- **Commit**: a2b6633
- **Severity**: HIGH
- **Category**: timing and rhythm
- **Estimated scope**: 2 files, approximately 120 lines

## Problem

Most internal cuts are evenly spaced at 82–112 frames, independent of the score. The Build Week section is the clearest example:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:958 — current
<Sequence durationInFrames={96} layout="none">
// ...
<Sequence from={82} durationInFrames={96} layout="none">
// ...
<Sequence from={164} durationInFrames={96} layout="none">
// ...
<Sequence from={246} durationInFrames={96} layout="none">
```

The approved score has an energetic first passage through roughly 29 seconds, a quiet breakdown from roughly 30–50 seconds, a rebuild at 50.60 seconds, a drop at 56.59 seconds, and a natural release after 82.52 seconds. The current uniform cadence ignores those changes, so motion feels metronomic and presentation-like.

## Target

Use this exact 30 fps cue map, derived from the rendered 90-second score:

| Frame | Time | Musical function | Visual event |
| ---: | ---: | --- | --- |
| 0 | 0.00s | breath | black field and first rail pulse |
| 52 | 1.73s | first strong onset | Trainy mark resolves |
| 199 | 6.63s | phrase turn | onboarding becomes the product hero |
| 457 | 15.23s | accented rise | Tokyo → Shin-Osaka journey begins |
| 611 | 20.37s | strong beat | Nozomi trip detail settles |
| 862 | 28.73s | end of first passage | match-cut into the quiet Netherlands act |
| 1260 | 42.00s | breakdown lift | Utrecht departures become legible |
| 1518 | 50.60s | rebuild onset | availability/fallback story begins |
| 1698 | 56.60s | drop | confident product montage begins |
| 1845 | 61.50s | strongest local onset | settings/privacy moment resolves |
| 2103 | 70.10s | climactic onset | final product hero begins |
| 2257 | 75.23s | release phrase | brand line appears |
| 2476 | 82.53s | last strong musical event | app mark and wordmark settle |
| 2520 | 84.00s | score release | clean cut to final credit |
| 2700 | 90.00s | delivery end | black |

Motion inside each span may accent subsidiary onsets, but structural cuts must stay on this map. Crossfades may begin up to 8 frames before a cue and finish up to 8 frames after it.

## Repo conventions to follow

- Keep the score mounted once with `@remotion/media` `Audio`, as in `marketing/trainy-launch-video/src/Root.tsx:43`.
- Express every timing value in frames and keep `fps={30}`.
- Keep sequence overlap explicit with `from` and `durationInFrames`; do not use time-based browser APIs.

## Steps

1. Replace the current root `from` values with the cue map above.
2. Re-time product actions inside `src/scenes/Scenes.tsx` so their visual settle lands on frames 199, 457, 611, 862, 1260, 1518, 1698, 1845, 2103, 2257, and 2476.
3. Allow the 30–50 second breakdown to breathe: use no more than two hard product changes between frames 862 and 1518.
4. Increase cut density only after frame 1698; use 12–18-frame transitions without resetting the persistent background.
5. Leave frames 2520–2700 to the final credit, with no product montage under the silent tail.

## Boundaries

- Do NOT replace, remix, pitch-shift, or time-stretch `public/audio/trainy-score.m4a`.
- Do NOT change total duration.
- Do NOT force every beat to create a cut; musical synchronization should emphasize phrases, not become a visualizer.
- Do NOT add sound effects unless separately licensed and attributed.
- If the prepared score changes, regenerate this cue map before editing.

## Verification

- **Mechanical**: run `npm run lint`, `npm run render:review`, `ffprobe` duration checks, and `npm run validate:media`; all must exit 0 and report 90 seconds at 30 fps.
- **Feel check**: watch once with sound and tap along with the visible changes. Confirm:
  - major reveals land on the table's named cues;
  - the breakdown visibly breathes instead of continuing the same cut rate;
  - the 56.60-second drop increases visual confidence without becoming frantic;
  - the final identity settles before the score releases.
- **Done when**: muting the film preserves comprehension, while restoring sound makes the same edit feel intentionally choreographed rather than coincidentally accompanied.
