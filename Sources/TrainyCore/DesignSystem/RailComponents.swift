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
            return RailDesign.Palette.warning
        case .officialTimetable:
            return RailDesign.Palette.accent
        case .realtimePrediction, .vehiclePosition:
            return RailDesign.Palette.info
        case .alertFeed:
            return RailDesign.Palette.danger
        case .inferred:
            return RailDesign.Palette.info
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
            return RailDesign.Palette.success
        case .stale:
            return RailDesign.Palette.warning
        case .expired:
            return RailDesign.Palette.danger
        case .unknown:
            return RailDesign.Palette.secondaryText
        }
    }
}

/// Liquid Glass panel container used only by `RailJourneyMapPanel` for the
/// hero map surface. Every other screen renders flat panels with
/// `RoundedRectangle(...).fill(.panel)` so the glass material stays special
/// rather than wallpaper. Kept in this library so the iOS 26 Liquid Glass
/// primitive has a single canonical entry point.
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

/// Semantic badge for the current rider-facing service state.
struct ServiceStatusPill: View {
    let status: RailServiceStatus

    var body: some View {
        RailBadge(
            status.title,
            tint: status.tint,
            symbol: status.symbolName
        )
    }
}

/// Compact provider or proxy status label with a caller-supplied semantic tint.
struct ProviderStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        RailBadge(text, tint: tint, minHeight: 26)
    }
}

struct SourceBadge: View {
    enum Style {
        case compact
        case regular

        var height: CGFloat { 30 }
    }

    let trip: TrainTrip
    var style: Style = .compact
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var source: SourceProvenance {
        trip.sourceProvenance
    }

    private var verbosity: UserPreferences.SourceLabelVerbosity {
        interfacePreferences.sourceLabelVerbosity
    }

    private var title: String {
        switch verbosity {
        case .compact:
            return source.sourceKind.badgeTitle
        case .detailed:
            return source.sourceKind.riderTitle
        }
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            Image(systemName: source.sourceKind.badgeSymbolName)
                .imageScale(.small)
                .frame(width: 14)

            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if source.freshness != .unknown {
                FreshnessBadge(state: source.freshness)
            }
        }
        .foregroundStyle(source.sourceKind.badgeTint)
        .padding(.horizontal, RailDesign.Spacing.xs)
        .frame(minHeight: style.height, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(source.sourceKind.badgeTint.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(source.sourceKind.badgeTint.opacity(0.18), lineWidth: 1))
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
                    .padding(RailDesign.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .fill(source.sourceKind.badgeTint.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .stroke(source.sourceKind.badgeTint.opacity(0.18), lineWidth: 1)
                    )

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
                    .padding(RailDesign.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .fill(RailDesign.Palette.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        Text("Fact Sources")
                            .font(.headline)
                            .foregroundStyle(RailDesign.Palette.ink)
                        ForEach(trip.factProvenance) { fact in
                            SourceFactRow(fact: fact)
                        }
                    }
                    .padding(RailDesign.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .fill(RailDesign.Palette.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                            .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                    )
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

    private var displayPlatform: String {
        platform.isEmpty || platform == "TBD" || platform == "Unknown" ? "Not available" : platform
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.xxs) {
            Image(systemName: "rectangle.split.3x1.fill")
                .imageScale(.small)
            Text(label)
            Text(displayPlatform)
                .fontWeight(.bold)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(RailDesign.Palette.info)
        .padding(.horizontal, RailDesign.Spacing.s)
        .padding(.vertical, 7)
        .background(RailDesign.Palette.infoSoft, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct TrainTripCard: View {
    let trip: TrainTrip
    var role: Role = .upcoming
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    enum Role {
        case upcoming
        case active
        case past
        case compact
    }

    private var status: RailServiceStatus {
        RailServiceStatus.from(trip)
    }

    private var timeFormat: UserPreferences.TimeFormat {
        interfacePreferences.timeFormat
    }

    private var formattedETA: String {
        trip.eta.formattedAsTime(in: trip.destination.timeZone, format: timeFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    Text(trip.service)
                        .font(RailDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                    Text(trip.train)
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    SourceBadge(trip: trip)
                }

                Spacer(minLength: RailDesign.Spacing.s)
                ServiceStatusPill(status: status)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(trip.train), \(trip.service), \(status.accessibilityTitle)")

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
                        .padding(.vertical, 6)
                        .background(RailDesign.Palette.inset, in: Capsule())
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
                        Text("ETA \(formattedETA)")
                            .font(.caption)
                            .foregroundStyle(status.tint)
                    }
                }
            }

            if !trip.alerts.isEmpty && role != .compact {
                AlertStrip(alert: trip.alerts[0])
            }
        }
        .padding(RailDesign.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(role == .active ? RailDesign.Palette.inset : RailDesign.Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.train), \(trip.origin.name) to \(trip.destination.name), \(trip.status), platform \(trip.displayPlatform), \(trip.sourceProvenance.sourceKind.riderTitle) source, \(trip.sourceProvenance.freshness.displayName)")
    }
}

struct StopTimelineRow: View {
    let stop: StationStop
    let isLast: Bool
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var tint: Color {
        switch stop.state {
        case .done:
            return RailDesign.Palette.success
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

    private var timeFormat: UserPreferences.TimeFormat {
        interfacePreferences.timeFormat
    }

    private var timeZone: TimeZone {
        TimeZone(identifier: "Asia/Tokyo")!
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
                    Text(stop.time.formattedAsTime(in: timeZone, format: timeFormat))
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
                    .background(tint.opacity(0.14), in: Circle())
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
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
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
        VStack(spacing: RailDesign.Spacing.m) {
            Image(systemName: symbolName)
                .font(.system(size: 36, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 56, height: 56)
                .background(RailDesign.Palette.accent.opacity(0.12), in: Circle())

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
                Button(action: action) {
                    Label(actionTitle, systemImage: "plus")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .padding(.vertical, RailDesign.Spacing.s)
                        .background(RailDesign.Palette.accent, in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
                        .foregroundStyle(RailDesign.Palette.onAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(RailDesign.Spacing.l)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

struct LoadingSkeletonView: View {
    var rows: Int = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerOffset: CGFloat = -0.6

    var body: some View {
        VStack(spacing: RailDesign.Spacing.m) {
            ForEach(0..<rows, id: \.self) { index in
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
                .padding(RailDesign.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                )
                .redacted(reason: .placeholder)
                .opacity(reduceMotion ? 0.72 : 0.92)
                .overlay {
                    if !reduceMotion {
                        GeometryReader { proxy in
                            LinearGradient(
                                colors: [.clear, RailDesign.Palette.panel.opacity(0.85), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: proxy.size.width * 0.5)
                            .offset(x: shimmerOffset * proxy.size.width)
                            .blendMode(.plusLighter)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading rail updates")
        .task {
            guard !reduceMotion else { return }
            withAnimation(RailDesign.Motion.shimmer) {
                shimmerOffset = 1.6
            }
        }
    }
}

struct OfflineBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(RailDesign.Palette.warning)
                .font(RailDesign.Typography.h3)
                .frame(width: 28, height: 28)
                .background(RailDesign.Palette.warning.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text("Offline mode")
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(message)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let retry {
                    Button("Try again", action: retry)
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.warning)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.top, RailDesign.Spacing.xxs)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(RailDesign.Palette.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.warning.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

/// Warning banner for a previously fetched provider response that is outside
/// its fresh window but still inside the proxy's bounded fallback window.
struct StaleDataBanner: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundStyle(RailDesign.Palette.warning)
                .font(RailDesign.Typography.h3)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text("Stale NS data")
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(message)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let retry {
                    Button("Refresh", action: retry)
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.warning)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(RailDesign.Palette.warningSoft, in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.warning.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

/// Retryable provider-throttle state with a full-size interaction target.
struct RateLimitBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "hourglass")
                .foregroundStyle(RailDesign.Palette.warning)
                .font(RailDesign.Typography.h3)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text("NS is busy")
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(message)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again", action: retry)
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.warning)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(RailDesign.Palette.warningSoft, in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.warning.opacity(0.20), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}

/// Plain-language source, attribution, and freshness disclosure for provider
/// surfaces that are not modeled as tracked trips.
struct RailSourceDisclosure: View {
    let sourceName: String
    let attribution: String
    let freshness: FreshnessState
    let fetchedAt: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        RailSurface(role: .accent(RailDesign.Palette.info)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        sourceHeading
                        freshnessBadge
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        sourceHeading
                        Spacer(minLength: RailDesign.Spacing.xs)
                        freshnessBadge
                    }
                }
                Text(verbatim: sourceName)
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: attribution)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let fetchedAt {
                    Text("Fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var sourceHeading: some View {
        Label("Source", systemImage: "checkmark.seal")
            .font(RailDesign.Typography.h3)
            .foregroundStyle(RailDesign.Palette.ink)
    }

    private var freshnessBadge: some View {
        RailBadge(
            freshness.displayName,
            tint: freshness == .fresh ? RailDesign.Palette.success : RailDesign.Palette.warning
        )
    }

    private var accessibilitySummary: String {
        var parts = ["Source \(sourceName)", attribution, freshness.displayName]
        if let fetchedAt {
            parts.append("Fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: ". ")
    }
}

private struct StationColumn: View {
    let title: String
    let time: String
    let timeZone: TimeZone
    var alignment: HorizontalAlignment = .leading
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    init(title: String, time: String, alignment: HorizontalAlignment = .leading) {
        self.title = title
        self.time = time
        self.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        self.alignment = alignment
    }

    var body: some View {
        VStack(alignment: alignment, spacing: RailDesign.Spacing.xxs) {
            Text(time.formattedAsTime(in: timeZone, format: timeFormat))
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

    private var timeFormat: UserPreferences.TimeFormat {
        interfacePreferences.timeFormat
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
                .foregroundStyle(alert.tone == .good ? RailDesign.Palette.success : RailDesign.Palette.warning)
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

// // // // // // // #Preview("Trip Card") {
// // // // // // //     TrainTripCard(trip: TrainTrip.samples[0], role: .active)
// // // // // // //         .padding()
// // // // // // //         .background(RailGradientBackground())
// // // // // // // }

// // // // // // // #Preview("States") {
// // // // // // //     VStack(spacing: 16) {
// // // // // // //         OfflineBanner(message: "Saved journeys are available until source data returns.")
// // // // // // //         EmptyStateView(title: "No journeys yet", message: "Search by train number, route, operator, or station pair.")
// // // // // // //         LoadingSkeletonView(rows: 1)
// // // // // // //     }
// // // // // // //     .padding()
// // // // // // //     .background(RailGradientBackground())
// // // // // // // }


// MARK: - Banners

/// Inline success banner used after pin/notify/share actions and
/// provider-state changes. Renders as a single tinted strip with an icon,
/// title, and optional message. Auto-dismisses after 2.4s.
struct SuccessBanner: View {
    let symbol: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(RailDesign.Palette.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                if let message {
                    Text(message)
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.s)
        .background(RailDesign.Palette.success.opacity(0.10), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.success.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Inline error banner for inline form errors and provider failures. Pairs
/// with OfflineBanner (which is a `wifi.slash` variant) and SuccessBanner
/// (positive). Uses `--status-danger`.
struct ErrorBanner: View {
    let symbol: String
    let title: LocalizedStringKey
    var detail: LocalizedStringKey? = nil
    var retry: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(RailDesign.Palette.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RailDesign.Typography.small.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                if let detail {
                    Text(detail)
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(3)
                }
                if let retry {
                    Button("Try again", action: retry)
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.accent)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.top, RailDesign.Spacing.xxs)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.s)
        .background(RailDesign.Palette.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(RailDesign.Palette.danger.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
