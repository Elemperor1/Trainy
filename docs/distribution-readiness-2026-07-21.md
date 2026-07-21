# Trainy distribution readiness — 2026-07-21

## Outcome

The final production-equivalent Release archive passed the complete content
audit with **0 failures across 44 checks**. The shipped app contains no known
credential value, private endpoint, local path, debug/test payload, embedded
third-party framework, extension, or undeclared privacy behavior.

The result is **content-ready but not distribution-signed**. The archive was
created with `CODE_SIGNING_ALLOWED=NO` so the complete shipped-content audit
cannot upload or be mistaken for distribution proof. A later signing follow-up
created and verified a Release-configured iPhoneOS app with the installed
Personal Team Apple Development identity and one-device profile. That artifact
is suitable for the registered-device demo only: `get-task-allow=true`, and the
profile cannot produce an App Store or TestFlight distribution. Nothing was
uploaded, notarized, exported, distributed, deployed, committed, pushed,
merged, or sent to a pull request during this audit.

## Scope and source state

- Repository HEAD at audit start:
  `cd7c5f466bce34c5fec175467028eabfc45ade85`.
- Xcode: 26.5 (`17F42`); SDK: `iphoneos26.5`; macOS: 26.5.2
  (`25F84`).
- Scheme/configuration/destination: shared `Trainy` / `Release` /
  `generic/platform=iOS`.
- Bundle: `com.jacobcyber.Trainy`, version `1.0` (`1`), arm64.
- The audit used the uncommitted working tree recorded by `git diff`; the
  archive identity below binds the actual output rather than implying it came
  only from HEAD.

## Archive identity

| Item | Identity |
| --- | --- |
| Archive | `/private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcarchive` |
| Result bundle | `/private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcresult` |
| Machine-readable audit | `/private/tmp/trainy-distribution/2026-07-21-devpost/audit.json` |
| Archive tree SHA-256 | `dc7ea5f07cd86ea65303d765927b342abf529ed4dacde6ee1ef098ba3cf67aea` |
| App binary SHA-256 | `454432f7b3e02f1b52302dec776d31fb0dd7b543f5124d489a51682638b7f9b1` |
| App arm64 UUID | `A76EA5F1-C540-33F3-A696-666B29498645` |
| dSYM DWARF SHA-256 | `149efcc84d9caffd0b9993c17e273ee5d5394237ab5fd5e93a5eb6064a39f147` |
| App / dSYM UUID match | Yes |
| Signing | Unsigned; no embedded profile or entitlement file |

## Development-signed demo proof

The same source also produced
`/private/tmp/trainy-device-derived-20260721/Build/Products/Release-iphoneos/Trainy.app`.
Strict code-signature verification passed with these non-secret properties:

| Property | Result |
| --- | --- |
| Signature authority | Apple Development |
| Bundle / team match | `com.jacobcyber.Trainy` / `KR4JDRB59R` |
| Provisioning | One registered device; expires `2026-07-28T16:53:12Z` |
| Entitlements | `application-identifier`, `com.apple.developer.team-identifier`, `get-task-allow` |
| Debug entitlement | `get-task-allow=true` |
| Binary SHA-256 | `05960a986e903fba998462831948f73011821a558ed3325c423a92a088d3bd06` |
| Product defaults | Crashlytics off; production HTTPS NS proxy pinned |

The phone was paired and in Developer Mode but offline when installation was
attempted (`tunnelState=unavailable`, developer services unavailable). Reconnect
and unlock that registered iPhone to install this exact app. This artifact is
not a substitute for a distribution-signed export.

The archive contains one app and one matching dSYM. The app contains 34
regular files, 14 privacy manifests, no app extensions, no embedded dynamic
frameworks, and no preview, test, or debug dylib. All 32 dynamic dependencies
are Apple system libraries; Firebase 12.15.0 and Trainy are statically linked.

## Privacy, permissions, and network policy

The first-party `PrivacyInfo.xcprivacy` declares no tracking, no tracking
domains, no collected data, and only
`NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`. Source inspection
found `UserDefaults`/`@AppStorage` as Trainy's only reviewed required-reason API
category.

All 14 shipped manifests are valid property lists and declare tracking false:

| Shipped owner | Required-reason declarations | Collected-data declarations |
| --- | --- | --- |
| Trainy | UserDefaults `CA92.1` | None |
| FirebaseCore | UserDefaults `CA92.1` | None |
| FirebaseCoreInternal | UserDefaults `1C8F.1` | None |
| FirebaseCrashlytics | UserDefaults `CA92.1` | Crash data; other diagnostic data |
| FirebaseInstallations | None | Other diagnostic data |
| GoogleDataTransport | None | Other diagnostic data |
| GoogleUtilities Environment | UserDefaults `C56D.1` | None |
| GoogleUtilities UserDefaults | UserDefaults `1C8F.1`, `C56D.1` | None |
| FirebaseCoreExtension, GoogleUtilities Logger/NSData, FBLPromises, Promises, nanopb | None | None |

Trainy references no protected-resource API and ships no permission-description
key. It ships no `NSAppTransportSecurity` exception: the production provider
endpoint is the approved public HTTPS Worker, and the ODPT build value is
present but empty. The app bundle contains no loopback, private-network,
`.local`, `.internal`, or `.invalid` URL literal.

Firebase Analytics and Ads flags are disabled. Crashlytics automatic collection
is disabled in the generated app plist. Runtime collection follows the rider's
explicit, default-off `trainy.diagnosticsConsent` preference; when disabled,
Trainy deletes unsent reports. Trainy adds no custom Crashlytics log, key, user
ID, or nonfatal payload. The archive build invoked Firebase's documented
validation-only mode: the result bundle contains seven `--validate` markers and
zero upload-success/build-event markers.

## Provider provenance and secret boundary

- The Release app contains the NS attribution and terms, ODPT timetable
  attribution, and Trainy's curated starter-catalog disclosure.
- The public NS proxy URL is pinned in the generated plist. NS upstream host,
  subscription-key setting/header, and authentication value are absent.
- ODPT is deliberately credential-neutral in this archive. No developer ODPT
  credential is the production path.
- The ignored local credential sources supplied to the audit were three env
  files and the fillable credential PDF. All four are mode `0600`.
- The PDF extractor found four candidate credential values without printing
  them. Combined with the env inputs, the audit scanned 13 unique credential
  fingerprints across 3,984 archive/result/DerivedData files
  (542,986,768 bytes): **0 matched**.
- The broader provider-boundary gate also checked repository, generated, log,
  and simulator/test artifacts plus the shipping simulator app for authorized
  NS values and upstream-only markers. It passed without exposing a value.
- Only the accepted empty key name `ODPT_CONSUMER_KEY` occurs in Release.

The Firebase `GoogleService-Info.plist` is treated as public Firebase client
configuration, not as a provider secret. The audit requires the shipped file
to match the tracked source exactly and separately enforces disabled
Analytics/Ads behavior.

## Finding ledger

| ID | Verified finding | Disposition |
| --- | --- | --- |
| F-01 | Trainy had no first-party privacy manifest despite using `UserDefaults`. | Added the minimal first-party manifest with reason `CA92.1`; final archive and all SDK manifests validated. |
| F-02 | Release inherited `NSAllowsLocalNetworking`. | Removed the ATS dictionary; source test and archive audit now require no ATS exception. |
| F-03 | Crashlytics collection used Firebase's automatic default. | Disabled automatic collection, added explicit default-off rider consent, and delete unsent reports while disabled. |
| F-04 | The Crashlytics build phase could upload symbols during an audit archive. | Unsigned and explicitly audit-mode builds run `upload-symbols --build-phase --validate`; the result bundle proves no upload marker. |
| F-05 | UI automation scenarios and fixtures were compiled outside an explicit Debug boundary. | Wrapped automation scenario/fixtures and launch routing in `#if DEBUG`; prohibited Release strings are absent. |
| F-06 | Release retained preview/development settings and incomplete stripping controls. | Disabled previews/development assets and enabled dead-code/installed-product stripping while suppressing serialized Swift debug options. |
| F-07 | One ignored local env file was group/world-readable. | Corrected all supplied credential inputs to mode `0600`; the audit enforces the mode before scanning. |
| F-08 | Initial dSYM metadata exposed workstation paths. | Added compiler prefix mapping and normalized the dSYM relocation map. No user-home path remains. One developer-only symbol file intentionally retains temporary module/source paths needed for complete symbolication; no credential fingerprint matched it. |
| F-09 | Distribution signing was initially unavailable. | A valid Personal Team Apple Development identity/profile now signs the registered-device demo. App Store/TestFlight remains blocked on a paid Developer Program distribution team; no development signature is presented as distribution proof. |
| F-10 | The new diagnostics preference initially bypassed Trainy's owned preference contract. | Moved persistence ownership to `ContentView`, injected the binding/environment contract, and added positive and duplicate-owner guard fixtures. |
| F-11 | One unit test still expected the removed ATS exception. | Updated it to require the stricter no-ATS policy; the complete Xcode suite passes. |

## Reproduction commands

Run from the repository root. These commands intentionally keep outputs under
`/private/tmp` and do not upload or distribute anything.

### Signing preflight

```bash
security find-identity -v -p codesigning
find "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" -type f 2>/dev/null
```

The current host has one Apple Development identity and one Personal Team
one-device profile. It has no Apple Distribution identity or distribution
profile.

### Canonical credential-neutral build and tests

```bash
ODPT_ENV_FILE=/dev/null \
TRAINY_PROVIDER_PROXY_BASE_URL='https://trainy-ns-provider-proxy.trainy-jacob.workers.dev' \
CODE_SIGNING_ALLOWED=NO \
scripts/build-ios.sh

DEVELOPER_DIR=/Applications/Xcode-26.5.0.app/Contents/Developer \
ODPT_CONSUMER_KEY='' \
xcodebuild test -quiet \
  -project TrainyIOS/Trainy.xcodeproj \
  -scheme TrainyTests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -derivedDataPath /private/tmp/trainy-validation-tests \
  -clonedSourcePackagesDirPath /private/tmp/trainy-source-packages \
  -packageCachePath /private/tmp/trainy-swiftpm-cache \
  -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  TRAINY_SOURCE_PACKAGES_DIR=/private/tmp/trainy-source-packages
```

### Release archive

Choose fresh paths; the wrapper refuses to overwrite an existing archive or
result bundle.

```bash
ARCHIVE_PATH=/private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcarchive \
RESULT_BUNDLE_PATH=/private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcresult \
DERIVED_DATA_PATH=/private/tmp/trainy-distribution/DerivedData-2026-07-21-devpost \
CODE_SIGNING_ALLOWED=NO \
scripts/archive-ios.sh
```

### Final archive and fingerprint audit

`pdftotext` is required only when supplying the ignored credential PDF. The
auditor extracts candidate values in memory and reports only counts and safe
fingerprints on a failure; it never prints a value.

```bash
scripts/audit-ios-archive.py \
  /private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcarchive \
  --result-bundle /private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/2026-07-21-devpost/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/DerivedData-2026-07-21-devpost \
  --credential-pdf docs/trainy_api_credentials_fillable_form.pdf \
  --json-output /private/tmp/trainy-distribution/2026-07-21-devpost/audit.json
```

### Repository gates

```bash
scripts/check-design-system-bypass.sh --self-test
scripts/check-design-system-bypass.sh
python3 scripts/test-provider-secret-boundary.py
bash scripts/test-provider-smoke-pattern.sh
bash scripts/smoke-source-provenance.sh
bash scripts/smoke-provider-registry.sh
bash scripts/smoke-shinkansen-provider.sh
scripts/check-provider-secret-boundary.py
npm run check --prefix provider-proxy
bash -n scripts/*.sh scripts/lib/*.sh
node --check app.js
node --check components.js
python3 -m py_compile scripts/audit-ios-archive.py scripts/normalize-ios-archive-metadata.py
plutil -lint TrainyIOS/Trainy/Info.plist TrainyIOS/Trainy/GoogleService-Info.plist TrainyIOS/Trainy/PrivacyInfo.xcprivacy
xmllint --noout TrainyIOS/Trainy.xcodeproj/xcshareddata/xcschemes/Trainy.xcscheme
git diff --check
```

## Validation record

- Release archive: succeeded; metadata normalization reported zero machine
  paths in shipped products and zero user-home paths.
- Archive audit: 44 checks, 0 failures, 3 documented warnings.
- Xcode `TrainyTests`: 66/66 passed with no failures or skips on iPhone 17 /
  iOS 26.5, including onboarding at AX2XL and Settings replay.
- Provider proxy: 35/35 Workerd contract tests passed.
- Design-system boundary: 27/27 guard fixtures and the 29-file repository scan
  passed.
- Provider secret-boundary regression tests: 4/4 passed; provider-smoke input
  pattern, provenance, registry, and Shinkansen offline smokes passed.

## Accepted limitations and next release-owner step

The non-shipping xcresult and DerivedData contain normal machine-local build
paths; they must remain local and are not part of the app. The dSYM retains
temporary compilation paths in one developer-only symbol file so `dsymutil`
can preserve complete symbols. The relocation map is normalized, the dSYM has
no user-home path, and no credential fingerprint matched any symbol content.

To turn this content-audited archive into a distribution-signed candidate, the
release owner must enroll in or select an active paid Apple Developer Program
team, create the App Store distribution assets, export a newly signed payload,
and repeat this audit plus signature/profile/entitlement extraction over that
payload. The Personal Team development build and unsigned archive must not be
reused as distribution proof. Export or upload requires separate authorization.
