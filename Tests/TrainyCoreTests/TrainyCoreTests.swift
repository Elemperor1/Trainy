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
            sourceName: "JR East official timetable, Jul 2026 JR JIKOKUHYO",
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

    func testDetailAndMapDisplayStatesStayHonestAboutPositionPlatformAndStaleData() throws {
        let starter = TrainTrip.samples[0]
        XCTAssertEqual(starter.vehiclePositionDisplayState.kind, .routeMarker)
        XCTAssertFalse(starter.vehiclePositionDisplayState.isLiveVehiclePosition)
        XCTAssertTrue(starter.vehiclePositionDisplayState.rendersMapMarker)
        XCTAssertTrue(starter.vehiclePositionDisplayState.mapLabel.localizedCaseInsensitiveContains("route marker"))
        XCTAssertFalse(starter.vehiclePositionDisplayState.detailText.localizedCaseInsensitiveContains("live"))
        XCTAssertEqual(starter.platformDisplayState.kind, .known)

        let vehicleSource = SourceProvenance(
            providerID: "vehicle-test",
            providerName: "Vehicle test provider",
            sourceName: "Vehicle positions",
            sourceKind: .vehiclePosition,
            confidence: .confirmed,
            freshness: .fresh
        )
        let liveTrip = tripVariant(
            from: starter,
            vehicleLatitude: 35.6812,
            vehicleLongitude: 139.7671,
            sourceProvenance: vehicleSource,
            factProvenance: [
                FactProvenance(
                    fact: .vehiclePosition,
                    source: vehicleSource,
                    confidence: .confirmed,
                    note: "Provider vehicle-position coordinate."
                )
            ]
        )
        XCTAssertEqual(liveTrip.vehiclePositionDisplayState.kind, .liveVehicle)
        XCTAssertTrue(liveTrip.vehiclePositionDisplayState.isLiveVehiclePosition)
        XCTAssertTrue(liveTrip.vehiclePositionDisplayState.detailText.localizedCaseInsensitiveContains("vehicle-position feed"))

        let unknownPositionTrip = tripVariant(
            from: starter,
            clearsVehicleCoordinate: true,
            sourceProvenance: SourceProvenance(
                providerID: "unknown-position",
                providerName: "Unknown position provider",
                sourceName: "Saved source",
                sourceKind: .inferred,
                confidence: .unknown,
                freshness: .unknown
            ),
            factProvenance: [
                FactProvenance(
                    fact: .vehiclePosition,
                    sourceName: "Saved source",
                    sourceKind: .inferred,
                    confidence: .unknown,
                    note: "No vehicle position source is connected."
                )
            ]
        )
        XCTAssertEqual(unknownPositionTrip.vehiclePositionDisplayState.kind, .unavailable)
        XCTAssertFalse(unknownPositionTrip.vehiclePositionDisplayState.rendersMapMarker)
        XCTAssertEqual(unknownPositionTrip.vehiclePositionDisplayState.mapLabel, "No vehicle position")

        let noPlatformTrip = tripVariant(
            from: starter,
            platform: "TBD",
            stops: [
                StationStop(name: "Tokyo", time: "09:21", platform: "Unknown", note: "Origin", state: .done),
                StationStop(name: "Nagoya", time: "10:59", platform: "", note: "Next", state: .current)
            ]
        )
        XCTAssertEqual(noPlatformTrip.platformDisplayState.kind, .unavailable)
        XCTAssertEqual(noPlatformTrip.displayPlatform, "Not available")
        XCTAssertEqual(noPlatformTrip.stops[0].displayPlatform, "Not available")
        XCTAssertTrue(noPlatformTrip.platformDisplayState.detailText.localizedCaseInsensitiveContains("not supplied"))

        let staleSource = SourceProvenance(
            providerID: "saved",
            providerName: "Saved trip",
            sourceName: "Legacy saved source",
            sourceKind: .inferred,
            confidence: .unknown,
            freshness: .stale
        )
        let staleTrip = tripVariant(
            from: starter,
            sourceProvenance: staleSource,
            factProvenance: FactProvenance.legacyFacts(for: staleSource)
        )
        XCTAssertEqual(staleTrip.sourceStateDisplayState.kind, .staleSaved)
        XCTAssertTrue(staleTrip.sourceStateDisplayState.needsVisibleCallout)
        XCTAssertEqual(staleTrip.sourceStateDisplayState.title, "Stale saved trip")
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

    func testSearchExamplesAndStarterSearchStayScopedToJapanProvider() async throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(defaults: defaults, provider: ShinkansenTrainProvider(consumerKey: nil))
        XCTAssertEqual(store.activeProviderRegion, .japan)
        XCTAssertTrue(store.searchExamples.contains("Tokyo to Shin-Osaka"))

        await store.searchLiveTrips(matching: "Tokyo to Shin-Osaka")
        let results = store.searchableResults

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.providerID == "shinkansen" })
        XCTAssertTrue(results.contains { $0.sourceProvenance.sourceKind == .starterCatalog })
        XCTAssertNil(store.searchEmptyState(for: "Tokyo to Shin-Osaka", results: results))
    }

    /// Verifies search retains a matching service even when the rider already tracks it.
    func testSearchKeepsAnAlreadyTrackedMatchingServiceVisible() async throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(defaults: defaults, provider: ShinkansenTrainProvider(consumerKey: nil))
        let query = "Tokyo to Shin-Osaka"
        XCTAssertTrue(store.trips.contains { $0.id == "nozomi-231" })

        store.query = query
        await store.searchLiveTrips(matching: query)
        let results = store.searchableResults

        XCTAssertTrue(results.contains { $0.id == "nozomi-231" })
        XCTAssertTrue(results.allSatisfy { ($0.routeID ?? "") == "tokaido" })
        XCTAssertNil(store.searchEmptyState(for: query, results: results))
    }

    func testSearchEmptyStateDistinguishesNoMatchesFromProviderUnavailable() async throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(defaults: defaults, provider: ShinkansenTrainProvider(consumerKey: nil))
        store.query = "zzzz-not-a-route"
        await store.searchLiveTrips(matching: "zzzz-not-a-route")
        let noMatchState = try XCTUnwrap(store.searchEmptyState(for: "zzzz-not-a-route", results: store.searchableResults))
        XCTAssertEqual(noMatchState.kind, .noMatches)
        XCTAssertTrue(noMatchState.title.localizedCaseInsensitiveContains("Japan"))
        XCTAssertTrue(noMatchState.message.localizedCaseInsensitiveContains("starter catalog"))
        XCTAssertEqual(noMatchState.actionTitle, "Manual note only")

        let unavailableProvider = SearchFixtureProvider(
            providerID: "blocked-provider",
            displayName: "Blocked Provider",
            region: .unitedKingdom,
            capabilities: [.schedule],
            availability: .requiresConfiguration("Missing provider credentials.", requirements: [.localKey("BLOCKED_KEY")]),
            catalog: [TrainTrip.samples[0]]
        )
        let unavailableStore = TrainStore(defaults: defaults, provider: unavailableProvider)
        unavailableStore.query = "London"
        await unavailableStore.searchLiveTrips(matching: "London")
        let unavailableState = try XCTUnwrap(unavailableStore.searchEmptyState(for: "London", results: unavailableStore.searchableResults))
        XCTAssertEqual(unavailableState.kind, .providerUnavailable)
        XCTAssertTrue(unavailableState.title.localizedCaseInsensitiveContains("Provider unavailable"))
        XCTAssertTrue(unavailableState.message.localizedCaseInsensitiveContains("Missing provider credentials"))
        XCTAssertNil(unavailableState.actionTitle)
    }

    func testSearchDistinguishesRealtimeUnavailableFromScheduleUnavailable() async throws {
        let shinkansenSuiteName = "TrainyTests-\(UUID().uuidString)"
        let schedulelessSuiteName = "TrainyTests-\(UUID().uuidString)"
        let shinkansenDefaults = try XCTUnwrap(UserDefaults(suiteName: shinkansenSuiteName))
        let schedulelessDefaults = try XCTUnwrap(UserDefaults(suiteName: schedulelessSuiteName))
        defer {
            shinkansenDefaults.removePersistentDomain(forName: shinkansenSuiteName)
            schedulelessDefaults.removePersistentDomain(forName: schedulelessSuiteName)
        }

        let shinkansenStore = TrainStore(defaults: shinkansenDefaults, provider: ShinkansenTrainProvider(consumerKey: nil))
        let realtimeNotice = try XCTUnwrap(shinkansenStore.searchCapabilityNotice)
        XCTAssertEqual(realtimeNotice.kind, .realtimeUnavailable)
        XCTAssertTrue(realtimeNotice.message.localizedCaseInsensitiveContains("Prediction labels"))

        let schedulelessProvider = SearchFixtureProvider(
            providerID: "board-only",
            displayName: "Board Only",
            region: .hongKong,
            capabilities: [.stationBoard],
            availability: .available("Station board only."),
            catalog: [TrainTrip.samples[0]]
        )
        let schedulelessStore = TrainStore(defaults: schedulelessDefaults, provider: schedulelessProvider)
        schedulelessStore.query = "Central"
        await schedulelessStore.searchLiveTrips(matching: "Central")
        let scheduleState = try XCTUnwrap(schedulelessStore.searchEmptyState(for: "Central", results: schedulelessStore.searchableResults))

        XCTAssertEqual(schedulelessStore.searchCapabilityNotice?.kind, .scheduleUnavailable)
        XCTAssertEqual(scheduleState.kind, .scheduleUnavailable)
        XCTAssertTrue(scheduleState.message.localizedCaseInsensitiveContains("scheduled trip search"))
        XCTAssertNil(scheduleState.actionTitle)
    }

    func testODPTTimetableFixtureMapsToNormalizedTrip() throws {
        let timetableData = try fixtureData("odpt_train_timetable_tokaido", fileExtension: "json")
        let timetables = try JSONDecoder().decode([ODPTTrainTimetable].self, from: timetableData)
        let route = try XCTUnwrap(ShinkansenTrainProvider.routes.first { $0.id == "tokaido" })
        let railwayRef = try XCTUnwrap(ShinkansenTrainProvider.odptRailwaysByRouteID["tokaido"]?.first)
        let starterTrips = ShinkansenTrainProvider.allTrips.filter { $0.routeID == route.id }

        let informationData = try fixtureData("odpt_train_information_tokaido", fileExtension: "json")
        let information = try JSONDecoder().decode([ODPTTrainInformation].self, from: informationData)
        let serviceNotice = try XCTUnwrap(information.first)
        let status = try XCTUnwrap(serviceNotice.status?.displayText)
        let detail = try XCTUnwrap(serviceNotice.text?.displayText)
        let alerts = [
            TrainAlert(
                title: status,
                detail: detail,
                tone: status.localizedCaseInsensitiveContains("normal") ? .good : .watch
            )
        ]

        let trips = timetables.compactMap { timetable in
            ShinkansenTrainProvider.trip(
                from: timetable,
                route: route,
                railwayRef: railwayRef,
                starterTrips: starterTrips,
                alerts: alerts
            )
        }
        let trip = try XCTUnwrap(trips.first)

        XCTAssertEqual(trip.providerID, "shinkansen")
        XCTAssertEqual(trip.routeID, "tokaido")
        XCTAssertEqual(trip.train, "Nozomi 231")
        XCTAssertEqual(trip.operatorName, "JR Central")
        XCTAssertEqual(trip.origin.name, "Tokyo")
        XCTAssertEqual(trip.destination.name, "Shin-Osaka")
        XCTAssertEqual(trip.duration, "2h 27m")
        XCTAssertEqual(trip.sourceProvenance.providerID, "odpt")
        XCTAssertEqual(trip.sourceProvenance.sourceKind, .officialTimetable)
        XCTAssertEqual(trip.factProvenance.first { $0.fact == .schedule }?.confidence, .confirmed)
        XCTAssertEqual(trip.stops.map(\.name), ["Tokyo", "Shin-Yokohama", "Nagoya", "Kyoto", "Shin-Osaka"])
        XCTAssertEqual(trip.stops.map(\.time), ["09:21", "09:39", "10:59", "11:35", "11:48"])
        XCTAssertTrue(trip.alerts.contains { $0.title == "Normal service" })
    }

    func testJREastHTMLFixtureMapsToTimetableTrip() throws {
        let html = try fixtureString("jr_east_train_timetable_tohoku", fileExtension: "html")
        let sourceURL = URL(string: "https://timetables.jreast.co.jp/en/train/fixture-hayabusa-17.html")!
        let timetable = try XCTUnwrap(JREastTimetableClient.trainTimetable(from: html, sourceURL: sourceURL))
        let route = try XCTUnwrap(ShinkansenTrainProvider.routes.first { $0.id == "tohoku" })
        let reference = try XCTUnwrap(ShinkansenTrainProvider.jrEastTimetableReferencesByRouteID["tohoku"])
        let starterTrips = ShinkansenTrainProvider.allTrips.filter { $0.routeID == route.id }
        let trip = try XCTUnwrap(
            ShinkansenTrainProvider.trip(
                from: timetable,
                route: route,
                reference: reference,
                starterTrips: starterTrips
            )
        )

        XCTAssertEqual(timetable.trainName, "Hayabusa 17")
        XCTAssertEqual(timetable.trainNumber, "17B")
        XCTAssertEqual(timetable.stops.map(\.stationName), ["Tokyo", "Omiya", "Sendai", "Morioka", "Shin-Aomori"])
        XCTAssertEqual(trip.providerID, "shinkansen")
        XCTAssertEqual(trip.routeID, "tohoku")
        XCTAssertEqual(trip.liveTripID, "17B")
        XCTAssertEqual(trip.train, "Hayabusa 17")
        XCTAssertEqual(trip.origin.name, "Tokyo")
        XCTAssertEqual(trip.destination.name, "Shin-Aomori")
        XCTAssertEqual(trip.duration, "3h 13m")
        XCTAssertEqual(trip.sourceProvenance.providerID, "jr-east")
        XCTAssertEqual(trip.sourceProvenance.sourceKind, .officialTimetable)
        XCTAssertEqual(trip.factProvenance.first { $0.fact == .schedule }?.confidence, .confirmed)
    }

    func testStarterCatalogExpectationFixtureMatchesFallbackWithoutNetwork() async throws {
        let expectationData = try fixtureData("starter_catalog_expectations", fileExtension: "json")
        let expectation = try JSONDecoder().decode(StarterCatalogExpectation.self, from: expectationData)
        let provider = ShinkansenTrainProvider(consumerKey: nil)

        XCTAssertFalse(expectation.requiresNetwork)
        XCTAssertFalse(provider.isODPTConfigured)
        XCTAssertEqual(provider.providerID, expectation.providerID)
        XCTAssertEqual(provider.defaultTrips.map(\.id), expectation.expectedTripIDs)
        XCTAssertEqual(provider.defaultTrips.count, expectation.defaultTripCount)

        let trips = try await provider.fetchTrips(matching: expectation.fallbackQuery, knownRoutes: ShinkansenTrainProvider.routes)
        XCTAssertFalse(trips.isEmpty)
        XCTAssertTrue(trips.contains { $0.routeID == expectation.expectedFallbackRouteID })
        XCTAssertTrue(trips.allSatisfy { $0.sourceProvenance.sourceKind.rawValue == expectation.expectedSourceKind })
    }

    func testFixtureFilesDoNotContainCredentialMarkers() throws {
        let forbiddenMarkers = [
            "ODPT_CONSUMER_KEY",
            "NS_SUBSCRIPTION_KEY",
            "TDX_CLIENT_ID",
            "TDX_CLIENT_SECRET",
            "TFNSW_API_KEY",
            "SWISS_OPEN_TRANSPORT_API_KEY",
            "SWISS_GTFS_RT_API_KEY",
            "TRANSPORT_DATA_GOUV_FR_TOKEN",
            "SNCF_API_TOKEN",
            "UK_DARWIN",
            "acl:consumerKey",
            "Ocp-Apim-Subscription-Key",
            "Authorization:",
            "Bearer ",
            "apikey ",
            "client_secret",
            "x-api-key",
            "password=",
            "secret=",
            "token="
        ]

        let fixtureURLs = try allFixtureFileURLs()
        XCTAssertFalse(fixtureURLs.isEmpty)

        for fixtureURL in fixtureURLs {
            let contents = try String(contentsOf: fixtureURL, encoding: .utf8)
            for marker in forbiddenMarkers {
                XCTAssertFalse(
                    contents.localizedCaseInsensitiveContains(marker),
                    "\(fixtureURL.lastPathComponent) should not contain credential marker \(marker)."
                )
            }
        }
    }

    func testStationNormalization() {
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("Tokyo"), "tokyo")
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("Shin-Osaka"), "shinosaka")
        XCTAssertEqual(ProviderTextUtilities.normalizedStationKey("odpt.Station.ShinOsaka"), "odptstationshinosaka")
        XCTAssertEqual(ShinkansenTrainProvider.stationName(from: "odpt.Station.ShinOsaka"), "Shin-Osaka")
        XCTAssertEqual(ShinkansenTrainProvider.operatorName(from: "odpt.Operator:JR-Central"), "JR Central")
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

    func testDisplayPreferencesPersistAndFormatWithoutProviderCredentials() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var preferences = UserPreferences(defaults: defaults)
        XCTAssertEqual(preferences.timeFormat, .hour12)
        XCTAssertEqual(preferences.unitSystem, .metric)
        XCTAssertEqual(preferences.sourceLabelVerbosity, .compact)

        preferences.timeFormat = .hour24
        preferences.unitSystem = .imperial
        preferences.sourceLabelVerbosity = .detailed
        defaults.set(true, forKey: "trainy.localDelayNoticesEnabled")
        defaults.set(true, forKey: "trainy.localPlatformNoticesEnabled")
        defaults.set(true, forKey: "trainy.diagnosticsConsent")

        let returningPreferences = UserPreferences(defaults: defaults)
        XCTAssertEqual(returningPreferences.timeFormat, .hour24)
        XCTAssertEqual(returningPreferences.unitSystem, .imperial)
        XCTAssertEqual(returningPreferences.sourceLabelVerbosity, .detailed)
        XCTAssertTrue(defaults.bool(forKey: "trainy.localDelayNoticesEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "trainy.localPlatformNoticesEnabled"))
        XCTAssertTrue(defaults.bool(forKey: "trainy.diagnosticsConsent"))

        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual("09:21".formattedAsTime(in: tokyo, format: .hour12), "9:21 AM")
        XCTAssertEqual("09:21".formattedAsTime(in: tokyo, format: returningPreferences.timeFormat), "09:21")

        let noKeyProvider = ShinkansenTrainProvider(consumerKey: nil)
        let store = TrainStore(defaults: defaults, provider: noKeyProvider)
        XCTAssertFalse(noKeyProvider.isODPTConfigured)
        XCTAssertFalse(store.trips.isEmpty)
        XCTAssertEqual(store.providerDirectory.first { $0.id == store.activeProviderID }?.region, .japan)
    }

    func testUnitConverterKeepsUnsupportedDisplayStringsAndConvertsMetricValues() {
        XCTAssertEqual(UnitConverter.displaySpeed("300 km/h", useMetric: true), "300 km/h")
        XCTAssertEqual(UnitConverter.displaySpeed("300 km/h", useMetric: false), "186 mph")
        XCTAssertEqual(UnitConverter.displaySpeed("Timetable", useMetric: false), "Timetable")
        XCTAssertEqual(UnitConverter.displayDistance("515.4 km", useMetric: true), "515.4 km")
        XCTAssertEqual(UnitConverter.displayDistance("515.4 km", useMetric: false), "320.3 mi")
        XCTAssertEqual(UnitConverter.displayDistance("5 stops", useMetric: false), "5 stops")
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

    func testFirstRunStatePersistsAndCanReset() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(defaults: defaults, registry: .default)
        XCTAssertTrue(store.shouldShowFirstRun)
        XCTAssertEqual(store.activeProviderID, "shinkansen")
        XCTAssertEqual(store.selectedProviderID, "shinkansen")
        XCTAssertEqual(store.providerDirectory.first { $0.id == store.activeProviderID }?.region, .japan)

        store.startFirstRunWithShinkansen()
        XCTAssertFalse(store.shouldShowFirstRun)
        XCTAssertEqual(store.selectedProviderID, "shinkansen")
        XCTAssertEqual(store.selectedRegionID, ProviderRegion.japan.id)

        let returningStore = TrainStore(defaults: defaults, registry: .default)
        XCTAssertFalse(returningStore.shouldShowFirstRun)
        XCTAssertEqual(returningStore.selectedProviderID, "shinkansen")
        XCTAssertEqual(returningStore.selectedRegionID, ProviderRegion.japan.id)

        returningStore.resetFirstRun()
        XCTAssertTrue(returningStore.shouldShowFirstRun)

        let resetStore = TrainStore(defaults: defaults, registry: .default)
        XCTAssertTrue(resetStore.shouldShowFirstRun)
    }

    func testFirstRunExplorePlannedRegionsKeepsProvidersUnavailable() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(defaults: defaults, registry: .default)
        store.explorePlannedRegionsFromFirstRun()

        XCTAssertFalse(store.shouldShowFirstRun)
        XCTAssertEqual(store.selectedRegionID, ProviderRegion.all.id)
        XCTAssertTrue(store.visibleProviderDirectory.contains { $0.id == "taiwan-tdx" })
        XCTAssertTrue(store.visibleProviderDirectory.contains { $0.implementationStatus == .planned })
        XCTAssertFalse(store.providerCanSearch("taiwan-tdx"))
        XCTAssertFalse(store.providerCanSearch("hong-kong-mtr"))

        let returningStore = TrainStore(defaults: defaults, registry: .default)
        XCTAssertFalse(returningStore.shouldShowFirstRun)
        XCTAssertEqual(returningStore.selectedRegionID, ProviderRegion.all.id)
        XCTAssertFalse(returningStore.providerCanSearch("taiwan-tdx"))
    }

    func testProviderSettingsMetadataShowsFallbackCredentialState() throws {
        let provider = ShinkansenTrainProvider(consumerKey: nil)
        let registry = ProviderRegistry(providers: [provider], defaultProviderID: provider.providerID)
        let metadata = try XCTUnwrap(registry.metadata(id: provider.providerID))

        XCTAssertEqual(metadata.displayName, "Japan Shinkansen")
        XCTAssertEqual(metadata.region, .japan)
        XCTAssertEqual(metadata.implementationStatus, .active)
        XCTAssertEqual(metadata.availability.status, .degraded)
        XCTAssertTrue(metadata.availability.canSearch)
        XCTAssertTrue(metadata.availability.message.localizedCaseInsensitiveContains("Starter catalog fallback"))
        XCTAssertTrue(metadata.availability.message.localizedCaseInsensitiveContains("ODPT_CONSUMER_KEY"))
        XCTAssertTrue(metadata.capabilities.contains(.schedule))
        XCTAssertFalse(metadata.capabilities.contains(.serviceAlerts))
        XCTAssertTrue(metadata.requirements.contains(.localKey("ODPT_CONSUMER_KEY")))
        XCTAssertTrue(metadata.requirements.contains(.attribution("ODPT developer terms and JR timetable attribution")))
        XCTAssertTrue(metadata.requirements.contains(.terms("ODPT developer terms and JR timetable terms")))
        XCTAssertTrue(metadata.sourceLinks.contains { $0.title.localizedCaseInsensitiveContains("ODPT") })
        XCTAssertTrue(metadata.sourceLinks.contains { $0.title.localizedCaseInsensitiveContains("JR East") })
    }

    func testPlannedProvidersRemainUnavailableForSettingsSelection() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let registry = ProviderRegistry.default
        let store = TrainStore(defaults: defaults, registry: registry)
        let planned = try XCTUnwrap(registry.metadata(id: "taiwan-tdx"))

        XCTAssertEqual(planned.implementationStatus, .planned)
        XCTAssertFalse(planned.isSearchable)
        XCTAssertFalse(planned.availability.canSearch)
        XCTAssertFalse(registry.canSearch(providerID: planned.id))
        XCTAssertTrue(planned.availability.message.localizedCaseInsensitiveContains("Needs"))

        store.selectProvider(planned.id)
        XCTAssertEqual(store.selectedProviderID, "shinkansen")
        XCTAssertEqual(store.activeProviderID, "shinkansen")
    }

    func testSelectingSearchableProviderChangesActiveProviderAndTripsImmediately() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstTrip = providerTrip(
            id: "first-provider-trip",
            providerID: "first-provider",
            train: "Alpha 1",
            service: "Alpha Line"
        )
        let secondTrip = providerTrip(
            id: "second-provider-trip",
            providerID: "second-provider",
            train: "Beta 2",
            service: "Beta Line"
        )
        let firstProvider = SearchFixtureProvider(
            providerID: "first-provider",
            displayName: "First Provider",
            region: .japan,
            capabilities: [.schedule],
            availability: .available("First provider is searchable."),
            catalog: [firstTrip],
            tripsToReturn: [firstTrip]
        )
        let secondProvider = SearchFixtureProvider(
            providerID: "second-provider",
            displayName: "Second Provider",
            region: .unitedKingdom,
            capabilities: [.schedule],
            availability: .available("Second provider is searchable."),
            catalog: [secondTrip],
            tripsToReturn: [secondTrip]
        )
        let registry = ProviderRegistry(
            providers: [firstProvider, secondProvider],
            defaultProviderID: firstProvider.providerID
        )
        let store = TrainStore(defaults: defaults, registry: registry)

        XCTAssertEqual(store.activeProviderID, "first-provider")
        XCTAssertEqual(store.selectedProviderID, "first-provider")
        XCTAssertEqual(store.trips.map(\.id), ["first-provider-trip"])

        store.selectProvider("second-provider")

        XCTAssertEqual(store.activeProviderID, "second-provider")
        XCTAssertEqual(store.selectedProviderID, "second-provider")
        XCTAssertEqual(store.activeProviderName, "Second Provider")
        XCTAssertEqual(store.trips.map(\.id), ["second-provider-trip"])
        XCTAssertEqual(store.selectedTripID, "second-provider-trip")
        XCTAssertTrue(store.searchScopeText.localizedCaseInsensitiveContains("Second Provider"))
        XCTAssertEqual(defaults.string(forKey: "trainy.selectedProviderID"), "second-provider")
        XCTAssertEqual(defaults.string(forKey: "trainy.dataScope"), "second-provider")
    }

    func testSearchableProviderCanStartAndSwitchWithoutBundledTrips() throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite")
            return
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let seededTrip = providerTrip(
            id: "seeded-provider-trip",
            providerID: "seeded-provider",
            train: "Seed 1",
            service: "Seed Line"
        )
        let seededProvider = SearchFixtureProvider(
            providerID: "seeded-provider",
            displayName: "Seeded Provider",
            region: .japan,
            capabilities: [.schedule],
            availability: .available("Seeded provider is searchable."),
            catalog: [seededTrip],
            tripsToReturn: [seededTrip]
        )
        let liveOnlyProvider = SearchFixtureProvider(
            providerID: "live-only-provider",
            displayName: "Live Only Provider",
            region: .unitedKingdom,
            capabilities: [.schedule],
            availability: .available("Live-only provider is searchable."),
            catalog: [],
            tripsToReturn: []
        )
        let registry = ProviderRegistry(
            providers: [seededProvider, liveOnlyProvider],
            defaultProviderID: liveOnlyProvider.providerID
        )
        let emptyStore = TrainStore(defaults: defaults, registry: registry)

        XCTAssertEqual(emptyStore.activeProviderID, "live-only-provider")
        XCTAssertEqual(emptyStore.selectedProviderID, "live-only-provider")
        XCTAssertTrue(emptyStore.trips.isEmpty)
        XCTAssertEqual(emptyStore.selectedTripID, "")
        XCTAssertNil(emptyStore.selectedTrip)
        XCTAssertEqual(emptyStore.shareSummary, "No selected Trainy trip.")

        emptyStore.refreshSelectedTrip()
        XCTAssertEqual(emptyStore.liveLoadState, .empty("no saved trip is selected"))

        let switchDefaults = try XCTUnwrap(UserDefaults(suiteName: "\(suiteName)-switch"))
        defer {
            switchDefaults.removePersistentDomain(forName: "\(suiteName)-switch")
        }
        let seededStore = TrainStore(
            defaults: switchDefaults,
            registry: ProviderRegistry(providers: [seededProvider, liveOnlyProvider], defaultProviderID: seededProvider.providerID)
        )
        XCTAssertEqual(seededStore.trips.map(\.id), ["seeded-provider-trip"])

        seededStore.selectProvider("live-only-provider")

        XCTAssertEqual(seededStore.activeProviderID, "live-only-provider")
        XCTAssertTrue(seededStore.trips.isEmpty)
        XCTAssertNil(seededStore.selectedTrip)
        XCTAssertEqual(seededStore.selectedTripID, "")
        XCTAssertEqual(switchDefaults.string(forKey: "trainy.selectedProviderID"), "live-only-provider")
        XCTAssertEqual(switchDefaults.string(forKey: "trainy.dataScope"), "live-only-provider")
    }

    func testProviderProxyConfigurationUsesOnlyBaseURLInputs() throws {
        let environmentConfig = ProviderProxyConfiguration.current(
            infoDictionary: [
                ProviderProxyConfiguration.infoPlistKey: "https://plist-proxy.example.com"
            ],
            environment: [
                ProviderProxyConfiguration.environmentVariable: " https://worker-proxy.example.com/trainy?debug=1 "
            ]
        )

        XCTAssertTrue(environmentConfig.isConfigured)
        XCTAssertEqual(environmentConfig.baseURL?.scheme, "https")
        XCTAssertEqual(environmentConfig.displayHost, "worker-proxy.example.com")
        XCTAssertEqual(environmentConfig.baseURL?.path, "/trainy")
        XCTAssertNil(environmentConfig.baseURL?.query)

        let infoPlistConfig = ProviderProxyConfiguration.current(
            infoDictionary: [
                ProviderProxyConfiguration.infoPlistKey: "https://plist-proxy.example.com/"
            ],
            environment: [:]
        )

        XCTAssertTrue(infoPlistConfig.isConfigured)
        XCTAssertEqual(infoPlistConfig.displayHost, "plist-proxy.example.com")

        let invalidConfig = ProviderProxyConfiguration.current(
            infoDictionary: nil,
            environment: [
                ProviderProxyConfiguration.environmentVariable: "file:///tmp/provider-secret"
            ]
        )

        XCTAssertFalse(invalidConfig.isConfigured)
        XCTAssertNil(invalidConfig.baseURL)
    }

    func testProviderProxyHealthDecodesCompactJSONAndBuildsEndpointURL() throws {
        let healthURL = ProviderProxyHealthClient.healthURL(from: URL(string: "https://worker-proxy.example.com/trainy")!)
        XCTAssertEqual(healthURL.absoluteString, "https://worker-proxy.example.com/trainy/v1/health/providers")

        let json = """
        {
          "generatedAt": "2026-06-20T00:00:00Z",
          "providers": [
            {
              "id": "ns",
              "region": "NL",
              "configured": true,
              "status": "ok",
              "capabilities": ["stationDepartures", "serviceAlerts"],
              "cache": {
                "staticFeed": "fresh",
                "updatedAt": "2026-06-20T00:00:00Z"
              },
              "checkedAt": "2026-06-20T00:00:00Z",
              "message": "Provider reachable."
            },
            {
              "id": "tdx",
              "region": "TW",
              "configured": false,
              "status": "missingCredential",
              "message": "Proxy credential is not configured."
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try ProviderProxyHealthClient.makeDecoder().decode(ProviderProxyHealthResponse.self, from: json)

        XCTAssertEqual(response.providers.count, 2)
        XCTAssertEqual(response.providers[0].id, "ns")
        XCTAssertEqual(response.providers[0].status, .ok)
        XCTAssertEqual(response.providers[0].cache?.staticFeed, .fresh)
        XCTAssertEqual(response.providers[1].status, .missingCredential)
        XCTAssertFalse(String(data: json, encoding: .utf8)?.localizedCaseInsensitiveContains("Tokyo to Shin-Osaka") == true)
        XCTAssertFalse(String(data: json, encoding: .utf8)?.localizedCaseInsensitiveContains("device") == true)
        XCTAssertFalse(String(data: json, encoding: .utf8)?.localizedCaseInsensitiveContains("secret") == true)
    }

    func testTrainStoreRefreshesProviderProxyHealthAndMatchesProviderAliases() async throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let generatedAt = Date(timeIntervalSince1970: 1_781_956_800)
        let response = ProviderProxyHealthResponse(
            generatedAt: generatedAt,
            providers: [
                ProviderProxyProviderHealth(
                    id: "ns",
                    region: "NL",
                    configured: true,
                    status: .ok,
                    capabilities: ["stationDepartures"],
                    cache: ProviderProxyCacheHealth(staticFeed: .fresh, updatedAt: generatedAt),
                    checkedAt: generatedAt,
                    message: "Provider reachable."
                ),
                ProviderProxyProviderHealth(
                    id: "tdx",
                    region: "TW",
                    configured: false,
                    status: .missingCredential,
                    message: "Proxy credential is not configured."
                )
            ]
        )
        let store = TrainStore(
            defaults: defaults,
            registry: .default,
            proxyConfiguration: ProviderProxyConfiguration(baseURL: URL(string: "https://worker-proxy.example.com")!),
            proxyHealthFetcher: ProviderProxyHealthFixtureFetcher(response: response)
        )

        XCTAssertEqual(store.providerProxyLoadState, .idle)

        await store.refreshProviderProxyHealth()

        XCTAssertEqual(store.providerProxyLoadState, .loaded(generatedAt))
        XCTAssertEqual(store.providerProxyHealthProviders.count, 2)
        XCTAssertEqual(store.providerProxyHealth(for: "netherlands-ns")?.id, "ns")
        XCTAssertEqual(store.providerProxyHealth(for: "taiwan-tdx")?.status, .missingCredential)
        XCTAssertNil(store.providerProxyHealth(for: "hong-kong-mtr"))
    }

    func testTrainStoreKeepsProxyHealthUnconfiguredWithoutBaseURL() async throws {
        let suiteName = "TrainyTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = TrainStore(
            defaults: defaults,
            registry: .default,
            proxyConfiguration: ProviderProxyConfiguration(baseURL: nil),
            proxyHealthFetcher: ProviderProxyHealthFixtureFetcher(
                response: ProviderProxyHealthResponse(generatedAt: nil, providers: [])
            )
        )

        XCTAssertEqual(store.providerProxyLoadState, .notConfigured)
        await store.refreshProviderProxyHealth()
        XCTAssertEqual(store.providerProxyLoadState, .notConfigured)
        XCTAssertNil(store.providerProxyHealth)
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
        XCTAssertEqual(
            TrainDataProviderError.badSourceResponse(source: "ODPT TrainTimetable API", statusCode: 401).errorDescription,
            "The ODPT TrainTimetable API returned HTTP 401."
        )
        XCTAssertEqual(
            TrainDataProviderError.badSourceResponse(source: "JR East official timetable", statusCode: nil).errorDescription,
            "The JR East official timetable returned an unexpected response."
        )
        XCTAssertEqual(
            TrainDataProviderError.unreadableSourceResponse(source: "ODPT TrainTimetable API").errorDescription,
            "Trainy could not read the ODPT TrainTimetable API response."
        )
        let chainDescription = TrainDataProviderError.sourceChainFailed(
            primary: "The ODPT TrainTimetable API returned HTTP 401.",
            fallback: "No scheduled Shinkansen departures matched that search."
        ).errorDescription
        XCTAssertEqual(
            chainDescription,
            "Scheduled Shinkansen lookup failed. Primary source: The ODPT TrainTimetable API returned HTTP 401. Fallback source: No scheduled Shinkansen departures matched that search."
        )
        XCTAssertFalse(chainDescription?.localizedCaseInsensitiveContains("consumerKey") == true)
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

    private func fixtureData(_ name: String, fileExtension: String) throws -> Data {
        try Data(contentsOf: fixtureURL("\(name).\(fileExtension)"))
    }

    private func fixtureString(_ name: String, fileExtension: String) throws -> String {
        try fixtureString("\(name).\(fileExtension)")
    }

    private func fixtureString(_ fileName: String) throws -> String {
        try String(contentsOf: fixtureURL(fileName), encoding: .utf8)
    }

    private func fixtureURL(_ fileName: String) -> URL {
        fixtureRootURL()
            .appendingPathComponent(fileName)
    }

    private func fixtureRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    private func allFixtureFileURLs() throws -> [URL] {
        let rootURL = fixtureRootURL()
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                urls.append(url)
            }
        }
        return urls
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

    private func tripVariant(
        from trip: TrainTrip,
        platform: String? = nil,
        stops: [StationStop]? = nil,
        vehicleLatitude: Double? = nil,
        vehicleLongitude: Double? = nil,
        clearsVehicleCoordinate: Bool = false,
        sourceProvenance: SourceProvenance? = nil,
        factProvenance: [FactProvenance]? = nil
    ) -> TrainTrip {
        TrainTrip(
            id: trip.id,
            providerID: trip.providerID,
            routeID: trip.routeID,
            liveTripID: trip.liveTripID,
            train: trip.train,
            operatorName: trip.operatorName,
            service: trip.service,
            origin: trip.origin,
            destination: trip.destination,
            duration: trip.duration,
            status: trip.status,
            statusTone: trip.statusTone,
            category: trip.category,
            platform: platform ?? trip.platform,
            nextStop: trip.nextStop,
            eta: trip.eta,
            speed: trip.speed,
            progress: trip.progress,
            bestCar: trip.bestCar,
            cars: trip.cars,
            seat: trip.seat,
            updated: trip.updated,
            callout: trip.callout,
            signal: trip.signal,
            signalCopy: trip.signalCopy,
            stops: stops ?? trip.stops,
            alerts: trip.alerts,
            pulse: trip.pulse,
            vehicleLatitude: clearsVehicleCoordinate ? nil : (vehicleLatitude ?? trip.vehicleLatitude),
            vehicleLongitude: clearsVehicleCoordinate ? nil : (vehicleLongitude ?? trip.vehicleLongitude),
            distanceText: trip.distanceText,
            dataSource: trip.dataSource,
            sourceProvenance: sourceProvenance ?? trip.sourceProvenance,
            factProvenance: factProvenance ?? trip.factProvenance
        )
    }

    private func providerTrip(id: String, providerID: String, train: String, service: String) -> TrainTrip {
        let sample = TrainTrip.samples[0]
        return TrainTrip(
            id: id,
            providerID: providerID,
            routeID: "\(providerID)-route",
            liveTripID: nil,
            train: train,
            operatorName: "\(providerID) operator",
            service: service,
            origin: sample.origin,
            destination: sample.destination,
            duration: sample.duration,
            status: sample.status,
            statusTone: sample.statusTone,
            category: sample.category,
            platform: sample.platform,
            nextStop: sample.nextStop,
            eta: sample.eta,
            speed: sample.speed,
            progress: sample.progress,
            bestCar: sample.bestCar,
            cars: sample.cars,
            seat: sample.seat,
            updated: sample.updated,
            callout: sample.callout,
            signal: sample.signal,
            signalCopy: sample.signalCopy,
            stops: sample.stops,
            alerts: sample.alerts,
            pulse: sample.pulse,
            vehicleLatitude: sample.vehicleLatitude,
            vehicleLongitude: sample.vehicleLongitude,
            distanceText: sample.distanceText,
            dataSource: "\(providerID) fixture",
            sourceProvenance: SourceProvenance(
                providerID: providerID,
                providerName: "\(providerID) provider",
                sourceName: "\(providerID) fixture",
                sourceKind: .officialTimetable,
                confidence: .confirmed,
                freshness: .fresh
            ),
            factProvenance: FactProvenance.timetableFacts(
                source: SourceProvenance(
                    providerID: providerID,
                    providerName: "\(providerID) provider",
                    sourceName: "\(providerID) fixture",
                    sourceKind: .officialTimetable,
                    confidence: .confirmed,
                    freshness: .fresh
                )
            )
        )
    }
}

private struct StarterCatalogExpectation: Decodable {
    let providerID: String
    let defaultTripCount: Int
    let expectedTripIDs: [String]
    let fallbackQuery: String
    let expectedFallbackRouteID: String
    let expectedSourceKind: String
    let requiresNetwork: Bool
}

private struct SearchFixtureProvider: ScheduleFeedProvider {
    let providerID: String
    let displayName: String
    let region: ProviderRegion
    let capabilities: Set<ProviderCapability>
    let availability: ProviderAvailability
    var feedLabel: String = "Fixture feed"
    var catalog: [TrainTrip] = []
    var includesCatalogResultsInSearch = false
    var tripsToReturn: [TrainTrip] = []

    func fetchRoutes() async throws -> [LiveTrainRoute] {
        ShinkansenTrainProvider.routes
    }

    func fetchTrips(matching query: String, knownRoutes: [LiveTrainRoute]) async throws -> [TrainTrip] {
        if tripsToReturn.isEmpty {
            throw TrainDataProviderError.noLiveTrips
        }
        return tripsToReturn
    }
}

private struct ProviderProxyHealthFixtureFetcher: ProviderProxyHealthFetching {
    let response: ProviderProxyHealthResponse

    func fetchProviderHealth(from baseURL: URL) async throws -> ProviderProxyHealthResponse {
        response
    }
}

private enum TestFailure: Error {
    case legacyPayload
}
