import XCTest

private final class AuditFindings: @unchecked Sendable {
    var unknown: [(key: String, detail: String)] = []
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

private func elementTypeName(_ type: XCUIElement.ElementType) -> String {
    switch type {
    case .other: return "Other"
    case .image: return "Image"
    case .staticText: return "StaticText"
    case .button: return "Button"
    case .cell: return "Cell"
    case .map: return "Map"
    case .scrollView: return "ScrollView"
    case .statusBar: return "StatusBar"
    case .tabBar: return "TabBar"
    case .navigationBar: return "NavigationBar"
    case .progressIndicator: return "ProgressIndicator"
    case .activityIndicator: return "ActivityIndicator"
    case .window: return "Window"
    case .group: return "Group"
    default: return "Type\(type.rawValue)"
    }
}

@MainActor
private func auditFindingKey(screen: String, issue: XCUIAccessibilityAuditIssue) -> String {
    let auditType = auditTypeName(issue.auditType)
    guard let element = issue.element else { return "\(screen) | \(auditType) | (no element)" }
    let name = findingName(identifier: element.identifier, label: element.label, type: element.elementType)
    return "\(screen) | \(auditType) | \(name)"
}

/// What the audit said, and which element it said it about, for a finding that
/// is not in the baseline.
@MainActor
private func auditFindingDetail(_ issue: XCUIAccessibilityAuditIssue) -> String {
    guard let element = issue.element else { return "\(issue.compactDescription) (the audit named no element)" }
    let excerpt = String(element.debugDescription.prefix(800))
    return "\(issue.compactDescription): \(elementTypeName(element.elementType)) at \(element.frame)\n        \(excerpt)"
}

/// An identifier names an element as it is. A label can carry counts, clock
/// times, dates, and ages that change between runs, so those are masked to keep
/// one element on one key. An element with neither is named by its type.
private func findingName(identifier: String, label: String, type: XCUIElement.ElementType) -> String {
    if !identifier.isEmpty { return identifier }
    var name = label.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    for mask in volatileLabelMasks {
        name = name.replacingOccurrences(of: mask.pattern, with: mask.replacement, options: .regularExpression)
    }
    return name.isEmpty ? "(unnamed \(elementTypeName(type)))" : String(name.prefix(80))
}

private let volatileLabelMasks: [(pattern: String, replacement: String)] = [
    (#"[0-9]+"#, "#"),
    (#"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?(?= #)"#, "<month>"),
    (#"\b[AP]M\b"#, "<am/pm>"),
    (#"\bupdated (?:now|#s ago|#m ago)"#, "updated <age>")
]

/// Runs Apple's automated accessibility audit on the screens riders reach first.
///
/// The audit reports contrast, hit-target, clipped-text, Dynamic Type, trait,
/// and missing-description problems. Findings that already exist are listed in
/// `knownAccessibilityIssues` (TrainyAccessibilityAuditBaseline.swift), so the
/// suite fails on anything new while the old ones are fixed. Delete an entry
/// when its screen is fixed. An attachment on each test lists entries the audit
/// no longer reproduces, and another lists findings only one of two audits saw.
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
        try requireSettledSearchResults()
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
        // The provider health row reads "Configured" or "Checking" until the fixture answers.
        try require(label("Healthy"), "the loaded provider health")
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
        let mapButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH 'Open rail map'"))
            .firstMatch
        try scrollTo(mapButton, "the Open rail map button on the active trip")
        mapButton.tap()
        try require(app.navigationBars["Rail map"], "the Rail map navigation bar")

        // VoiceOver reaches each stop by name, platform, and where the train is.
        let stopPins = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", ".+, platform .+, .+"))
        try require(stopPins.firstMatch, "labelled stop pins on the map", timeout: 10)
        XCTAssertGreaterThanOrEqual(stopPins.count, 2, "Expected the origin and destination stops to be labelled on the map")

        try require(app.buttons["Center map"], "the Center map button")

        // The starter catalog has no vehicle-position feed, so the marker must call
        // itself a route marker and nothing may present it as a vehicle position.
        let routeMarker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Route marker'"))
            .firstMatch
        try require(routeMarker, "the route marker")
        let vehiclePosition = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Vehicle position'"))
            .firstMatch
        XCTAssertFalse(vehiclePosition.exists, "A schedule-only trip must not present its map marker as a vehicle position")

        try audit("rail-map")
    }

    // MARK: - Audit

    /// A finding that is not in the baseline fails the test only if a second
    /// audit, a few seconds later, reports it again. A view caught mid-update
    /// (an animation, a load that finished late) can show a contrast problem for
    /// a moment that the next look no longer sees.
    private func audit(_ screen: String) throws {
        settle()
        let first = try runAudit(screen)
        var reproduced = first.reproduced
        var unknown = first.unknown
        var transient: [(key: String, detail: String)] = []

        if !first.unknown.isEmpty {
            settle(3)
            let second = try runAudit(screen)
            reproduced.formUnion(second.reproduced)
            let firstKeys = Set(first.unknown.map { $0.key })
            let secondKeys = Set(second.unknown.map { $0.key })
            unknown = second.unknown.filter { firstKeys.contains($0.key) }
            transient = first.unknown.filter { !secondKeys.contains($0.key) }
                + second.unknown.filter { !firstKeys.contains($0.key) }
        }

        let stale = knownAccessibilityIssues
            .filter { $0.hasPrefix("\(screen) | ") && !reproduced.contains($0) }
            .sorted()
        if !stale.isEmpty {
            attach("Fixed accessibility findings", "Remove from knownAccessibilityIssues:\n" + stale.joined(separator: "\n"))
        }
        if !transient.isEmpty {
            let lines = transient.map { "\($0.key)\n    \($0.detail)" }.joined(separator: "\n")
            attach("Accessibility findings seen once", "Reported by one audit of \(screen) and not by the other:\n" + lines)
        }
        if !unknown.isEmpty {
            let lines = unknown
                .sorted { $0.key < $1.key }
                .map { "    \($0.key)\n        \($0.detail)" }
                .joined(separator: "\n")
            XCTFail(
                "Two audits found \(unknown.count) finding(s) on \(screen) that are not in knownAccessibilityIssues:\n" + lines
            )
        }
    }

    private func runAudit(_ screen: String) throws -> AuditFindings {
        let findings = AuditFindings()
        try app.performAccessibilityAudit(for: .all) { issue in
            let key = auditFindingKey(screen: screen, issue: issue)
            findings.reproduced.insert(key)
            if !knownAccessibilityIssues.contains(key) {
                findings.unknown.append((key: key, detail: auditFindingDetail(issue)))
            }
            return true
        }
        return findings
    }

    private func attach(_ name: String, _ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    /// The active trip's card opens the rail map, not the trip. The rows under
    /// "More active journeys" open trip details.
    private func openTripDetail() throws {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Hayabusa 17'"))
            .firstMatch
        try scrollTo(row, "the Hayabusa 17 row")
        row.tap()
        try require(app.navigationBars["Hayabusa 17"], "the Hayabusa 17 detail screen")
    }

    /// The field searches each prefix while a test types, and the list keeps the
    /// rows of the last finished search until the finished query's results
    /// replace them. Only the trip that matches the whole route belongs on the
    /// screen the audit sees, so wait until it is listed alone and stays that way.
    private func requireSettledSearchResults() throws {
        let rows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'search.result.'"))
        let strays = rows.matching(NSPredicate(format: "identifier != 'search.result.nozomi-231'"))
        var steadyChecks = 0
        let deadline = Date().addingTimeInterval(20)
        while steadyChecks < 3 && Date() < deadline {
            let listedAlone = rows.count > 0 && strays.count == 0
            steadyChecks = listedAlone ? steadyChecks + 1 : 0
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        guard steadyChecks >= 3 else {
            XCTFail("Expected the search results to narrow to the Nozomi 231 trip. Visible hierarchy:\n\(String(app.debugDescription.prefix(6000)))")
            throw AuditStop()
        }
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

    private func settle(_ seconds: TimeInterval = 1) {
        // Let transitions and list animations finish so the audit sees the final layout.
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func label(_ text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", text))
            .firstMatch
    }
}
