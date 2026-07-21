# Trainy distribution readiness — 2026-07-21

## Outcome

The final production-equivalent Release archive passed the complete content
audit with **0 failures across 44 checks**. The shipped app contains no known
credential value, private endpoint, local path, debug/test payload, embedded
third-party framework, extension, or undeclared privacy behavior.

The result is **content-ready but not distribution-signed**. This Mac has no
valid Apple signing identity or provisioning profile, and the project does not
set a development team. The archive was therefore created with
`CODE_SIGNING_ALLOWED=NO`. Signing, export, and installation on a physical
device remain an external release-owner prerequisite. Nothing was uploaded,
notarized, exported, distributed, deployed, committed, pushed, merged, or sent
to a pull request during this audit.

## Scope and source state

- Repository HEAD at audit start:
  `5895bcdf413c1dbd89ed1cf233c6086e2d1600d4`.
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
| Archive | `/private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcarchive` |
| Result bundle | `/private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcresult` |
| Machine-readable audit | `/private/tmp/trainy-distribution/2026-07-21-final/audit.json` |
| Archive tree SHA-256 | `155f9cb9b91a8a581766172f91b0af606823caa167cae39c77c9704acf1ff6ea` |
| App binary SHA-256 | `ba8488cc27cda22223fba4a2a1cd471c2dd1c435e7154a04b1a7bf315d072bf3` |
| App arm64 UUID | `71FAB2F1-936D-303C-A7FB-AC88453D57DF` |
| dSYM DWARF SHA-256 | `e67e555782a5629662d13133edc959614503992c86ae70060b67551c5e967821` |
| App / dSYM UUID match | Yes |
| Signing | Unsigned; no embedded profile or entitlement file |

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
| F-09 | No signing identity, profile, or team is available. | Documented external blocker; archive remains unsigned. No fake/ad-hoc signature was presented as distribution proof. |
| F-10 | The new diagnostics preference initially bypassed Trainy's owned preference contract. | Moved persistence ownership to `ContentView`, injected the binding/environment contract, and added positive and duplicate-owner guard fixtures. |
| F-11 | One unit test still expected the removed ATS exception. | Updated it to require the stricter no-ATS policy; the complete Xcode suite passes. |

## Reproduction commands

Run from the repository root. These commands intentionally keep outputs under
`/private/tmp` and do not upload or distribute anything.

### Signing preflight

```bash
security find-identity -v -p codesigning
find "$HOME/Library/MobileDevice/Provisioning Profiles" -type f 2>/dev/null
```

The audited host returned zero valid code-signing identities and no
provisioning profiles.

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
ARCHIVE_PATH=/private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcarchive \
RESULT_BUNDLE_PATH=/private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcresult \
DERIVED_DATA_PATH=/private/tmp/trainy-distribution/DerivedData-2026-07-21-final \
CODE_SIGNING_ALLOWED=NO \
scripts/archive-ios.sh
```

### Final archive and fingerprint audit

`pdftotext` is required only when supplying the ignored credential PDF. The
auditor extracts candidate values in memory and reports only counts and safe
fingerprints on a failure; it never prints a value.

```bash
scripts/audit-ios-archive.py \
  /private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcarchive \
  --result-bundle /private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/2026-07-21-final/Trainy.xcresult \
  --scan-root /private/tmp/trainy-distribution/DerivedData-2026-07-21-final \
  --credential-pdf docs/trainy_api_credentials_fillable_form.pdf \
  --json-output /private/tmp/trainy-distribution/2026-07-21-final/audit.json
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
- Xcode `TrainyTests`: 65/65 passed with no failures or skips on iPhone 17 /
  iOS 26.5, including the diagnostics-consent UI interaction.
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
release owner must install/select the correct Apple Distribution identity and
profile/team, recreate the archive with signing enabled, and repeat this audit
plus entitlement extraction. That future action must not reuse the unsigned
archive as proof of signing and requires separate authorization for any export
or upload.
