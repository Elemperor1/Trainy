import MapKit
import SwiftUI

struct RailJourneyMapPanel: View {
    enum Style {
        case detail
        case full

        var height: CGFloat {
            switch self {
            case .detail:
                return 450
            case .full:
                return 610
            }
        }

        var stopRailBottomInset: CGFloat {
            switch self {
            case .detail:
                return 44
            case .full:
                return 68
            }
        }

        var mapCornerRadius: CGFloat {
            switch self {
            case .detail:
                return RailDesign.Radius.hero - 6
            case .full:
                return RailDesign.Radius.hero - 8
            }
        }

        var mapAttributionInset: CGFloat {
            switch self {
            case .detail:
                return 12
            case .full:
                return 18
            }
        }
    }

    let trip: TrainTrip
    let style: Style

    @State private var mapMode: RailMapMode = .all  // kept for future re-introduction
    @State private var cameraPosition: MapCameraPosition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var model: RailMapModel {
        RailMapModel(trip: trip)
    }

    init(trip: TrainTrip, style: Style = .detail) {
        self.trip = trip
        self.style = style
        _cameraPosition = State(initialValue: .region(RailMapModel(trip: trip).region))
    }

    var body: some View {
        let model = model

        GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.onAccent.opacity(0.06), padding: 0) {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition, interactionModes: .all) {
                    MapPolyline(coordinates: model.routeCoordinates)
                        .stroke(RailDesign.Palette.onAccent.opacity(0.90), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))

                    MapPolyline(coordinates: model.upcomingCoordinates)
                        .stroke(RailDesign.Palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round, dash: [11, 8]))

                    MapPolyline(coordinates: model.upcomingCoordinates)
                        .stroke(RailDesign.Palette.accent.opacity(0.84), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round, dash: [11, 8]))

                    MapPolyline(coordinates: model.completedCoordinates)
                        .stroke(RailDesign.Palette.ink.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

                    MapPolyline(coordinates: model.completedCoordinates)
                        .stroke(model.completedRouteTint, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

                    ForEach(model.stops) { stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            RailMapStationPin(stop: stop, isNext: stop.id == model.nextStop?.id, showsLabel: true)
                        }
                    }

                    ForEach(model.disruptionStops) { stop in
                        Annotation("Service marker", coordinate: stop.coordinate) {
                            RailMapDisruptionMarker(status: model.status)
                        }
                    }

                    if let positionCoordinate = model.positionCoordinate {
                        Annotation("", coordinate: positionCoordinate) {
                            RailMapPositionPin(state: model.positionState, status: model.status)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: style.mapAttributionInset)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: style.mapCornerRadius, style: .continuous))
                .frame(height: style.height)
                .overlay(
                    RoundedRectangle(cornerRadius: style.mapCornerRadius, style: .continuous)
                        .stroke(RailDesign.Palette.hairline.opacity(0.7), lineWidth: 1)
                )

                VStack(spacing: RailDesign.Spacing.s) {
                    HStack(alignment: .top) {
                        RailMapStatusOverlay(model: model)
                        Spacer(minLength: RailDesign.Spacing.s)
                        RailMapControls(
                            recenter: {
                                if reduceMotion {
                                    cameraPosition = .region(model.region)
                                } else {
                                    withAnimation(RailDesign.Motion.soft) {
                                        cameraPosition = .region(model.region)
                                    }
                                }
                            }
                        )
                    }

                    Spacer(minLength: 0)

                    RailMapStopRail(
                        title: mapMode.title,
                        stops: model.upcomingStops,
                        status: model.status
                    )
                }
                .padding(RailDesign.Spacing.m)
                .padding(.bottom, style.stopRailBottomInset)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct RailJourneyMapScreen: View {
    let trip: TrainTrip

    private var model: RailMapModel {
        RailMapModel(trip: trip)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                RailJourneyMapPanel(trip: trip, style: .full)

                RailMapSectionHeader(
                    title: "Route intelligence",
                    subtitle: "Operational signals for the next part of this journey."
                )

                LazyVStack(spacing: RailDesign.Spacing.s) {
                    ForEach(model.insights) { insight in
                        RailMapInsightCard(insight: insight)
                    }

                    ForEach(model.stops) { stop in
                        RailMapStopDetailCard(stop: stop, isNext: stop.id == model.nextStop?.id, status: model.status)
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Rail map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .railScreenChrome()
    }
}

private enum RailMapMode: String, CaseIterable, Identifiable {
    case all

    var id: String { rawValue }

    var title: LocalizedStringKey {
        return "Route focus"
    }

    var symbolName: String { "train.side.front.car" }

    var controlTitle: LocalizedStringKey {
        return "Route"
    }

    var accessibilityTitle: LocalizedStringKey {
        return "Route focus"
    }

    var contextTitle: String {
        return "Show route, upcoming stops, and any disruption pins."
    }
}

private struct RailMapModel {
    let trip: TrainTrip
    let stops: [RailMapStop]
    let routeCoordinates: [CLLocationCoordinate2D]
    let trainCoordinate: CLLocationCoordinate2D
    let positionCoordinate: CLLocationCoordinate2D?
    let positionState: RailVehiclePositionDisplayState
    let status: RailServiceStatus

    init(trip: TrainTrip) {
        self.trip = trip
        self.status = RailServiceStatus.from(trip)
        self.stops = Self.makeStops(for: trip)
        self.routeCoordinates = Self.curvedRouteCoordinates(from: stops.map(\.coordinate))
        self.trainCoordinate = Self.coordinate(at: trip.progress, in: routeCoordinates)
        let resolvedPositionState = trip.vehiclePositionDisplayState
        self.positionState = resolvedPositionState
        switch resolvedPositionState.kind {
        case .liveVehicle:
            self.positionCoordinate = trip.vehicleMapCoordinate ?? trainCoordinate
        case .routeMarker:
            self.positionCoordinate = trainCoordinate
        case .unavailable:
            self.positionCoordinate = nil
        }
    }

    var completedCoordinates: [CLLocationCoordinate2D] {
        guard !routeCoordinates.isEmpty else { return [trainCoordinate] }
        let progressIndex = max(0, min(routeCoordinates.count - 1, Int(Double(routeCoordinates.count - 1) * trip.progress)))
        return Array(routeCoordinates.prefix(progressIndex + 1)) + [trainCoordinate]
    }

    var completedRouteTint: Color {
        status == .onTime || status == .boarding || status == .arrived
            ? RailDesign.Palette.accent.opacity(0.98)
            : status.tint.opacity(0.98)
    }

    var upcomingCoordinates: [CLLocationCoordinate2D] {
        guard !routeCoordinates.isEmpty else { return [trainCoordinate] }
        let progressIndex = max(0, min(routeCoordinates.count - 1, Int(Double(routeCoordinates.count - 1) * trip.progress)))
        let upcoming = routeCoordinates.suffix(from: min(progressIndex + 1, routeCoordinates.count))
        return [trainCoordinate] + Array(upcoming)
    }

    var nextStop: RailMapStop? {
        stops.first { $0.name == trip.nextStop } ?? stops.first { $0.state == .current } ?? upcomingStops.first
    }

    var upcomingStops: [RailMapStop] {
        Array(stops.filter { $0.state != .done }.prefix(4))
    }

    var disruptionStops: [RailMapStop] {
        guard status != .onTime && status != .boarding && status != .arrived else { return [] }
        return Array((stops.filter(\.isTransferPoint) + [nextStop].compactMap { $0 }).prefix(3))
    }

    var disruptionAwareStops: [RailMapStop] {
        let marked = disruptionStops
        return marked.isEmpty ? upcomingStops : marked
    }

    var insights: [RailMapInsight] {
        var items: [RailMapInsight] = []

        items.append(
            RailMapInsight(
                title: trip.vehiclePositionDisplayState.title,
                detail: trip.vehiclePositionDisplayState.detailText,
                symbolName: trip.vehiclePositionDisplayState.symbolName,
                tint: trip.vehiclePositionDisplayState.isLiveVehiclePosition ? RailDesign.Palette.info : RailDesign.Palette.accent
            )
        )

        if let nextStop {
            let platform = nextStop.platformDisplayState
            items.append(
                RailMapInsight(
                    title: platform.isKnown ? "Platform \(platform.displayText) at \(nextStop.name)" : "Platform not available at \(nextStop.name)",
                    detail: platform.isKnown
                        ? "Arrive around \(nextStop.time) on platform \(platform.displayText). Keep this as the next station check."
                        : "Arrive around \(nextStop.time). This source has not supplied a platform for the next station.",
                    symbolName: "rectangle.split.3x1.fill",
                    tint: platform.isKnown ? RailDesign.Palette.accent : RailDesign.Palette.secondaryText
                )
            )
        }

        if let transferStop = stops.first(where: \.isTransferPoint) {
            let platform = transferStop.platformDisplayState
            items.append(
                RailMapInsight(
                    title: "\(transferStop.name) transfer cue",
                    detail: platform.isKnown
                        ? "Watch platform \(platform.displayText) and the split/through-service note before changing trains."
                        : "Watch the split/through-service note before changing trains; platform is not available from this source.",
                    symbolName: "arrow.triangle.branch",
                    tint: RailDesign.Palette.warning
                )
            )
        } else if status == .onTime || status == .boarding {
            items.append(
                RailMapInsight(
                    title: "No disruptions ahead",
                    detail: "Tracked stops ahead are clear in the current trip data.",
                    symbolName: "checkmark.shield.fill",
                    tint: RailDesign.Palette.success
                )
            )
        } else {
            items.append(
                RailMapInsight(
                    title: "Service watch after \(nextStop?.name ?? trip.nextStop)",
                    detail: "Delay and disruption markers are highlighted on the route map.",
                    symbolName: "exclamationmark.triangle.fill",
                    tint: status.tint
                )
            )
        }

        return items
    }

    var region: MKCoordinateRegion {
        let coordinates = routeCoordinates + [trainCoordinate]
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
        }

        let minLatitude = coordinates.map(\.latitude).min() ?? 35.6812
        let maxLatitude = coordinates.map(\.latitude).max() ?? 35.6812
        let minLongitude = coordinates.map(\.longitude).min() ?? 139.7671
        let maxLongitude = coordinates.map(\.longitude).max() ?? 139.7671

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (minLatitude + maxLatitude) / 2,
                longitude: (minLongitude + maxLongitude) / 2
            ),
            span: MKCoordinateSpan(
                latitudeDelta: max(0.8, (maxLatitude - minLatitude) * 1.7),
                longitudeDelta: max(0.8, (maxLongitude - minLongitude) * 1.7)
            )
        )
    }

    private static func makeStops(for trip: TrainTrip) -> [RailMapStop] {
        let rawStops = trip.stops.isEmpty
            ? [
                StationStop(name: trip.origin.name, time: trip.origin.time, platform: trip.platform, note: "Origin", state: .done),
                StationStop(name: trip.destination.name, time: trip.destination.time, platform: trip.platform, note: "Destination", state: .pending)
            ]
            : trip.stops

        return rawStops.enumerated().map { index, stop in
            RailMapStop(
                id: "\(index)-\(stop.name)",
                index: index,
                name: stop.name,
                time: stop.time,
                platform: stop.displayPlatform,
                platformDisplayState: stop.platformDisplayState,
                note: stop.displayNote,
                state: stop.state,
                coordinate: coordinate(for: stop, index: index, count: rawStops.count, trip: trip),
                isTransferPoint: stop.note.isTransferCue,
                isDisruptionPoint: trip.statusTone != .good && (stop.state == .current || stop.note.isTransferCue)
            )
        }
    }

    private static func coordinate(for stop: StationStop, index: Int, count: Int, trip: TrainTrip) -> CLLocationCoordinate2D {
        if let coordinate = knownStationCoordinates[stop.name] {
            return coordinate
        }
        if stop.name == trip.origin.name, let coordinate = trip.origin.mapCoordinate {
            return coordinate
        }
        if stop.name == trip.destination.name, let coordinate = trip.destination.mapCoordinate {
            return coordinate
        }

        let origin = trip.origin.mapCoordinate ?? CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        let destination = trip.destination.mapCoordinate ?? origin
        let denominator = max(1, count - 1)
        let fraction = Double(index) / Double(denominator)
        return CLLocationCoordinate2D(
            latitude: origin.latitude + (destination.latitude - origin.latitude) * fraction,
            longitude: origin.longitude + (destination.longitude - origin.longitude) * fraction
        )
    }

    private static func coordinate(at progress: Double, in coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard let first = coordinates.first else {
            return CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
        }
        guard coordinates.count > 1 else { return first }

        let clamped = min(1, max(0, progress))
        let scaled = clamped * Double(coordinates.count - 1)
        let lowerIndex = min(coordinates.count - 2, Int(scaled.rounded(.down)))
        let upperIndex = lowerIndex + 1
        let local = scaled - Double(lowerIndex)
        let lower = coordinates[lowerIndex]
        let upper = coordinates[upperIndex]

        return CLLocationCoordinate2D(
            latitude: lower.latitude + (upper.latitude - lower.latitude) * local,
            longitude: lower.longitude + (upper.longitude - lower.longitude) * local
        )
    }

    private static func curvedRouteCoordinates(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count > 1 else { return coordinates }

        var curved: [CLLocationCoordinate2D] = []
        for index in 0..<(coordinates.count - 1) {
            let start = coordinates[index]
            let end = coordinates[index + 1]
            if curved.isEmpty {
                curved.append(start)
            }

            let sign = index.isMultiple(of: 2) ? 1.0 : -1.0
            let deltaLatitude = end.latitude - start.latitude
            let deltaLongitude = end.longitude - start.longitude
            let control = CLLocationCoordinate2D(
                latitude: (start.latitude + end.latitude) / 2 + deltaLongitude * 0.08 * sign,
                longitude: (start.longitude + end.longitude) / 2 - deltaLatitude * 0.08 * sign
            )

            for step in 1...10 {
                let t = Double(step) / 10.0
                let oneMinus = 1.0 - t
                curved.append(
                    CLLocationCoordinate2D(
                        latitude: oneMinus * oneMinus * start.latitude + 2 * oneMinus * t * control.latitude + t * t * end.latitude,
                        longitude: oneMinus * oneMinus * start.longitude + 2 * oneMinus * t * control.longitude + t * t * end.longitude
                    )
                )
            }
        }

        return curved
    }

    private static let knownStationCoordinates: [String: CLLocationCoordinate2D] = [
        "Tokyo": CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        "Shin-Yokohama": CLLocationCoordinate2D(latitude: 35.5075, longitude: 139.6176),
        "Nagoya": CLLocationCoordinate2D(latitude: 35.1709, longitude: 136.8815),
        "Kyoto": CLLocationCoordinate2D(latitude: 34.9858, longitude: 135.7588),
        "Shin-Osaka": CLLocationCoordinate2D(latitude: 34.7335, longitude: 135.5002),
        "Okayama": CLLocationCoordinate2D(latitude: 34.6666, longitude: 133.9186),
        "Hiroshima": CLLocationCoordinate2D(latitude: 34.3973, longitude: 132.4757),
        "Hakata": CLLocationCoordinate2D(latitude: 33.5902, longitude: 130.4206),
        "Kumamoto": CLLocationCoordinate2D(latitude: 32.7898, longitude: 130.6880),
        "Kagoshima-Chuo": CLLocationCoordinate2D(latitude: 31.5838, longitude: 130.5412),
        "Omiya": CLLocationCoordinate2D(latitude: 35.9064, longitude: 139.6241),
        "Sendai": CLLocationCoordinate2D(latitude: 38.2602, longitude: 140.8820),
        "Morioka": CLLocationCoordinate2D(latitude: 39.7015, longitude: 141.1363),
        "Shin-Aomori": CLLocationCoordinate2D(latitude: 40.8287, longitude: 140.6933),
        "Shin-Hakodate-Hokuto": CLLocationCoordinate2D(latitude: 41.9049, longitude: 140.6476),
        "Nagano": CLLocationCoordinate2D(latitude: 36.6433, longitude: 138.1886),
        "Toyama": CLLocationCoordinate2D(latitude: 36.7012, longitude: 137.2137),
        "Kanazawa": CLLocationCoordinate2D(latitude: 36.5781, longitude: 136.6480),
        "Tsuruga": CLLocationCoordinate2D(latitude: 35.6456, longitude: 136.0769),
        "Takasaki": CLLocationCoordinate2D(latitude: 36.3223, longitude: 139.0124),
        "Echigo-Yuzawa": CLLocationCoordinate2D(latitude: 36.9360, longitude: 138.8090),
        "Niigata": CLLocationCoordinate2D(latitude: 37.9120, longitude: 139.0610),
        "Tazawako": CLLocationCoordinate2D(latitude: 39.7000, longitude: 140.7221),
        "Akita": CLLocationCoordinate2D(latitude: 39.7166, longitude: 140.1297),
        "Fukushima": CLLocationCoordinate2D(latitude: 37.7541, longitude: 140.4595),
        "Yamagata": CLLocationCoordinate2D(latitude: 38.2489, longitude: 140.3273),
        "Shinjo": CLLocationCoordinate2D(latitude: 38.7628, longitude: 140.3060)
    ]
}

private struct RailMapStop: Identifiable, Hashable {
    let id: String
    let index: Int
    let name: String
    let time: String
    let platform: String
    let platformDisplayState: RailPlatformDisplayState
    let note: String
    let state: StationStop.StopState
    let coordinate: CLLocationCoordinate2D
    let isTransferPoint: Bool
    let isDisruptionPoint: Bool

    var shortLabel: String {
        let parts = name.split(separator: "-")
        if parts.count > 1, let last = parts.last {
            return String(last)
        }
        return String(name.prefix(14))
    }

    static func == (lhs: RailMapStop, rhs: RailMapStop) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

private extension RailMapStop {
    func formattedTime(format: UserPreferences.TimeFormat) -> String {
        time.formattedAsTime(in: TimeZone(identifier: "Asia/Tokyo")!, format: format)
    }
}

private struct RailMapInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
}

private struct RailMapStatusOverlay: View {
    let model: RailMapModel
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var formattedETA: String {
        model.trip.eta.formattedAsTime(
            in: model.trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var platformText: String {
        model.nextStop?.platformDisplayState.displayText ?? model.trip.displayPlatform
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack(spacing: RailDesign.Spacing.xs) {
                ServiceStatusPill(status: model.status)
                Text("\(Int(model.trip.progress * 100))%")
                    .font(RailDesign.Typography.small.weight(.semibold).monospacedDigit())
                    .foregroundStyle(RailDesign.Palette.ink)
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, RailDesign.Spacing.xs + 2)
                    .background(RailDesign.Palette.inset, in: Capsule())
            }
            SourceBadge(trip: model.trip)
            Label(model.positionState.mapLabel, systemImage: model.positionState.symbolName)
                .font(RailDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(model.positionState.isLiveVehiclePosition ? RailDesign.Palette.info : RailDesign.Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .padding(.horizontal, RailDesign.Spacing.xs)
                .padding(.vertical, RailDesign.Spacing.xs)
                .background(RailDesign.Palette.textSurface, in: Capsule())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text("Next stop")
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .textCase(.uppercase)
                Text(model.nextStop?.name ?? model.trip.nextStop)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Platform \(platformText) · \(formattedETA)")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.ink.opacity(0.74))
            }
        }
        .padding(RailDesign.Spacing.s)
        .railSurfaceStyle(role: .material)
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapControls: View {
    let recenter: () -> Void

    var body: some View {
        Button(action: recenter) {
            Image(systemName: "scope")
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
                .frame(width: 44, height: 44)
                .background(RailDesign.Palette.panel, in: Circle())
                .overlay(Circle().stroke(RailDesign.Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel("Center map")
        .accessibilityHint("Re-centers the map on the trip route")
    }
}

private struct RailMapStopRail: View {
    let title: LocalizedStringKey
    let stops: [RailMapStop]
    let status: RailServiceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            Text(title)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
                .padding(.horizontal, RailDesign.Spacing.xxs)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RailDesign.Spacing.s) {
                    ForEach(stops) { stop in
                        RailMapStopCard(stop: stop, status: status)
                    }
                }
                .padding(.vertical, RailDesign.Spacing.xxs)
            }
        }
    }
}

private struct RailMapStopCard: View {
    let stop: RailMapStop
    let status: RailServiceStatus
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var platformBadgeText: String {
        stop.platformDisplayState.isKnown ? "P\(stop.platform)" : "Platform n/a"
    }

    private var platformTint: Color {
        stop.platformDisplayState.isKnown ? status.tint : RailDesign.Palette.secondaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack {
                Text(stop.formattedTime(format: interfacePreferences.timeFormat))
                    .font(RailDesign.Typography.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(RailDesign.Palette.ink)
                Spacer()
                Text(platformBadgeText)
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, RailDesign.Spacing.xxs)
                    .background(platformTint.opacity(0.16), in: Capsule())
            }
            Text(stop.name)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(stop.note)
                .font(RailDesign.Typography.caption)
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .lineLimit(2)
        }
        .frame(width: 150, alignment: .leading)
        .padding(RailDesign.Spacing.s)
        .railSurfaceStyle(role: .material)
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapStopDetailCard: View {
    let stop: RailMapStop
    let isNext: Bool
    let status: RailServiceStatus
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            RailMapStationPin(stop: stop, isNext: isNext)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(stop.name)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                HStack(spacing: RailDesign.Spacing.xs) {
                    Text(stop.formattedTime(format: interfacePreferences.timeFormat))
                        .font(RailDesign.Typography.small.monospacedDigit().weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.ink)
                    Text("·")
                        .foregroundStyle(RailDesign.Palette.inkDisabled)
                    Text("Platform \(stop.platformDisplayState.displayText)")
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
                Text(stop.note)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if stop.isTransferPoint {
                Image(systemName: "arrow.triangle.branch")
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.warning)
                    .frame(width: 28, height: 28)
                    .background(RailDesign.Palette.warning.opacity(0.12), in: Circle())
                    .accessibilityLabel("Transfer cue")
            } else if isNext {
                Image(systemName: "location.north.line.fill")
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(status.tint)
                    .frame(width: 28, height: 28)
                    .background(status.tint.opacity(0.12), in: Circle())
                    .accessibilityLabel("Next stop")
            }
        }
        .padding(RailDesign.Spacing.m)
        .background(RailDesign.Palette.panel, in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapStationPin: View {
    let stop: RailMapStop
    let isNext: Bool
    var showsLabel = false

    var body: some View {
        VStack(spacing: RailDesign.Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: isNext ? 28 : 18, height: isNext ? 28 : 18)
                    .railShadow(RailDesign.Elevation.mapStation(isEmphasized: isNext), tint: fillColor)
                Circle()
                    .stroke(RailDesign.Palette.onAccent.opacity(0.82), lineWidth: isNext ? 3 : 2)
                    .frame(width: isNext ? 28 : 18, height: isNext ? 28 : 18)
                if stop.isTransferPoint {
                    Image(systemName: "arrow.triangle.branch")
                        .font(RailDesign.Typography.mapTransferSymbol(isEmphasized: isNext))
                        .foregroundStyle(RailDesign.Palette.onAccent)
                }
            }

            if showsLabel {
                Text(stop.shortLabel)
                    .font(RailDesign.Typography.mapStationLabel(isEmphasized: isNext))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, RailDesign.Spacing.xxs)
                    .background(RailDesign.Palette.textSurface, in: Capsule())
                    .railPanelShadow(RailDesign.Elevation.mapLabel)
            }
        }
        .accessibilityLabel("\(stop.name), platform \(stop.platformDisplayState.displayText), \(stop.note)")
    }

    private var fillColor: Color {
        if stop.isDisruptionPoint {
            return RailDesign.Palette.warning
        }
        if isNext {
            return RailDesign.Palette.accent
        }
        switch stop.state {
        case .done:
            return RailDesign.Palette.success
        case .current:
            return RailDesign.Palette.accent
        case .pending:
            return RailDesign.Palette.accent
        }
    }
}

private struct RailMapPositionPin: View {
    let state: RailVehiclePositionDisplayState
    let status: RailServiceStatus

    private var tint: Color {
        state.isLiveVehiclePosition ? status.tint : RailDesign.Palette.accent
    }

    var body: some View {
        VStack(spacing: RailDesign.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(tint.opacity(state.isLiveVehiclePosition ? 0.16 : 0.10))
                    .frame(width: state.isLiveVehiclePosition ? 76 : 58, height: state.isLiveVehiclePosition ? 76 : 58)
                    .overlay(Circle().stroke(RailDesign.Palette.onAccent.opacity(0.58), lineWidth: 1))
                Circle()
                    .stroke(tint.opacity(state.isLiveVehiclePosition ? 0.38 : 0.30), lineWidth: state.isLiveVehiclePosition ? 3 : 2)
                    .frame(width: state.isLiveVehiclePosition ? 60 : 44, height: state.isLiveVehiclePosition ? 60 : 44)
                Image(systemName: state.isLiveVehiclePosition ? "train.side.front.car" : state.symbolName)
                    .font(RailDesign.Typography.mapVehicle(isLive: state.isLiveVehiclePosition))
                    .foregroundStyle(RailDesign.Palette.onAccent)
                    .padding(state.isLiveVehiclePosition ? 14 : 11)
                    .background(tint, in: Circle())
                    .overlay(Circle().stroke(RailDesign.Palette.onAccent.opacity(0.88), lineWidth: 2))
            }
            Text(state.mapLabel)
                .font(RailDesign.Typography.mapPositionLabel)
                .foregroundStyle(RailDesign.Palette.ink)
                .padding(.horizontal, RailDesign.Spacing.xs)
                .padding(.vertical, RailDesign.Spacing.xxs)
                .background(RailDesign.Palette.textSurface, in: Capsule())
        }
        .railShadow(RailDesign.Elevation.mapVehicle(isLive: state.isLiveVehiclePosition), tint: tint)
        .accessibilityLabel(state.mapLabel)
        .accessibilityValue(state.detailText)
    }
}

private struct RailMapDisruptionMarker: View {
    let status: RailServiceStatus

    var body: some View {
        Image(systemName: status == .platformChanged ? "rectangle.split.3x1.fill" : "exclamationmark.triangle.fill")
            .font(RailDesign.Typography.caption.weight(.bold))
            .foregroundStyle(RailDesign.Palette.onAccent)
            .padding(RailDesign.Spacing.xs)
            .background(status.tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous)) // ds-allow: map canvas
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous) // ds-allow: map canvas
                    .stroke(RailDesign.Palette.onAccent.opacity(0.8), lineWidth: 1.5)
            )
            .railShadow(RailDesign.Elevation.mapAlert, tint: status.tint)
            .accessibilityLabel("Service marker")
    }
}

private struct RailMapSectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
            Text(title)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
            Text(subtitle)
                .font(RailDesign.Typography.caption)
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct RailMapInsightCard: View {
    let insight: RailMapInsight

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: insight.symbolName)
                .font(RailDesign.Typography.h3.weight(.bold))
                .foregroundStyle(insight.tint)
                .frame(width: 34, height: 34)
                .background(insight.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(insight.title)
                    .font(RailDesign.Typography.h3.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(insight.detail)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(insight.tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(insight.tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private extension StationPoint {
    var mapCoordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension TrainTrip {
    var vehicleMapCoordinate: CLLocationCoordinate2D? {
        guard let latitude = vehicleLatitude, let longitude = vehicleLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension StationStop {
    var displayNote: String {
        note
            .replacingOccurrences(of: "Gate", with: "Platform")
            .replacingOccurrences(of: "gate", with: "platform")
    }
}

private extension String {
    var isTransferCue: Bool {
        localizedCaseInsensitiveContains("handoff") ||
        localizedCaseInsensitiveContains("transfer") ||
        localizedCaseInsensitiveContains("split")
    }
}

// // // // // // // #Preview("Rail Map Detail") {
// // // // // // //     RailJourneyMapPanel(trip: TrainTrip.samples[0], style: .detail)
// // // // // // //         .padding()
// // // // // // //         .background(RailGradientBackground())
// // // // // // // }
