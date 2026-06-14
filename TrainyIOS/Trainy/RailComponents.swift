import SwiftUI

extension SourceKind {
    var badgeTitle: String {
        compactTitle
    }

    var badgeSymbolName: String {
        switch self {
        case .starterCatalog:
            return "sparkles"
        case .officialTimetable:
            return "building.columns.fill"
        case .realtimePrediction:
            return "dot.radiowaves.left.and.right"
        case .vehiclePosition:
            return "location.fill"
        case .alertFeed:
            return "exclamationmark.triangle.fill"
        case .inferred:
            return "tray.full.fill"
        }
    }

    var badgeTint: Color {
        switch self {
        case .starterCatalog:
            return RailDesign.Palette.copper
        case .officialTimetable:
            return RailDesign.Palette.accent
        case .realtimePrediction, .vehiclePosition:
            return RailDesign.Palette.blue
        case .alertFeed:
            return RailDesign.Palette.amber
        case .inferred:
            return RailDesign.Palette.violet
        }
    }
}

extension FreshnessState {
    var compactTitle: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .stale:
            return "Stale"
        case .expired:
            return "Expired"
        case .unknown:
            return "Unk"
        }
    }

    var tint: Color {
        switch self {
        case .fresh:
            return RailDesign.Palette.mint
        case .stale:
            return RailDesign.Palette.amber
        case .expired:
            return RailDesign.Palette.red
        case .unknown:
            return RailDesign.Palette.secondaryText
        }
    }
}

struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let tint: Color
    let padding: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = RailDesign.Radius.panel,
        tint: Color = .white.opacity(0.10),
        padding: CGFloat = RailDesign.Spacing.m,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: RailDesign.Spacing.m) {
            content
                .padding(padding)
                .railLiquidGlass(cornerRadius: cornerRadius, tint: tint)
                .railPanelShadow()
        }
    }
}

struct FloatingGlassButton<Label: View>: View {
    let action: () -> Void
    let label: Label

    init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .font(.headline.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.ink)
                .frame(minWidth: 48, minHeight: 48)
                .padding(.horizontal, RailDesign.Spacing.m)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .railLiquidGlass(cornerRadius: 24, tint: RailDesign.Palette.accent.opacity(0.16), interactive: true)
        .railPanelShadow()
    }
}

struct ServiceStatusPill: View {
    let status: RailServiceStatus

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            Image(systemName: status.symbolName)
                .imageScale(.small)
            Text(status.title)
        }
        .font(RailDesign.Typography.compactLabel)
        .foregroundStyle(status.tint)
        .padding(.horizontal, RailDesign.Spacing.s)
        .padding(.vertical, 7)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.chip, tint: status.glassTint)
        .accessibilityElement(children: .combine)
    }
}

struct SourceBadge: View {
    enum Style {
        case compact
        case regular

        var width: CGFloat {
            switch self {
            case .compact:
                return 128
            case .regular:
                return 164
            }
        }

        var height: CGFloat { 30 }
    }

    let trip: TrainTrip
    var style: Style = .compact

    private var source: SourceProvenance {
        trip.sourceProvenance
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            Image(systemName: source.sourceKind.badgeSymbolName)
                .imageScale(.small)
                .frame(width: 14)

            Text(source.sourceKind.badgeTitle)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            FreshnessBadge(state: source.freshness)
        }
        .foregroundStyle(source.sourceKind.badgeTint)
        .padding(.horizontal, RailDesign.Spacing.xs)
        .frame(width: style.width, height: style.height, alignment: .leading)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.chip, tint: source.sourceKind.badgeTint.opacity(0.12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(source.sourceKind.riderTitle) source, \(source.confidence.displayName) confidence, \(source.freshness.displayName)")
    }
}

struct FreshnessBadge: View {
    let state: FreshnessState

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(state.tint)
                .frame(width: 6, height: 6)
            Text(state.compactTitle)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Freshness \(state.displayName)")
    }
}

struct SourceFactRow: View {
    let fact: FactProvenance

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Text(fact.fact.displayName)
                .font(.caption.weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            VStack(alignment: .leading, spacing: 2) {
                Text(fact.summaryText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(fact.note)
                    .font(.caption2)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct SourceDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let trip: TrainTrip

    private var source: SourceProvenance {
        trip.sourceProvenance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    GlassPanel(tint: source.sourceKind.badgeTint.opacity(0.12)) {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                            SourceBadge(trip: trip, style: .regular)
                            Text(source.sourceName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(RailDesign.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(source.riderExplanation)
                                .font(.subheadline)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(trip.sourceBreakdownText)
                                .font(.subheadline)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                            SourceMetadataLine(symbol: "building.columns", title: "Provider", value: source.providerName)
                            SourceMetadataLine(symbol: "calendar.badge.clock", title: "Source type", value: source.sourceKind.riderTitle)
                            SourceMetadataLine(symbol: "checkmark.seal", title: "Confidence", value: source.summaryText)
                            SourceMetadataLine(symbol: "clock.badge.checkmark", title: "Freshness", value: "\(source.freshness.displayName). \(source.freshnessExplanation)")
                            SourceMetadataLine(symbol: "doc.plaintext", title: "License and attribution", value: source.licenseAttributionText)
                            if let sourceURL = source.sourceURL {
                                Link(destination: sourceURL) {
                                    Label(sourceURL.host ?? sourceURL.absoluteString, systemImage: "arrow.up.right.square")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RailDesign.Palette.accent)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }
                                .accessibilityLabel("Open source \(source.sourceName)")
                            }
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Fact Sources")
                                .font(.headline)
                                .foregroundStyle(RailDesign.Palette.ink)
                            ForEach(trip.factProvenance) { fact in
                                SourceFactRow(fact: fact)
                            }
                        }
                    }
                }
                .padding(RailDesign.Spacing.m)
            }
            .background(RailGradientBackground().ignoresSafeArea())
            .navigationTitle("Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SourceMetadataLine: View {
    let symbol: String
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                Text(value.isEmpty ? "Not available" : value)
                    .font(.subheadline)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct StationBadge: View {
    let name: String
    let code: String?

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(RailDesign.Palette.accent.opacity(0.16))
                Image(systemName: "tram.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RailDesign.Palette.accent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let code, !code.isEmpty {
                    Text(code)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .textCase(.uppercase)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct PlatformChip: View {
    let platform: String
    var label: LocalizedStringKey = "Platform"

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            Image(systemName: "rectangle.split.3x1.fill")
                .imageScale(.small)
            Text(label)
            Text(platform)
                .fontWeight(.bold)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(RailDesign.Palette.marine)
        .padding(.horizontal, RailDesign.Spacing.s)
        .padding(.vertical, 7)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.chip, tint: RailDesign.Palette.blue.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}

struct TrainTripCard: View {
    let trip: TrainTrip
    var role: Role = .upcoming

    enum Role {
        case upcoming
        case active
        case past
        case compact
    }

    private var status: RailServiceStatus {
        RailServiceStatus.from(trip)
    }

    var body: some View {
        GlassPanel(cornerRadius: 24, tint: role == .active ? .white.opacity(0.08) : .white.opacity(0.09)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(trip.service)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                        Text(trip.train)
                            .font(RailDesign.Typography.routeTitle)
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        SourceBadge(trip: trip)
                    }

                    Spacer(minLength: RailDesign.Spacing.s)
                    ServiceStatusPill(status: status)
                    TripOpenCue()
                }

                HStack(alignment: .firstTextBaseline) {
                    StationColumn(title: trip.origin.name, time: trip.origin.time, alignment: .leading)
                    RouteProgressLine(progress: trip.progress, status: status)
                        .frame(minWidth: 88, maxWidth: 150)
                    StationColumn(title: trip.destination.name, time: trip.destination.time, alignment: .trailing)
                }

                HStack(spacing: RailDesign.Spacing.xs) {
                    PlatformChip(platform: trip.platform)

                    if role != .past {
                        Label(trip.duration, systemImage: "timer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .padding(.horizontal, RailDesign.Spacing.s)
                            .padding(.vertical, 7)
                            .railLiquidGlass(cornerRadius: RailDesign.Radius.chip, tint: .white.opacity(0.10))
                    }

                    Spacer(minLength: 0)
                }

                if role == .compact {
                    Divider()
                        .overlay(RailDesign.Palette.hairline)

                    HStack {
                        Label("Next stop", systemImage: "location.north.line.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(trip.nextStop)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RailDesign.Palette.ink)
                            Text("ETA \(trip.eta)")
                                .font(.caption)
                                .foregroundStyle(status.tint)
                        }
                    }
                }

                if !trip.alerts.isEmpty && role != .compact {
                    AlertStrip(alert: trip.alerts[0])
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.train), \(trip.origin.name) to \(trip.destination.name), \(trip.status), platform \(trip.platform), \(trip.sourceProvenance.sourceKind.riderTitle) source, \(trip.sourceProvenance.freshness.displayName)")
    }
}

private struct TripOpenCue: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle(RailDesign.Palette.secondaryText)
            .frame(width: 28, height: 28)
            .railLiquidGlass(cornerRadius: 14, tint: .white.opacity(0.12), strokeOpacity: 0.28)
            .accessibilityHidden(true)
    }
}

struct StopTimelineRow: View {
    let stop: StationStop
    let isLast: Bool

    private var tint: Color {
        switch stop.state {
        case .done:
            return RailDesign.Palette.mint
        case .current:
            return RailDesign.Palette.accent
        case .pending:
            return RailDesign.Palette.secondaryText
        }
    }

    private var statusSymbol: String {
        switch stop.state {
        case .done:
            return "checkmark"
        case .current:
            return "train.side.front.car"
        case .pending:
            return "circle"
        }
    }

    private var displayNote: String {
        stop.note
            .replacingOccurrences(of: "Gate", with: "Platform")
            .replacingOccurrences(of: "gate", with: "platform")
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: statusSymbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }

                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.55), RailDesign.Palette.hairline],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2, height: 44)
                }
            }

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(stop.time)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.ink)
                    Text(stop.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(2)
                    Spacer(minLength: RailDesign.Spacing.s)
                }

                HStack(spacing: RailDesign.Spacing.xs) {
                    PlatformChip(platform: stop.platform)
                    Text(displayNote)
                        .font(.caption)
                        .foregroundStyle(tint)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, isLast ? 0 : RailDesign.Spacing.m)
        }
        .accessibilityElement(children: .combine)
    }
}

struct TransferWarningCard: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var tone: Color = RailDesign.Palette.amber

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "arrow.triangle.branch")
                .font(.title3.weight(.semibold))
                .foregroundStyle(tone)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tone.opacity(0.16))
        .accessibilityElement(children: .combine)
    }
}

struct DisruptionBanner: View {
    let alert: TrainAlert

    private var tint: Color {
        alert.tone == .good ? RailDesign.Palette.mint : (alert.tone == .late ? RailDesign.Palette.red : RailDesign.Palette.amber)
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: alert.tone == .good ? "info.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                Text(alert.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(alert.detail)
                    .font(.footnote)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tint.opacity(0.16))
        .accessibilityElement(children: .combine)
    }
}

struct MetricTile: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey
    let symbolName: String
    var tint: Color = RailDesign.Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .railLiquidGlass(cornerRadius: 14, tint: tint.opacity(0.18))
                Spacer(minLength: 0)
            }
            Text(value)
                .font(RailDesign.Typography.metricValue)
                .foregroundStyle(RailDesign.Palette.ink)
                .minimumScaleFactor(0.76)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tint.opacity(0.10))
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateView: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var symbolName: String = "tram"
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        GlassPanel {
            VStack(spacing: RailDesign.Spacing.m) {
                Image(systemName: symbolName)
                    .font(.system(size: 36, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RailDesign.Palette.accent)
                    .frame(width: 64, height: 64)
                    .railLiquidGlass(cornerRadius: 32, tint: RailDesign.Palette.accent.opacity(0.18))

                VStack(spacing: RailDesign.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let actionTitle, let action {
                    FloatingGlassButton(action: action) {
                        Label(actionTitle, systemImage: "plus")
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

struct LoadingSkeletonView: View {
    var rows: Int = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: RailDesign.Spacing.m) {
            ForEach(0..<rows, id: \.self) { index in
                GlassPanel {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        Capsule()
                            .fill(RailDesign.Palette.hairline)
                            .frame(width: index == 0 ? 128 : 174, height: 12)
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(RailDesign.Palette.hairline)
                            .frame(height: 54)
                        Capsule()
                            .fill(RailDesign.Palette.hairline)
                            .frame(width: 220, height: 10)
                    }
                    .redacted(reason: .placeholder)
                    .opacity(reduceMotion ? 0.72 : 0.92)
                }
            }
        }
        .accessibilityLabel("Loading rail updates")
    }
}

struct OfflineBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(RailDesign.Palette.amber)
                .font(.headline)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text("Offline mode")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: RailDesign.Palette.amber.opacity(0.18))
        .accessibilityElement(children: .combine)
    }
}

private struct StationColumn: View {
    let title: String
    let time: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: RailDesign.Spacing.xxs) {
            Text(time)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct RouteProgressLine: View {
    let progress: Double
    let status: RailServiceStatus

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let x = max(10, min(width - 10, width * progress))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(RailDesign.Palette.hairline)
                    .frame(height: 4)

                Capsule()
                    .fill(status.tint)
                    .frame(width: max(12, x), height: 4)

                Image(systemName: "train.side.front.car")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(status.tint, in: Circle())
                    .offset(x: x - 13)
            }
            .frame(height: 28)
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

private struct AlertStrip: View {
    let alert: TrainAlert

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xs) {
            Image(systemName: alert.tone == .good ? "sparkle.magnifyingglass" : "exclamationmark.triangle.fill")
                .foregroundStyle(alert.tone == .good ? RailDesign.Palette.mint : RailDesign.Palette.amber)
            Text(alert.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RailDesign.Spacing.s)
        .padding(.vertical, RailDesign.Spacing.xs)
        .background(RailDesign.Palette.hairline.opacity(0.35), in: Capsule())
    }
}

#Preview("Trip Card") {
    TrainTripCard(trip: TrainTrip.samples[0], role: .active)
        .padding()
        .background(RailGradientBackground())
}

#Preview("States") {
    VStack(spacing: 16) {
        OfflineBanner(message: "Saved journeys are available until source data returns.")
        EmptyStateView(title: "No journeys yet", message: "Search by train number, route, operator, or station pair.")
        LoadingSkeletonView(rows: 1)
    }
    .padding()
    .background(RailGradientBackground())
}
