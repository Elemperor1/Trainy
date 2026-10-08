# Security review and threat model, 2026-10-07

Reviewed against commit `3edcc9b` (master `127aecd` plus the npm lockfile fix
from PR #20 and the CI and hygiene changes in PR #21). The reviewer read the
code and configuration listed below. This was not a penetration test: there was
no runtime traffic capture, no fuzzing, and no access to the Apple, Cloudflare,
Google, or NS consoles. The Apple signing identity does not exist yet, so the
signed-export checks in the pre-submission checklist are still ahead.

Severity scale: **High** means a stranger can cause rider-visible harm with
little effort. **Medium** needs a precondition or has limited impact. **Low** is
defense in depth. **Info** needs no action.

## Summary

- No provider credential is in the app, the tracked tree, or any of the 82
  commits reachable from any branch. A scan for common key shapes found the
  Firebase client key and nothing else. The Release archive audit confirmed on CI that the NS host, auth
  header, and key name are absent from the shipped binary.
- The main exposure is availability. One anonymous client can drain the shared
  NS budget in about five minutes and keep it drained (F1). This is acceptable
  for a closed beta and not for public launch. Plan items 7.2 and 7.3 are the
  real fix; F1 lists cheap Worker changes that reduce it sooner.
- The Firebase API key is a public client identifier, but it is in a public
  repository and may be unrestricted. Restrict it to the bundle ID and rotate it
  now, while no rider holds a build that embeds it (F2). Only you can do this in
  the Google Cloud console.
- The app has no inbound attack surface today: no URL schemes, extensions,
  entitlements, web views, pasteboard reads, or permission requests.
- Nothing here blocks a closed TestFlight beta.

## System and trust boundaries

```text
Rider's iPhone (Trainy app)
  |-- HTTPS --> Trainy provider proxy (Cloudflare Worker, workers.dev)
  |               '-- HTTPS --> NS Reisinformatie API   (NS key lives only here)
  |-- HTTPS --> Firebase Crashlytics                    (only after the rider opts in)
  '-- developer builds only --> ODPT API, JR East timetable pages

Maintainer --> GitHub (source, CI) | Cloudflare (Worker, secret) | Apple
               (signing, App Store Connect) | Google Cloud (Firebase) | NS API portal
```

Assets, most valuable first: the NS subscription key (Worker secret) and the
shared NS request budget of 240 per five minutes; the maintainer accounts above;
rider data (station search text, tracked trips, diagnostics consent); the signing
identity once it exists; the Firebase project; the local-only ODPT developer key.

## Threats and controls

| # | Threat | Controls in place | Residual |
| --- | --- | --- | --- |
| T1 | NS key leaks through the app, repo, logs, or responses | The app knows no upstream host or auth header (`NSClient.swift:3`). The key is a Worker secret (`wrangler.jsonc:9`). Logs hold only an allowlisted event (`handler.ts:97`). Upstream failures map to fixed messages (`upstream.ts:89`). The archive audit pins the absence of upstream markers (`audit-ios-archive.py:88`). | Low |
| T2 | An anonymous client exhausts the shared NS budget | Per-IP limit of 60 per minute per route (`handler.ts:78`), 48 per minute per location upstream (`handler.ts:263`), 240 per five minutes globally in a Durable Object (`quota.ts:3`), cache with stale fallback (`cache.ts:129`). | **High** before launch (F1) |
| T3 | A network attacker reads or alters traffic | HTTPS required except loopback (`ProviderProxy.swift:52`), no ATS exceptions (audit check), strict response validation (`NSClient.swift:89`). No certificate pinning, which is acceptable for a `workers.dev` host. | Low |
| T4 | A broken or hostile payload from NS or the Worker | Worker field limits, 2 MiB cap, manual redirects (`upstream.ts:5`, `:9`, `:85`). The app re-validates, caps at 1 MiB (`NSClient.swift:10`), and renders plain text. No proxy content is opened as a URL. | Low |
| T5 | Injection or SSRF through the Worker | One fixed upstream origin (`upstream.ts:4`), allowlisted parameters with strict patterns (`contracts.ts:76`), `GET` only (`handler.ts:71`), cache keys from fixed prefixes and validated codes (`cache.ts:16`). | Low |
| T6 | Rider data exposure | Only search text and station codes leave the device, and only to the proxy. No analytics, ads, advertising ID, location, or accounts. The Worker does not log queries. Local data is non-secret `UserDefaults` in the app container. Cloudflare still sees request IPs, and Tail shows request metadata live (`provider-proxy/README.md`). | Low |
| T7 | Diagnostics collected without consent | Collection is off in `Info.plist:19`, enabled at launch only from stored consent, and unsent reports are deleted otherwise (`TrainyApp.swift:16`). Audit checks cover the plist flag and the source wiring. | Low |
| T8 | Firebase API key abuse | The key is public by design and Analytics and Ads are off. No restriction is known. | **Medium** until restricted (F2) |
| T9 | Developer behavior ships in Release (fixtures, ODPT key, local proxy URL) | Automation is behind `#if DEBUG` (`TrainyApp.swift:11`). `archive-ios.sh` blanks the ODPT key (`:44`, `:76`) and pins the proxy URL (`:78`). The audit checks markers. CI now compiles Release on every relevant PR. | Low (F3) |
| T10 | A compromised dependency or build tool | Lockfiles, the npm audit policy, grouped Dependabot, a pinned Firebase version with a privacy-manifest inventory, actions pinned to SHAs, `contents: read`, no secrets in any workflow, no `pull_request_target`. | Low to medium (F7) |
| T11 | Maintainer account takeover | Nothing visible in the repo. The Worker README says Cloudflare tokens are short-lived. A Cloudflare takeover exposes the NS key and lets an attacker change responses (the app's validation limits that to wrong data). An Apple takeover could ship a malicious build. | **Medium** for a one-person project |
| T12 | Tampering with on-device state | Out of scope: the app stores no credentials. | Info |
| T13 | The coming-soon site | A single static page with `default-src 'none'`, no forms, scripts, or third-party calls (`prepare-dist.mjs:47`). | Low |

## Findings

**F1. High before launch: one client can drain the shared NS budget.**
The per-IP limiter passes 60 requests a minute (`handler.ts:78`). The upstream
limiter then lets 48 a minute through per location (`handler.ts:263`), which is
exactly the global budget of 240 per five minutes (`quota.ts:3`). Departures for
a station code the Worker has not cached call NS and spend a reservation, and an
unknown code is never cached (`upstream.ts:105`, `cache.ts:134`), so a script
sending a fresh code every second keeps the budget empty. Riders then get
`429 provider_budget_exhausted` (`handler.ts:265`) once their cached entries age
out: five minutes for departures, ten for disruptions, 24 hours for the station
catalog. Sweeping real station codes works too, because fresh departures last
only 20 seconds (`handler.ts:19`). The limiter key is the full client address
(`handler.ts:78`), so an IPv6 client with a /64 can also rotate addresses.

Reduce it now with Worker-only changes: reject station codes missing from the
cached catalog before calling NS, cache unknown-code answers for a few minutes,
and consider a 30 to 60 second departures freshness window (a product trade-off).
Fix it properly with App Attest and a custom domain with WAF rules (7.2, 7.3).
These touch `provider-proxy/src`, which another thread owns.

**F2. Medium: Firebase API key.** `GoogleService-Info.plist` carries a client
key that ships in every build and has been in the published repository since
2026-06-21 (commit `bf78439`, in two copies). Google treats it as an identifier,
not a secret, but an unrestricted key can be used to spend Firebase quota.
Rotate and restrict it using the steps below. The removed root copy was
identical to the shipped one, so removing it from the tree changes nothing for
the app, and history was not rewritten.

**F3. Low to medium: the legacy ODPT key path.** `Info.plist:23` reads
`ODPT_CONSUMER_KEY` at build time. Local developer builds can embed a personal
key. `archive-ios.sh` and the audit stop that for scripted archives, and the CI
archive confirmed `ODPTConsumerKey` is empty. A hand-made Xcode archive from a
shell that exports the variable is the gap. Delete the key and its client when
Japan data moves behind the Worker (2.3).

**F4. Low: JR East parser follows absolute links.** `trainDetailURLs` resolves
`href` values against the page URL (`JREastTimetableClient.swift:77`), so a
hostile page could point the app at another host. It only runs when an ODPT key
is present (`ShinkansenTrainProvider.swift:113`), so not in production builds.
If the scraper is revived, require the resolved URL to share the base host.

**F5. Low: unbounded dev clients.** The ODPT and JR East clients use
`session.data(for:)` (`ODPTClient.swift:61`, `JREastTimetableClient.swift:58`)
with no size ceiling or total deadline, unlike `BoundedURLSession`. Developer
builds only today.

**F6. Info: environment override of the proxy URL.**
`TRAINY_PROVIDER_PROXY_BASE_URL` beats the `Info.plist` value in every
configuration (`ProviderProxy.swift:23`). A rider cannot set a process
environment, so only a developer can use it. Compiling the override under
`#if DEBUG` would leave Release with one source of truth.

**F7. Low: supply-chain gaps.** `npm ci` runs dependency install scripts on CI
and on any machine used to deploy the Worker, which holds a Cloudflare login.
Registry signatures are not verified (`npm audit signatures`). Branch
protection settings could not be read from here. Deploy the Worker from a clean
checkout, and require the `build`, `npm audit policy`, and `Release archive
audit` checks on `master`.

**F8. Info: CI cannot run the value-level secret scan.** The CI audit reported
`0 of 0 unique credential fingerprints` and 43 of 44 checks, because the ignored
local env files and credential PDF are absent. Run the audit and
`scripts/check-provider-secret-boundary.py` on your Mac against the final signed
export.

**F9. Info: other observations.** `.xcodebuildmcp/config.yaml` holds a local
`/Users/...` path. A third-party stock music file is tracked under
`marketing/trainy-launch-video/public/audio/` although `.gitignore` lists it;
check that its license allows publishing. `.gitignore` now also covers signing
material and a root `GoogleService-Info.plist`.

## Actions for the owner

Firebase API key (F2). The app has no public users yet, so rotation is cheap.
Do not paste the key into chats or tickets.

1. Google Cloud console, project `trainy-ios-20260621`, APIs and Services,
   Credentials. Create a replacement API key with the application restriction
   set to iOS apps and the bundle ID `com.jacobcyber.Trainy`. If you rename the
   bundle ID before creating the App Store Connect record, register the new
   bundle ID in Firebase, download its plist, and restrict the key to that ID.
2. Put the new key in `TrainyIOS/Trainy/GoogleService-Info.plist` (or replace
   the file with a fresh download and confirm `IS_ANALYTICS_ENABLED` and
   `IS_ADS_ENABLED` stay false), then commit it.
3. Run a build, opt in to diagnostics in Settings, force a test crash, and
   confirm the report reaches Crashlytics.
4. Delete the old key.
5. In the Firebase console, confirm Firestore, Realtime Database, and Storage
   are off or locked. The app uses none of them, and a public key plus open
   rules would let anyone read or write.

Accounts. Turn on passkeys or two-factor sign-in for GitHub, Cloudflare, Google,
the Apple ID, and the NS API portal, and keep recovery codes offline.

GitHub. Protect `master`, require the checks named in F7, block force pushes,
and confirm secret scanning with push protection and Dependabot alerts are on.

## Pre-submission checklist

Final diff review, against the last released commit or an empty tree for 1.0:

1. List every new host: search the diff for `https://`, `http://`, and
   `URLSession`. Each must be the Trainy proxy or Firebase.
2. List every new `Info.plist` key, entitlement, background mode, URL scheme,
   extension, and SDK. None are expected before 3.1 and 3.3.
3. Check the privacy manifests and the App Privacy answers still match:
   Crashlytics crash data is optional, nothing tracks, search text is processed
   but not stored.
4. Look for logging or persistence of search text, station codes, or trip data.
5. Confirm no new `#if DEBUG` boundary leaks and no automation marker appears
   in the Release archive.

Then run, in this order:

1. The `Release archive audit` check green on the release commit.
2. The signed export audit with the value-level scan on your Mac (F8).
3. A network capture of a clean install: only the Trainy proxy host before
   opt-in, nothing to Firebase until consent, and only Firebase after.
4. A check that the Worker secret is set, previews are off, only the allowlisted
   log event is written, and Tail is not left running.

## Re-review triggers

Repeat this review when any of these land: local notifications (3.1); widgets or
an App Group (3.3); StoreKit (5.x); App Attest and its entitlement (7.2); Japan
ingestion with its own credentials and storage (2.x); a custom domain or any
Worker route change (7.3); a new SwiftData or iCloud store (1.4, 8.2); a new
data provider; or a Firebase major version.
