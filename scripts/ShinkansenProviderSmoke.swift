import Foundation

enum ShinkansenProviderSmokeError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

@main
struct ShinkansenProviderSmoke {
    static func main() async {
        do {
            try await run()
            print("Shinkansen provider smoke passed: protocol conformance, no-key starter startup, samples, refresh, and saved-trip migration are intact.")
        } catch {
            fputs("Shinkansen provider smoke failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func run() async throws {
        let provider = ShinkansenTrainProvider(consumerKey: nil, session: URLSession(configuration: .ephemeral))
        let trainProvider: any TrainProvider = provider
        let scheduleProvider: any ScheduleFeedProvider = provider
        let realtimeProvider: any RealtimeFeedProvider = provider

        try require(trainProvider.providerID == "shinkansen", "providerID changed from shinkansen.")
        try require(trainProvider.dataScope == "japan-shinkansen-v2", "dataScope changed from japan-shinkansen-v2.")
        try require(!provider.isODPTConfigured, "Nil consumer key should leave ODPT unconfigured.")
        try require(provider.includesCatalogResultsInSearch, "No-key provider should include starter catalog search results.")
        try require(provider.capabilities == [.schedule], "No-key provider should declare schedule-only capability.")
        try require(provider.authStrategy.requiresLocalKey, "Provider should declare a local key auth strategy.")
        try require(provider.availability.canSearch, "No-key starter catalog should remain searchable.")

        let keyedProvider = ShinkansenTrainProvider(consumerKey: "smoke-key", session: URLSession(configuration: .ephemeral))
        try require(keyedProvider.isODPTConfigured, "Non-empty consumer key should configure ODPT mode.")
        try require(keyedProvider.capabilities.contains(.serviceAlerts), "ODPT-configured provider should declare alert capability.")
        try require(!keyedProvider.includesCatalogResultsInSearch, "ODPT-configured searches should not mix starter catalog rows into query results.")

        let routes = try await scheduleProvider.fetchRoutes()
        try require(!routes.isEmpty, "Shinkansen provider returned no routes.")

        let starterTrips = try await scheduleProvider.fetchTrips(matching: "Tokyo", knownRoutes: routes)
        try require(!starterTrips.isEmpty, "No-key provider returned no starter trips.")
        try require(starterTrips.allSatisfy { $0.providerID == "shinkansen" }, "Starter trips should remain owned by shinkansen provider.")
        try require(starterTrips.allSatisfy { $0.sourceProvenance.sourceKind == .starterCatalog }, "No-key searches should return starter catalog provenance.")
        try require(provider.defaultTrips.map(\.id) == Array(provider.catalog.prefix(4)).map(\.id), "Default trips should remain the first four catalog trips.")
        try require(TrainTrip.samples.map(\.id) == provider.defaultTrips.map(\.id), "TrainTrip.samples no longer mirrors default Shinkansen trips.")
        try require(TrainTrip.discoverable.map(\.id) == Array(provider.catalog.dropFirst(provider.defaultTrips.count)).map(\.id), "TrainTrip.discoverable no longer mirrors Shinkansen catalog remainder.")

        let refreshedTrip = try await realtimeProvider.refresh(provider.defaultTrips[0], knownRoutes: routes)
        try require(refreshedTrip?.providerID == "shinkansen", "No-key refresh should keep Shinkansen provider ownership.")
        try require(refreshedTrip?.updated == "just now", "No-key refresh should preserve starter refresh behavior.")

        try await verifyNoKeyStoreStartup(provider: provider)
        try await verifyIDOnlyPersistenceMigration(provider: provider)
        try await verifyStoredPayloadMigration(provider: provider)
    }

    @MainActor
    private static func verifyNoKeyStoreStartup(provider: ShinkansenTrainProvider) throws {
        let defaults = isolatedDefaults(name: "startup")
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName("startup")) }

        let store = TrainStore(defaults: defaults, provider: provider)
        try require(store.activeProviderID == "shinkansen", "TrainStore did not select the Shinkansen provider.")
        try require(store.trips.map(\.id) == provider.defaultTrips.map(\.id), "No-key TrainStore should start with default starter trips.")
        try require(store.trips.allSatisfy { $0.sourceProvenance.sourceKind == .starterCatalog }, "No-key TrainStore startup should use starter catalog provenance.")
        try require(store.selectedTripID == provider.defaultTrips[0].id, "No-key TrainStore should select the first default trip.")
        try require(store.activeProviderSupports(.schedule), "UI preflight should see schedule support before search.")
    }

    @MainActor
    private static func verifyIDOnlyPersistenceMigration(provider: ShinkansenTrainProvider) throws {
        let defaults = isolatedDefaults(name: "id-migration")
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName("id-migration")) }

        let trackedIDs = [provider.catalog[2].id, provider.catalog[4].id]
        defaults.set(provider.dataScope, forKey: "trainy.dataScope")
        defaults.set(trackedIDs, forKey: "trainy.trackedTripIDs")
        defaults.set(trackedIDs[1], forKey: "trainy.selectedTripID")

        let store = TrainStore(defaults: defaults, provider: provider)
        try require(store.trips.map(\.id) == trackedIDs, "ID-only saved trips did not resolve from the Shinkansen catalog.")
        try require(store.selectedTripID == trackedIDs[1], "ID-only selected trip did not migrate.")
    }

    @MainActor
    private static func verifyStoredPayloadMigration(provider: ShinkansenTrainProvider) throws {
        let defaults = isolatedDefaults(name: "payload-migration")
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName("payload-migration")) }

        let savedTrip = provider.defaultTrips[1]
        let savedPayload = try JSONEncoder().encode([savedTrip])
        defaults.set(provider.dataScope, forKey: "trainy.dataScope")
        defaults.set(savedPayload, forKey: "trainy.trackedTripsPayload")
        defaults.set(savedTrip.id, forKey: "trainy.selectedTripID")

        let store = TrainStore(defaults: defaults, provider: provider)
        try require(store.trips.map(\.id) == [savedTrip.id], "Stored payload saved trip did not load.")
        try require(store.selectedTripID == savedTrip.id, "Stored payload selected trip did not load.")
        try require(store.trips[0].sourceProvenance.sourceKind == .starterCatalog, "Stored payload source provenance did not remain decodable.")
    }

    private static func isolatedDefaults(name: String) -> UserDefaults {
        let suiteName = defaultsSuiteName(name)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static func defaultsSuiteName(_ name: String) -> String {
        "trainy.shinkansen-provider-smoke.\(name)"
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else {
            throw ShinkansenProviderSmokeError.failed(message)
        }
    }
}
