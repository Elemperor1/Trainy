# Trainy launch film

Repository-owned Remotion source for Trainy's 90-second OpenAI Build Week
launch film. The film is 16:9 at 30 fps, contains a licensed upbeat 48 kHz
stereo score, uses real iPhone 17 Simulator footage from Trainy's ordinary
production UI, and contains no narration.

## Reproduce

From this directory:

```bash
npm install
npm run assets
npm run capture
npm run lint
npm run stills
npm run render:review
npm run render:master
npm run render:poster
npm run validate:media
```

`npm run capture` needs Xcode 26.5, the iOS 26.5 runtime, and the repository's
existing `TrainyTests` scheme. It records only Debug-only deterministic
automation fixtures through the ordinary Trainy UI; it does not use provider
credentials or make provider requests. Generated capture clips, audio, stills,
and renders are ignored because they are reproducible and comparatively large.
The licensed source MP3 is retained in the repository; `npm run assets`
normalizes it to the delivery score and adds a silent final-credit tail. See
the attribution ledger for its author, source URL, and license.

The Remotion Studio is available with `npm run dev`. Composition-level copy,
palette, and footage visibility remain editable through named sequences and
inline Remotion keyframes.

See [storyboard.md](storyboard.md), [copy.md](copy.md),
[assets/ATTRIBUTION.md](assets/ATTRIBUTION.md), and
[production-report.md](production-report.md) for the production contract.
