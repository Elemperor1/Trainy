import SwiftUI
import UIKit
import XCTest
@testable import TrainyCore

@MainActor
final class RailDesignSystemTests: XCTestCase {
    /// Resolved red, green, blue, and alpha components for one interface style.
    private struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    /// Resolves a SwiftUI color to RGB components under a specific appearance.
    private func resolvedRGBA(
        _ color: Color,
        style: UIUserInterfaceStyle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> RGBA {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
            "Expected an RGB-compatible design token",
            file: file,
            line: line
        )
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Asserts two dynamic colors resolve equally under the selected appearance.
    private func assertColorsEqual(
        _ lhs: Color,
        _ rhs: Color,
        style: UIUserInterfaceStyle = .light,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lhsRGBA = resolvedRGBA(lhs, style: style, file: file, line: line)
        let rhsRGBA = resolvedRGBA(rhs, style: style, file: file, line: line)
        XCTAssertEqual(lhsRGBA.red, rhsRGBA.red, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhsRGBA.green, rhsRGBA.green, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhsRGBA.blue, rhsRGBA.blue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhsRGBA.alpha, rhsRGBA.alpha, accuracy: 0.001, file: file, line: line)
    }

    /// Calculates WCAG relative luminance for resolved RGB components.
    private func relativeLuminance(_ color: RGBA) -> CGFloat {
        /// Linearizes one sRGB component for luminance calculation.
        func linearized(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearized(color.red))
            + (0.7152 * linearized(color.green))
            + (0.0722 * linearized(color.blue))
    }

    /// Calculates the WCAG contrast ratio between two resolved colors.
    private func contrastRatio(_ lhs: RGBA, _ rhs: RGBA) -> CGFloat {
        let lighter = max(relativeLuminance(lhs), relativeLuminance(rhs))
        let darker = min(relativeLuminance(lhs), relativeLuminance(rhs))
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: - Token scales

    /// Verifies spacing tokens follow the documented four-point grid.
    func testSpacingScaleUsesDocumentedFourPointGrid() {
        let values: [CGFloat] = [
            RailDesign.Spacing.xxs,
            RailDesign.Spacing.xs,
            RailDesign.Spacing.s,
            RailDesign.Spacing.m,
            RailDesign.Spacing.l,
            RailDesign.Spacing.xl,
            RailDesign.Spacing.xxl,
            RailDesign.Spacing.hero
        ]

        XCTAssertEqual(values, [4, 8, 12, 16, 24, 32, 48, 64])
        XCTAssertTrue(zip(values, values.dropFirst()).allSatisfy(<))
        XCTAssertTrue(values.allSatisfy { $0.truncatingRemainder(dividingBy: 4) == 0 })
    }

    /// Verifies radius tokens preserve their documented semantic ordering.
    func testRadiusScalePreservesSemanticContracts() {
        XCTAssertEqual(RailDesign.Radius.xs, 8)
        XCTAssertEqual(RailDesign.Radius.sm, 12)
        XCTAssertEqual(RailDesign.Radius.chip, 13)
        XCTAssertEqual(RailDesign.Radius.control, 16)
        XCTAssertEqual(RailDesign.Radius.card, RailDesign.Radius.control)
        XCTAssertEqual(RailDesign.Radius.panel, 24)
        XCTAssertEqual(RailDesign.Radius.hero, 32)
        XCTAssertEqual(RailDesign.Radius.pill, 999)
        XCTAssertEqual(RailDesign.Radius.station, RailDesign.Radius.sm)

        let structuralScale = [
            RailDesign.Radius.xs,
            RailDesign.Radius.sm,
            RailDesign.Radius.control,
            RailDesign.Radius.panel,
            RailDesign.Radius.hero,
            RailDesign.Radius.pill
        ]
        XCTAssertTrue(zip(structuralScale, structuralScale.dropFirst()).allSatisfy(<))
        XCTAssertTrue(RailDesign.Radius.chip > RailDesign.Radius.sm)
        XCTAssertTrue(RailDesign.Radius.chip < RailDesign.Radius.control)
    }

    /// Verifies elevation presets increase predictably without invalid opacity.
    func testElevationPresetsIncreasePredictably() {
        let presets = [
            RailDesign.Elevation.resting,
            RailDesign.Elevation.raised,
            RailDesign.Elevation.hero
        ]

        XCTAssertEqual(presets.map(\.radius), [18, 26, 34])
        XCTAssertEqual(presets.map(\.y), [9, 14, 18])
        XCTAssertEqual(presets.map(\.opacity), [0.10, 0.16, 0.22])
        XCTAssertTrue(zip(presets, presets.dropFirst()).allSatisfy { $0.radius < $1.radius })
        XCTAssertTrue(zip(presets, presets.dropFirst()).allSatisfy { $0.y < $1.y })
        XCTAssertTrue(zip(presets, presets.dropFirst()).allSatisfy { $0.opacity < $1.opacity })
        XCTAssertTrue(presets.allSatisfy { (0 ... 1).contains($0.opacity) })
    }

    /// Verifies the canonical typography scale and compatibility aliases compile.
    func testTypographyScaleAndCompatibilityAliasesRemainAvailable() {
        _ = RailDesign.Typography.display
        _ = RailDesign.Typography.h1
        _ = RailDesign.Typography.h2
        _ = RailDesign.Typography.h3
        _ = RailDesign.Typography.body
        _ = RailDesign.Typography.small
        _ = RailDesign.Typography.caption

        _ = RailDesign.Typography.largeTitle
        _ = RailDesign.Typography.title
        _ = RailDesign.Typography.metricValue
        _ = RailDesign.Typography.routeTitle
        _ = RailDesign.Typography.headline
        _ = RailDesign.Typography.callout
        _ = RailDesign.Typography.compactLabel
        _ = RailDesign.Typography.micro
    }

    // MARK: - Palette contracts

    /// Verifies the semantic status palette is complete, distinct, and adaptive.
    func testSemanticPaletteRolesAreDistinctAndAdaptive() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let roles = [
                resolvedRGBA(RailDesign.Palette.success, style: style),
                resolvedRGBA(RailDesign.Palette.warning, style: style),
                resolvedRGBA(RailDesign.Palette.danger, style: style),
                resolvedRGBA(RailDesign.Palette.info, style: style)
            ]
            XCTAssertEqual(Set(roles.map { "\($0.red)-\($0.green)-\($0.blue)" }).count, 4)
        }

        XCTAssertNotEqual(
            resolvedRGBA(RailDesign.Palette.success, style: .light).green,
            resolvedRGBA(RailDesign.Palette.success, style: .dark).green
        )
        XCTAssertEqual(resolvedRGBA(RailDesign.Palette.successSoft, style: .light).alpha, 0.12, accuracy: 0.001)
        XCTAssertEqual(resolvedRGBA(RailDesign.Palette.warningSoft, style: .light).alpha, 0.12, accuracy: 0.001)
        XCTAssertEqual(resolvedRGBA(RailDesign.Palette.dangerSoft, style: .light).alpha, 0.12, accuracy: 0.001)
        XCTAssertEqual(resolvedRGBA(RailDesign.Palette.infoSoft, style: .light).alpha, 0.12, accuracy: 0.001)
    }

    /// Verifies primary and secondary text meet contrast targets in both appearances.
    func testTextTokensMaintainReadableCanvasContrastInLightAndDarkModes() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let background = resolvedRGBA(RailDesign.Palette.background, style: style)
            let ink = resolvedRGBA(RailDesign.Palette.ink, style: style)
            let secondary = resolvedRGBA(RailDesign.Palette.secondaryText, style: style)

            XCTAssertGreaterThanOrEqual(
                contrastRatio(ink, background),
                7,
                "Primary text should retain enhanced contrast in \(style)"
            )
            XCTAssertGreaterThanOrEqual(
                contrastRatio(secondary, background),
                4.5,
                "Secondary text should retain normal-text contrast in \(style)"
            )
        }
    }

    // MARK: - Component and semantic display contracts

    /// Verifies both source-badge styles retain the compact height contract.
    func testSourceBadgeStylesKeepAStableCompactHeight() {
        XCTAssertEqual(SourceBadge.Style.compact.height, 30)
        XCTAssertEqual(SourceBadge.Style.regular.height, 30)
    }

    /// Verifies every service status has distinct assets and the expected tint.
    func testEveryServiceStatusHasUniqueDisplayAssetsAndExpectedTint() {
        XCTAssertEqual(RailServiceStatus.allCases.count, 7)
        XCTAssertEqual(Set(RailServiceStatus.allCases.map(\.symbolName)).count, 7)
        XCTAssertEqual(Set(RailServiceStatus.allCases.map(\.accessibilityTitle)).count, 7)
        XCTAssertTrue(RailServiceStatus.allCases.allSatisfy { !$0.symbolName.isEmpty })
        XCTAssertTrue(RailServiceStatus.allCases.allSatisfy { !$0.accessibilityTitle.isEmpty })

        let expectedTints: [(RailServiceStatus, Color)] = [
            (.onTime, RailDesign.Palette.success),
            (.boarding, RailDesign.Palette.success),
            (.arrived, RailDesign.Palette.success),
            (.delayed, RailDesign.Palette.warning),
            (.platformChanged, RailDesign.Palette.warning),
            (.canceled, RailDesign.Palette.danger),
            (.disruption, RailDesign.Palette.danger)
        ]
        for (status, expectedTint) in expectedTints {
            assertColorsEqual(status.tint, expectedTint)
            XCTAssertEqual(resolvedRGBA(status.glassTint, style: .light).alpha, 0.16, accuracy: 0.001)
        }
    }

    /// Verifies interface preferences expose one stable default contract.
    func testInterfacePreferencesHaveOnePredictableDefaultContract() {
        XCTAssertEqual(RailInterfacePreferences.defaults.timeFormat, .hour12)
        XCTAssertEqual(RailInterfacePreferences.defaults.unitSystem, .metric)
        XCTAssertEqual(RailInterfacePreferences.defaults.sourceLabelVerbosity, .compact)
        XCTAssertFalse(RailInterfacePreferences.defaults.diagnosticsConsent)
        XCTAssertTrue(RailInterfacePreferences.defaults.usesMetricUnits)

        var preferences = RailInterfacePreferences.defaults
        preferences.unitSystem = .imperial
        preferences.diagnosticsConsent = true
        XCTAssertFalse(preferences.usesMetricUnits)
        XCTAssertTrue(preferences.diagnosticsConsent)
    }

    /// Verifies rail time formatting honors an explicit clock preference.
    func testTimeFormattingRequiresAnExplicitPreference() {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        XCTAssertEqual("13:05".formattedAsTime(in: tokyo, format: .hour24), "13:05")
        XCTAssertEqual("not-a-time".formattedAsTime(in: tokyo, format: .hour24), "not-a-time")
    }

    // MARK: - RailServiceStatus.from(trip) mapping

    private func makeStatusTrip(
        status: String,
        tone: TrainStatusTone,
        progress: Double,
        alerts: [TrainAlert] = []
    ) -> TrainTrip {
        let sample = TrainTrip.samples[0]
        return TrainTrip(
            id: "status-test",
            providerID: sample.providerID,
            routeID: sample.routeID,
            liveTripID: sample.liveTripID,
            train: sample.train,
            operatorName: sample.operatorName,
            service: sample.service,
            origin: sample.origin,
            destination: sample.destination,
            duration: sample.duration,
            status: status,
            statusTone: tone,
            category: sample.category,
            platform: sample.platform,
            nextStop: sample.nextStop,
            eta: sample.eta,
            speed: sample.speed,
            progress: progress,
            bestCar: sample.bestCar,
            cars: sample.cars,
            seat: sample.seat,
            updated: sample.updated,
            callout: sample.callout,
            signal: sample.signal,
            signalCopy: sample.signalCopy,
            stops: sample.stops,
            alerts: alerts,
            pulse: sample.pulse,
            vehicleLatitude: sample.vehicleLatitude,
            vehicleLongitude: sample.vehicleLongitude,
            distanceText: sample.distanceText,
            dataSource: sample.dataSource,
            sourceProvenance: sample.sourceProvenance,
            factProvenance: sample.factProvenance
        )
    }

    /// Verifies trip facts map to every semantic service state.
    func testStatusMappingCoversEachSemanticState() {
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "On time", tone: .good, progress: 0.3)),
            .onTime
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "Running", tone: .late, progress: 0.3)),
            .delayed
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "Canceled", tone: .late, progress: 0)),
            .canceled
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "On time", tone: .good, progress: 0.99)),
            .arrived
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "Platform change", tone: .good, progress: 0)),
            .platformChanged
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "Boarding open", tone: .good, progress: 0)),
            .boarding
        )
        XCTAssertEqual(
            RailServiceStatus.from(makeStatusTrip(status: "On time", tone: .watch, progress: 0.3)),
            .disruption
        )
    }

    /// Verifies alert text can identify a platform-change service state.
    func testStatusMappingUsesAlertTextForPlatformChanges() {
        let trip = makeStatusTrip(
            status: "On time",
            tone: .good,
            progress: 0.3,
            alerts: [TrainAlert(title: "Notice", detail: "Platform changed to 14", tone: .watch)]
        )
        XCTAssertEqual(RailServiceStatus.from(trip), .platformChanged)
    }

    /// Verifies train tones route exclusively through semantic palette roles.
    func testTrainStatusToneRoutesThroughSemanticPaletteRoles() {
        let expectedTints: [(TrainStatusTone, Color)] = [
            (.good, RailDesign.Palette.success),
            (.watch, RailDesign.Palette.warning),
            (.late, RailDesign.Palette.danger)
        ]

        for (tone, expectedTint) in expectedTints {
            assertColorsEqual(tone.tint, expectedTint)
            XCTAssertEqual(resolvedRGBA(tone.softFill, style: .light).alpha, 0.14, accuracy: 0.001)
        }
    }
}
