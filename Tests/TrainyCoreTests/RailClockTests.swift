import Foundation
import XCTest
@testable import TrainyCore

@MainActor
final class RailClockTests: XCTestCase {
    // MARK: - RailClock

    func testSystemClockTracksTheWallClock() {
        let before = Date()
        let reading = RailClock.system.now
        let after = Date()

        XCTAssertGreaterThanOrEqual(reading, before)
        XCTAssertLessThanOrEqual(reading, after)
    }

    func testFixedClockReportsItsInstantEveryTime() throws {
        let pinned = try instant("2026-06-20T00:30:00Z")
        let clock = RailClock.fixed(pinned)

        XCTAssertEqual(clock.now, pinned)
        XCTAssertEqual(clock.now, pinned)
    }

    func testClockReadsItsSourceOnEveryCall() throws {
        let start = try instant("2026-06-20T00:30:00Z")
        let source = LockedTestClock(start)
        let clock = RailClock { source.read() }

        XCTAssertEqual(clock.now, start)
        source.advance(by: 90)
        XCTAssertEqual(clock.now, start.addingTimeInterval(90))
    }

    // MARK: - Freshness

    func testFreshnessResolvesAgainstTheSuppliedInstant() throws {
        let fetched = try instant("2026-06-20T00:30:00Z")
        let validUntil = try instant("2026-06-30T14:59:00Z")

        XCTAssertEqual(
            FreshnessState.resolved(fetchedAt: fetched, validUntil: validUntil, now: fetched.addingTimeInterval(3_600)),
            .fresh
        )
        XCTAssertEqual(
            FreshnessState.resolved(fetchedAt: fetched, validUntil: validUntil, now: fetched.addingTimeInterval(2 * 86_400)),
            .stale
        )
        XCTAssertEqual(
            FreshnessState.resolved(fetchedAt: fetched, validUntil: validUntil, now: validUntil.addingTimeInterval(1)),
            .expired
        )
        XCTAssertEqual(FreshnessState.resolved(fetchedAt: nil, validUntil: nil, now: fetched), .unknown)
    }

    func testProvenanceFactoriesResolveFreshnessAtTheSuppliedInstant() throws {
        let fetched = try instant("2026-06-20T00:30:00Z")
        let validUntil = try instant("2026-06-30T14:59:00Z")
        let jrEastURL = URL(string: "https://timetables.jreast.co.jp/en/")

        let odptFresh = SourceProvenance.odptTimetable(
            fetchedAt: fetched,
            validUntil: validUntil,
            now: fetched.addingTimeInterval(60)
        )
        XCTAssertEqual(odptFresh.fetchedAt, fetched)
        XCTAssertEqual(odptFresh.freshness, .fresh)

        let odptStale = SourceProvenance.odptTimetable(
            fetchedAt: fetched,
            validUntil: validUntil,
            now: fetched.addingTimeInterval(2 * 86_400)
        )
        XCTAssertEqual(odptStale.freshness, .stale)

        let odptExpired = SourceProvenance.odptTimetable(
            fetchedAt: fetched,
            validUntil: validUntil,
            now: validUntil.addingTimeInterval(60)
        )
        XCTAssertEqual(odptExpired.freshness, .expired)

        let jrEastFresh = SourceProvenance.jrEastTimetable(
            sourceName: "JR East official timetable",
            sourceURL: jrEastURL,
            fetchedAt: fetched,
            now: fetched.addingTimeInterval(60)
        )
        XCTAssertEqual(jrEastFresh.freshness, .fresh)

        let jrEastStale = SourceProvenance.jrEastTimetable(
            sourceName: "JR East official timetable",
            sourceURL: jrEastURL,
            fetchedAt: fetched,
            now: fetched.addingTimeInterval(2 * 86_400)
        )
        XCTAssertEqual(jrEastStale.freshness, .stale)
    }

    // MARK: - Stop state

    func testRailStopTimeStateFollowsTheSuppliedInstant() throws {
        let scheduled = try instant("2026-06-20T00:30:00Z")
        let stop = RailStopTime(stationID: "tokyo", scheduledTime: scheduled)

        XCTAssertEqual(stop.state(at: scheduled.addingTimeInterval(-60)), .pending)
        XCTAssertEqual(stop.state(at: scheduled), .done)
        XCTAssertEqual(stop.state(at: scheduled.addingTimeInterval(60)), .done)
        XCTAssertEqual(RailStopTime(stationID: "tokyo").state(at: scheduled), .pending)
    }

    // MARK: - Shinkansen mapper

    func testTimetableStatusAndCurrentStopFollowTokyoTime() throws {
        let stops = Self.tokaidoTimedStops
        let expectations: [(isoTime: String, status: String, stopIndex: Int)] = [
            ("2026-06-20T08:00:00+09:00", "Scheduled", 0),
            ("2026-06-20T09:21:00+09:00", "In timetable", 0),
            ("2026-06-20T09:30:00+09:00", "In timetable", 1),
            ("2026-06-20T10:59:00+09:00", "In timetable", 2),
            ("2026-06-20T11:48:00+09:00", "In timetable", 4),
            ("2026-06-20T11:49:00+09:00", "Completed", 4)
        ]

        for expectation in expectations {
            let now = try instant(expectation.isoTime)
            XCTAssertEqual(
                ShinkansenTrainProvider.statusText(for: stops, now: now),
                expectation.status,
                expectation.isoTime
            )
            XCTAssertEqual(
                ShinkansenTrainProvider.currentStopIndex(in: stops, now: now),
                expectation.stopIndex,
                expectation.isoTime
            )
        }
    }

    func testTokyoMinutesUsesTokyoTimeWhateverTheDeviceZoneIs() throws {
        XCTAssertEqual(ShinkansenTrainProvider.tokyoMinutes(at: try instant("2026-06-20T00:30:00Z")), 9 * 60 + 30)
        XCTAssertEqual(ShinkansenTrainProvider.tokyoMinutes(at: try instant("2026-06-20T14:59:00Z")), 23 * 60 + 59)
        XCTAssertEqual(ShinkansenTrainProvider.tokyoMinutes(at: try instant("2026-06-20T15:00:00Z")), 0)
    }

    // MARK: - Provider and store edges

    func testShinkansenProviderMapsODPTTripsAtItsOwnClock() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ODPTFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let midMorning = try instant("2026-06-20T09:30:00+09:00")
        let afternoon = try instant("2026-06-20T14:00:00+09:00")
        let morningProvider = ShinkansenTrainProvider(
            consumerKey: "fixture-consumer-key",
            session: session,
            clock: .fixed(midMorning)
        )
        let afternoonProvider = ShinkansenTrainProvider(
            consumerKey: "fixture-consumer-key",
            session: session,
            clock: .fixed(afternoon)
        )

        let morningTrips = try await morningProvider.fetchTrips(
            matching: "Tokaido",
            knownRoutes: ShinkansenTrainProvider.routes
        )
        let afternoonTrips = try await afternoonProvider.fetchTrips(
            matching: "Tokaido",
            knownRoutes: ShinkansenTrainProvider.routes
        )
        let morning = try XCTUnwrap(morningTrips.first { $0.routeID == "tokaido" })
        let later = try XCTUnwrap(afternoonTrips.first { $0.routeID == "tokaido" })

        XCTAssertEqual(morning.status, "In timetable")
        XCTAssertEqual(morning.nextStop, "Shin-Yokohama")
        XCTAssertEqual(morning.sourceProvenance.fetchedAt, midMorning)
        XCTAssertEqual(morning.sourceProvenance.freshness, .fresh)

        XCTAssertEqual(later.status, "Completed")
        XCTAssertEqual(later.nextStop, "Shin-Osaka")
        XCTAssertEqual(later.sourceProvenance.fetchedAt, afternoon)
        XCTAssertEqual(later.sourceProvenance.freshness, .fresh)
    }

    func testShinkansenProviderReadsItsClockAfterTheTimetableResponseArrives() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ODPTFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        // The search starts half a minute before the 09:21 departure and the
        // timetable response takes a minute to arrive.
        let start = try instant("2026-06-20T09:20:30+09:00")
        let source = LockedTestClock(start)
        ODPTFixtureURLProtocol.timetableServed.install { source.advance(by: 60) }
        defer { ODPTFixtureURLProtocol.timetableServed.install(nil) }

        let provider = ShinkansenTrainProvider(
            consumerKey: "fixture-consumer-key",
            session: session,
            clock: RailClock { source.read() }
        )
        let trips = try await provider.fetchTrips(
            matching: "Tokaido",
            knownRoutes: ShinkansenTrainProvider.routes
        )
        let trip = try XCTUnwrap(trips.first { $0.routeID == "tokaido" })

        XCTAssertEqual(trip.status, "In timetable")
        XCTAssertEqual(trip.sourceProvenance.fetchedAt, start.addingTimeInterval(60))
    }

    func testStoreMeasuresLiveRefreshAgeWithItsClock() async throws {
        let suiteName = "RailClockTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let source = LockedTestClock(try instant("2026-06-20T00:30:00Z"))
        let store = TrainStore(
            defaults: defaults,
            provider: ClockFixtureProvider(),
            clock: RailClock { source.read() }
        )

        XCTAssertEqual(store.liveStatusText, "Ready for rail search")

        await store.loadLiveRoutes()
        XCTAssertEqual(store.liveStatusText, "Clock fixture feed · updated 0s ago")

        source.advance(by: 45)
        XCTAssertEqual(store.liveStatusText, "Clock fixture feed · updated 45s ago")

        source.advance(by: 135)
        XCTAssertEqual(store.liveStatusText, "Clock fixture feed · updated 3m ago")
    }

    // MARK: - Time formatting

    func testFormattedAsTimePlacesTheTimeOnTheSuppliedDay() throws {
        let tokyo = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let now = try instant("2026-06-20T00:30:00Z")

        XCTAssertEqual("21:05".formattedAsTime(in: tokyo, format: .hour12, now: now), "9:05 PM")
        XCTAssertEqual("21:05".formattedAsTime(in: tokyo, format: .hour24, now: now), "21:05")
        XCTAssertEqual("later".formattedAsTime(in: tokyo, format: .hour24, now: now), "later")
    }

    // MARK: - Stable ids

    func testStationStopIdentityComesFromWhereAndWhen() throws {
        let stop = StationStop(name: "Nagoya", time: "10:59", platform: "TBD", note: "Next timetable stop", state: .current)
        let refreshed = StationStop(name: "Nagoya", time: "10:59", platform: "16", note: "Passed", state: .done)
        let rescheduled = StationStop(name: "Nagoya", time: "11:02", platform: "TBD", note: "Next timetable stop", state: .current)

        XCTAssertEqual(stop.id, "Nagoya|10:59")
        XCTAssertEqual(stop.id, refreshed.id)
        XCTAssertNotEqual(stop.id, rescheduled.id)

        let decoded = try JSONDecoder().decode(StationStop.self, from: JSONEncoder().encode(stop))
        XCTAssertEqual(decoded.id, stop.id)
        XCTAssertEqual(decoded, stop)
    }

    func testTrainAlertIdentityComesFromItsContent() throws {
        let alert = TrainAlert(title: "Normal service", detail: "Trains are running on time.", tone: .good)
        let copy = TrainAlert(title: "Normal service", detail: "Trains are running on time.", tone: .good)
        let delayed = TrainAlert(title: "Normal service", detail: "Trains are running on time.", tone: .late)
        let reworded = TrainAlert(title: "Normal service", detail: "Expect small delays.", tone: .good)

        XCTAssertEqual(alert.id, copy.id)
        XCTAssertNotEqual(alert.id, delayed.id)
        XCTAssertNotEqual(alert.id, reworded.id)

        let decoded = try JSONDecoder().decode(TrainAlert.self, from: JSONEncoder().encode(alert))
        XCTAssertEqual(decoded.id, alert.id)
        XCTAssertEqual(decoded, alert)
    }

    func testStoredPayloadsKeepTheirShapeWithoutAnIDKey() throws {
        let stop = StationStop(name: "Tokyo", time: "09:21", platform: "18", note: "Origin", state: .done)
        let alert = TrainAlert(title: "Normal service", detail: "Trains are running on time.", tone: .good)

        let stopJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(stop)) as? [String: Any])
        let alertJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(alert)) as? [String: Any])
        XCTAssertEqual(Set(stopJSON.keys), ["name", "time", "platform", "note", "state"])
        XCTAssertEqual(Set(alertJSON.keys), ["title", "detail", "tone"])

        // Payloads written before ids were derived never carried one either.
        let storedStop = Data(#"{"name":"Tokyo","time":"09:21","platform":"18","note":"Origin","state":"done"}"#.utf8)
        let storedAlert = Data(#"{"title":"Normal service","detail":"Trains are running on time.","tone":"good"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(StationStop.self, from: storedStop), stop)
        XCTAssertEqual(try JSONDecoder().decode(TrainAlert.self, from: storedAlert), alert)
    }

    func testDecodingTheSamePayloadTwiceYieldsTheSameIdentities() throws {
        let trip = try XCTUnwrap(ShinkansenTrainProvider.allTrips.first)
        let payload = try JSONEncoder().encode(trip)

        let first = try JSONDecoder().decode(TrainTrip.self, from: payload)
        let second = try JSONDecoder().decode(TrainTrip.self, from: payload)

        XCTAssertFalse(first.stops.isEmpty)
        XCTAssertFalse(first.alerts.isEmpty)
        XCTAssertEqual(first.stops.map(\.id), second.stops.map(\.id))
        XCTAssertEqual(first.alerts.map(\.id), second.alerts.map(\.id))
        XCTAssertEqual(first.stops, second.stops)
        XCTAssertEqual(first.alerts, second.alerts)
    }

    func testStarterCatalogStopsAndAlertsHaveUniqueIDsWithinATrip() {
        for trip in ShinkansenTrainProvider.allTrips {
            XCTAssertEqual(Set(trip.stops.map(\.id)).count, trip.stops.count, "\(trip.train) stops")
            XCTAssertEqual(Set(trip.alerts.map(\.id)).count, trip.alerts.count, "\(trip.train) alerts")
        }
    }

    // MARK: - Helpers

    private static let tokaidoTimedStops = [
        ODPTTimedStop(stationID: "odpt.Station:JR-Central.TokaidoShinkansen.Tokyo", time: "09:21", platform: "18"),
        ODPTTimedStop(stationID: "odpt.Station:JR-Central.TokaidoShinkansen.ShinYokohama", time: "09:39", platform: "3"),
        ODPTTimedStop(stationID: "odpt.Station:JR-Central.TokaidoShinkansen.Nagoya", time: "10:59", platform: "16"),
        ODPTTimedStop(stationID: "odpt.Station:JR-Central.TokaidoShinkansen.Kyoto", time: "11:35", platform: "14"),
        ODPTTimedStop(stationID: "odpt.Station:JR-Central.TokaidoShinkansen.ShinOsaka", time: "11:48", platform: "25")
    ]

    private func instant(_ iso8601: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso8601), iso8601)
    }
}

private struct ClockFixtureProvider: ScheduleFeedProvider {
    let providerID = "clock-fixture"
    let capabilities: Set<ProviderCapability> = [.schedule]
    let feedLabel = "Clock fixture feed"

    func fetchRoutes() async throws -> [LiveTrainRoute] {
        ShinkansenTrainProvider.routes
    }

    func fetchTrips(matching query: String, knownRoutes: [LiveTrainRoute]) async throws -> [TrainTrip] {
        []
    }
}

/// A test-installed action that runs when the fixture protocol serves a response.
private final class ServedResponseHook: @unchecked Sendable {
    private let lock = NSLock()
    private var action: (@Sendable () -> Void)?

    func install(_ action: (@Sendable () -> Void)?) {
        lock.lock()
        self.action = action
        lock.unlock()
    }

    func fire() {
        lock.lock()
        let action = self.action
        lock.unlock()
        action?()
    }
}

/// Serves the recorded ODPT fixtures for any api.odpt.org request so provider
/// tests run without a network.
private final class ODPTFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    /// Runs as each timetable response is served, so a test can move its clock
    /// while the request is still in flight.
    static let timetableServed = ServedResponseHook()

    private static let fixtureRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures")

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.odpt.org"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let fixtureName: String
        if url.absoluteString.contains("TrainTimetable") {
            fixtureName = "odpt_train_timetable_tokaido.json"
            Self.timetableServed.fire()
        } else if url.absoluteString.contains("TrainInformation") {
            fixtureName = "odpt_train_information_tokaido.json"
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }

        guard
            let data = try? Data(contentsOf: Self.fixtureRoot.appendingPathComponent(fixtureName)),
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotOpenFile))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
