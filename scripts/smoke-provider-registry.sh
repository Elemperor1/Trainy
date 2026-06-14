#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
  "$ROOT_DIR/TrainyIOS/Trainy/TrainModels.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ProviderCapabilities.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ProviderErrors.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/TrainProvider.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ProviderRegistry.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ProviderTextUtilities.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ODPT/ODPTClient.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/ODPT/ODPTModels.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/JREast/JREastTimetableClient.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/Shinkansen/ShinkansenTrainProvider.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/Shinkansen/ShinkansenRouteCatalog.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/Shinkansen/ShinkansenStarterCatalog.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/Providers/Shinkansen/ShinkansenTrainTripMapper.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/TrainDataProvider.swift" \
  "$ROOT_DIR/TrainyIOS/Trainy/TrainStore.swift" \
  "$ROOT_DIR/scripts/ProviderRegistrySmoke.swift" \
  -o "$SMOKE_BINARY"

"$SMOKE_BINARY"
