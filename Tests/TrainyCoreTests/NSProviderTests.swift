import Foundation
import SwiftUI
import UIKit
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

    func testNSProviderProductionStatusDoesNotDependOnBuildConfiguration() throws {
        let unconfigured = NSTrainProvider(proxyBaseURL: nil)
        let unconfiguredRegistry = ProviderRegistry(
            providers: [unconfigured],
            defaultProviderID: unconfigured.providerID
        )
        let metadata = try XCTUnwrap(unconfiguredRegistry.metadata(id: unconfigured.providerID))

        XCTAssertEqual(metadata.displayName, "Netherlands NS")
        XCTAssertEqual(metadata.region, .netherlands)
        XCTAssertEqual(metadata.implementationStatus, .active)
        XCTAssertEqual(metadata.capabilities, [.stationBoard, .serviceAlerts])
        XCTAssertEqual(metadata.availability.status, .requiresProxy)
        XCTAssertFalse(metadata.availability.canSearch)
        XCTAssertFalse(metadata.isRiderAvailable)
        XCTAssertTrue(metadata.requirements.contains(.proxy))
        XCTAssertFalse(metadata.requirements.contains { requirement in
            if case .localKey = requirement { return true }
            return false
        })
        XCTAssertTrue(metadata.requirements.contains(.attribution("Data from Nederlandse Spoorwegen (NS)")))

        let configured = NSTrainProvider(proxyBaseURL: URL(string: "https://proxy.example")!)
        let configuredRegistry = ProviderRegistry(
            providers: [configured],
            defaultProviderID: configured.providerID
        )
        let configuredMetadata = try XCTUnwrap(configuredRegistry.metadata(id: configured.providerID))
        XCTAssertTrue(configured.isConfigured)
        XCTAssertEqual(configuredMetadata.implementationStatus, .active)
        XCTAssertEqual(configuredMetadata.availability.status, .available)
        XCTAssertTrue(configuredMetadata.isRiderAvailable)
        XCTAssertTrue(configured.authStrategy.requiresProxy)
    }

    func testNSProxyStationFixtureDecodesIntoProviderStations() throws {
        let response = try ProviderProxyHealthClient.makeDecoder().decode(
            NSProxyStationSearchResponse.self,
            from: fixtureData("future_providers/ns_proxy_station_search_utrecht.json")
        )

        XCTAssertEqual(response.data.stations.count, 2)
        XCTAssertEqual(response.data.stations[0].code, "UT")
        XCTAssertEqual(response.data.stations[0].name, "Utrecht Centraal")
        XCTAssertEqual(response.meta.provider, "ns")
        XCTAssertEqual(response.meta.freshness, .fresh)
        XCTAssertEqual(response.meta.attribution, "Data from Nederlandse Spoorwegen (NS)")
    }

    func testNSProxyDeparturesFixtureMapsToStationBoardEntriesAndStaleProvenance() throws {
        let response = try ProviderProxyHealthClient.makeDecoder().decode(
            NSProxyDeparturesResponse.self,
            from: fixtureData("future_providers/ns_proxy_departures_utrecht.json")
        )

        XCTAssertEqual(response.data.departures.count, 3)
        let first = NSTrainProvider.boardEntry(from: response.data.departures[0])
        XCTAssertEqual(first.tripID, "1735")
        XCTAssertEqual(first.destinationName, "Enschede")
        XCTAssertEqual(first.scheduledDeparture, "15:37")
        XCTAssertEqual(first.estimatedDeparture, "15:44")
        XCTAssertEqual(first.platform, "9")
        XCTAssertEqual(first.status, "At platform")

        let cancelled = NSTrainProvider.boardEntry(from: response.data.departures[2])
        XCTAssertEqual(cancelled.status, "Cancelled")

        let provenance = NSTrainProvider.provenance(meta: response.meta)
        XCTAssertEqual(provenance.freshness, .stale)
        XCTAssertEqual(provenance.sourceName, "NS Reisinformatie API")
        XCTAssertEqual(provenance.attributionText, "Data from Nederlandse Spoorwegen (NS)")
    }

    func testNSProxyClientBuildsOnlyNarrowProxyURLs() throws {
        let stationURL = try XCTUnwrap(NSClient.endpointURL(
            baseURL: URL(string: "https://proxy.example/trainy")!,
            path: "v1/ns/stations",
            queryItems: [URLQueryItem(name: "query", value: "Utrecht")]
        ))
        let departureURL = try XCTUnwrap(NSClient.endpointURL(
            baseURL: URL(string: "http://127.0.0.1:8787")!,
            path: "v1/ns/departures",
            queryItems: [URLQueryItem(name: "station", value: "UT")]
        ))

        XCTAssertEqual(stationURL.absoluteString, "https://proxy.example/trainy/v1/ns/stations?query=Utrecht")
        XCTAssertEqual(departureURL.absoluteString, "http://127.0.0.1:8787/v1/ns/departures?station=UT")
        XCTAssertFalse(stationURL.absoluteString.localizedCaseInsensitiveContains("gateway.apiportal"))
        XCTAssertFalse(stationURL.absoluteString.localizedCaseInsensitiveContains("subscription"))
    }

    func testBoundedURLSessionEnforcesDeclaredSizeAndWholeResponseDeadline() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BoundedResponseURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let request = URLRequest(url: URL(string: "https://oversized.test/value")!)
            _ = try await BoundedURLSession.data(
                for: request,
                using: session,
                maximumResponseBytes: 64,
                deadline: .seconds(1)
            )
            XCTFail("A declared oversized response must be rejected")
        } catch {
            XCTAssertEqual(error as? BoundedURLSessionError, .responseTooLarge)
        }

        do {
            let request = URLRequest(url: URL(string: "https://slow.test/value")!)
            _ = try await BoundedURLSession.data(
                for: request,
                using: session,
                maximumResponseBytes: 64,
                deadline: .milliseconds(100)
            )
            XCTFail("A response body that never completes must hit the whole-response deadline")
        } catch {
            XCTAssertEqual(error as? BoundedURLSessionError, .timedOut)
        }
    }

    func testNSProvenanceCarriesTruthfulAttributionWithoutFreshnessEvidence() {
        let provenance = NSTrainProvider.provenance(fetchedAt: nil)

        XCTAssertEqual(provenance.providerID, "netherlands-ns")
        XCTAssertEqual(provenance.providerName, "Nederlandse Spoorwegen (NS)")
        XCTAssertEqual(provenance.sourceName, "NS Reisinformatie API")
        XCTAssertEqual(provenance.sourceKind, .realtimePrediction)
        XCTAssertEqual(provenance.confidence, .confirmed)
        XCTAssertEqual(provenance.freshness, .unknown)
        XCTAssertEqual(provenance.attributionText, "Data from Nederlandse Spoorwegen (NS)")
        XCTAssertEqual(provenance.licenseName, "NS API terms")
        XCTAssertEqual(provenance.sourceURL?.absoluteString, "https://apiportal.ns.nl/")
    }

    func testNSStationCodeNormalizationAndAmsterdamTimeParsing() {
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "UT"), "Utrecht Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ASD"), "Amsterdam Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ut"), "Utrecht Centraal")
        XCTAssertEqual(NSTrainProvider.stationDisplayName(for: "ZZ"), "ZZ")
        XCTAssertEqual(NSTrainProvider.shortTime(from: "2026-06-17T15:37:00+0200"), "15:37")
        XCTAssertEqual(NSTrainProvider.shortTime(from: "2026-06-17T15:37:00+02:00"), "15:37")
        XCTAssertNil(NSTrainProvider.shortTime(from: "15:37"))
        XCTAssertNil(NSTrainProvider.shortTime(from: "2026-02-30T15:37:00+02:00"))

        let malformed = NSProxyDeparture(
            id: "fixture",
            service: "Intercity",
            destination: "Utrecht",
            scheduledAt: "2026-02-30T15:37:00+02:00",
            expectedAt: nil,
            platform: nil,
            status: .scheduled
        )
        XCTAssertEqual(NSTrainProvider.boardEntry(from: malformed).scheduledDeparture, "Time unavailable")
    }

    func testStationSearchViewModelCoversResultsNoMatchRateLimitAndRecovery() async {
        let freshPage = makeSearchPage(stations: [makeStation()], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            searchOutcomes: [
                .failure(.offline),
                .success(freshPage),
                .success(makeSearchPage(stations: [], freshness: .fresh)),
                .failure(.rateLimited(retryAfterSeconds: 45))
            ]
        )
        let viewModel = StationDirectoryViewModel(provider: provider)

        viewModel.query = "Utrecht"
        await viewModel.search()
        XCTAssertEqual(viewModel.phase, .failed(.offline))

        await viewModel.search()
        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertEqual(viewModel.stations.map(\.code), ["UT"])
        XCTAssertEqual(viewModel.accessibilityAnnouncement, "1 NS stations found.")

        viewModel.query = "Missing"
        await viewModel.search()
        XCTAssertEqual(viewModel.phase, .noMatches)
        XCTAssertTrue(viewModel.stations.isEmpty)

        viewModel.query = "Amsterdam"
        await viewModel.search()
        XCTAssertEqual(viewModel.phase, .failed(.rateLimited(retryAfterSeconds: 45)))
    }

    func testStationSearchViewModelMarksProxyFallbackAsStale() async {
        let provider = SequencedNSRiderProvider(
            searchOutcomes: [.success(makeSearchPage(stations: [makeStation()], freshness: .stale))]
        )
        let viewModel = StationDirectoryViewModel(provider: provider)
        viewModel.query = "Utrecht"

        await viewModel.search()

        XCTAssertEqual(viewModel.phase, .results)
        XCTAssertEqual(viewModel.notice, .stale)
        XCTAssertEqual(viewModel.sourceProvenance?.freshness, .stale)

        viewModel.query = "U"
        viewModel.scheduleSearch()
        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertTrue(viewModel.stations.isEmpty)
        XCTAssertNil(viewModel.sourceProvenance)
    }

    func testDepartureBoardViewModelCoversLoadedEmptyStaleOfflineAndRateLimitStates() async {
        let board = makeBoard(departures: [
            StationBoardDeparture(
                tripID: "1735",
                trainName: "Intercity 1735",
                destinationName: "Enschede",
                scheduledDeparture: "15:37",
                estimatedDeparture: "15:44",
                platform: "9",
                status: "Delayed"
            )
        ], freshness: .stale)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [
                .success(board),
                .failure(.offline)
            ],
            alertOutcomes: [.success(makeAlertPage(
                alerts: [TrainAlert(title: "Track work", detail: "Allow extra time.", tone: .watch)],
                freshness: .fresh
            ))]
        )
        let viewModel = StationBoardViewModel(station: makeStation(), provider: provider)

        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.notice, .stale)
        XCTAssertEqual(viewModel.board?.departures.count, 1)
        XCTAssertEqual(viewModel.alerts.count, 1)

        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.notice, .offline)
        XCTAssertEqual(viewModel.board?.departures.count, 1)

        let emptyProvider = SequencedNSRiderProvider(
            boardOutcomes: [.success(makeBoard(departures: [], freshness: .fresh))]
        )
        let emptyViewModel = StationBoardViewModel(station: makeStation(), provider: emptyProvider)
        await emptyViewModel.load()
        XCTAssertEqual(emptyViewModel.phase, .empty)

        let limitedProvider = SequencedNSRiderProvider(
            boardOutcomes: [.failure(.rateLimited(retryAfterSeconds: 30))]
        )
        let limitedViewModel = StationBoardViewModel(station: makeStation(), provider: limitedProvider)
        await limitedViewModel.load()
        XCTAssertEqual(limitedViewModel.phase, .failed(.rateLimited(retryAfterSeconds: 30)))
    }

    func testDepartureBoardKeepsAlertFreshnessAndFailureSeparateFromBoardState() async {
        let board = makeBoard(
            departures: [StationBoardDeparture(
                trainName: "Intercity 1735",
                destinationName: "Enschede",
                scheduledDeparture: "15:37"
            )],
            freshness: .fresh
        )
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board), .success(board)],
            alertOutcomes: [
                .success(makeAlertPage(
                    alerts: [TrainAlert(title: "Track work", detail: "Allow extra time.", tone: .watch)],
                    freshness: .stale
                )),
                .failure(.offline)
            ]
        )
        let viewModel = StationBoardViewModel(station: makeStation(), provider: provider)

        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.notice, nil)
        XCTAssertEqual(viewModel.alertPhase, .loaded)
        XCTAssertEqual(viewModel.alertFreshness, .stale)
        XCTAssertEqual(viewModel.alertNotice, .stale)
        XCTAssertEqual(viewModel.alerts.count, 1)

        await viewModel.load()
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.alertPhase, .loaded)
        XCTAssertEqual(viewModel.alertNotice, .offline)
        XCTAssertEqual(viewModel.alerts.count, 1, "A failed refresh keeps the labelled last alert response")

        let unavailableProvider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board)],
            alertOutcomes: [.failure(.offline)]
        )
        let unavailable = StationBoardViewModel(station: makeStation(), provider: unavailableProvider)
        await unavailable.load()
        XCTAssertEqual(unavailable.phase, .loaded)
        XCTAssertEqual(unavailable.alertPhase, .failed(.offline))
        XCTAssertTrue(unavailable.alerts.isEmpty)
    }

    func testDepartureBoardPublishesAlertsWithoutWaitingForTheBoard() async {
        let board = makeBoard(
            departures: [StationBoardDeparture(
                trainName: "Intercity 1735",
                destinationName: "Enschede",
                scheduledDeparture: "15:37"
            )],
            freshness: .fresh
        )
        let alertPage = makeAlertPage(
            alerts: [TrainAlert(title: "Track work", detail: "Allow extra time.", tone: .watch)],
            freshness: .fresh
        )
        let provider = DelayedBoardNSRiderProvider(board: board, alertPage: alertPage)
        let viewModel = StationBoardViewModel(station: makeStation(), provider: provider)
        let loadTask = Task { await viewModel.load() }

        for _ in 0..<200 where !(await provider.boardIsWaiting()) {
            await Task.yield()
        }
        for _ in 0..<200 where viewModel.alertPhase != .loaded {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.phase, .loading)
        XCTAssertEqual(viewModel.alertPhase, .loaded)
        XCTAssertEqual(viewModel.alerts.map(\.title), ["Track work"])

        await provider.releaseBoard()
        await loadTask.value
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    func testDepartureBoardIgnoresACompletedResultFromAnOlderLoad() async {
        let oldBoard = makeBoard(
            departures: [StationBoardDeparture(
                trainName: "Old service",
                destinationName: "Old destination",
                scheduledDeparture: "15:30"
            )],
            freshness: .fresh
        )
        let newBoard = makeBoard(
            departures: [StationBoardDeparture(
                trainName: "Current service",
                destinationName: "Current destination",
                scheduledDeparture: "15:40"
            )],
            freshness: .fresh
        )
        let provider = SupersedingNSRiderProvider(
            delayedBoard: oldBoard,
            currentBoard: newBoard,
            alertPage: makeAlertPage(alerts: [], freshness: .fresh)
        )
        let viewModel = StationBoardViewModel(station: makeStation(), provider: provider)
        let oldLoad = Task { await viewModel.load() }

        for _ in 0..<200 where !(await provider.firstBoardIsWaiting()) {
            await Task.yield()
        }
        await viewModel.load()
        XCTAssertEqual(viewModel.board?.departures.first?.destinationName, "Current destination")

        await provider.releaseFirstBoard()
        await oldLoad.value
        XCTAssertEqual(viewModel.board?.departures.first?.destinationName, "Current destination")
    }

    func testDepartureAndAlertFreshnessExpiresAgainstTheCurrentClock() async {
        let initialNow = Date(timeIntervalSince1970: 1_784_467_200)
        let clock = LockedTestClock(initialNow)
        let validUntil = initialNow.addingTimeInterval(20)
        let board = makeBoard(
            departures: [StationBoardDeparture(
                trainName: "Intercity 1735",
                destinationName: "Enschede",
                scheduledDeparture: "15:37"
            )],
            freshness: .fresh,
            validUntil: validUntil
        )
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board)],
            alertOutcomes: [.success(makeAlertPage(
                alerts: [TrainAlert(title: "Track work", detail: "Allow extra time.", tone: .watch)],
                freshness: .fresh,
                validUntil: validUntil
            ))]
        )
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read)
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.boardFreshness, .fresh)
        XCTAssertEqual(viewModel.alertFreshness, .fresh)
        XCTAssertNil(viewModel.notice)
        XCTAssertNil(viewModel.alertNotice)

        clock.advance(by: 21)
        viewModel.refreshFreshnessForCurrentTime()

        XCTAssertEqual(viewModel.boardFreshness, .expired)
        XCTAssertEqual(viewModel.alertFreshness, .expired)
        XCTAssertEqual(viewModel.notice, .stale)
        XCTAssertEqual(viewModel.alertNotice, .stale)
    }

    // MARK: - Board refresh cadence

    func testRefreshPolicyHoldsTheFreshCadenceAndBacksOffFailures() {
        let policy = StationBoardRefreshPolicy.standard

        XCTAssertEqual(policy.delay(after: .fresh, consecutiveSetbacks: 0), 30)
        XCTAssertEqual(policy.delay(after: .degraded, consecutiveSetbacks: 1), 30)
        XCTAssertEqual(policy.delay(after: .degraded, consecutiveSetbacks: 2), 60)
        XCTAssertEqual(policy.delay(after: .failed(.offline), consecutiveSetbacks: 3), 120)
        XCTAssertEqual(policy.delay(after: .failed(.unavailable), consecutiveSetbacks: 9), 120)
        XCTAssertNil(policy.delay(after: .failed(.notConfigured), consecutiveSetbacks: 1))
    }

    func testRefreshPolicyHonoursRetryAfterWithinItsBounds() {
        let policy = StationBoardRefreshPolicy.standard

        XCTAssertEqual(policy.delay(after: .failed(.rateLimited(retryAfterSeconds: 45)), consecutiveSetbacks: 1), 45)
        XCTAssertEqual(
            policy.delay(after: .failed(.rateLimited(retryAfterSeconds: 5)), consecutiveSetbacks: 1),
            30,
            "A short Retry-After never shortens the cadence"
        )
        XCTAssertEqual(policy.delay(after: .failed(.rateLimited(retryAfterSeconds: nil)), consecutiveSetbacks: 1), 60)
        XCTAssertEqual(policy.delay(after: .failed(.rateLimited(retryAfterSeconds: nil)), consecutiveSetbacks: 4), 240)
        XCTAssertEqual(policy.delay(after: .failed(.rateLimited(retryAfterSeconds: 900)), consecutiveSetbacks: 1), 300)
        XCTAssertEqual(policy.delay(after: .failed(.rateLimited(retryAfterSeconds: nil)), consecutiveSetbacks: 12), 300)
    }

    func testOpenBoardRefreshesOnTheFreshCadenceWithoutAnnouncingEachRefresh() async {
        let clock = LockedTestClock(Date(timeIntervalSince1970: 1_784_467_200))
        let firstBoard = makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)
        let laterBoard = makeBoard(departures: [makeDeparture("1735"), makeDeparture("1737")], freshness: .fresh)
        let alertPage = makeAlertPage(alerts: [], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(firstBoard), .success(laterBoard), .success(laterBoard)],
            alertOutcomes: [.success(alertPage), .success(alertPage), .success(alertPage)]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 2)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )

        await viewModel.keepFresh()

        let counts = await provider.requestCounts()
        XCTAssertEqual(counts.board, 3, "One requested load and two scheduled refreshes")
        XCTAssertEqual(counts.alerts, 3)
        assertWaits(sleeper.recordedWaits, [30, 30, 30])
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.board?.departures.count, 2)
        XCTAssertNil(viewModel.notice)
        XCTAssertEqual(viewModel.consecutiveSetbacks, 0)
        XCTAssertEqual(
            viewModel.accessibilityAnnouncement,
            "1 NS departures loaded for Utrecht Centraal.",
            "Scheduled refreshes do not re-announce the board"
        )
    }

    func testOpenBoardBacksOffOnRateLimitHonouringRetryAfterThenRecovers() async {
        let clock = LockedTestClock(Date(timeIntervalSince1970: 1_784_467_200))
        let board = makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)
        let alertPage = makeAlertPage(alerts: [], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board), .failure(.rateLimited(retryAfterSeconds: 90)), .success(board)],
            alertOutcomes: [.success(alertPage), .success(alertPage), .success(alertPage)]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 2)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )
        let log = BoardStateLog()
        sleeper.onWait = { log.record(viewModel) }

        await viewModel.keepFresh()

        assertWaits(sleeper.recordedWaits, [30, 90, 30])
        XCTAssertEqual(log.notices, [nil, .rateLimited(retryAfterSeconds: 90), nil])
        XCTAssertEqual(viewModel.phase, .loaded)
        XCTAssertEqual(viewModel.consecutiveSetbacks, 0)
        XCTAssertFalse(viewModel.refreshStopped)
    }

    func testOpenBoardBacksOffSavedCopiesLikeFailuresAndTrustsFreshResponsesAgain() async {
        let clock = LockedTestClock(Date(timeIntervalSince1970: 1_784_467_200))
        let saved = makeBoard(departures: [makeDeparture("1735")], freshness: .stale)
        let fresh = makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)
        let alertPage = makeAlertPage(alerts: [], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(saved), .success(saved), .success(fresh)],
            alertOutcomes: [.success(alertPage), .success(alertPage), .success(alertPage)]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 2)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )

        await viewModel.keepFresh()

        assertWaits(sleeper.recordedWaits, [30, 60, 30])
        XCTAssertEqual(viewModel.consecutiveSetbacks, 0)
        XCTAssertNil(viewModel.notice)
    }

    func testOpenBoardStopsRefreshingWhenTheProviderIsNotConfigured() async {
        let clock = LockedTestClock(Date(timeIntervalSince1970: 1_784_467_200))
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.failure(.notConfigured)],
            alertOutcomes: [.failure(.notConfigured)]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 5)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )

        await viewModel.keepFresh()

        XCTAssertEqual(viewModel.phase, .failed(.notConfigured))
        XCTAssertTrue(viewModel.refreshStopped)
        XCTAssertNil(viewModel.nextRefreshAt)
        XCTAssertTrue(sleeper.recordedWaits.isEmpty)
        let counts = await provider.requestCounts()
        XCTAssertEqual(counts.board, 1)
    }

    func testOpenBoardWaitsOutTheScheduleAfterARequestedRefresh() async {
        let start = Date(timeIntervalSince1970: 1_784_467_200)
        let clock = LockedTestClock(start)
        let board = makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board)],
            alertOutcomes: [.success(makeAlertPage(alerts: [], freshness: .fresh))]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 0)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.nextRefreshAt, start.addingTimeInterval(30))

        clock.advance(by: 20)
        await viewModel.keepFresh()

        assertWaits(sleeper.recordedWaits, [10])
        let counts = await provider.requestCounts()
        XCTAssertEqual(counts.board, 1, "A board that is not due is not reloaded when refreshing starts")
    }

    func testPullToRefreshPostponesTheScheduledRefresh() async {
        let start = Date(timeIntervalSince1970: 1_784_467_200)
        let clock = LockedTestClock(start)
        let board = makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)
        let alertPage = makeAlertPage(alerts: [], freshness: .fresh)
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board), .success(board)],
            alertOutcomes: [.success(alertPage), .success(alertPage)]
        )
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read)
        )

        await viewModel.load()
        XCTAssertEqual(viewModel.nextRefreshAt, start.addingTimeInterval(30))

        clock.advance(by: 20)
        await viewModel.load()
        XCTAssertEqual(viewModel.nextRefreshAt, start.addingTimeInterval(50))
    }

    func testOpenBoardRefreshesAtOnceAndQuietlyWhenTheScheduleHasPassed() async {
        let clock = LockedTestClock(Date(timeIntervalSince1970: 1_784_467_200))
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [
                .success(makeBoard(departures: [makeDeparture("1735")], freshness: .fresh)),
                .success(makeBoard(departures: [makeDeparture("1735"), makeDeparture("1737")], freshness: .fresh))
            ],
            alertOutcomes: [
                .success(makeAlertPage(alerts: [], freshness: .fresh)),
                .success(makeAlertPage(alerts: [], freshness: .fresh))
            ]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 0)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )

        await viewModel.load()
        clock.advance(by: 120)
        await viewModel.keepFresh()

        let counts = await provider.requestCounts()
        XCTAssertEqual(counts.board, 2)
        XCTAssertEqual(viewModel.board?.departures.count, 2)
        assertWaits(sleeper.recordedWaits, [30])
        XCTAssertEqual(viewModel.accessibilityAnnouncement, "1 NS departures loaded for Utrecht Centraal.")
    }

    func testCancellingARefreshLeavesNoLoadingBoardOrFailureBehind() async {
        let provider = CancellableBoardNSRiderProvider(alertPage: makeAlertPage(alerts: [], freshness: .fresh))
        let viewModel = StationBoardViewModel(station: makeStation(), provider: provider)
        let refreshTask = Task { await viewModel.keepFresh() }

        for _ in 0..<500 where !(await provider.boardRequestIsInFlight()) {
            await Task.yield()
        }
        refreshTask.cancel()
        await refreshTask.value

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertNil(viewModel.notice)
        XCTAssertNil(viewModel.board)
        XCTAssertNil(viewModel.nextRefreshAt, "A refresh that never arrived leaves no schedule behind")
        XCTAssertFalse(viewModel.refreshStopped)
    }

    func testOpenBoardStaysLabelledFreshForTheGracePeriodPastTheProxyWindow() async {
        let start = Date(timeIntervalSince1970: 1_784_467_200)
        let clock = LockedTestClock(start)
        let board = makeBoard(
            departures: [makeDeparture("1735")],
            freshness: .fresh,
            validUntil: start.addingTimeInterval(20)
        )
        let alertPage = makeAlertPage(
            alerts: [],
            freshness: .fresh,
            validUntil: start.addingTimeInterval(3_600)
        )
        let provider = SequencedNSRiderProvider(
            boardOutcomes: [.success(board), .failure(.offline), .failure(.offline)],
            alertOutcomes: [.success(alertPage), .success(alertPage), .success(alertPage)]
        )
        let sleeper = ScriptedRefreshSleeper(clock: clock, allowedWaits: 2)
        let viewModel = StationBoardViewModel(
            station: makeStation(),
            provider: provider,
            clock: RailClock(clock.read),
            refreshSleep: { duration in try await sleeper.sleep(duration) }
        )
        let log = BoardStateLog()
        sleeper.onWait = { log.record(viewModel) }

        await viewModel.keepFresh()

        // The log samples the label 0 s, 30 s and 60 s after the first load. The proxy window closed
        // at 20 s, so the last sample sits exactly 40 s past it, where the grace period ends.
        assertWaits(sleeper.recordedWaits, [30, 30, 60])
        XCTAssertEqual(log.freshness, [.fresh, .fresh, .expired])
        XCTAssertEqual(viewModel.notice, .offline)
        XCTAssertEqual(
            viewModel.boardFreshness,
            .expired,
            "Once the board is no longer refreshing itself the label is strict again"
        )
    }

    func testStationDirectoryOffersTheProvidersSuggestedSearches() {
        let viewModel = StationDirectoryViewModel(provider: SequencedNSRiderProvider())
        XCTAssertEqual(viewModel.suggestedSearches, ["Utrecht Centraal", "Amsterdam Centraal"])

        let nsProvider = NSTrainProvider(proxyBaseURL: nil)
        XCTAssertFalse(nsProvider.isConfigured)
        XCTAssertEqual(nsProvider.suggestedSearches.first, "Utrecht Centraal")
        XCTAssertEqual(nsProvider.providerID, "netherlands-ns")
    }

    // MARK: - Favorites

    func testFavoritesToggleAndPersistPerProviderInNameOrder() throws {
        let suiteName = "NSProviderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let utrecht = makeStation()
        let amsterdam = ProviderStation(
            providerID: "netherlands-ns",
            code: "ASD",
            name: "Amsterdam Centraal",
            shortName: "Amsterdam C.",
            countryCode: "NL",
            latitude: 52.37,
            longitude: 4.9
        )
        let sameCodeElsewhere = ProviderStation(
            providerID: "other-provider",
            code: "UT",
            name: "Zürich HB",
            shortName: nil,
            countryCode: "CH",
            latitude: nil,
            longitude: nil
        )

        let store = StationFavoritesStore(defaults: defaults)
        XCTAssertFalse(store.isFavorite(utrecht))
        store.toggle(utrecht)
        store.toggle(amsterdam)
        store.toggle(sameCodeElsewhere)

        XCTAssertTrue(store.isFavorite(utrecht))
        XCTAssertEqual(store.favorites(for: "netherlands-ns").map(\.code), ["ASD", "UT"])
        XCTAssertEqual(store.favorites(for: "other-provider").map(\.name), ["Zürich HB"])

        store.toggle(sameCodeElsewhere)
        XCTAssertFalse(store.isFavorite(sameCodeElsewhere))
        XCTAssertTrue(store.isFavorite(utrecht), "The same code at another provider is a different station")

        let reloaded = StationFavoritesStore(defaults: defaults)
        XCTAssertEqual(reloaded.favorites(for: "netherlands-ns").map(\.code), ["ASD", "UT"])
        XCTAssertEqual(reloaded.favorites(for: "netherlands-ns").first?.station, amsterdam)
        XCTAssertTrue(reloaded.favorites(for: "other-provider").isEmpty)

        reloaded.toggle(utrecht)
        XCTAssertFalse(StationFavoritesStore(defaults: defaults).isFavorite(utrecht))
    }

    func testFavoritesIgnoreAndPreserveAnUnreadablePayload() throws {
        let suiteName = "NSProviderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let unreadable = Data("not a favorites list".utf8)
        defaults.set(unreadable, forKey: StationFavoritesStore.storageKey)

        let store = StationFavoritesStore(defaults: defaults)

        XCTAssertTrue(store.stations.isEmpty)
        XCTAssertEqual(defaults.data(forKey: StationFavoritesStore.undecodableStorageKey), unreadable)
    }

    func testNSProxyContractRejectsOversizedDisplayFieldsAndWrongMetadata() {
        let fetchedAt = Date(timeIntervalSince1970: 1_784_467_200)
        let metadata = NSProxyMetadata(
            provider: "ns",
            source: NSClient.sourceName,
            attribution: "Data from Nederlandse Spoorwegen (NS)",
            fetchedAt: fetchedAt,
            expiresAt: fetchedAt.addingTimeInterval(20),
            freshness: .fresh,
            cacheStatus: .miss
        )
        let oversized = NSProxyDeparturesResponse(
            data: .init(
                station: .init(code: "UT"),
                departures: [.init(
                    id: "1735",
                    service: "Intercity 1735",
                    destination: String(repeating: "X", count: 161),
                    scheduledAt: "2026-07-19T14:37:00+0200",
                    expectedAt: nil,
                    platform: "9",
                    status: .onTime
                )]
            ),
            meta: metadata,
            requestId: "fixture-request"
        )
        XCTAssertFalse(oversized.hasValidContract())

        let wrongSource = NSProxyStationSearchResponse(
            data: .init(stations: []),
            meta: NSProxyMetadata(
                provider: "other",
                source: NSClient.sourceName,
                attribution: "Data from Nederlandse Spoorwegen (NS)",
                fetchedAt: fetchedAt,
                expiresAt: fetchedAt.addingTimeInterval(20),
                freshness: .fresh,
                cacheStatus: .miss
            ),
            requestId: "fixture-request"
        )
        XCTAssertFalse(wrongSource.hasValidContract())
    }

    func testNSProxyContractRejectsMalformedAndInconsistentDepartureTimes() {
        let fetchedAt = Date(timeIntervalSince1970: 1_784_467_200)
        let metadata = NSProxyMetadata(
            provider: "ns",
            source: NSClient.sourceName,
            attribution: "Data from Nederlandse Spoorwegen (NS)",
            fetchedAt: fetchedAt,
            expiresAt: fetchedAt.addingTimeInterval(20),
            freshness: .fresh,
            cacheStatus: .miss
        )
        func response(
            scheduledAt: String,
            expectedAt: String?,
            status: NSProxyDeparture.Status
        ) -> NSProxyDeparturesResponse {
            NSProxyDeparturesResponse(
                data: .init(
                    station: .init(code: "UT"),
                    departures: [.init(
                        id: "1735",
                        service: "Intercity 1735",
                        destination: "Enschede",
                        scheduledAt: scheduledAt,
                        expectedAt: expectedAt,
                        platform: "9",
                        status: status
                    )]
                ),
                meta: metadata,
                requestId: "fixture-request"
            )
        }

        XCTAssertFalse(response(
            scheduledAt: "2026-02-30T14:37:00+02:00",
            expectedAt: nil,
            status: .scheduled
        ).hasValidContract())
        XCTAssertFalse(response(
            scheduledAt: "2026-07-19T14:37:00+02:00",
            expectedAt: "14:44",
            status: .delayed
        ).hasValidContract())
        XCTAssertFalse(response(
            scheduledAt: "2026-07-19T14:37:00+02:00",
            expectedAt: nil,
            status: .onTime
        ).hasValidContract())
        XCTAssertFalse(response(
            scheduledAt: "2026-07-19T14:37:00+02:00",
            expectedAt: "2026-07-19T14:44:00+02:00",
            status: .onTime
        ).hasValidContract())
        XCTAssertTrue(response(
            scheduledAt: "2026-07-19T14:37:00+02:00",
            expectedAt: "2026-07-19T14:44:00+02:00",
            status: .delayed
        ).hasValidContract())
    }

    func testStationViewsRenderCoreStatesAtAccessibility2XLInLightAndDarkMode() async throws {
        let suiteName = "NSProviderTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let favorites = StationFavoritesStore(defaults: defaults)
        favorites.toggle(makeStation())

        let searchProvider = SequencedNSRiderProvider(
            searchOutcomes: [.success(makeSearchPage(stations: [makeStation()], freshness: .fresh))]
        )
        let idleImage = try render(
            StationsScreen(
                provider: searchProvider,
                favorites: favorites,
                viewModel: StationDirectoryViewModel(provider: searchProvider)
            ),
            style: .light,
            dynamicTypeSize: .accessibility2
        )

        let searchViewModel = StationDirectoryViewModel(provider: searchProvider)
        searchViewModel.query = "Utrecht"
        await searchViewModel.search()
        let searchImage = try render(
            StationsScreen(provider: searchProvider, favorites: favorites, viewModel: searchViewModel),
            style: .light,
            dynamicTypeSize: .accessibility2
        )

        let boardProvider = SequencedNSRiderProvider(
            boardOutcomes: [.success(makeBoard(
                departures: [StationBoardDeparture(
                    trainName: "Intercity 1735",
                    destinationName: "Enschede",
                    scheduledDeparture: "15:37",
                    estimatedDeparture: "15:44",
                    platform: "9",
                    status: "Delayed"
                )],
                freshness: .stale
            ))],
            alertOutcomes: [.success(makeAlertPage(
                alerts: [TrainAlert(title: "Track work", detail: "Allow extra time.", tone: .watch)],
                freshness: .stale
            ))]
        )
        let boardViewModel = StationBoardViewModel(station: makeStation(), provider: boardProvider)
        await boardViewModel.load()
        let boardImage = try render(
            StationBoardView(viewModel: boardViewModel, favorites: favorites),
            style: .dark,
            dynamicTypeSize: .accessibility2
        )

        let failureProvider = SequencedNSRiderProvider(
            boardOutcomes: [.failure(.rateLimited(retryAfterSeconds: 30))],
            alertOutcomes: [.failure(.offline)]
        )
        let failureViewModel = StationBoardViewModel(station: makeStation(), provider: failureProvider)
        await failureViewModel.load()
        let failureImage = try render(
            StationBoardView(viewModel: failureViewModel, favorites: favorites),
            style: .light,
            dynamicTypeSize: .large
        )

        for image in [idleImage, searchImage, boardImage, failureImage] {
            XCTAssertEqual(image.size, CGSize(width: 320, height: 844))
            XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 1_000)
        }
    }

    private func makeDeparture(_ tripID: String) -> StationBoardDeparture {
        StationBoardDeparture(
            tripID: tripID,
            trainName: "Intercity \(tripID)",
            destinationName: "Enschede",
            scheduledDeparture: "15:37"
        )
    }

    private func assertWaits(
        _ actual: [TimeInterval],
        _ expected: [TimeInterval],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, "Refresh waits: \(actual)", file: file, line: line)
        for (actualWait, expectedWait) in zip(actual, expected) {
            XCTAssertEqual(actualWait, expectedWait, accuracy: 0.001, file: file, line: line)
        }
    }

    private func render<Content: View>(
        _ content: Content,
        style: UIUserInterfaceStyle,
        dynamicTypeSize: DynamicTypeSize
    ) throws -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 844)
        let colorScheme: ColorScheme = style == .dark ? .dark : .light
        let controller = UIHostingController(
            rootView: NavigationStack { content }
                .environment(\.dynamicTypeSize, dynamicTypeSize)
                .preferredColorScheme(colorScheme)
        )
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = frame
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = frame
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertFalse(controller.view.hasAmbiguousLayout)
        let image = UIGraphicsImageRenderer(bounds: frame).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
        window.isHidden = true
        return image
    }

    private func makeStation() -> ProviderStation {
        ProviderStation(
            providerID: "netherlands-ns",
            code: "UT",
            name: "Utrecht Centraal",
            shortName: "Utrecht C.",
            countryCode: "NL",
            latitude: 52.09,
            longitude: 5.11
        )
    }

    private func makeSearchPage(
        stations: [ProviderStation],
        freshness: FreshnessState
    ) -> StationSearchPage {
        StationSearchPage(
            providerID: "netherlands-ns",
            query: "Utrecht",
            generatedAt: Date(timeIntervalSince1970: 1_784_467_200),
            stations: stations,
            sourceProvenance: SourceProvenance(
                providerID: "netherlands-ns",
                providerName: "Nederlandse Spoorwegen (NS)",
                sourceName: "NS Reisinformatie API",
                sourceKind: .officialTimetable,
                confidence: .confirmed,
                freshness: freshness,
                fetchedAt: Date(timeIntervalSince1970: 1_784_467_200),
                attributionText: "Data from Nederlandse Spoorwegen (NS)"
            )
        )
    }

    private func makeBoard(
        departures: [StationBoardDeparture],
        freshness: FreshnessState,
        validUntil: Date? = nil
    ) -> StationBoard {
        StationBoard(
            providerID: "netherlands-ns",
            stationID: "UT",
            stationName: "Utrecht Centraal",
            generatedAt: Date(timeIntervalSince1970: 1_784_467_200),
            departures: departures,
            sourceProvenance: SourceProvenance(
                providerID: "netherlands-ns",
                providerName: "Nederlandse Spoorwegen (NS)",
                sourceName: "NS Reisinformatie API",
                sourceKind: .realtimePrediction,
                confidence: .confirmed,
                freshness: freshness,
                fetchedAt: Date(timeIntervalSince1970: 1_784_467_200),
                validUntil: validUntil,
                attributionText: "Data from Nederlandse Spoorwegen (NS)"
            )
        )
    }

    private func makeAlertPage(
        alerts: [TrainAlert],
        freshness: FreshnessState,
        validUntil: Date? = nil
    ) -> ServiceAlertPage {
        ServiceAlertPage(
            providerID: "netherlands-ns",
            stationID: "UT",
            generatedAt: Date(timeIntervalSince1970: 1_784_467_200),
            alerts: alerts,
            sourceProvenance: SourceProvenance(
                providerID: "netherlands-ns",
                providerName: "Nederlandse Spoorwegen (NS)",
                sourceName: NSClient.sourceName,
                sourceKind: .alertFeed,
                confidence: .confirmed,
                freshness: freshness,
                fetchedAt: Date(timeIntervalSince1970: 1_784_467_200),
                validUntil: validUntil,
                attributionText: "Data from Nederlandse Spoorwegen (NS)"
            )
        )
    }
}

private actor SequencedNSRiderProvider: StationDataProviding {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"
    let suggestedSearches = ["Utrecht Centraal", "Amsterdam Centraal"]

    enum SearchOutcome: Sendable {
        case success(StationSearchPage)
        case failure(NSClientError)
    }

    enum BoardOutcome: Sendable {
        case success(StationBoard)
        case failure(NSClientError)
    }

    enum AlertOutcome: Sendable {
        case success(ServiceAlertPage)
        case failure(NSClientError)
    }

    private var searchOutcomes: [SearchOutcome]
    private var boardOutcomes: [BoardOutcome]
    private var alertOutcomes: [AlertOutcome]
    private var boardRequestCount = 0
    private var alertRequestCount = 0

    init(
        searchOutcomes: [SearchOutcome] = [],
        boardOutcomes: [BoardOutcome] = [],
        alertOutcomes: [AlertOutcome] = []
    ) {
        self.searchOutcomes = searchOutcomes
        self.boardOutcomes = boardOutcomes
        self.alertOutcomes = alertOutcomes
    }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage {
        guard !searchOutcomes.isEmpty else { throw NSClientError.unavailable }
        switch searchOutcomes.removeFirst() {
        case .success(let page): return page
        case .failure(let error): throw error
        }
    }

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        boardRequestCount += 1
        guard !boardOutcomes.isEmpty else { throw NSClientError.unavailable }
        switch boardOutcomes.removeFirst() {
        case .success(let board): return board
        case .failure(let error): throw error
        }
    }

    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage {
        alertRequestCount += 1
        guard !alertOutcomes.isEmpty else { throw NSClientError.unavailable }
        switch alertOutcomes.removeFirst() {
        case .success(let page): return page
        case .failure(let error): throw error
        }
    }

    func requestCounts() -> (board: Int, alerts: Int) {
        (boardRequestCount, alertRequestCount)
    }
}

private actor DelayedBoardNSRiderProvider: StationDataProviding {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"

    private let board: StationBoard
    private let alertPage: ServiceAlertPage
    private var boardContinuation: CheckedContinuation<Void, Never>?

    init(board: StationBoard, alertPage: ServiceAlertPage) {
        self.board = board
        self.alertPage = alertPage
    }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage {
        throw NSClientError.unavailable
    }

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        await withCheckedContinuation { continuation in
            boardContinuation = continuation
        }
        return board
    }

    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage {
        alertPage
    }

    func boardIsWaiting() -> Bool {
        boardContinuation != nil
    }

    func releaseBoard() {
        boardContinuation?.resume()
        boardContinuation = nil
    }
}

private actor SupersedingNSRiderProvider: StationDataProviding {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"

    private let delayedBoard: StationBoard
    private let currentBoard: StationBoard
    private let alertPage: ServiceAlertPage
    private var boardRequestCount = 0
    private var firstBoardContinuation: CheckedContinuation<Void, Never>?

    init(delayedBoard: StationBoard, currentBoard: StationBoard, alertPage: ServiceAlertPage) {
        self.delayedBoard = delayedBoard
        self.currentBoard = currentBoard
        self.alertPage = alertPage
    }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage {
        throw NSClientError.unavailable
    }

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        boardRequestCount += 1
        if boardRequestCount == 1 {
            await withCheckedContinuation { continuation in
                firstBoardContinuation = continuation
            }
            return delayedBoard
        }
        return currentBoard
    }

    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage {
        alertPage
    }

    func firstBoardIsWaiting() -> Bool {
        firstBoardContinuation != nil
    }

    func releaseFirstBoard() {
        firstBoardContinuation?.resume()
        firstBoardContinuation = nil
    }
}

private actor CancellableBoardNSRiderProvider: StationDataProviding {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"

    private let alertPage: ServiceAlertPage
    private var boardRequestStarted = false

    init(alertPage: ServiceAlertPage) {
        self.alertPage = alertPage
    }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage {
        throw NSClientError.unavailable
    }

    /// Never answers on its own: it only ends when the caller's task is cancelled.
    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        boardRequestStarted = true
        try await Task.sleep(for: .seconds(60))
        throw NSClientError.unavailable
    }

    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage {
        alertPage
    }

    func boardRequestIsInFlight() -> Bool {
        boardRequestStarted
    }
}

/// Stands in for the board's refresh timer. It records each wait the board asks
/// for, moves a fake clock forward by that wait, and ends the refresh loop by
/// throwing once the allowed number of waits has been used.
final class ScriptedRefreshSleeper: @unchecked Sendable {
    /// Runs on the main actor each time the board asks to wait, before the clock moves.
    var onWait: (@MainActor @Sendable () -> Void)?

    private let lock = NSLock()
    private let clock: LockedTestClock
    private let allowedWaits: Int
    private var waits: [TimeInterval] = []

    init(clock: LockedTestClock, allowedWaits: Int) {
        self.clock = clock
        self.allowedWaits = allowedWaits
    }

    var recordedWaits: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return waits
    }

    func sleep(_ duration: Duration) async throws {
        let seconds = TimeInterval(duration.components.seconds)
            + TimeInterval(duration.components.attoseconds) / 1_000_000_000_000_000_000
        let allowed = record(seconds)
        await onWait?()
        guard allowed else { throw CancellationError() }
        clock.advance(by: seconds)
    }

    private func record(_ seconds: TimeInterval) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        waits.append(seconds)
        return waits.count <= allowedWaits
    }
}

/// What a board looked like each time it went to sleep.
@MainActor
private final class BoardStateLog {
    private(set) var notices: [StationBoardViewModel.Notice?] = []
    private(set) var freshness: [FreshnessState] = []

    func record(_ viewModel: StationBoardViewModel) {
        notices.append(viewModel.notice)
        freshness.append(viewModel.boardFreshness)
    }
}

final class LockedTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) {
        self.value = value
    }

    func read() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(by interval: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(interval)
        lock.unlock()
    }
}

private final class BoundedResponseURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        ["oversized.test", "slow.test"].contains(request.url?.host)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let headers = url.host == "oversized.test" ? ["Content-Length": "1024"] : [:]
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if url.host == "oversized.test" {
            client?.urlProtocol(self, didLoad: Data([0]))
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
