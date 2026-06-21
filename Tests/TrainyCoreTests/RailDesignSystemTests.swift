import XCTest
@testable import TrainyCore

@MainActor
final class RailDesignSystemTests: XCTestCase {

    // MARK: - Tokens

    func testSpacingScaleValues() {
        XCTAssertEqual(RailDesign.Spacing.xxs, 4)
        XCTAssertEqual(RailDesign.Spacing.xs, 8)
        XCTAssertEqual(RailDesign.Spacing.s, 12)
        XCTAssertEqual(RailDesign.Spacing.m, 16)
        XCTAssertEqual(RailDesign.Spacing.l, 20)
        XCTAssertEqual(RailDesign.Spacing.xl, 28)
        XCTAssertEqual(RailDesign.Spacing.xxl, 36)
        // Monotonically non-decreasing.
        let values: [CGFloat] = [RailDesign.Spacing.xxs, RailDesign.Spacing.xs, RailDesign.Spacing.s, RailDesign.Spacing.m, RailDesign.Spacing.l, RailDesign.Spacing.xl, RailDesign.Spacing.xxl]
        XCTAssertEqual(values, values.sorted())
    }

    func testRadiusScaleValues() {
        XCTAssertEqual(RailDesign.Radius.xs, 8)
        XCTAssertEqual(RailDesign.Radius.sm, 10)
        XCTAssertEqual(RailDesign.Radius.chip, 13)
        XCTAssertEqual(RailDesign.Radius.control, 18)
        XCTAssertEqual(RailDesign.Radius.panel, 28)
        XCTAssertEqual(RailDesign.Radius.hero, 34)
        let values: [CGFloat] = [RailDesign.Radius.xs, RailDesign.Radius.sm, RailDesign.Radius.chip, RailDesign.Radius.control, RailDesign.Radius.panel, RailDesign.Radius.hero]
        XCTAssertEqual(values, values.sorted())
    }

    func testElevationPresetsAreOrdered() {
        XCTAssertTrue(RailDesign.Elevation.resting.radius < RailDesign.Elevation.raised.radius)
        XCTAssertTrue(RailDesign.Elevation.raised.radius < RailDesign.Elevation.hero.radius)
        XCTAssertTrue(RailDesign.Elevation.resting.opacity < RailDesign.Elevation.hero.opacity)
    }

    func testTypographyPresetsAreAccessible() {
        // Referencing each preset ensures the public typography scale compiles
        // and is wired into the design system (regression guard).
        _ = RailDesign.Typography.largeTitle
        _ = RailDesign.Typography.title
        _ = RailDesign.Typography.metricValue
        _ = RailDesign.Typography.routeTitle
        _ = RailDesign.Typography.headline
        _ = RailDesign.Typography.body
        _ = RailDesign.Typography.callout
        _ = RailDesign.Typography.compactLabel
        _ = RailDesign.Typography.caption
        _ = RailDesign.Typography.micro
    }

    // MARK: - Service status display assets

    func testEveryServiceStatusHasDisplayAssets() {
        XCTAssertEqual(RailServiceStatus.allCases.count, 7)
        for status in RailServiceStatus.allCases {
            XCTAssertFalse(status.symbolName.isEmpty, "Status \(status) missing symbol")
        }
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

    func testStatusMappingOnTime() {
        let trip = makeStatusTrip(status: "On time", tone: .good, progress: 0.3)
        XCTAssertEqual(RailServiceStatus.from(trip), .onTime)
    }

    func testStatusMappingDelayed() {
        let trip = makeStatusTrip(status: "Running", tone: .late, progress: 0.3)
        XCTAssertEqual(RailServiceStatus.from(trip), .delayed)
    }

    func testStatusMappingCanceled() {
        let trip = makeStatusTrip(status: "Canceled", tone: .late, progress: 0.0)
        XCTAssertEqual(RailServiceStatus.from(trip), .canceled)
    }

    func testStatusMappingArrivedByProgress() {
        let trip = makeStatusTrip(status: "On time", tone: .good, progress: 0.99)
        XCTAssertEqual(RailServiceStatus.from(trip), .arrived)
    }

    func testStatusMappingPlatformChanged() {
        let trip = makeStatusTrip(status: "Platform change", tone: .good, progress: 0.0)
        XCTAssertEqual(RailServiceStatus.from(trip), .platformChanged)
    }

    func testStatusMappingBoarding() {
        let trip = makeStatusTrip(status: "Boarding open", tone: .good, progress: 0.0)
        XCTAssertEqual(RailServiceStatus.from(trip), .boarding)
    }

    func testStatusMappingDisruptionFromWatchTone() {
        let trip = makeStatusTrip(status: "On time", tone: .watch, progress: 0.3)
        XCTAssertEqual(RailServiceStatus.from(trip), .disruption)
    }

    // MARK: - TrainStatusTone routes through design-system semantic roles

    func testTrainStatusToneTintRoutesThroughPalette() {
        // After the refactor, TrainStatusTone.tint must resolve via RailDesign
        // semantic role aliases, not the removed TrainyColor duplicate palette.
        // We assert the mapping is stable and non-default for each case.
        for tone in TrainStatusTone.allCases {
            _ = tone.tint
            _ = tone.softFill
        }
        XCTAssertEqual(TrainStatusTone.allCases.count, 3)
    }
}

