# 003 — Remove presentation scaffolding and let the product speak

- **Status**: TODO
- **Commit**: a2b6633
- **Severity**: HIGH
- **Category**: typographic motion and information hierarchy
- **Estimated scope**: 3 files, approximately 250 lines removed or simplified

## Problem

The reusable headline component forces every beat into the same corporate presentation structure:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:163 — current
const BeatTitle: React.FC<{
  readonly name: string;
  readonly eyebrow: string;
  readonly title: string;
  readonly detail?: string;
```

That structure produces internal language rather than traveler language:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:785 — current
<BeatTitle
  name="Credential neutral label"
  eyebrow="AVAILABLE"
  title="Truth before theater."
  detail="Capabilities are labeled—not assumed."
```

The Build Week sequence becomes literal numbered presentation slides:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:960 — current
<ProofShot
  index="01"
  title="Contract"
  detail="Source + freshness"
```

Typography compounds the problem with oversized headings and tighter-than-brand-safe tracking:

```tsx
// marketing/trainy-launch-video/src/scenes/Scenes.tsx:211 — current
fontSize: titleSize,
lineHeight: 1,
fontWeight: 650,
letterSpacing: "-0.052em",
```

## Target

- Remove all eyebrow labels, numbered sections, feature taxonomy, and internal engineering nouns from the product story.
- Replace `BeatTitle` with a single `FilmLine` component supporting one main line and one optional factual subline.
- Main-line type is 88–128 px at 4K, weight 560–650, line height 0.98–1.06, and letter spacing no tighter than `-0.035em`.
- Supporting type is 34–48 px at 4K with no negative tracking beyond `-0.015em`.
- No product-story card contains more than 7 main-line words or 10 supporting words.
- Use this traveler-first copy sequence:
  1. `Going somewhere?`
  2. `Meet your train.`
  3. `Tokyo → Shin‑Osaka`
  4. `Nozomi 231 · 09:21`
  5. `Utrecht Centraal`
  6. `What leaves next?`
  7. `Live when it’s live.`
  8. `Clear when it isn’t.`
  9. `Built with Codex + GPT‑5.6`
  10. `Trainy`
  11. `Know before you go.`
- Keep provider labels, source names, freshness, privacy state, and retry actions visible inside the real captured UI rather than restating them as marketing copy.
- Preserve the required final credit exactly as `Created with GPT‑5.6 Sol + Skills`.

## Repo conventions to follow

- Keep the existing SF Pro/system font stack in `marketing/trainy-launch-video/src/palette.ts:18`; it is part of Trainy's iOS identity.
- Keep text layers named with `Interactive.Div` for Studio inspection.
- Use `palette.ink` and `palette.secondary`; reserve `palette.accentBright` for the rail/light and one final brand emphasis.
- Keep copy centralized in `src/copy.ts`, but structure it by journey beat rather than by corporate topic.

## Steps

1. Replace `src/copy.ts` with the exact traveler-first sequence above and short factual sublines only.
2. Delete `BeatTitle`, `ProofShot`, `SecureRail`, and `TruthRail` from `src/scenes/Scenes.tsx`.
3. Add `FilmLine` with the exact type limits above; animate it with 12–16 frames of opacity and 20–36 px of shared-axis translation.
4. Let four long spans contain no overlay copy at all, so the real UI is the sole communication surface.
5. Reduce the Build Week proof to one quiet line, `Built with Codex + GPT‑5.6`, held long enough to read once.
6. Change the composition and poster tagline in `src/Root.tsx` to `Know before you go.`.
7. Run the copy-editing seven sweeps and score the result with four reviewers: a rail traveler, a UX writer, a brand strategist, and a product-truth reviewer. Each must score at least 7/10, with an average of at least 8/10.

## Boundaries

- Do NOT claim realtime data for a provider state shown as starter or scheduled.
- Do NOT claim coverage, speed, accuracy, availability, or privacy behavior beyond what the captured UI and repository evidence show.
- Do NOT invent customer quotes, usage statistics, awards, or superlatives.
- Do NOT enlarge typography to fill empty space; empty space is intentional.
- Do NOT change the final credit wording.
- If any exact route, train number, or time does not appear in the corresponding capture, replace it with the truthful visible value rather than preserving this plan's example.

## Verification

- **Mechanical**: run `rg -n 'CONTEXT FIRST|PROVIDER TRUTH|SECURE PATH|GRACEFUL FALLBACK|AVAILABLE|ADAPTS|APPEARANCE|PRIVACY|Contract|Credential boundaries|Simulator|Audit|01|02|03|04' marketing/trainy-launch-video/src`; there must be no on-screen marketing-copy hits. Run `npm run lint` and `npm run build`; both must exit 0.
- **Feel check**: watch the review muted and confirm:
  - every line sounds natural when spoken aloud;
  - the copy speaks to a traveler, not a judge or engineering reviewer;
  - no frame resembles a keynote agenda or feature slide;
  - the viewer can read each line once without pausing;
  - the UI, not the copy, carries the technical proof.
- **Done when**: all seven copy sweeps pass, every factual statement is visible or repo-supported, and the four-person panel averages at least 8/10 with no score below 7.
