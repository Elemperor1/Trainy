import SwiftUI
import UIKit

struct NSStationSearchView: View {
    @StateObject private var viewModel: NSStationSearchViewModel
    private let provider: any NSRiderDataProviding

    init(proxyBaseURL: URL?) {
        let provider = NSTrainProvider(proxyBaseURL: proxyBaseURL)
        self.provider = provider
        _viewModel = StateObject(wrappedValue: NSStationSearchViewModel(provider: provider))
    }

    init(provider: any NSRiderDataProviding, startsLoading: Bool) {
        self.provider = provider
        _viewModel = StateObject(
            wrappedValue: NSStationSearchViewModel(provider: provider, initialPhase: startsLoading ? .loading : .idle)
        )
    }

    init(provider: any NSRiderDataProviding, viewModel: NSStationSearchViewModel) {
        self.provider = provider
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                RailSurface(role: .accent(RailDesign.Palette.accent)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        Label("NS departures", systemImage: "train.side.front.car")
                            .font(RailDesign.Typography.h2)
                            .foregroundStyle(RailDesign.Palette.ink)
                        Text("Search Dutch stations, then open a departure board with explicit freshness. NS credentials stay behind Trainy's provider proxy.")
                            .font(RailDesign.Typography.small)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RailSearchField(
                    title: "Find a station",
                    prompt: "Dutch station name or code",
                    text: $viewModel.query,
                    action: viewModel.submitSearch,
                    accessibilityIdentifierPrefix: "ns.stationSearch"
                )

                if case .idle = viewModel.phase {
                    suggestedSearches
                }

                notice
                phaseContent

                if let source = viewModel.sourceProvenance, !viewModel.stations.isEmpty {
                    RailSourceDisclosure(
                        sourceName: source.sourceName,
                        attribution: source.attributionText ?? "Data from Nederlandse Spoorwegen (NS)",
                        freshness: viewModel.sourceFreshness,
                        fetchedAt: source.fetchedAt
                    )
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("NS departures")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.query) { _, _ in viewModel.scheduleSearch() }
        .onChange(of: viewModel.accessibilityAnnouncement) { _, announcement in
            announce(announcement)
        }
        .accessibilityIdentifier("ns.stationSearch.screen")
        .railScreenChrome()
    }

    private var suggestedSearches: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Common stations", subtitle: "Suggestions start a source-backed NS station lookup")
            ForEach(viewModel.suggestedSearches, id: \.self) { suggestion in
                Button {
                    viewModel.useSuggestion(suggestion)
                } label: {
                    RailActionLabel(title: LocalizedStringKey(suggestion), symbol: "magnifyingglass", role: .secondary)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Search for \(suggestion)")
            }
        }
    }

    @ViewBuilder
    private var notice: some View {
        switch viewModel.notice {
        case .stale:
            StaleDataBanner(
                message: "These station results came from the proxy's bounded fallback cache. Refresh before relying on them.",
                retry: viewModel.retry
            )
        case .offline:
            OfflineBanner(
                message: "Showing your last results for this search. Refresh when connectivity returns.",
                retry: viewModel.retry
            )
        case .rateLimited(let retryAfterSeconds):
            RateLimitBanner(message: rateLimitMessage(retryAfterSeconds), retry: viewModel.retry)
        case .unavailable:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "Could not refresh stations",
                detail: "Showing your last results for this search.",
                retry: viewModel.retry
            )
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch viewModel.phase {
        case .idle:
            EmptyStateView(
                title: "Find an NS station",
                message: "Enter at least two characters or choose a common station.",
                symbolName: "tram"
            )
        case .loading:
            LoadingSkeletonView(rows: 4)
                .accessibilityIdentifier("ns.stationSearch.loading")
        case .results:
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                SectionHeader(
                    title: "Stations",
                    subtitle: "\(viewModel.stations.count) source-backed \(viewModel.stations.count == 1 ? "match" : "matches")"
                )
                ForEach(viewModel.stations) { station in
                    NavigationLink {
                        NSDepartureBoardView(station: station, provider: provider)
                    } label: {
                        RailSurface {
                            RailNavigationCard(
                                symbol: "tram.fill",
                                verbatimTitle: station.name,
                                detail: stationDetail(station),
                                tint: RailDesign.Palette.accent
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(station.name), station code \(station.code)")
                    .accessibilityHint("Opens the NS departure board")
                    .accessibilityIdentifier("ns.station.\(station.code)")
                }
            }
        case .noMatches:
            EmptyStateView(
                title: "No NS station found",
                message: "Check the spelling or try a station code such as UT or ASD.",
                symbolName: "magnifyingglass"
            )
            .accessibilityIdentifier("ns.stationSearch.noMatches")
        case .failed(let failure):
            failureView(failure)
        }
    }

    @ViewBuilder
    private func failureView(_ failure: NSRiderFailure) -> some View {
        switch failure {
        case .notConfigured:
            EmptyStateView(
                title: "NS departures aren't configured",
                message: "This build has no provider proxy base URL. No NS credential belongs in the app.",
                symbolName: "lock.shield"
            )
            .accessibilityIdentifier("ns.stationSearch.notConfigured")
        case .offline:
            OfflineBanner(message: failure.message, retry: viewModel.retry)
                .accessibilityIdentifier("ns.stationSearch.offline")
        case .rateLimited(let retryAfterSeconds):
            RateLimitBanner(message: rateLimitMessage(retryAfterSeconds), retry: viewModel.retry)
                .accessibilityIdentifier("ns.stationSearch.rateLimited")
        case .unavailable:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "NS stations unavailable",
                detail: "Try again. Your tracked Trainy journeys are unchanged.",
                retry: viewModel.retry
            )
            .accessibilityIdentifier("ns.stationSearch.unavailable")
        }
    }

    private func stationDetail(_ station: ProviderStation) -> String {
        let country = station.countryCode == "NL" ? "Netherlands" : (station.countryCode ?? "NS network")
        return "Station code \(station.code) · \(country)"
    }

    private func rateLimitMessage(_ seconds: Int?) -> String {
        if let seconds { return "Try again in about \(seconds) seconds." }
        return "Try again shortly."
    }

    private func announce(_ announcement: String) {
        guard !announcement.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

struct NSDepartureBoardView: View {
    @StateObject private var viewModel: NSDepartureBoardViewModel

    init(station: ProviderStation, provider: any NSRiderDataProviding) {
        _viewModel = StateObject(
            wrappedValue: NSDepartureBoardViewModel(station: station, provider: provider)
        )
    }

    init(viewModel: NSDepartureBoardViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                RailSurface(role: .accent(RailDesign.Palette.accent)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(verbatim: viewModel.station.name)
                            .font(RailDesign.Typography.h2)
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("NS station code \(viewModel.station.code)")
                            .font(RailDesign.Typography.small)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                }

                boardNotice
                boardContent

                serviceAlertsSection

                if let source = viewModel.board?.sourceProvenance {
                    RailSourceDisclosure(
                        sourceName: source.sourceName,
                        attribution: source.attributionText ?? "Data from Nederlandse Spoorwegen (NS)",
                        freshness: viewModel.boardFreshness,
                        fetchedAt: source.fetchedAt
                    )
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Departures")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .task {
            guard viewModel.phase == .idle else { return }
            await viewModel.load()
        }
        .onChange(of: viewModel.accessibilityAnnouncement) { _, announcement in
            announce(announcement)
        }
        .accessibilityIdentifier("ns.departures.screen")
        .railScreenChrome()
    }

    @ViewBuilder
    private var boardNotice: some View {
        switch viewModel.notice {
        case .stale:
            StaleDataBanner(
                message: "These departures are outside the fresh window. Check station displays before boarding.",
                retry: viewModel.retry
            )
        case .offline:
            OfflineBanner(
                message: "Showing the last departure board loaded for this station.",
                retry: viewModel.retry
            )
        case .rateLimited(let retryAfterSeconds):
            RateLimitBanner(message: rateLimitMessage(retryAfterSeconds), retry: viewModel.retry)
        case .unavailable:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "Could not refresh departures",
                detail: "Showing the last board loaded for this station.",
                retry: viewModel.retry
            )
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var boardContent: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LoadingSkeletonView(rows: 5)
        case .loaded:
            if let board = viewModel.board {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(
                        title: "Upcoming departures",
                        subtitle: departureSubtitle(count: board.departures.count)
                    )
                    ForEach(board.departures) { departure in
                        NSDepartureRow(departure: departure)
                            .accessibilityIdentifier("ns.departure.\(departure.tripID ?? departure.id)")
                    }
                }
            }
        case .empty:
            EmptyStateView(
                title: "No upcoming departures",
                message: emptyDepartureMessage,
                symbolName: "clock"
            )
        case .failed(let failure):
            boardFailure(failure)
        }
    }

    @ViewBuilder
    private var serviceAlertsSection: some View {
        switch viewModel.alertPhase {
        case .idle:
            EmptyView()
        case .loading:
            LoadingSkeletonView(rows: 1)
        case .loaded:
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                alertNotice
                SectionHeader(
                    title: "Service alerts",
                    subtitle: alertSubtitle(count: viewModel.alerts.count)
                )
                ForEach(viewModel.alerts) { alert in
                    RailSurface(role: .status(alert.tone == .late ? RailDesign.Palette.danger : RailDesign.Palette.warning)) {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                            Label {
                                Text(verbatim: alert.title)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .font(RailDesign.Typography.h3)
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: alert.detail)
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                alertSourceDisclosure
            }
        case .empty:
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                alertNotice
                EmptyStateView(
                    title: "No service alerts in the response",
                    message: emptyAlertMessage,
                    symbolName: "checkmark.shield"
                )
                alertSourceDisclosure
            }
        case .failed:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "Service alerts unavailable",
                detail: "The departure board loaded, but Trainy could not verify NS disruption notices.",
                retry: viewModel.retry
            )
        }
    }

    @ViewBuilder
    private var alertNotice: some View {
        switch viewModel.alertNotice {
        case .stale:
            StaleDataBanner(
                message: "These service notices are outside their fresh window. Refresh before relying on them.",
                retry: viewModel.retry
            )
        case .offline:
            OfflineBanner(
                message: "Showing the last service-alert response loaded for this station.",
                retry: viewModel.retry
            )
        case .rateLimited(let retryAfterSeconds):
            RateLimitBanner(message: rateLimitMessage(retryAfterSeconds), retry: viewModel.retry)
        case .unavailable:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "Could not refresh service alerts",
                detail: "Showing the last service-alert response loaded for this station.",
                retry: viewModel.retry
            )
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var alertSourceDisclosure: some View {
        if let source = viewModel.alertSourceProvenance {
            RailSourceDisclosure(
                sourceName: source.sourceName,
                attribution: source.attributionText ?? "Data from Nederlandse Spoorwegen (NS)",
                freshness: viewModel.alertFreshness,
                fetchedAt: source.fetchedAt
            )
        }
    }

    private func departureSubtitle(count: Int) -> String {
        let noun = count == 1 ? "service" : "services"
        switch viewModel.boardFreshness {
        case .fresh:
            return "\(count) fresh \(noun)"
        case .stale, .expired:
            return "\(count) saved \(noun) · refresh before relying"
        case .unknown:
            return "\(count) \(noun) · freshness unknown"
        }
    }

    private var emptyDepartureMessage: LocalizedStringKey {
        switch viewModel.boardFreshness {
        case .fresh:
            return "NS returned no departures within this fresh response. Pull to refresh."
        case .stale, .expired:
            return "The saved response contained no departures. Refresh before relying on it."
        case .unknown:
            return "The response contained no departures, but its freshness is unknown. Pull to refresh."
        }
    }

    private func alertSubtitle(count: Int) -> String {
        let noun = count == 1 ? "notice" : "notices"
        switch viewModel.alertFreshness {
        case .fresh:
            return "\(count) fresh NS \(noun)"
        case .stale, .expired:
            return "\(count) saved \(noun) · refresh before relying"
        case .unknown:
            return "\(count) \(noun) · freshness unknown"
        }
    }

    private var emptyAlertMessage: LocalizedStringKey {
        switch viewModel.alertFreshness {
        case .fresh:
            return "NS reported no relevant active notices in this fresh response."
        case .stale, .expired:
            return "The saved alert response contained no notices. Refresh before relying on it."
        case .unknown:
            return "The alert response contained no notices, but its freshness is unknown."
        }
    }

    @ViewBuilder
    private func boardFailure(_ failure: NSRiderFailure) -> some View {
        switch failure {
        case .notConfigured:
            EmptyStateView(
                title: "NS departures aren't configured",
                message: "This build has no provider proxy base URL. No NS credential belongs in the app.",
                symbolName: "lock.shield"
            )
        case .offline:
            OfflineBanner(message: failure.message, retry: viewModel.retry)
        case .rateLimited(let retryAfterSeconds):
            RateLimitBanner(message: rateLimitMessage(retryAfterSeconds), retry: viewModel.retry)
        case .unavailable:
            ErrorBanner(
                symbol: "exclamationmark.triangle",
                title: "NS departures unavailable",
                detail: "Try again. Your tracked Trainy journeys are unchanged.",
                retry: viewModel.retry
            )
        }
    }

    private func rateLimitMessage(_ seconds: Int?) -> String {
        if let seconds { return "Try again in about \(seconds) seconds." }
        return "Try again shortly."
    }

    private func announce(_ announcement: String) {
        guard !announcement.isEmpty, UIAccessibility.isVoiceOverRunning else { return }
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

private struct NSDepartureRow: View {
    let departure: StationBoardDeparture

    var body: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.s) {
                        departureTime
                        Spacer(minLength: RailDesign.Spacing.xs)
                        statusBadge
                    }
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        departureTime
                        statusBadge
                    }
                }

                Text(verbatim: departure.destinationName)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verbatim: departure.trainName)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: RailDesign.Spacing.m) {
                        departureMetadata
                    }
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        departureMetadata
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var departureMetadata: some View {
        if let estimatedDeparture = departure.estimatedDeparture,
           estimatedDeparture != departure.scheduledDeparture {
            Label("Expected \(estimatedDeparture)", systemImage: "clock.badge.exclamationmark")
                .font(RailDesign.Typography.small.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.warning)
                .fixedSize(horizontal: false, vertical: true)
        }
        Label(
            departure.platform.map { "Platform \($0)" } ?? "Platform not announced",
            systemImage: "rectangle.split.3x1"
        )
        .font(RailDesign.Typography.small)
        .foregroundStyle(RailDesign.Palette.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusText: String {
        departure.status ?? "Scheduled"
    }

    private var departureTime: some View {
        Text(verbatim: departure.scheduledDeparture)
            .font(RailDesign.Typography.h2.monospacedDigit())
            .foregroundStyle(RailDesign.Palette.ink)
    }

    private var statusBadge: some View {
        RailBadge(statusText, tint: statusTint)
    }

    private var statusTint: Color {
        let status = statusText.lowercased()
        if status.contains("cancel") || status.contains("delay") { return RailDesign.Palette.danger }
        if status.contains("board") || status.contains("arriv") || status.contains("platform") { return RailDesign.Palette.warning }
        if status.contains("on time") { return RailDesign.Palette.success }
        return RailDesign.Palette.info
    }

    private var accessibilityLabel: String {
        var parts = [
            "\(departure.scheduledDeparture) departure to \(departure.destinationName)",
            departure.trainName,
            statusText
        ]
        if let expected = departure.estimatedDeparture, expected != departure.scheduledDeparture {
            parts.append("expected \(expected)")
        }
        parts.append(departure.platform.map { "platform \($0)" } ?? "platform not announced")
        return parts.joined(separator: ", ")
    }
}
