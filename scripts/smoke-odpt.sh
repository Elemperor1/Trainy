#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/Sources/TrainyCore"
XCODE_APP="${XCODE_APP:-/Applications/Xcode-26.5.0.app}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_APP/Contents/Developer}"
ODPT_ENV_FILE="${ODPT_ENV_FILE:-$ROOT_DIR/TrainyIOS/Config/odpt.env}"
SMOKE_BINARY="${SMOKE_BINARY:-/private/tmp/trainy-odpt-smoke}"
SWIFT_MODULE_CACHE="${SWIFT_MODULE_CACHE:-/private/tmp/trainy-swift-module-cache}"

# shellcheck source=scripts/lib/odpt-env.sh
source "$ROOT_DIR/scripts/lib/odpt-env.sh"
load_trainy_odpt_env "$ODPT_ENV_FILE"
ODPT_CONSUMER_KEY="${ODPT_CONSUMER_KEY:-}"
export ODPT_CONSUMER_KEY

# shellcheck source=scripts/lib/swift-smoke-sources.sh
source "$ROOT_DIR/scripts/lib/swift-smoke-sources.sh"
configure_trainy_swift_smoke_sources "$CORE_DIR"

if [[ -d "$DEVELOPER_DIR" ]]; then
  export DEVELOPER_DIR
fi

SWIFTC="${SWIFTC:-}"
if [[ -z "$SWIFTC" ]]; then
  if [[ -x "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" ]]; then
    SWIFTC="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
  else
    SWIFTC="$(xcrun -f swiftc)"
  fi
fi

mkdir -p "$SWIFT_MODULE_CACHE"

"$SWIFTC" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -module-cache-path "$SWIFT_MODULE_CACHE" \
  -parse-as-library \
  "${TRAINY_PROVIDER_SMOKE_SOURCES[@]}" \
  "$ROOT_DIR/scripts/ODPTSmoke.swift" \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
