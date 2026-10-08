import SwiftUI
import UIKit

/// The Stations tab: one directory for station search, favorites, and
/// departure boards, driven by whichever provider it is given.
struct StationsScreen: View {
    @StateObject private var viewModel: StationDirectoryViewModel
    @ObservedObject private var favorites: StationFavoritesStore
    private let provider: any StationDataProviding

    init(provider: any StationDataProviding, favorites: StationFavoritesStore, startsLoading: Bool) {
        self.provider = provider
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(
            wrappedValue: StationDirectoryViewModel(provider: provider, initialPhase: startsLoading ? .loading : .idle)
        )
    }

    init(provider: any StationDataProviding, favorites: StationFavoritesStore, viewModel: StationDirectoryViewModel) {
        self.provider = provider
        _favorites = ObservedObject(wrappedValue: favorites)
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                RailSurface(role: .accent(RailDesign.Palette.accent)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        Label("Station departures", systemImage: "tram.circle")
                            .font(RailDesign.Typography.h2)
                            .foregroundStyle(RailDesign.Palette.ink)
                        Text("Search a station, open its departure board, and star the ones you check often. Every board shows its source and freshness. Provider credentials stay behind Trainy's proxy.")
                            .font(RailDesign.Typography.small)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                RailSearchField(
                    title: "Find a station",
                    prompt: "Station name or code",
                    text: $viewModel.query,
                    action: viewModel.submitSearch,
                    accessibilityIdentifierPrefix: "ns.stationSearch"
                )

                if case .idle = viewModel.phase {
                    idleContent
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
        .navigationTitle("Stations")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.query) { _, _ in viewModel.scheduleSearch() }
        .onChange(of: viewModel.accessibilityAnnouncement) { _, announcement in
            announce(announcement)
        }
        .accessibilityIdentifier("stations.screen")
        .railScreenChrome()
    }

    /// What the tab shows before the rider has searched: favorites, common
    /// stations, and where boards are available.
    @ViewBuilder
    private var idleContent: some View {
        if provider.isConfigured {
            favoritesSection
            suggestedSearches
        } else {
            notConfiguredView
        }
        coverageNote
    }

    @ViewBuilder
    private var favoritesSection: some View {
        let favoriteStations = favorites.favorites(for: provider.providerID)
        if !favoriteStations.isEmpty {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                SectionHeader(title: "Favorites", subtitle: "Starred stations open their departure board")
                ForEach(favoriteStations) { favorite in
                    stationLink(favorite.station, identifier: "stations.favorite.\(favorite.code)")
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedSearches: some View {
        if !viewModel.suggestedSearches.isEmpty {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                SectionHeader(title: "Common stations", subtitle: "Suggestions start a source-backed station lookup")
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
    }

    private var coverageNote: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                Label("Where boards are available", systemImage: "map")
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text("Departure boards cover \(provider.displayName) today. For trains elsewhere, such as Shinkansen journeys, use Search.")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    // SearchScreen listens for this and takes focus.
                    NotificationCenter.default.post(name: .trainyFocusSearch, object: nil)
                } label: {
                    RailActionLabel(title: "Search trains", symbol: "magnifyingglass", role: .secondary)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityIdentifier("stations.coverage")
            }
        }
    }

    private var notConfiguredView: some View {
        EmptyStateView(
            title: "NS departures aren't configured",
            message: "This build has no provider proxy base URL. No NS credential belongs in the app.",
            symbolName: "lock.shield"
        )
        .accessibilityIdentifier("ns.stationSearch.notConfigured")
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
            EmptyView()
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
                    stationLink(station, identifier: "ns.station.\(station.code)")
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

    /// One row that opens a station's board. Favorites and search results share
    /// it so a station looks and reads the same wherever it appears.
    private func stationLink(_ station: ProviderStation, identifier: String) -> some View {
        NavigationLink {
            StationBoardView(station: station, provider: provider, favorites: favorites)
        } label: {
            RailSurface {
                RailNavigationCard(
                    symbol: favorites.isFavorite(station) ? "star.fill" : "tram.fill",
                    verbatimTitle: station.name,
                    detail: stationDetail(station),
                    tint: RailDesign.Palette.accent
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(station.name), station code \(station.code)")
        .accessibilityValue(favorites.isFavorite(station) ? "Favorite" : "")
        .accessibilityHint("Opens the departure board")
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func failureView(_ failure: StationDataFailure) -> some View {
        switch failure {
        case .notConfigured:
            notConfiguredView
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
        let region = station.countryCode.flatMap { Locale.current.localizedString(forRegionCode: $0) }
            ?? provider.displayName
        return "Station code \(station.code) · \(region)"
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
