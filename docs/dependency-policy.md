# Dependency policy

How Trainy keeps its dependencies current without a stream of one-package pull
requests, and what makes a vulnerable dependency block a merge. The settings
live in three files, and this page explains them:

- `.github/dependabot.yml` decides which updates Dependabot opens and how it
  groups them.
- `scripts/npm-audit-policy.json` decides which advisories fail the
  `npm audit policy` check, and holds the exceptions.
- `scripts/audit-ios-archive.py` pins the Firebase version and its privacy
  manifests for the Release archive audit.

## What Trainy depends on

| Area | Directory | What it ships |
| --- | --- | --- |
| Firebase (Core, Crashlytics) | `TrainyIOS/Trainy.xcodeproj` | Linked into the app. The only third-party code in the binary. |
| Root Swift package | `Package.swift` | Nothing third-party. |
| Cloudflare Worker | `provider-proxy/` | The Worker imports no npm packages at runtime, so every npm dependency is build, test, or deploy tooling. |
| Coming-soon site | `marketing/trainy-coming-soon/` | `next`, `react`, and `react-dom` ship in the static site. |
| Launch film | `marketing/trainy-launch-video/` | Nothing. Remotion tooling that renders the launch film. |
| GitHub Actions | `.github/workflows/` | Nothing. Runs in CI only. |

## Dependabot

Version updates run monthly, and each directory groups its updates so a month
of releases becomes a few pull requests. Security updates ignore the schedule
and arrive as soon as an advisory has a fix; the `security-updates` groups fold
those into one pull request per directory.

| Directory | Groups |
| --- | --- |
| `/TrainyIOS` (Swift) | `firebase`: every Firebase and Google package in one pull request. |
| `/` (Swift) | None. The root package has no third-party dependencies. |
| `/provider-proxy` | `cloudflare-toolchain`: wrangler, miniflare, workerd, `@cloudflare/*`. `dev-tooling`: every other dev dependency, minor and patch only. `security-updates`. |
| `/marketing/trainy-coming-soon` | `framework`: next, react, react-dom. `security-updates`. |
| `/marketing/trainy-launch-video` | `remotion`: remotion and `@remotion/*`. `react`: react, react-dom, `@types/react`. `dev-tooling`. `security-updates`. |
| GitHub Actions | `github-actions`: every action in one pull request. |

A dependency joins the first group it matches, so the narrow groups come first.
Major versions are left out of the tooling groups on purpose. They arrive as
their own pull requests so the breaking change is reviewed alone.

The groups follow real version constraints. `wrangler` and
`@cloudflare/vitest-pool-workers` each pin an exact `miniflare`, and
`miniflare` pins an exact `undici`, so those packages only work when they move
together. `next`, `react`, and `react-dom` must match, and so must every
Remotion package.

The `/TrainyIOS` entry is the one that covers Firebase, because Dependabot
reads an Xcode project from the directory that contains the `.xcodeproj`. It
was added without a way to test it locally. The first monthly run should open a
`firebase` group pull request if Firebase has a newer release in the allowed
range; if the Dependabot logs (Insights, Dependency graph, Dependabot) show an
error for `/TrainyIOS`, fix the entry before relying on it.

### Reviewing a Dependabot pull request

1. Wait for the checks. `Swift CI`, `npm audit policy`, and, when Swift or Xcode
   inputs changed, `Release archive audit` must all pass.
2. For a toolchain or framework group, skim the release notes for major
   behavior changes. Dev-tooling groups with green CI can merge as they are.
3. For a GitHub Actions pull request, confirm the pinned SHA is the commit of
   the release tag in the comment, and keep the `# vX.Y.Z` comment.
4. Merge. Do not close a grouped pull request to skip one package; add an
   `ignore` entry with a comment explaining why instead.

## npm audit policy

`npm audit --audit-level=high` cannot tell a package that ships from one that
only runs on a laptop, so a single advisory in `wrangler`, `vitest`, or Remotion
used to fail `Swift CI` and skip the iOS build and tests behind it. The policy
separates the two:

| Dependency class | Fails at |
| --- | --- |
| Production (reaches `dependencies`, per `npm audit --omit=dev`) | `high` or `critical` |
| Development tooling | `critical` |

`marketing/trainy-launch-video` is marked `"tooling": true` in the policy, so
all of its dependencies count as development tooling even though Remotion sits
under `dependencies`. The check is its own job (`npm audit policy`) so a red
audit never skips the iOS build.

Run it locally with `node scripts/npm-audit-policy.mjs`, or pass one project
path. The exit status is 0 when the policy holds, 1 when an advisory is over
threshold or the policy is invalid, and 2 when `npm audit` itself could not run
(for example, the registry was unreachable). The rules are tested with
`node --test scripts/npm-audit-policy.test.mjs`. The run also fails if a
tracked `package-lock.json` is not listed in the policy, so a new npm project
cannot skip the audit.

### Allowing an advisory

Prefer fixing the dependency. When no fixed release exists, add an entry to
`allowlist` in `scripts/npm-audit-policy.json`:

```json
{
  "advisory": "GHSA-xxxx-xxxx-xxxx",
  "project": "provider-proxy",
  "reason": "Dev server only; the fix needs a major wrangler upgrade tracked in #123.",
  "expires": "2027-01-15"
}
```

- `advisory` is the GitHub advisory id from the audit output.
- `project` is optional; leave it out to cover every project.
- `reason` must say why the advisory cannot reach a rider and what ends the
  exception. The check rejects reasons shorter than 20 characters.
- `expires` is a `YYYY-MM-DD` date no more than `maxAllowanceDays` (180) away.
  After that date the advisory fails again, so every exception gets a review.

The audit output also flags an exception that no longer matches any advisory
(`UNUSED`); delete it. Dismiss the matching Dependabot alert in GitHub only when
the vulnerable code is genuinely unreachable, and cite the same reason.

## Firebase

Firebase is the only third-party code in the shipped app, and the Release
archive audit pins its exact version (`FIREBASE_PINNED_VERSION`) and the full
list of privacy manifests it contributes (`EXPECTED_PRIVACY_MANIFESTS`). That
makes every Firebase bump a deliberate release decision.

Cadence:

- Dependabot checks once a month and opens at most one `firebase` pull request.
- A release that fixes a vulnerability or a Crashlytics problem is taken within
  a week of the pull request opening.
- Any other release waits for the start of a release cycle, right after an
  App Store submission, and is never taken in the last two weeks before one.
- At most one Firebase bump ships per app release. A new major version is a
  planned migration, not a Dependabot merge: read the release notes for minimum
  iOS and Xcode requirements and privacy manifest changes first.

To accept a bump:

1. Open the Dependabot pull request. It changes `Package.resolved` and the
   `minimumVersion` in `project.pbxproj`.
2. Expect `Release archive audit` to fail on `Firebase dependency pin`, and
   possibly on `privacy manifest inventory`. The failure lists the manifests
   that went missing or appeared.
3. In the same pull request, set `FIREBASE_PINNED_VERSION` to the new version.
   If the inventory changed, open each new or changed `PrivacyInfo.xcprivacy`
   and confirm `NSPrivacyTracking` is false and the collected data types still
   match the App Privacy answers in App Store Connect, then update
   `EXPECTED_PRIVACY_MANIFESTS`.
4. Merge only when `Swift CI` and `Release archive audit` are green.

## When Dependabot cannot update a package

A failed run with `security_update_not_possible` means an alert exists for a
package, and some parent pins that package to an exact version, so updating it
alone would break the parent. The `undici` alerts in `provider-proxy` were this:
`wrangler` depends on `miniflare`, which pins `undici` exactly, so the patched
`undici` was unreachable until `miniflare` caught up.

1. Find the parent that holds the pin: `npm ls <package> --all` in the project.
2. If a newer release of the parent lifts the pin, take it. The toolchain
   groups exist so that parent and child arrive together.
3. If none does, pin the patched version in the project's `overrides` in
   `package.json`, as `provider-proxy` does for `undici`. Run
   `npm install --package-lock-only`, then `npm ls <package>` to confirm one
   patched copy, then the project's own checks (`npm run check` for
   `provider-proxy`; `npm test` and `npm run build` for the coming-soon site).
4. Overrides are manual maintenance. Dependabot does not reliably update a
   version pinned in `overrides`, so on each monthly toolchain pull request,
   check whether the parent now ships the patched version and remove the
   override if so.
5. If the vulnerable code cannot be reached and no fix exists, add an allowlist
   entry with an expiry and dismiss the alert, as described above.

## GitHub Actions

Every workflow action is pinned to a commit SHA with the version in a trailing
comment, for example `actions/checkout@<sha> # v6.1.0`. Dependabot moves the SHA
and the comment together. When adding an action, pin it the same way; never use
a floating tag such as `@v4` in a workflow that has repository access.
