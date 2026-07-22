# Trainy — OpenAI Build Week submission readiness

## Deadline and submission route

OpenAI Build Week submissions close on **July 21, 2026 at 5:00 PM PDT / 8:00
PM EDT**. Devpost requires a working Codex/GPT-5.6 project, repository URL,
project description, category, public video under three minutes with audio,
and a Codex `/feedback` session ID. A downloadable iOS binary is not a required
deliverable.

Trainy's honest judge path is:

1. Public repository with credential-neutral simulator instructions.
2. A short product video showing first launch, Shinkansen search, the live NS
   station-board path, and truthful provider/source labels.
3. The repository-owned build, test, privacy, provenance, and archive evidence.

## Current readiness

| Area | Status | Evidence or owner action |
| --- | --- | --- |
| Working project | Ready | Canonical iOS build, simulator suite, provider gates, and audited Release archive |
| Judge setup | Ready | Root README has a credential-neutral iPhone 17 simulator path |
| First-run onboarding | Ready | Current Japan/Netherlands scope, deterministic AX2XL completion/replay coverage, and visual Dark Mode review passed |
| Repository | Public | `https://github.com/Elemperor1/Trainy` |
| Repository license | Ready | Proprietary notice preserves all rights while permitting activities needed to judge, administer, document, and promote Trainy's Build Week participation |
| Category | Recommended | Apps for Your Life |
| Project name, tagline, description | Owner voice required | Devpost explicitly asks entrants to describe their work in their own voice |
| Demo video | Owner action required | Publish an audio-enabled YouTube video under three minutes |
| Codex feedback ID | Owner action required | Run `/feedback` in the Codex task to obtain the session ID |
| Devpost submission | Approval required | Do not update or submit the external project without owner approval |

## Signing and distribution

The installed profile is an Apple Development profile for the Personal Team,
restricted to one registered device and expiring July 28, 2026. It signs the
Release-configured Trainy device build, but it cannot produce an App Store or
TestFlight distribution. The phone was offline during this pass, so installation
still requires reconnecting and unlocking it. The content-audited Release
archive remains the authoritative shipping-content proof.

For Devpost this is not a submission blocker because an iOS binary is optional.
Use the registered iPhone for the product recording and give judges the
credential-neutral simulator instructions. App Store Connect/TestFlight should
remain a post-hackathon release task requiring an active paid Apple Developer
Program team and a newly audited distribution-signed export.

## Suggested video outline (maximum 2:45)

| Time | Show | Explain |
| --- | --- | --- |
| 0:00–0:20 | First-launch onboarding | The rider sees what is starter, scheduled, or realtime before relying on a status |
| 0:20–0:55 | Search and open a Shinkansen trip | Trainy makes multi-leg rail progress and source provenance easy to scan |
| 0:55–1:30 | Search Utrecht and open departures | Netherlands station boards run through the secure production proxy without exposing provider credentials |
| 1:30–1:55 | Provider status and fallback | Availability copy reflects the complete provider path and does not overclaim live data |
| 1:55–2:25 | Tests and release evidence | Deterministic simulator automation, accessibility, privacy manifests, and archive auditing make the demo reproducible |
| 2:25–2:45 | Codex/GPT-5.6 contribution and impact | Describe in the submitter's own words how the model helped build and verify the project |

## Final owner checklist

- [x] Add the proprietary repository notice with a Build Week evaluation grant.
- [ ] Confirm the Devpost project name and tagline in the submitter's own voice.
- [ ] Supply submitter type and country.
- [ ] Confirm **Apps for Your Life** or choose another category.
- [ ] Record and publish the public YouTube video with audio, under three minutes.
- [ ] Run `/feedback` and copy the resulting session ID.
- [ ] Review the final Devpost preview.
- [ ] Explicitly approve the external update and submission.
