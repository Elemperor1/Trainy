#!/usr/bin/env bash

# Shared, Foundation-only provider source manifests for executable host smokes.
# Keep UI and UIKit-backed design files out of this list so the harnesses retain
# their fast credential-free macOS execution contract.
TRAINY_PROVIDER_SMOKE_SOURCES=()
TRAINY_STORE_SMOKE_SOURCES=()

configure_trainy_swift_smoke_sources() {
  local core_dir="$1"

  TRAINY_PROVIDER_SMOKE_SOURCES=(
    "$core_dir/TrainModels.swift"
    "$core_dir/Providers/ProviderCapabilities.swift"
    "$core_dir/Providers/ProviderErrors.swift"
    "$core_dir/Providers/TrainProvider.swift"
    "$core_dir/Providers/ProviderRegistry.swift"
    "$core_dir/Providers/ProviderTextUtilities.swift"
    "$core_dir/ProviderProxy.swift"
    "$core_dir/Providers/ODPT/ODPTClient.swift"
    "$core_dir/Providers/ODPT/ODPTModels.swift"
    "$core_dir/Providers/JREast/JREastTimetableClient.swift"
    "$core_dir/Providers/Shinkansen/ShinkansenTrainProvider.swift"
    "$core_dir/Providers/Shinkansen/ShinkansenRouteCatalog.swift"
    "$core_dir/Providers/Shinkansen/ShinkansenStarterCatalog.swift"
    "$core_dir/Providers/Shinkansen/ShinkansenTrainTripMapper.swift"
    "$core_dir/Providers/NS/NSClient.swift"
    "$core_dir/Providers/NS/NSModels.swift"
    "$core_dir/Providers/NS/NSTrainProvider.swift"
    "$core_dir/TrainDataProvider.swift"
  )

  TRAINY_STORE_SMOKE_SOURCES=(
    "$core_dir/TrainStore.swift"
  )
}
