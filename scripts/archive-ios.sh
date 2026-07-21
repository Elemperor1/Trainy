#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TrainyIOS/Trainy.xcodeproj"
XCODE_APP="${XCODE_APP:-/Applications/Xcode-26.5.0.app}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_APP/Contents/Developer}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/private/tmp/trainy-distribution/Trainy.xcarchive}"
RESULT_BUNDLE_PATH="${RESULT_BUNDLE_PATH:-${ARCHIVE_PATH%.xcarchive}.xcresult}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/trainy-distribution/DerivedData}"
CLONED_SOURCE_PACKAGES_DIR="${CLONED_SOURCE_PACKAGES_DIR:-/private/tmp/trainy-source-packages}"
PACKAGE_CACHE_PATH="${PACKAGE_CACHE_PATH:-/private/tmp/trainy-swiftpm-cache}"
XCODEBUILD_HOME="${XCODEBUILD_HOME:-/private/tmp/trainy-xcode-home}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
PRODUCTION_PROXY_BASE_URL="https://trainy-ns-provider-proxy.trainy-jacob.workers.dev"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2
  exit 1
fi

if [[ "$CODE_SIGNING_ALLOWED" != "YES" && "$CODE_SIGNING_ALLOWED" != "NO" ]]; then
  echo "CODE_SIGNING_ALLOWED must be YES or NO." >&2
  exit 1
fi

if [[ -e "$ARCHIVE_PATH" || -e "$RESULT_BUNDLE_PATH" ]]; then
  echo "Archive or result bundle already exists; choose fresh output paths." >&2
  exit 1
fi

umask 077
mkdir -p \
  "$(dirname "$ARCHIVE_PATH")" \
  "$(dirname "$RESULT_BUNDLE_PATH")" \
  "$DERIVED_DATA_PATH" \
  "$CLONED_SOURCE_PACKAGES_DIR" \
  "$PACKAGE_CACHE_PATH" \
  "$XCODEBUILD_HOME"

export DEVELOPER_DIR

# Distribution candidates must never inherit the local ODPT developer secret.
unset ODPT_CONSUMER_KEY

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not ready for the configured developer directory." >&2
  exit 1
fi

SOURCE_PACKAGES_ALIAS="$CLONED_SOURCE_PACKAGES_DIR"
if [[ "$SOURCE_PACKAGES_ALIAS" == /private/tmp/* ]]; then
  SOURCE_PACKAGES_ALIAS="/tmp/${SOURCE_PACKAGES_ALIAS#/private/tmp/}"
fi

# Preserve real module/object paths for dsymutil. Only first-party Swift source
# paths and compile-time file macros are normalized before linking.
SWIFT_PREFIX_MAP_FLAGS="\$(inherited) -file-compilation-dir /Trainy -debug-prefix-map $ROOT_DIR=/Trainy"
CLANG_PREFIX_MAP_FLAGS="\$(inherited) -fdebug-compilation-dir=/Sources -fmacro-prefix-map=$ROOT_DIR=/Trainy -fmacro-prefix-map=$CLONED_SOURCE_PACKAGES_DIR=/SourcePackages -fmacro-prefix-map=$SOURCE_PACKAGES_ALIAS=/SourcePackages"

HOME="$XCODEBUILD_HOME" CFFIXED_USER_HOME="$XCODEBUILD_HOME" xcodebuild \
  -quiet \
  -project "$PROJECT" \
  -scheme Trainy \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" \
  -packageCachePath "$PACKAGE_CACHE_PATH" \
  CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  OTHER_CFLAGS="$CLANG_PREFIX_MAP_FLAGS" \
  OTHER_SWIFT_FLAGS="$SWIFT_PREFIX_MAP_FLAGS" \
  ODPT_CONSUMER_KEY= \
  TRAINY_CRASHLYTICS_VALIDATE_ONLY=YES \
  TRAINY_PROVIDER_PROXY_BASE_URL="$PRODUCTION_PROXY_BASE_URL" \
  TRAINY_SOURCE_PACKAGES_DIR="$CLONED_SOURCE_PACKAGES_DIR" \
  SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
  archive

"$ROOT_DIR/scripts/normalize-ios-archive-metadata.py" "$ARCHIVE_PATH"

echo "Release archive created at $ARCHIVE_PATH"
echo "Build result bundle created at $RESULT_BUNDLE_PATH"
