import Foundation

enum ProviderRegistrySmokeError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct ProviderRegistrySmoke {
    static func main() async {
        do {
            try await run()
            print("Provider registry smoke passed: Shinkansen remains active, planned providers are disabled, and region/provider settings are scoped.")
        } catch {
            fputs("Provider registry smoke failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let registry = ProviderRegistry.default
        let expectedPlannedIDs: Set<String> = [
            "taiwan-tdx",
            "hong-kong-mtr",
            "deutsche-bahn",
            "switzerland-opentransportdata",
            "uk-national-rail-darwin",
            "transport-for-nsw",
            "mta-lirr-metro-north",
            "netherlands-ns",
            "south-korea-tago-topis",
            "france-sncf-transport-data-gouv"
        ]

        try require(registry.providers.map(\.providerID) == ["shinkansen"], "Only the implemented Shinkansen provider should be an active provider.")
        try require(registry.defaultProviderID == "shinkansen", "Default provider should remain Shinkansen.")
        try require(registry.defaultScheduleProvider?.providerID == "shinkansen", "Default schedule provider should be Shinkansen.")
        try require(registry.canSearch(providerID: "shinkansen"), "Shinkansen should remain searchable.")

        let activeMetadata = try unwrap(registry.metadata(id: "shinkansen"), "Shinkansen metadata is missing.")
        try require(activeMetadata.displayName == "Japan Shinkansen", "Shinkansen display name changed.")
        try require(activeMetadata.region == .japan, "Shinkansen region should be Japan.")
        try require(activeMetadata.authStrategy.requiresLocalKey, "Shinkansen should declare a local-key auth strategy.")
        try require(activeMetadata.capabilities == [.schedule], "No-key Shinkansen should declare schedule-only capability.")
        try require(activeMetadata.implementationStatus == .active, "Shinkansen should be active.")
        try require(activeMetadata.sourceLinks.count >= 2, "Shinkansen metadata should expose source links.")
        try require(activeMetadata.isSearchable, "Shinkansen active metadata should be searchable.")

        let plannedIDs = Set(registry.plannedProviders.map(\.id))
        try require(plannedIDs == expectedPlannedIDs, "Planned provider IDs do not match the top 10 registry list.")
        try require(registry.providerDirectory.count == expectedPlannedIDs.count + 1, "Directory should include one active provider plus ten planned providers.")

        for providerID in expectedPlannedIDs {
            let metadata = try unwrap(registry.metadata(id: providerID), "Missing planned metadata for \(providerID).")
            try require(metadata.implementationStatus == .planned, "\(providerID) should be marked planned.")
            try require(!metadata.isSearchable, "\(providerID) should not be searchable.")
            try require(!metadata.availability.canSearch, "\(providerID) availability should block search.")
            try require(!registry.canSearch(providerID: providerID), "\(providerID) registry canSearch should be false.")
            try require(registry.provider(id: providerID) == nil, "\(providerID) should not have an active provider object.")
            try require(registry.scheduleProvider(id: providerID) == nil, "\(providerID) should not have a schedule provider implementation.")
            try require(!metadata.displayName.isEmpty, "\(providerID) needs a display name.")
            try require(!metadata.capabilities.isEmpty, "\(providerID) needs declared future capabilities.")
            try require(!metadata.requirements.isEmpty, "\(providerID) needs requirements.")
            try require(!metadata.sourceLinks.isEmpty, "\(providerID) needs source links.")
            try require(metadata.availability.message.localizedCaseInsensitiveContains("needs"), "\(providerID) should explain what is needed.")
        }

        try require(registry.providers(supporting: .schedule).map(\.providerID) == ["shinkansen"], "Schedule support should only include implemented providers.")
        try require(registry.providers(supporting: .serviceAlerts).isEmpty, "No-key registry should not expose active alert providers.")
        try await verifyTrainStoreSettings(registry: registry)
    }

    @MainActor
    private static func verifyTrainStoreSettings(registry: ProviderRegistry) throws {
        let defaults = isolatedDefaults(name: "settings")
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName("settings")) }

        defaults.set("taiwan-tdx", forKey: "trainy.selectedProviderID")
        let store = TrainStore(defaults: defaults, registry: registry)

        try require(store.activeProviderID == "shinkansen", "Store should fall back to Shinkansen when a planned provider is selected.")
        try require(store.selectedProviderID == "shinkansen", "Store should persist only searchable provider selection.")
        try require(store.providerDirectory.count == 11, "Store should expose active plus planned provider metadata.")
        try require(store.visibleProviderDirectory.count == 11, "All-regions view should expose the provider directory.")
        try require(store.activeProviderSupports(.schedule), "Store should expose active schedule support before search.")
        try require(!store.providerCanSearch("taiwan-tdx"), "Planned Taiwan provider should not be searchable.")
        try require(!store.providerSupports(.schedule, providerID: "taiwan-tdx"), "Planned Taiwan provider should not appear as an active schedule provider.")

        store.selectProvider("taiwan-tdx")
        try require(store.selectedProviderID == "shinkansen", "Selecting a planned provider should not change the active provider setting.")

        store.selectRegion(ProviderRegion.germany.id)
        let visibleIDs = Set(store.visibleProviderDirectory.map(\.id))
        try require(store.selectedRegionID == ProviderRegion.germany.id, "Region setting should persist Germany selection.")
        try require(visibleIDs.contains("deutsche-bahn"), "Germany region should show Deutsche Bahn.")
        try require(visibleIDs.contains("shinkansen"), "Active Shinkansen provider should stay visible in filtered provider settings.")
        try require(!visibleIDs.contains("taiwan-tdx"), "Germany region should hide unrelated planned providers.")
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw ProviderRegistrySmokeError.failed(message)
        }
        return value
    }

    private static func isolatedDefaults(name: String) -> UserDefaults {
        let suiteName = defaultsSuiteName(name)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func defaultsSuiteName(_ name: String) -> String {
        "trainy.provider-registry-smoke.\(name)"
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw ProviderRegistrySmokeError.failed(message)
        }
    }
}
