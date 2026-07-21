#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT_DIR/TrainyIOS/Trainy.xcodeproj"
XCODE_APP="${XCODE_APP:-/Applications/Xcode-26.5.0.app}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_APP/Contents/Developer}"
DESTINATION="${DESTINATION:-generic/platform=iOS Simulator}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/private/tmp/trainy-derived}"
CLONED_SOURCE_PACKAGES_DIR="${CLONED_SOURCE_PACKAGES_DIR:-/private/tmp/trainy-source-packages}"
PACKAGE_CACHE_PATH="${PACKAGE_CACHE_PATH:-/private/tmp/trainy-swiftpm-cache}"
XCODEBUILD_HOME="${XCODEBUILD_HOME:-/private/tmp/trainy-xcode-home}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"
ODPT_ENV_FILE="${ODPT_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/odpt.env}"

# shellcheck source=scripts/lib/odpt-env.sh
source "$ROOT_DIR/scripts/lib/odpt-env.sh"
load_trainy_odpt_env "$ODPT_ENV_FILE"

ODPT_CONSUMER_KEY="${ODPT_CONSUMER_KEY:-}"
export ODPT_CONSUMER_KEY
TRAINY_PROVIDER_PROXY_BASE_URL="${TRAINY_PROVIDER_PROXY_BASE_URL:-}"
export TRAINY_PROVIDER_PROXY_BASE_URL

XCODE_BUILD_SETTINGS=(
  "CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED"
  "TRAINY_PROVIDER_PROXY_BASE_URL=$TRAINY_PROVIDER_PROXY_BASE_URL"
  "TRAINY_SOURCE_PACKAGES_DIR=$CLONED_SOURCE_PACKAGES_DIR"
)

if [[ -n "${ARCHS:-}" ]]; then
  XCODE_BUILD_SETTINGS+=("ARCHS=$ARCHS")
fi

if [[ -n "${ONLY_ACTIVE_ARCH:-}" ]]; then
  XCODE_BUILD_SETTINGS+=("ONLY_ACTIVE_ARCH=$ONLY_ACTIVE_ARCH")
fi

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2
  exit 1
fi

export DEVELOPER_DIR
mkdir -p "$CLONED_SOURCE_PACKAGES_DIR" "$PACKAGE_CACHE_PATH" "$XCODEBUILD_HOME"

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "xcodebuild is not ready. If this is a license issue, run:" >&2
  echo "  sudo DEVELOPER_DIR=\"$DEVELOPER_DIR\" xcodebuild -license accept" >&2
  exit 1
fi

HOME="$XCODEBUILD_HOME" CFFIXED_USER_HOME="$XCODEBUILD_HOME" xcodebuild \
  -project "$PROJECT" \
  -scheme Trainy \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR" \
  -packageCachePath "$PACKAGE_CACHE_PATH" \
  "${XCODE_BUILD_SETTINGS[@]}" \
  build
