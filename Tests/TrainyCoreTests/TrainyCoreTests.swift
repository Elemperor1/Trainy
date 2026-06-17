import XCTest
@testable import TrainyCore

@MainActor
final class TrainyTests: XCTestCase {
    func testSourceProvenanceMapping() throws {
        let starter = TrainTrip.samples[0]
        XCTAssertEqual(starter.sourceProvenance.sourceKind, .starterCatalog)
        XCTAssertEqual(starter.sourceProvenance.confidence, .estimated)
        XCTAssertEqual(starter.sourceProvenance.sourceKind.compactTitle, "Starter")
        XCTAssertTrue(starter.sourceProvenance.riderExplanation.localizedCaseInsensitiveContains("starter catalog"))
        XCTAssertFalse(starter.sourceProvenance.riderExplanation.localizedCaseInsensitiveContains("live"))
        XCTAssertTrue(
            starter.sourceProvenance.licenseAttributionText.localizedCaseInsensitiveContains("Trainy-owned starter catalog")
        )

        let starterFacts = FactProvenance.starterCatalogFacts(source: starter.sourceProvenance)
        XCTAssertTrue(starterFacts.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred && $0.sourceKind == .inferred })
        XCTAssertTrue(starterFacts.contains { $0.fact == .speed && $0.confidence == .unknown })

        let legacyStarterData = try legacyPayloadWithoutNewSourceFields(from: starter)
        let decodedStarter = try JSONDecoder().decode(TrainTrip.self, from: legacyStarterData)
        XCTAssertEqual(decodedStarter.sourceProvenance.sourceKind, .starterCatalog)
        XCTAssertTrue(
            decodedStarter.factProvenance.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred }
        )

        let odpt = SourceProvenance.odptTimetable(fetchedAt: nil)
        XCTAssertEqual(odpt.sourceKind, .officialTimetable)
        XCTAssertEqual(odpt.confidence, .confirmed)
        XCTAssertEqual(odpt.sourceKind.compactTitle, "Scheduled")
        XCTAssertTrue(odpt.summaryText.localizedCaseInsensitiveContains("Scheduled timetable"))
        XCTAssertTrue(odpt.riderExplanation.localizedCaseInsensitiveContains("scheduled timetable"))
        XCTAssertFalse(odpt.riderExplanation.localizedCaseInsensitiveContains("live"))
        XCTAssertTrue(
            odpt.licenseAttributionText.localizedCaseInsensitiveContains("License: ODPT developer terms")
        )
        XCTAssertTrue(
            odpt.licenseAttributionText.localizedCaseInsensitiveContains("Attribution: Timetable data from ODPT TrainTimetable")
        )
        assertTimetableFacts(FactProvenance.timetableFacts(source: odpt), label: "ODPT")

        let jrEast = SourceProvenance.jrEastTimetable(
            sourceName: "JR East official timetable, Jun 2026 JR JIKOKUHYO",
            sourceURL: URL(string: "https://timetables.jreast.co.jp/en/")
        )
        XCTAssertEqual(jrEast.sourceKind, .officialTimetable)
        XCTAssertEqual(jrEast.confidence, .confirmed)
        assertTimetableFacts(FactProvenance.timetableFacts(source: jrEast), label: "JR East")

        let prediction = SourceProvenance(
            providerID: "gtfs-rt",
            providerName: "GTFS-RT test provider",
            sourceName: "Trip updates",
            sourceKind: .realtimePrediction,
            confidence: .estimated,
            freshness: .fresh,
            licenseName: "Test license",
            attributionText: "GTFS-RT trip updates"
        )
        XCTAssertEqual(prediction.sourceKind.compactTitle, "Prediction")
        XCTAssertTrue(prediction.riderExplanation.localizedCaseInsensitiveContains("prediction"))

        let vehicle = SourceProvenance(
            providerID: "vehicle-test",
            providerName: "Vehicle test provider",
            sourceName: "Vehicle positions",
            sourceKind: .vehiclePosition,
            confidence: .confirmed,
            freshness: .fresh
        )
        XCTAssertEqual(vehicle.sourceKind.riderTitle, "Vehicle position")
        XCTAssertTrue(vehicle.riderExplanation.localizedCaseInsensitiveContains("actual vehicle position"))

        let staleSaved = SourceProvenance(
            providerID: "saved",
            providerName: "Saved trip",
            sourceName: "Legacy saved source",
            sourceKind: .inferred,
            confidence: .unknown,
            freshness: .stale
        )
        XCTAssertTrue(staleSaved.riderExplanation.localizedCaseInsensitiveContains("stale saved data"))
        XCTAssertTrue(SourceProvenance.providerUnavailableText(message: "quota reached").localizedCaseInsensitiveContains("source provider unavailable"))
    }

    func testFallbackBehavior() throws {
        let provider = ShinkansenTrainProvider(consumerKey: nil)
        XCTAssertFalse(provider.isODPTConfigured)
        XCTAssertTrue(provider.supports(.schedule))
        XCTAssertFalse(provider.supports(.serviceAlerts))
        XCTAssertTrue(provider.feedLabel.localizedCaseInsensitiveContains("starter catalog"))
        XCTAssertTrue(provider.includesCatalogResultsInSearch)
    }

    func testRouteMatching() async throws {
        let provider = ShinkansenTrainProvider(consumerKey: nil)
        let trips = try await provider.fetchTrips(matching: "Tokyo to Shin-Osaka", knownRoutes: ShinkansenTrainProvider.routes)
        XCTAssertFalse(trips.isEmpty)
        XCTAssertTrue(trips.contains { ($0.routeID ?? "") == "tokaido" })
        XCTAssertTrue(trips.contains { $0.sourceProvenance.sourceKind == .starterCatalog })
    }

    func testStationNormalization() {
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("Tokyo"), "tokyo")
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("Shin-Osaka"), "shinosaka")
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("odpt.Station.ShinOsaka"), "odptstationshinosaka")
        XCTAssertEqual(ShinkansenTrainProvider.stationName(from: "odpt.Station.ShinOsaka"), "Shin-Osaka")
        XCTAssertEqual(ShinkansenTrainProvider.point(for: "odpt.Station.Tokyo", time: "09:21").name, "Tokyo")
        XCTAssertEqual(ShinkansenTrainProvider.point(for: "odpt.Station.ShinOsaka", time: "11:48").name, "Shin-Osaka")
    }

    func testTimeParsingAcrossMidnight() {
        XCTAssertEqual(ShinkansenTrainProvider.minutes(from: "08:30"), 510)
        XCTAssertEqual(ShinkansenTrainProvider.minutes(from: "invalid"), 0)
        XCTAssertEqual(ShinkansenTrainProvider.minutes(from: "00:30", allowingNextDayAfter: 23 * 60 + 30), 24 * 60 + 30)
        XCTAssertEqual(ShinkansenTrainProvider.durationText(from: "08:00", to: "08:30"), "30m")
        XCTAssertEqual(ShinkansenTrainProvider.durationText(from: "23:30", to: "00:30"), "1h 0m")
        XCTAssertEqual(ShinkansenTrainProvider.progress(currentIndex: 0, count: 1), 0)
        XCTAssertEqual(ShinkansenTrainProvider.progress(currentIndex: 0, count: 3), 0)
        XCTAssertEqual(ShinkansenTrainProvider.progress(currentIndex: 2, count: 3), 0.98)
    }

    func testPersistenceMigrationByDataScope() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let provider = ShinkansenTrainProvider(consumerKey: nil)
        let staleLegacyID = "legacy-us-saved-trip"
        let legacyTrip = TrainTrip.samples[0]
        defaults.set("legacy-us-saved-trips", forKey: "trainy.dataScope")
        defaults.set([staleLegacyID], forKey: "trainy.trackedTripIDs")
        defaults.set(try storedTripsPayload(from: legacyTrip, replacingIDWith: staleLegacyID), forKey: "trainy.trackedTripsPayload")
        defaults.set(staleLegacyID, forKey: "trainy.selectedTripID")

        let migratedStore = TrainStore(defaults: defaults, provider: provider)
        XCTAssertNotEqual(migratedStore.selectedTripID, staleLegacyID)
        XCTAssertFalse(migratedStore.trips.contains { $0.id == staleLegacyID })
        XCTAssertTrue(migratedStore.trips.contains { $0.sourceProvenance.sourceKind == .starterCatalog })

        let currentTrip = TrainTrip.samples[1]
        defaults.set(provider.dataScope, forKey: "trainy.dataScope")
        defaults.set([currentTrip.id], forKey: "trainy.trackedTripIDs")
        defaults.set(try JSONEncoder().encode([currentTrip]), forKey: "trainy.trackedTripsPayload")
        defaults.set(currentTrip.id, forKey: "trainy.selectedTripID")

        let currentStore = TrainStore(defaults: defaults, provider: provider)
        XCTAssertEqual(currentStore.trips.map(\.id), [currentTrip.id])
        XCTAssertEqual(currentStore.selectedTripID, currentTrip.id)
    }

    func testProviderErrorToUserMessageMapping() {
        XCTAssertEqual(
            ProviderError.providerNotFound("test").errorDescription,
            "Trainy could not find provider 'test'."
        )
        XCTAssertEqual(
            ProviderError.unsupportedCapability(providerID: "test", capability: .schedule).errorDescription,
            "Provider 'test' does not support schedule."
        )
        XCTAssertEqual(
            ProviderError.providerUnavailable(providerID: "test", reason: "quota reached").errorDescription,
            "Provider 'test' is unavailable: quota reached."
        )
        XCTAssertEqual(
            ProviderError.missingRequirement(providerID: "test", requirement: .networkAccess).errorDescription,
            "Provider 'test' needs Network access."
        )
        XCTAssertEqual(
            ProviderError.badResponse(providerID: "test").errorDescription,
            "Provider 'test' returned an unexpected response."
        )
        XCTAssertEqual(
            ProviderError.noResults(providerID: "test").errorDescription,
            "Provider 'test' did not return matching trips."
        )
        XCTAssertTrue(SourceProvenance.providerUnavailableText(message: "").localizedCaseInsensitiveContains("unavailable"))
        XCTAssertEqual(TrainyAPIConfig.cleanODPTKey("test-key"), "test-key")
    }

    private func assertTimetableFacts(_ facts: [FactProvenance], label: String) {
        XCTAssertTrue(
            facts.contains { $0.fact == .schedule && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable },
            "\(label) timetable schedule should be confirmed official timetable."
        )
        XCTAssertTrue(
            facts.contains { $0.fact == .platform && $0.confidence == .confirmed && $0.sourceKind == .officialTimetable },
            "\(label) timetable platform should be confirmed official timetable when supplied."
        )
        XCTAssertFalse(
            facts.contains { $0.fact == .route && $0.confidence == .confirmed },
            "\(label) timetable route label should not be marked as a confirmed timetable fact."
        )
        XCTAssertTrue(
            facts.contains { $0.fact == .speed && $0.confidence == .unknown },
            "\(label) timetable speed should not be marked as live."
        )
        XCTAssertTrue(
            facts.contains { $0.fact == .vehiclePosition && $0.confidence == .inferred && $0.sourceKind == .inferred },
            "\(label) timetable map marker should be inferred."
        )
    }

    private func legacyPayloadWithoutNewSourceFields(from trip: TrainTrip) throws -> Data {
        let encoded = try JSONEncoder().encode(trip)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw TestFailure.legacyPayload
        }
        object.removeValue(forKey: "sourceProvenance")
        object.removeValue(forKey: "factProvenance")
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func storedTripsPayload(from trip: TrainTrip, replacingIDWith id: String) throws -> Data {
        let encoded = try JSONEncoder().encode(trip)
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw TestFailure.legacyPayload
        }
        object["id"] = id
        object["providerID"] = "legacy-us"
        object["routeID"] = "legacy-us-route"
        return try JSONSerialization.data(withJSONObject: [object])
    }
}

private enum TestFailure: Error {
    case legacyPayload
}
