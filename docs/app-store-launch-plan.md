# App Store launch plan — 2026-10-07

Goal: publish Trainy on the App Store and earn money from it. This plan lists
what stands between the current repository and that outcome, who has to do each
piece, and the order to do it in.

## Bottom line

The engineering foundation is unusually solid for a pre-launch app: a
reproducible build, a 66-test simulator suite (as of the July 21 audit), a
credential-safe provider proxy, privacy manifests, and an audited Release archive
([`distribution-readiness-2026-07-21.md`](distribution-readiness-2026-07-21.md)).
It is not yet shippable or sellable, for five reasons:

1. **No paid Apple Developer team.** Everything so far is signed with a Personal
   Team. App Store Connect and TestFlight need the paid program.
2. **The Japan "flagship" ships sample data.** A production build has no ODPT
   key (by policy), so Japan search returns the curated starter catalog, whose
   own provenance says "Representative starter schedule, not an operating feed"
   (`Sources/TrainyCore/TrainModels.swift:474`). Only the Netherlands NS boards
   are real data today.
3. **Nothing to charge for.** There is no StoreKit code, no product, and no
   paywall.
4. **A shipped control does nothing.** The per-trip "Alerts on" / "Notify" toggle
   only stores a flag (`TrainStore.toggleNotification`,
   `Sources/TrainyCore/TrainStore.swift:550`). No notification permission is
   requested and nothing is ever scheduled, yet the UI confirms "Alerts enabled
   for …" (`Sources/TrainyCore/ContentView.swift:705`). Non-functional controls are a
   common App Review rejection (guideline 2.1) and would be a trust problem with
   paying users.
5. **No store listing assets.** There is no privacy policy URL, support URL,
   screenshots, description, or age-rating answers. The marketing site is a
   single "coming soon" page.

Separately, the `Swift CI` workflow was red on every recent pull request because
its `npm audit` step failed on dev-tool dependencies, which skipped the build,
test, and secret-boundary steps behind it. This branch fixes that (see
[What this change does](#what-this-change-does)).

## Who does what

| Needs Jacob | Can be done from here (Claude) |
| --- | --- |
| Enroll in the paid Apple Developer Program; choose individual vs company | Draft privacy policy, support page, and site routes once a contact email and legal name are chosen |
| Pick the final bundle ID and app name before the first App Store Connect record | Real local notifications, or removal of the toggle, once the product call is made |
| Confirm commercial-use terms with NS and ODPT | ODPT-through-the-Worker route for real Japan timetables (needs an ODPT account/terms decision) |
| Choose the pricing model and price points | StoreKit 2 integration, paywall, restore purchases, and tests |
| Banking, tax, and agreements in App Store Connect; EU trader details | Draft listing copy, keywords, review notes, and privacy-label answers |
| Real-device testing, screenshots approval, final submit | Worker hardening (App Attest, quota monitoring), CI release workflow |

## Blockers before the first submission

### 1. Apple Developer Program (Jacob)

- Enroll at developer.apple.com (paid, annual). Seller name on the listing is
  the enrolled legal name. Showing a company name requires enrolling as an
  organization (needs a D-U-N-S number).
- Apps distributed in the EU storefronts must carry verified trader status, and
  a trader's address, phone, and email are shown publicly on the listing
  ([Apple requirements](https://developer.apple.com/news/upcoming-requirements/)).
  The Netherlands is in scope, so decide now whether a company entity is worth
  forming before launch.
- Once enrolled, replace `DEVELOPMENT_TEAM = KR4JDRB59R` (the Personal Team) with
  the paid team in the Xcode project.

### 2. Bundle ID and app name (Jacob, before the first App Store Connect record)

The bundle ID is permanent once an app record exists. The current
`com.jacobcyber.Trainy` is also baked into the Firebase app registration
(`GoogleService-Info.plist`) and the archive audit. If a different ID is wanted
(for example one under a company domain), change it now. Also confirm the name
"Trainy" is available in App Store Connect; reserving it is the first step after
enrollment.

### 3. Real Japan data (Claude + Jacob)

- Production builds pass `ODPT_ENV_FILE=/dev/null` because no provider secret may
  ship in the binary (`CLAUDE.md`, Credential Safety). The same boundary the NS
  provider uses must be built for ODPT: add fixed, normalized ODPT routes to
  `provider-proxy/`, keep the key as a Worker secret, and point the Shinkansen
  provider at the proxy.
- The JR East timetable fallback parses an HTML site
  (`JREastTimetableClient.swift`). It only runs when an ODPT key is present
  (`ShinkansenTrainProvider.swift:113`), so Release builds do not use it today. Do
  not enable it in a commercial app without permission from JR East; Apple's
  guideline 5.2.2 expects authorization for third-party content.
- Settings currently tells riders "Add an ODPT consumer key in the developer
  configuration" (`ContentView.swift:1564` and `:2076`). That is developer
  language and must be replaced with rider-facing copy before release.
- Until real data lands, App Store copy must describe Japan as a starter catalog,
  not live or official tracking.

### 4. Data licensing for commercial use (Jacob)

- **NS:** the portal showed no separate reuse clause, and the public disclaimer
  says NS owns the copyright in its site content and is not liable for
  inaccuracies. The external non-paying limit is 300 requests per five minutes
  for the whole subscription
  ([`Provider_Status.md`](Provider_Status.md)). Email NS API support to confirm a
  paid app is allowed and ask what higher-quota terms exist.
- **ODPT:** read the developer terms for commercial use, required attribution,
  and whether your use case needs the "Challenge" or the general data set. The
  terms page is JavaScript-rendered, so this plan could not read it.
- Keep text-only attribution (no NS logo), as the app does today.

### 5. Alerts: make them real or remove them (decision, then Claude)

Recommendation: build real **local notifications** for scheduled departure
reminders ("departs in 30 minutes, platform X if known"), labelled as based on
the schedule rather than live status. It needs the notification permission flow
(`UNUserNotificationCenter`), scheduling on toggle, cancellation on mute or
untrack, and tests. This is also the most natural thing to put behind a paid
tier (see below). If that is out of scope for 1.0, hide the toggle rather than
ship it.

### 6. Store listing and compliance assets

| Item | Notes |
| --- | --- |
| Privacy policy URL | Required in App Store Connect and should be reachable in-app (guideline 5.1.1). Facts to cover are listed under [Privacy facts](#privacy-facts-for-the-policy-and-privacy-label). |
| Support URL | Needs a contact method. A GitHub issues page is technically valid but weak for paying users. |
| Site routes | `marketing/trainy-coming-soon/scripts/prepare-dist.mjs` returns 404 for every path except `/`, so `/privacy` and `/support` need worker routes as well as pages. |
| Age rating | Answer the updated age-rating questionnaire in App Information. Likely the lowest tier (no user content, no accounts, no open web access). |
| App Privacy label | See below. |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` is added by this change (HTTPS only, through system APIs). Confirm that matches your understanding. |
| Screenshots | The current required sizes are shown in App Store Connect (6.9-inch iPhone, plus 13-inch iPad if iPad stays supported). `marketing/trainy-launch-video/scripts/capture-simulator.sh` already captures simulator footage. |
| Listing copy | Do not name other apps in metadata (guideline 2.3.7). `CLAUDE.md` and a few internal docs describe Trainy as "Flighty-style"; keep that out of the listing and keywords. |
| App Review notes | Tell the reviewer how to see data without an account: search "Utrecht" for live NS boards and "Tokyo to Shin-Osaka" for the Japan starter catalog. Make sure the Worker is healthy during review. |

### 7. iPad: test it or drop it (decision)

`TARGETED_DEVICE_FAMILY = "1,2"` ships to iPad, but every test, screenshot, and
audit in the repository is iPhone 17. Apple reviews on iPad when it is
supported. For 1.0 the lower-risk path is `TARGETED_DEVICE_FAMILY = 1`
(iPhone only), then add iPad deliberately.

## Before real users arrive

### Provider proxy capacity and abuse resistance

The production Worker is a public, unauthenticated endpoint on a free
`workers.dev` hostname, backed by one shared NS budget of 240 attempted upstream
requests per five minutes (`provider-proxy/README.md`). One script can exhaust that
budget and lock out every rider. Workers Free also caps at 100,000 requests per
day. Before marketing:

- Validate App Attest or DeviceCheck tokens at the Worker so only the real app
  can spend quota.
- Move to a custom domain with a WAF/rate rule, and consider the Workers paid
  plan.
- Define the monitoring and emergency-disable threshold the Worker docs already
  call out.
- Ask NS for a quota that matches the user base you are aiming for.

### Operations

- Restrict the Firebase API key to the app's bundle ID in the Google Cloud
  console. The key is public client configuration, not a provider secret, but an
  unrestricted key can be abused.
- `GoogleService-Info.plist` at the repository root is an unreferenced duplicate
  of `TrainyIOS/Trainy/GoogleService-Info.plist`; remove it when convenient.
- Use TestFlight for at least one internal round on a real iPhone, then an
  external round (which goes through Beta App Review), before submitting.
- iOS 26.0 is the minimum deployment target (the design system uses
  `glassEffect`). That limits the audience to devices on iOS 26; revisit once
  App Store Connect shows who actually downloads it.
- Localization (Japanese, Dutch) is not required for launch but would widen the
  two audiences the app currently serves.

## Monetization

Constraints that shape the model:

- The audience is niche and seasonal (visitors to Japan, plus Dutch commuters
  who already have the NS app), so expect modest revenue early and plan for
  low running costs.
- Upstream data is free and subject to provider terms. Do not charge for the raw
  data itself until NS and ODPT confirm that is allowed. Charge for the features
  Trainy adds on top.
- A paywall needs something real behind it. Today the candidates (alerts,
  widgets, history) are not built.

Options:

| Model | Fits | Trade-offs |
| --- | --- | --- |
| Free, then one-time "Pro" unlock | Seasonal trip use | Simplest to build and review; no recurring revenue |
| Free, then "Plus" subscription (annual, optionally monthly) | Frequent travelers and commuters | Recurring revenue; needs the full subscription disclosure UI; weak conversion for one-trip tourists |
| Paid upfront | Very small, fixed audience | Highest friction and no discovery |

Recommendation: ship 1.0 **free** with no in-app purchase while the Japan data
path and alerts are built, then add **Plus** in 1.1 (real notifications, more
than a couple of tracked trips, history, and later widgets and Live
Activities), with an annual price and a lifetime option. Apple mechanics to plan
for:

- Accept the Paid Applications Agreement and complete banking and tax forms
  before any product can sell.
- Apply to the App Store Small Business Program before the first sale; it
  reduces the commission for developers under Apple's annual proceeds threshold.
- Use StoreKit 2. Subscription screens must show price, period, and renewal
  terms, include a Restore Purchases control, and link to the Terms of Use and
  Privacy Policy (guideline 3.1.2).
- In most storefronts Apple collects and remits sales tax and VAT on your behalf.

## Privacy facts for the policy and privacy label

Derived from the code, the Worker documentation, and the privacy manifests. Check
each against reality again at submission time.

- **On device only:** tracked trips, pins, alert flags, provider and region
  choice, display preferences (`UserDefaults`, required-reason `CA92.1`).
- **Japan (Release today):** no network request; starter data is built in.
- **Netherlands:** station search text or a validated station code, plus the
  device's IP address, reaches the Trainy Cloudflare Worker, which calls NS. The
  Worker does not persist invocation logs and its custom event omits rider
  inputs. Cloudflare's transient request metadata is visible in an active Tail
  session. If it stays that way, search text is processed transiently rather than
  stored.
- **Crash diagnostics:** Firebase Crashlytics, off by default, enabled only by a
  Settings opt-in. When on, Google receives crash traces and diagnostic data and
  a Firebase installation identifier. The App Privacy label should list
  Diagnostics (crash and other diagnostic data), marked optional, not used for
  tracking. Confirm the exact data types against Firebase's current disclosure
  guidance when filling in the form.
- **Not present:** accounts, advertising, analytics, tracking, location access,
  or any permission prompt (until alerts are built, which adds a notification
  prompt).

## Suggested order

1. **Now, no account needed:** merge this change (CI is runnable again); decide
   bundle ID, iPad scope, alerts scope, and pricing direction; email NS and
   ODPT about commercial use.
2. **Enroll** in the Apple Developer Program; reserve the app name; set up the
   trader status, agreements, banking, and tax.
3. **Build** (Claude): ODPT-through-Worker, rider-facing copy fixes, real alerts
   or removal, privacy and support pages, Worker hardening.
4. **Prove it:** run the repository gates, a distribution-signed Archive from
   Xcode, then repeat `scripts/audit-ios-archive.py` on the signed payload as
   `distribution-readiness-2026-07-21.md` requires. Upload to TestFlight.
5. **Beta:** internal, then external TestFlight on real devices on real
   trains; fix what shows up.
6. **Submit** 1.0 free. Add Plus in 1.1.

## What this change does

- Restores `Swift CI`: `npm audit --audit-level=high` now passes in
  `provider-proxy` and `marketing/trainy-coming-soon`. The advisories were in
  dev-tool dependencies (`undici`, `sharp`, `nanoid`, `postcss`,
  `source-map-js` under Wrangler/Miniflare, and `next` in the marketing site),
  fixed by pinning patched versions through `overrides` and moving `next` to
  16.4.0. The Worker's 35 contract tests, type checks, and bundle dry run still
  pass, and the marketing site still builds. This supersedes the open
  Dependabot PRs that cannot pass CI on their own.
- Adds `ITSAppUsesNonExemptEncryption = false` to `Info.plist` so App Store
  Connect stops asking the export-compliance question on every upload.
- Adds this document.

## What this review could not verify

- Xcode builds and tests (the review ran on Linux). The CI run on this pull
  request is the check for the Swift side.
- The live Worker (outbound access to `workers.dev` was blocked).
- App Store Connect state, the Apple account, and provider terms behind login
  pages.
