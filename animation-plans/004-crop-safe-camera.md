# 004 — Lock the product camera to intentional, crop-safe geometry

- **Status**: TODO
- **Commit**: a2b6633
- **Severity**: HIGH
- **Category**: spatial continuity and camera motion
- **Estimated scope**: 2 files, approximately 180 lines

## Problem

The current camera accepts large arbitrary scale and position ranges, then clamps them at render time:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:113 — current
const requestedScale = move(frame, [0, duration], scale);
const safeScale = Math.min(requestedScale, 2500 / height);
// ...
const safeX = Math.max(
  -displayedWidth * 0.1,
  Math.min(rawX, 3840 - displayedWidth * 0.9),
);
```

Call sites request scales as high as 1.58 and negative vertical positions:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:469 — current
<CameraProduct
  name="Shinkansen search macro"
  file="shinkansen-search.mp4"
  trimBefore={390}
  duration={112}
  x={[-410, -80]}
  y={[-760, -520]}
  scale={[1.42, 1.58]}
```

The clamp prevents total loss of the phone but changes the requested composition unpredictably. Adjacent shots also jump between opposite edges, different scales, and rotations, which reads as arbitrary zooming rather than an intentional camera.

## Target

- Replace free-form `x`, `y`, and `scale` tuples with named camera poses: `center`, `left`, `right`, and `detail`.
- For 1280×2780 captures at 3840×2160:
  - `center`: `x=1480`, `y=151`, `scale=0.668` (the full capture is visible with 151 px vertical breathing room);
  - `left`: `x=520`, `y=151`, `scale=0.668`;
  - `right`: `x=2465`, `y=151`, `scale=0.668`;
  - `detail`: `x=1360`, `y=-120`, `scale=0.82` (at least 90% of capture height and 100% of width remain visible).
- Correct pose values proportionally for captures whose declared source dimensions differ from 1280×2780.
- Scale drift within a held shot is limited to 4%; translation drift is limited to 96 px; rotation is limited to ±0.3°.
- Every 16-frame crossfade begins and ends with outgoing and incoming products on the same pose.
- No phone may lose more than 5% of its width or 10% of its height.
- Remove side-dependent `FilmShade` gradients. If copy needs contrast, use a local 640 px feather behind the text, not a full-frame dark veil.

## Repo conventions to follow

- Keep the existing `PhoneFootage` wrapper and real `Video` assets.
- Keep `objectFit="cover"` only because each wrapper matches the capture's declared aspect ratio.
- Keep `animateIn={false}` for product clips that participate in timeline-level matched transitions.
- Use the existing `cinematicEase` for pose interpolation.

## Steps

1. Replace `CameraProduct`'s free-form tuple props with a `pose` and optional `nextPose` API.
2. Add a single dimension-aware pose resolver in `src/scenes/Scenes.tsx`; reject or clamp any result outside the visibility limits above.
3. Reframe all product footage with the named poses and keep each act on a stable side or center rather than alternating every shot.
4. Use `detail` only for a visible interaction that benefits from enlargement; return to a full pose on the next musical phrase.
5. Remove rotation from all ordinary shots and keep at most one ±0.3° hero drift in the final montage.
6. Render the internal midpoint audit and inspect every sampled frame at full resolution.

## Boundaries

- Do NOT crop away the status bar, route endpoints, source/freshness labels, provider status, retry action, or privacy setting when that element is the evidence for the beat.
- Do NOT substitute screenshots for the moving Simulator footage.
- Do NOT use device bezels or assets that imply a hardware model not present in the source.
- Do NOT add perspective transforms.
- If a capture's actual encoded dimensions differ from its declared wrapper dimensions, inspect with `ffprobe` and correct the wrapper before positioning it.

## Verification

- **Mechanical**: run `npm run lint`, `npm run stills:shots`, and `npm run render:review`. Inspect all generated shot-audit stills and run `ffprobe` on every source capture.
- **Feel check**: watch at normal speed, then scrub through every product transition. Confirm:
  - no zoom lands on a clipped or irrelevant part of the UI;
  - the phone appears to occupy one coherent space across cuts;
  - every detail enlargement has a visible narrative reason;
  - no transition uses a scale jump to manufacture energy;
  - important UI evidence stays inside frame.
- **Done when**: all sampled frames satisfy the stated visibility limits and a normal-speed watch contains no moment that feels accidentally zoomed or misframed.
