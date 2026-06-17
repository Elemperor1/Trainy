#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_DIR="$ROOT_DIR/Sources/TrainyCore"
XCODE_APP="${XCODE_APP:-/Applications/Xcode-26.5.0.app}"
DEVELOPER_DIR="${DEVELOPER_DIR:-$XCODE_APP/Contents/Developer}"
SMOKE_BINARY="${SMOKE_BINARY:-/private/tmp/trainy-provider-registry-smoke}"
SWIFT_MODULE_CACHE="${SWIFT_MODULE_CACHE:-/private/tmp/trainy-swift-module-cache}"

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
  "$CORE_DIR/TrainModels.swift" \
  "$CORE_DIR/Providers/ProviderCapabilities.swift" \
  "$CORE_DIR/Providers/ProviderErrors.swift" \
  "$CORE_DIR/Providers/TrainProvider.swift" \
  "$CORE_DIR/Providers/ProviderRegistry.swift" \
  "$CORE_DIR/Providers/ProviderTextUtilities.swift" \
  "$CORE_DIR/Providers/ODPT/ODPTClient.swift" \
  "$CORE_DIR/Providers/ODPT/ODPTModels.swift" \
  "$CORE_DIR/Providers/JREast/JREastTimetableClient.swift" \
  "$CORE_DIR/Providers/Shinkansen/ShinkansenTrainProvider.swift" \
  "$CORE_DIR/Providers/Shinkansen/ShinkansenRouteCatalog.swift" \
  "$CORE_DIR/Providers/Shinkansen/ShinkansenStarterCatalog.swift" \
  "$CORE_DIR/Providers/Shinkansen/ShinkansenTrainTripMapper.swift" \
  "$CORE_DIR/TrainDataProvider.swift" \
  "$CORE_DIR/TrainStore.swift" \
  "$ROOT_DIR/scripts/ProviderRegistrySmoke.swift" \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
