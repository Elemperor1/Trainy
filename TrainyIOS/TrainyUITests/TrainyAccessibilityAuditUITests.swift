import XCTest

/// Accepted audit findings, as `screen | audit type | element`. The element is
/// the accessibility identifier when there is one, otherwise its label.
private let knownAccessibilityIssues: Set<String> = []

private final class AuditFindings: @unchecked Sendable {
    var unknown: [String] = []
    var reproduced: Set<String> = []
}

private struct AuditStop: Error {}

private func auditTypeName(_ type: XCUIAccessibilityAuditType) -> String {
    switch type {
    case .contrast: return "contrast"
    case .elementDetection: return "elementDetection"
    case .hitRegion: return "hitRegion"
    case .sufficientElementDescription: return "sufficientElementDescription"
    case .dynamicType: return "dynamicType"
    case .textClipped: return "textClipped"
    case .trait: return "trait"
    default: return "type\(type.rawValue)"
    }
}

@MainActor
private func auditFindingKey(screen: String, issue: XCUIAccessibilityAuditIssue) -> String {
    let identifier = issue.element?.identifier ?? ""
    let label = issue.element?.label ?? ""
    let name = identifier.isEmpty ? String(label.prefix(80)) : identifier
    return "\(screen) | \(auditTypeName(issue.auditType)) | \(name.isEmpty ? "(unnamed element)" : name)"
}

/// Runs Apple's automated accessibility audit on the screens riders reach first.
///
/// The audit reports contrast, hit-target, clipped-text, Dynamic Type, trait,
/// and missing-description problems. Findings that already exist are listed in
/// `knownAccessibilityIssues`, so the suite fails on anything new while the old
/// ones are fixed. Delete an entry when its screen is fixed. An attachment on
/// each test lists entries the audit no longer reproduces.
@MainActor
final class TrainyAccessibilityAuditUITests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testTripsTab() throws {
        defer { app.terminate() }
        launch("fixture")
        try require(app.staticTexts["Nozomi 231"], "the tracked Nozomi 231 trip")
        try audit("trips")
    }

    func testSearchTab() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["Search"].tap()
        try require(app.searchFields.firstMatch, "the search field")
        try audit("search")
    }

    func testSearchResults() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["Search"].tap()
        let field = app.searchFields.firstMatch
        try require(field, "the search field")
        field.tap()
        field.typeText("Tokyo to Shin-Osaka")
        try require(element("search.result.nozomi-231"), "the Nozomi 231 search result")
        let keyboardSearch = app.keyboards.firstMatch.buttons["Search"]
        if keyboardSearch.waitForExistence(timeout: 5) {
            keyboardSearch.tap()
            _ = app.keyboards.firstMatch.waitForNonExistence(timeout: 5)
        }
        try audit("search-results")
    }

    func testStationsTab() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["Stations"].tap()
        try require(element("stations.nsDepartures"), "the NS departures link")
        try audit("stations")
    }

    func testNSStationSearch() throws {
        defer { app.terminate() }
        launch("fixture")
        try openNSStationSearch()
        try audit("ns-station-search")
    }

    func testNSDepartures() throws {
        defer { app.terminate() }
        launch("fixture")
        try openNSStationSearch()
        let field = element("ns.stationSearch.field")
        try require(field, "the station search field")
        field.tap()
        field.typeText("Utrecht")
        element("ns.stationSearch.submit").tap()
        let station = element("ns.station.UT")
        try require(station, "the Utrecht Centraal result")
        station.tap()
        try require(element("ns.departures.screen"), "the departures screen")
        try require(element("ns.departure.fixture-sprinter-7400"), "the Sprinter 7400 departure")
        try audit("ns-departures")
    }

    func testHistoryTab() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["History"].tap()
        try require(app.navigationBars["History"], "the History navigation bar")
        try audit("history")
    }

    func testSettingsTab() throws {
        defer { app.terminate() }
        launch("fixture")
        app.tabBars.buttons["Settings"].tap()
        try require(app.navigationBars["Settings"], "the Settings navigation bar")
        try audit("settings")
    }

    func testOnboarding() throws {
        defer { app.terminate() }
        launch("onboarding")
        try require(element("onboarding.screen"), "the onboarding screen")
        try audit("onboarding")
    }

    func testTripDetail() throws {
        defer { app.terminate() }
        launch("fixture")
        try openTripDetail()
        try audit("trip-detail")
    }

    func testRailMapExposesLabelledStopsAndControls() throws {
        defer { app.terminate() }
        launch("fixture")
        try openTripDetail()
        let mapLink = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Open rail map'"))
            .firstMatch
        try scrollTo(mapLink, "the Open rail map card")
        mapLink.tap()
        try require(app.navigationBars["Rail map"], "the Rail map navigation bar")
        continueAfterFailure = true
        dumpLabelledElements("rail map")
        try audit("rail-map")
    }

    // DISCOVERY ONLY: remove with the first baseline commit.
    private func dumpLabelledElements(_ title: String) {
        let lines = app.debugDescription.split(separator: "\n").filter {
            $0.contains("label:") || $0.contains("identifier:")
        }
        var chunk = ""
        var index = 1
        for line in lines {
            if chunk.count + line.count > 7000 {
                XCTFail("DISCOVERY \(title) \(index)\n\(chunk)")
                chunk = ""
                index += 1
                if index > 3 { return }
            }
            chunk += String(line) + "\n"
        }
        XCTFail("DISCOVERY \(title) \(index)\n\(chunk)")
    }

    // MARK: - Audit

    private func audit(_ screen: String) throws {
        settle()
        let findings = AuditFindings()
        try app.performAccessibilityAudit(for: .all) { issue in
            let key = auditFindingKey(screen: screen, issue: issue)
            findings.reproduced.insert(key)
            if !knownAccessibilityIssues.contains(key) {
                findings.unknown.append("\(key)\n        \(issue.compactDescription)")
            }
            return true
        }

        let unknown = findings.unknown
        let stale = knownAccessibilityIssues
            .filter { $0.hasPrefix("\(screen) | ") && !findings.reproduced.contains($0) }
            .sorted()
        if !stale.isEmpty {
            let attachment = XCTAttachment(string: "Remove from knownAccessibilityIssues:\n" + stale.joined(separator: "\n"))
            attachment.name = "Fixed accessibility findings"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if !unknown.isEmpty {
            XCTFail(
                "The accessibility audit found \(unknown.count) finding(s) on \(screen) that are not in knownAccessibilityIssues:\n"
                    + unknown.sorted().map { "    " + $0 }.joined(separator: "\n")
            )
        }
    }

    // MARK: - Navigation

    private func launch(_ scenario: String) {
        continueAfterFailure = false
        app.launchArguments = ["--trainy-automation", scenario]
        app.launchEnvironment = [
            "ODPT_CONSUMER_KEY": "",
            "TRAINY_PROVIDER_PROXY_BASE_URL": ""
        ]
        app.launch()
    }

    private func openNSStationSearch() throws {
        let stationsTab = app.tabBars.buttons["Stations"]
        try require(stationsTab, "the Stations tab")
        stationsTab.tap()
        let link = element("stations.nsDepartures")
        try scrollTo(link, "the NS departures link")
        link.tap()
        try require(element("ns.stationSearch.screen"), "the NS station search screen")
    }

    private func openTripDetail() throws {
        let trip = app.staticTexts["Nozomi 231"]
        try require(trip, "the tracked Nozomi 231 trip")
        trip.tap()
        try require(app.navigationBars["Nozomi 231"], "the Nozomi 231 detail screen")
    }

    private func require(_ element: XCUIElement, _ name: String, timeout: TimeInterval = 5) throws {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("Expected \(name) to exist. Visible hierarchy:\n\(String(app.debugDescription.prefix(6000)))")
            throw AuditStop()
        }
    }

    private func scrollTo(_ element: XCUIElement, _ name: String, attempts: Int = 12) throws {
        for _ in 0..<attempts where !element.exists || !element.isHittable {
            app.swipeUp()
        }
        guard element.exists, element.isHittable else {
            XCTFail("Expected \(name) to become hittable after scrolling. Visible hierarchy:\n\(String(app.debugDescription.prefix(6000)))")
            throw AuditStop()
        }
    }

    private func settle() {
        // Let transitions and list animations finish so the audit sees the final layout.
        RunLoop.current.run(until: Date().addingTimeInterval(1))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
