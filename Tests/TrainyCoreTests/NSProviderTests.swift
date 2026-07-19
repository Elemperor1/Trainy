import XCTest
@testable import TrainyCore

@MainActor
final class NSProviderTests: XCTestCase {
    private func fixtureRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private func fixtureData(_ relativePath: String) throws -> Data {
        try Data(contentsOf: fixtureRootURL().appendingPathComponent(relativePath))
    }

    // MARK: - Provider Metadata

    /// Verifies the NS adapter advertises only its implemented capabilities.
    func testNSProviderMetadataIsAdapterReadyWithStationBoardAndServiceAlerts() throws {
        let provider = NSTrainProvider(subscriptionKey: nil)
        let registry = ProviderRegistry(providers: [provider], defaultProviderID: provider.providerID)
        let metadata = try XCTUnwrap(registry.metadata(id: provider.providerID))

        XCTAssertEqual(metadata.displayName, "Netherlands NS")
        XCTAssertEqual(metadata.region, .netherlands)
        XCTAssertEqual(metadata.implementationStatus, .adapterReady)
        XCTAssertEqual(metadata.capabilities, [.stationBoard, .serviceAlerts])
        XCTAssertEqual(metadata.availability.status, .requiresConfiguration)
        XCTAssertFalse(metadata.availability.canSearch)
        XCTAssertTrue(metadata.requirements.contains(.localKey("NS_SUBSCRIPTION_KEY")))
        XCTAssertTrue(metadata.requirements.contains(.attribution("Data from Nederlandse Spoorwegen (NS)")))
        XCTAssertTrue(metadata.sourceLinks.contains { $0.title.localizedCaseInsensitiveContains("NS API portal") })
    }

    func testNSProviderIsConfiguredWhenKeyIsPresent() {
        let provider = NSTrainProvider(subscriptionKey: "test-ns-key")
        XCTAssertTrue(provider.isConfigured)
        XCTAssertEqual(provider.availability.status, .available)
        XCTAssertTrue(provider.availability.canSearch)
    }

    func testNSProviderIsNotConfiguredWithoutKey() {
        let provider = NSTrainProvider(subscriptionKey: nil)
        XCTAssertFalse(provider.isConfigured)
        XCTAssertEqual(provider.availability.status, .requiresConfiguration)
    }

    /// Verifies NS appears in the adapter-ready directory rather than the planned list.
    func testNSProviderAppearsAsAdapterReadyAndNotPlanned() throws {
        let registry = ProviderRegistry.default
        let metadata = try XCTUnwrap(registry.metadata(id: "netherlands-ns"))

        XCTAssertEqual(metadata.implementationStatus, .adapterReady)
        XCTAssertFalse(registry.plannedProviders.contains { $0.id == "netherlands-ns" })
        XCTAssertFalse(registry.activeProviderMetadata.contains { $0.id == "netherlands-ns" })
        XCTAssertTrue(registry.adapterReadyProviderMetadata.contains { $0.id == "netherlands-ns" })
        XCTAssertTrue(registry.providerDirectory.contains { $0.id == "netherlands-ns" })
        XCTAssertFalse(registry.canSearch(providerID: "netherlands-ns"))
    }

    // MARK: - Departures Fixture Mapping

    func testNSDeparturesFixtureDecodesAndMapsToStationBoardEntries() throws {
        let data = try fixtureData("future_providers/ns_departures_utrecht_centraal.json")

        let decoder = JSONDecoder()
        let response = try decoder.decode(NSDeparturesResponse.self, from: data)

        XCTAssertEqual(response.departures.count, 3)

        let first = response.departures[0]
        XCTAssertEqual(first.direction, "Enschede")
        XCTAssertEqual(first.product?.categoryCode, "IC")
        XCTAssertEqual(first.isCancelled, false)
        XCTAssertEqual(first.effectiveTrack, "9")

        let entry = NSTrainProvider.boardEntry(from: first)
        XCTAssertEqual(entry.destinationName, "Enschede")
        XCTAssertEqual(entry.scheduledDeparture, "15:37")
        XCTAssertEqual(entry.estimatedDeparture, "15:44")
        XCTAssertEqual(entry.platform, "9")
        XCTAssertEqual(entry.status, "At platform")
    }

    /// Verifies nested and flat NS departure payloads decode to identical values.
    func testNSDeparturesNestedPayloadMatchesFlatResponse() throws {
        let departure = #"{"direction":"Rotterdam Centraal","name":"Intercity 1735","plannedDateTime":"2026-06-17T15:37:00+0200","actualDateTime":"2026-06-17T15:41:00+0200","plannedTrack":"8","actualTrack":"9","cancelled":false,"departureStatus":"INCOMING","product":{"number":"1735","categoryCode":"IC","shortCategoryName":"IC","longCategoryName":"Intercity","operatorName":"NS","operatorCode":"NS"}}"#
        let flatData = Data(#"{"source":"NS","departures":[\#(departure)]}"#.utf8)
        let nestedData = Data(#"{"payload":{"source":"NS","departures":[\#(departure)]}}"#.utf8)
        let decoder = JSONDecoder()

        let flat = try decoder.decode(NSDeparturesResponse.self, from: flatData)
        let nested = try decoder.decode(NSDeparturesResponse.self, from: nestedData)

        XCTAssertEqual(nested.source, flat.source)
        XCTAssertEqual(nested.departures.count, flat.departures.count)
        XCTAssertEqual(nested.departures.map(\.effectiveTrack), flat.departures.map(\.effectiveTrack))
        XCTAssertEqual(
            nested.departures.map { NSTrainProvider.boardEntry(from: $0) },
            flat.departures.map { NSTrainProvider.boardEntry(from: $0) }
        )
    }

    func testNSDeparturesCancelledEntryMapsToCancelledStatus() throws {
        let data = try fixtureData("future_providers/ns_departures_utrecht_centraal.json")

        let decoder = JSONDecoder()
        let response = try decoder.decode(NSDeparturesResponse.self, from: data)

        let cancelled: NSDeparture? = response.departures.first(where: { $0.isCancelled })
        let unwrapped = try XCTUnwrap(cancelled)
        let entry = NSTrainProvider.boardEntry(from: unwrapped)
        XCTAssertEqual(entry.status, "Cancelled")
    }

    // MARK: - Disruptions Fixture Mapping

    func testNSDisruptionsFixtureDecodesAndMapsToTrainAlerts() throws {
        let data = try fixtureData("future_providers/ns_active_disruptions.json")

        let decoder = JSONDecoder()
        let response = try decoder.decode(NSDisruptionsResponse.self, from: data)

        XCTAssertEqual(response.disruptions.count, 3)

        let first = response.disruptions[0]
        XCTAssertEqual(first.id, "6065287")
        XCTAssertEqual(first.title, "Utrecht - 's-Hertogenbosch.")
        XCTAssertEqual(first.impact?.value, 3)
        XCTAssertNotNil(first.primarySituationText)
        XCTAssertNotNil(first.primaryCauseText)

        let alert = NSTrainProvider.alert(from: first)
        XCTAssertEqual(alert.tone, TrainStatusTone.late)
        XCTAssertTrue(alert.detail.localizedCaseInsensitiveContains("technisch onderzoek"))
        XCTAssertTrue(alert.detail.localizedCaseInsensitiveContains("15:45"))
    }

    func testNSLowImpactDisruptionMapsToWatchTone() throws {
        let data = try fixtureData("future_providers/ns_active_disruptions.json")

        let decoder = JSONDecoder()
        let response = try decoder.decode(NSDisruptionsResponse.self, from: data)

        let lowImpact: NSDisruption? = response.disruptions.first(where: { ($0.impact?.value ?? 0) < 3 })
        let unwrapped = try XCTUnwrap(lowImpact)
        let alert = NSTrainProvider.alert(from: unwrapped)
        XCTAssertEqual(alert.tone, TrainStatusTone.watch)
    }

    // MARK: - Provenance and Attribution

    func testNSProvenanceCarriesAttribution() {
        let provenance = NSTrainProvider.provenance(fetchedAt: nil)

        XCTAssertEqual(provenance.providerID, "netherlands-ns")
        XCTAssertEqual(provenance.providerName, "Nederlandse Spoorwegen (NS)")
        XCTAssertEqual(provenance.sourceName, "NS Reisinformatie API")
        XCTAssertEqual(provenance.sourceKind, .realtimePrediction)
        XCTAssertEqual(provenance.confidence, .confirmed)
        XCTAssertEqual(provenance.attributionText, "Data from Nederlandse Spoorwegen (NS)")
        XCTAssertEqual(provenance.licenseName, "NS API terms")
        XCTAssertEqual(provenance.sourceURL?.absoluteString, "https://apiportal.ns.nl/")
    }

    // MARK: - Station Code Normalization

    func testNSStationCodeNormalization() {
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "UT"), "Utrecht Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ASD"), "Amsterdam Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ut"), "Utrecht Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ZZ"), "ZZ")
    }

    // MARK: - Time Parsing

    func testNSTimeParsesAmsterdamLocalTime() {
        // NS format: offset without colon, e.g. +0200.
        XCTAssertEqual(NSTrainProvider.shortTime(from: "2026-06-17T15:37:00+0200"), "15:37")
        XCTAssertEqual(NSTrainProvider.shortTime(from: "2026-06-17T15:40:00+0200"), "15:40")
        // Colon-separated offset variant.
        XCTAssertEqual(NSTrainProvider.shortTime(from: "2026-06-17T15:37:00+02:00"), "15:37")
        // Insufficient data for extraction.
        XCTAssertNil(NSTrainProvider.shortTime(from: "15:37"))
        XCTAssertNil(NSTrainProvider.shortTime(from: nil))
    }

    // MARK: - Error Mapping

    func testNSFetchStationBoardThrowsWhenUnconfigured() async {
        let provider = NSTrainProvider(subscriptionKey: nil)
        do {
            _ = try await provider.fetchStationBoard(stationID: "UT")
            XCTFail("Expected providerUnavailable error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .providerUnavailable(providerID: "netherlands-ns", reason: "NS subscription key is not configured."))
        } catch {
            XCTFail("Expected ProviderError, got \(error)")
        }
    }

    func testNSFetchServiceAlertsThrowsWhenUnconfigured() async {
        let provider = NSTrainProvider(subscriptionKey: nil)
        do {
            _ = try await provider.fetchServiceAlerts()
            XCTFail("Expected providerUnavailable error")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .providerUnavailable(providerID: "netherlands-ns", reason: "NS subscription key is not configured."))
        } catch {
            XCTFail("Expected ProviderError, got \(error)")
        }
    }
}
