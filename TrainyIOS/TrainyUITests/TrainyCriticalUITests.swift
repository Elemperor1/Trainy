import XCTest

@MainActor
final class TrainyCriticalUITests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testOnboardingExplainsDataScopeCompletesAndCanBeReopened() throws {
        defer { app.terminate() }
        launch(
            "onboarding",
            additionalArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"
            ]
        )

        let onboarding = element("onboarding.screen")
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to Trainy"].exists)
        XCTAssertTrue(app.staticTexts["Japan Shinkansen and Netherlands station boards are ready. Every status includes its source and freshness context."].exists)

        let start = element("onboarding.start")
        scrollUntilHittable(start)
        start.tap()
        XCTAssertTrue(onboarding.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Trips"].isSelected)

        app.tabBars.buttons["Settings"].tap()
        let guide = app.buttons["Onboarding guide"]
        scrollUntilHittable(guide)
        guide.tap()
        XCTAssertTrue(element("onboarding.screen").waitForExistence(timeout: 5))
    }

    func testLaunchFilmStandardOnboardingAndTrackedTripSurface() throws {
        defer { app.terminate() }
        launch(
            "onboarding",
            additionalArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
            ]
        )

        let onboarding = element("onboarding.screen")
        XCTAssertTrue(onboarding.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Welcome to Trainy"].exists)
        sleep(2)

        let start = element("onboarding.start")
        XCTAssertTrue(start.isHittable)
        start.tap()
        XCTAssertTrue(onboarding.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Trips"].isSelected)
        XCTAssertTrue(app.staticTexts["Nozomi 231"].waitForExistence(timeout: 5))
        sleep(2)
    }

    func testTrackedServiceSearchThenNoMatchRecovery() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Tokyo to Shin-Osaka")

        let trackedService = element("search.result.nozomi-231")
        XCTAssertTrue(trackedService.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nozomi 231"].exists)

        clear(searchField)
        searchField.typeText("zzqx no service")
        XCTAssertTrue(element("search.result.nozomi-231").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No Japan services found"].waitForExistence(timeout: 5))

        clear(searchField)
        searchField.typeText("Tokyo to Shin-Osaka")
        XCTAssertTrue(trackedService.waitForExistence(timeout: 5))
    }

    func testLaunchFilmJapanJourneyAtStandardSize() throws {
        defer { app.terminate() }
        launch(
            "fixture",
            additionalArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
            ]
        )

        XCTAssertTrue(app.staticTexts["Nozomi 231"].waitForExistence(timeout: 5))
        sleep(1)

        app.tabBars.buttons["Search"].tap()
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        sleep(1)

        searchField.tap()
        searchField.typeText("Tokyo to Shin-Osaka")
        let trackedService = element("search.result.nozomi-231")
        XCTAssertTrue(trackedService.waitForExistence(timeout: 5))
        sleep(2)

        let keyboard = app.keyboards.firstMatch
        let keyboardSearch = keyboard.buttons["Search"]
        XCTAssertTrue(keyboardSearch.waitForExistence(timeout: 5))
        keyboardSearch.tap()
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))

        app.tabBars.buttons["Trips"].tap()
        XCTAssertTrue(app.navigationBars["Trips"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nozomi 231"].exists)
        sleep(3)
    }

    func testCredentialNeutralFallbackAndProviderStatusAreExplicit() throws {
        defer { app.terminate() }
        launch("credential-neutral")
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.staticTexts["Japan Shinkansen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Starter catalog is active. Add an ODPT consumer key in the developer configuration for official timetable and alert feeds."].exists)

        app.staticTexts["Japan Shinkansen"].tap()
        XCTAssertTrue(app.staticTexts["AVAILABLE NOW"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Japan Shinkansen"].exists)
        XCTAssertTrue(app.staticTexts["NEEDS SETUP"].exists)
        XCTAssertTrue(app.staticTexts["Netherlands NS"].exists)
        XCTAssertTrue(app.staticTexts["Configure Trainy's provider proxy base URL to use NS station search and departures."].exists)
    }

    func testCrashDiagnosticsAreOffByDefaultAndRequireOptIn() throws {
        defer { app.terminate() }
        launch(
            "credential-neutral",
            additionalArguments: ["--trainy-reset-diagnostics-consent"]
        )
        app.tabBars.buttons["Settings"].tap()

        let diagnostics = app.switches["Share crash diagnostics"]
        XCTAssertTrue(diagnostics.waitForExistence(timeout: 5))
        if !diagnostics.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(diagnostics.isHittable)
        XCTAssertEqual(diagnostics.value as? String, "0")

        diagnostics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let optInApplied = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '1'"),
            object: diagnostics
        )
        XCTAssertEqual(XCTWaiter.wait(for: [optInApplied], timeout: 2), .completed)
    }

    func testNSStationSearchAndDepartureResultsUseFixtureData() throws {
        defer { app.terminate() }
        launch("fixture")
        openNSStationSearch()

        let stationField = element("ns.stationSearch.field")
        XCTAssertTrue(stationField.waitForExistence(timeout: 5))
        XCTAssertEqual(stationField.label, "Find a station")
        stationField.tap()
        stationField.typeText("Utrecht")
        element("ns.stationSearch.submit").tap()

        let station = element("ns.station.UT")
        XCTAssertTrue(station.waitForExistence(timeout: 5))
        XCTAssertEqual(station.label, "Utrecht Centraal, station code UT")
        station.tap()

        XCTAssertTrue(element("ns.departures.screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("ns.departure.fixture-sprinter-7400").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sprinter 7400"].exists)
        XCTAssertTrue(app.staticTexts["Data from Nederlandse Spoorwegen (NS)"].exists)
    }

    func testLaunchFilmUtrechtJourneyAtStandardSize() throws {
        defer { app.terminate() }
        launch(
            "fixture",
            additionalArguments: [
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"
            ]
        )

        XCTAssertTrue(app.staticTexts["Nozomi 231"].waitForExistence(timeout: 5))
        sleep(1)
        openNSStationSearch()

        let stationField = element("ns.stationSearch.field")
        XCTAssertTrue(stationField.waitForExistence(timeout: 5))
        sleep(1)
        stationField.tap()
        stationField.typeText("Utrecht")
        element("ns.stationSearch.submit").tap()

        let station = element("ns.station.UT")
        XCTAssertTrue(station.waitForExistence(timeout: 5))
        sleep(2)
        station.tap()

        XCTAssertTrue(element("ns.departures.screen").waitForExistence(timeout: 5))
        XCTAssertTrue(element("ns.departure.fixture-sprinter-7400").waitForExistence(timeout: 5))
        sleep(3)
    }

    func testNSFailureRecoversThroughTheVisibleRetryAction() throws {
        defer { app.terminate() }
        launch("search-failure-recovery")
        openNSStationSearch()

        let stationField = element("ns.stationSearch.field")
        XCTAssertTrue(stationField.waitForExistence(timeout: 5))
        stationField.tap()
        stationField.typeText("Utrecht")

        XCTAssertTrue(element("ns.stationSearch.unavailable").waitForExistence(timeout: 5))
        app.buttons["Try again"].tap()
        XCTAssertTrue(element("ns.station.UT").waitForExistence(timeout: 5))
    }

    func testNSLoadingStateHasAnAccessibleStatus() throws {
        defer { app.terminate() }
        launch("loading")
        openNSStationSearch()

        let loading = element("ns.stationSearch.loading")
        XCTAssertTrue(loading.waitForExistence(timeout: 5))
        XCTAssertEqual(loading.label, "Loading rail updates")
    }

    func testNSJourneyInLightDarkAndAX2XL() throws {
        defer { app.terminate() }
        for appearance in ["Light", "Dark"] {
            launch(
                "fixture",
                additionalArguments: [
                    "-AppleInterfaceStyle", appearance,
                    "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXL"
                ]
            )
            openNSStationSearch()

            let stationField = element("ns.stationSearch.field")
            XCTAssertTrue(stationField.waitForExistence(timeout: 5), "\(appearance) AX2XL search field")
            XCTAssertEqual(stationField.label, "Find a station")

            stationField.tap()
            stationField.typeText("UT")
            let submit = element("ns.stationSearch.submit")
            XCTAssertTrue(submit.exists, "\(appearance) AX2XL search action exists")
            if !submit.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(submit.isHittable, "\(appearance) AX2XL search action after scrolling")
            submit.tap()
            let station = element("ns.station.UT")
            XCTAssertTrue(station.waitForExistence(timeout: 5), "\(appearance) AX2XL station result")
            if !station.isHittable {
                app.swipeUp()
            }
            XCTAssertTrue(station.isHittable, "\(appearance) AX2XL station result after scrolling")
            app.terminate()
        }
    }

    private func launch(_ scenario: String, additionalArguments: [String] = []) {
        continueAfterFailure = false
        app.launchArguments = ["--trainy-automation", scenario] + additionalArguments
        app.launchEnvironment = [
            "ODPT_CONSUMER_KEY": "",
            "TRAINY_PROVIDER_PROXY_BASE_URL": ""
        ]
        app.launch()
    }

    private func openNSStationSearch() {
        app.tabBars.buttons["Stations"].tap()
        let link = element("stations.nsDepartures")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(element("ns.stationSearch.screen").waitForExistence(timeout: 5))
    }

    private func clear(_ field: XCUIElement) {
        field.tap()
        let clearText = app.buttons["Clear text"]
        XCTAssertTrue(clearText.waitForExistence(timeout: 2), "Expected the system search field to expose its Clear text action.")
        clearText.tap()
    }

    private func scrollUntilHittable(_ element: XCUIElement, attempts: Int = 12) {
        for _ in 0..<attempts where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Expected \(element) to become hittable after scrolling.")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
