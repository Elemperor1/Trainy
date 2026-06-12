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

    @State private var mapMode: RailMapMode = .route
    @State private var cameraPosition: MapCameraPosition

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

        GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: .white.opacity(0.06), padding: 0) {
            ZStack(alignment: .top) {
                Map(position: $cameraPosition, interactionModes: .all) {
                    MapPolyline(coordinates: model.routeCoordinates)
                        .stroke(.white.opacity(0.90), style: StrokeStyle(lineWidth: 15, lineCap: .round, lineJoin: .round))

                    MapPolyline(coordinates: model.upcomingCoordinates)
                        .stroke(RailDesign.Palette.ink.opacity(0.22), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round, dash: [11, 8]))

                    MapPolyline(coordinates: model.upcomingCoordinates)
                        .stroke(RailDesign.Palette.marine.opacity(0.84), style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round, dash: [11, 8]))

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

                    Annotation("", coordinate: model.trainCoordinate) {
                        RailMapTrainPin(status: model.status)
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
                            mode: $mapMode,
                            recenter: {
                                withAnimation(RailDesign.Motion.soft) {
                                    cameraPosition = .region(model.region)
                                }
                            }
                        )
                    }

                    Spacer(minLength: 0)

                    RailMapStopRail(
                        title: mapMode.title,
                        stops: mapMode == .alerts ? model.disruptionAwareStops : model.upcomingStops,
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
            .padding(.bottom, 120)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Rail map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .railScreenChrome()
    }
}

private enum RailMapMode: String, CaseIterable, Identifiable {
    case route
    case stops
    case alerts

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .route:
            return "Route focus"
        case .stops:
            return "Upcoming stops"
        case .alerts:
            return "Disruptions"
        }
    }

    var symbolName: String {
        switch self {
        case .route:
            return "train.side.front.car"
        case .stops:
            return "mappin.circle.fill"
        case .alerts:
            return "exclamationmark.triangle.fill"
        }
    }

    var controlTitle: LocalizedStringKey {
        switch self {
        case .route:
            return "Route"
        case .stops:
            return "Stops"
        case .alerts:
            return "Disruptions"
        }
    }

    var accessibilityTitle: LocalizedStringKey {
        switch self {
        case .route:
            return "Route"
        case .stops:
            return "Stops"
        case .alerts:
            return "Disruptions"
        }
    }

    var contextTitle: String {
        switch self {
        case .route:
            return "Show route emphasis"
        case .stops:
            return "Show upcoming stops"
        case .alerts:
            return "Show disruptions"
        }
    }
}

private struct RailMapModel {
    let trip: TrainTrip
    let stops: [RailMapStop]
    let routeCoordinates: [CLLocationCoordinate2D]
    let trainCoordinate: CLLocationCoordinate2D
    let status: RailServiceStatus

    init(trip: TrainTrip) {
        self.trip = trip
        self.status = RailServiceStatus.from(trip)
        self.stops = Self.makeStops(for: trip)
        self.routeCoordinates = Self.curvedRouteCoordinates(from: stops.map(\.coordinate))
        self.trainCoordinate = Self.coordinate(at: trip.progress, in: routeCoordinates)
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

        if let nextStop {
            items.append(
                RailMapInsight(
                    title: "Platform confirmed at \(nextStop.name)",
                    detail: "Arrive around \(nextStop.time) on platform \(nextStop.platform). Keep this as the next station check.",
                    symbolName: "rectangle.split.3x1.fill",
                    tint: RailDesign.Palette.accent
                )
            )
        }

        if let transferStop = stops.first(where: \.isTransferPoint) {
            items.append(
                RailMapInsight(
                    title: "\(transferStop.name) transfer cue",
                    detail: "Watch platform \(transferStop.platform) and the split/through-service note before changing trains.",
                    symbolName: "arrow.triangle.branch",
                    tint: RailDesign.Palette.amber
                )
            )
        } else if status == .onTime || status == .boarding {
            items.append(
                RailMapInsight(
                    title: "No disruptions ahead",
                    detail: "Tracked stops ahead are clear in the current status feed.",
                    symbolName: "checkmark.shield.fill",
                    tint: RailDesign.Palette.mint
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
                platform: stop.platform,
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

private struct RailMapInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
}

private struct RailMapStatusOverlay: View {
    let model: RailMapModel

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack(spacing: RailDesign.Spacing.xs) {
                ServiceStatusPill(status: model.status)
                Text("\(Int(model.trip.progress * 100))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, 7)
                    .background(RailDesign.Palette.textSurface, in: Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Next stop")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                Text(model.nextStop?.name ?? model.trip.nextStop)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Platform \(model.nextStop?.platform ?? model.trip.platform) - \(model.trip.eta)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RailDesign.Palette.ink.opacity(0.74))
            }
        }
        .padding(RailDesign.Spacing.s)
        .railLiquidGlass(cornerRadius: 22, tint: .white.opacity(0.16), strokeOpacity: 0.34)
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapControls: View {
    @Binding var mode: RailMapMode
    let recenter: () -> Void

    var body: some View {
        VStack(spacing: RailDesign.Spacing.xs) {
            ForEach(RailMapMode.allCases) { item in
                Button {
                    mode = item
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: item.symbolName)
                            .font(.caption.weight(.bold))
                        Text(item.controlTitle)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(mode == item ? RailDesign.Palette.ink : RailDesign.Palette.secondaryText)
                    .frame(width: 68, height: 42)
                }
                .buttonStyle(.plain)
                .railLiquidGlass(cornerRadius: 19, tint: mode == item ? RailDesign.Palette.accent.opacity(0.18) : .white.opacity(0.10), interactive: true, strokeOpacity: 0.26)
                .accessibilityLabel(item.accessibilityTitle)
                .contextMenu {
                    Text(item.contextTitle)
                }
            }

            Button(action: recenter) {
                VStack(spacing: 2) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.caption.weight(.bold))
                    Text("Train")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 68, height: 42)
            }
            .buttonStyle(.plain)
            .railLiquidGlass(cornerRadius: 19, tint: RailDesign.Palette.accent.opacity(0.12), interactive: true, strokeOpacity: 0.26)
            .accessibilityLabel("Locate train")
            .contextMenu {
                Text("Locate train")
            }
        }
    }
}

private struct RailMapStopRail: View {
    let title: LocalizedStringKey
    let stops: [RailMapStop]
    let status: RailServiceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RailDesign.Spacing.s) {
                    ForEach(stops) { stop in
                        RailMapStopCard(stop: stop, status: status)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct RailMapStopCard: View {
    let stop: RailMapStop
    let status: RailServiceStatus

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack {
                Text(stop.time)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Spacer()
                Text("P\(stop.platform)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(status.tint.opacity(0.12), in: Capsule())
            }
            Text(stop.name)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.74)
            Text(stop.note)
                .font(.caption2.weight(.medium))
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .lineLimit(1)
        }
        .frame(width: 150, alignment: .leading)
        .padding(RailDesign.Spacing.s)
        .railLiquidGlass(cornerRadius: 20, tint: .white.opacity(0.18), strokeOpacity: 0.32)
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapStopDetailCard: View {
    let stop: RailMapStop
    let isNext: Bool
    let status: RailServiceStatus

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            RailMapStationPin(stop: stop, isNext: isNext)
            VStack(alignment: .leading, spacing: 3) {
                Text(stop.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text("\(stop.time) - Platform \(stop.platform)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RailDesign.Palette.ink.opacity(0.74))
                Text(stop.note)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
            }
            Spacer()
            if stop.isTransferPoint {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(RailDesign.Palette.amber)
            } else if isNext {
                Image(systemName: "location.north.line.fill")
                    .foregroundStyle(status.tint)
            }
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: .white.opacity(0.11), strokeOpacity: 0.28)
        .accessibilityElement(children: .combine)
    }
}

private struct RailMapStationPin: View {
    let stop: RailMapStop
    let isNext: Bool
    var showsLabel = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(fillColor)
                    .frame(width: isNext ? 28 : 18, height: isNext ? 28 : 18)
                    .shadow(color: fillColor.opacity(0.34), radius: isNext ? 8 : 3, y: 2)
                Circle()
                    .stroke(.white.opacity(0.82), lineWidth: isNext ? 3 : 2)
                    .frame(width: isNext ? 28 : 18, height: isNext ? 28 : 18)
                if stop.isTransferPoint {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: isNext ? 11 : 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if showsLabel {
                Text(stop.shortLabel)
                    .font(.system(size: isNext ? 10 : 9, weight: .bold, design: .rounded))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RailDesign.Palette.textSurface, in: Capsule())
                    .shadow(color: RailDesign.Palette.ink.opacity(0.08), radius: 4, y: 2)
            }
        }
        .accessibilityLabel("\(stop.name), platform \(stop.platform), \(stop.note)")
    }

    private var fillColor: Color {
        if stop.isDisruptionPoint {
            return RailDesign.Palette.amber
        }
        if isNext {
            return RailDesign.Palette.accent
        }
        switch stop.state {
        case .done:
            return RailDesign.Palette.mint
        case .current:
            return RailDesign.Palette.accent
        case .pending:
            return RailDesign.Palette.marine
        }
    }
}

private struct RailMapTrainPin: View {
    let status: RailServiceStatus

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(status.tint.opacity(0.16))
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(.white.opacity(0.62), lineWidth: 1))
                Circle()
                    .stroke(status.tint.opacity(0.38), lineWidth: 3)
                    .frame(width: 60, height: 60)
                Image(systemName: "train.side.front.car")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(status.tint, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.88), lineWidth: 2))
            }
            Text("Current train")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(RailDesign.Palette.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RailDesign.Palette.textSurface, in: Capsule())
        }
        .shadow(color: status.tint.opacity(0.30), radius: 14, y: 5)
        .accessibilityLabel("Current train position")
    }
}

private struct RailMapDisruptionMarker: View {
    let status: RailServiceStatus

    var body: some View {
        Image(systemName: status == .platformChanged ? "rectangle.split.3x1.fill" : "exclamationmark.triangle.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(7)
            .background(status.tint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(.white.opacity(0.8), lineWidth: 1.5)
            )
            .shadow(color: status.tint.opacity(0.32), radius: 8, y: 3)
            .accessibilityLabel("Service marker")
    }
}

private struct RailMapSectionHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RailDesign.Palette.ink)
            Text(subtitle)
                .font(.caption)
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
                .font(.headline.weight(.bold))
                .foregroundStyle(insight.tint)
                .frame(width: 34, height: 34)
                .background(insight.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: insight.tint.opacity(0.10), strokeOpacity: 0.28)
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

#Preview("Rail Map Detail") {
    RailJourneyMapPanel(trip: TrainTrip.samples[0], style: .detail)
        .padding()
        .background(RailGradientBackground())
}
