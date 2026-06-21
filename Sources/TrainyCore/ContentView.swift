import MapKit
import SwiftUI
import UIKit

public struct ContentView: View {
    @StateObject private var store = TrainStore()
    @State private var selectedTab: RailTab = .trips
    @State private var presentedSheet: RailSheet?

    public init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(RailDesign.Palette.panel)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(RailDesign.Palette.accent.opacity(0.78))
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(RailDesign.Palette.accent.opacity(0.78))
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.secondaryLabel
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TripsScreen(store: store)
            }
            .tabItem { Label(RailTab.trips.title, systemImage: RailTab.trips.symbolName) }
            .tag(RailTab.trips)

            NavigationStack {
                SearchScreen(store: store)
            }
            .tabItem { Label(RailTab.search.title, systemImage: RailTab.search.symbolName) }
            .tag(RailTab.search)

            NavigationStack {
                StationsScreen(store: store)
            }
            .tabItem { Label(RailTab.stations.title, systemImage: RailTab.stations.symbolName) }
            .tag(RailTab.stations)

            NavigationStack {
                HistoryScreen(store: store)
            }
            .tabItem { Label(RailTab.history.title, systemImage: RailTab.history.symbolName) }
            .tag(RailTab.history)

            NavigationStack {
                SettingsScreen(store: store)
            }
            .tabItem { Label(RailTab.settings.title, systemImage: RailTab.settings.symbolName) }
            .tag(RailTab.settings)
        }
        .tint(RailDesign.Palette.accent.opacity(0.78))
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            await store.bootstrapLiveData()
        }
        .onAppear {
            presentFirstRunIfNeeded()
        }
        .onChange(of: store.shouldShowFirstRun) { _, shouldShowFirstRun in
            presentedSheet = shouldShowFirstRun ? .firstRun : nil
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .firstRun:
                FirstRunExperienceSheet(
                    store: store,
                    startWithShinkansen: {
                        store.startFirstRunWithShinkansen()
                        selectedTab = .trips
                        presentedSheet = nil
                    },
                    explorePlannedRegions: {
                        store.explorePlannedRegionsFromFirstRun()
                        selectedTab = .settings
                        presentedSheet = nil
                    },
                    skip: {
                        store.completeFirstRun()
                        presentedSheet = nil
                    }
                )
                .interactiveDismissDisabled()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private func presentFirstRunIfNeeded() {
        guard store.shouldShowFirstRun else { return }
        presentedSheet = .firstRun
    }
}

private enum RailTab: Hashable {
    case trips
    case search
    case stations
    case history
    case settings

    var title: LocalizedStringKey {
        switch self {
        case .trips:
            return "Trips"
        case .search:
            return "Search"
        case .stations:
            return "Stations"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }

    var symbolName: String {
        switch self {
        case .trips:
            return "train.side.front.car"
        case .search:
            return "magnifyingglass"
        case .stations:
            return "tram.circle"
        case .history:
            return "chart.bar.xaxis"
        case .settings:
            return "gearshape"
        }
    }
}

private enum RailSheet: Identifiable {
    case firstRun

    var id: String {
        switch self {
        case .firstRun:
            return "first-run"
        }
    }
}

private struct FirstRunExperienceSheet: View {
    @ObservedObject var store: TrainStore
    let startWithShinkansen: () -> Void
    let explorePlannedRegions: () -> Void
    let skip: () -> Void

    private var activeProvider: ProviderMetadata? {
        store.providerDirectory.first { $0.id == store.activeProviderID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    FirstRunHeader()

                    FirstRunDefaultProviderCard(provider: activeProvider)

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Data scope", subtitle: "What each label means before global providers arrive")
                        GlassPanel {
                            VStack(spacing: 0) {
                                FirstRunScopeRow(
                                    symbol: "books.vertical.fill",
                                    title: "Starter catalog",
                                    detail: "Curated Shinkansen examples are available even without provider credentials."
                                )
                                Divider()
                                    .background(RailDesign.Palette.hairline)
                                FirstRunScopeRow(
                                    symbol: "calendar.badge.checkmark",
                                    title: "Official timetable",
                                    detail: "ODPT and JR timetable results are shown as scheduled data when those sources return trips."
                                )
                                Divider()
                                    .background(RailDesign.Palette.hairline)
                                FirstRunScopeRow(
                                    symbol: "dot.radiowaves.left.and.right",
                                    title: "Realtime",
                                    detail: "Predictions and vehicle positions stay off unless a provider supplies those exact feeds."
                                )
                            }
                        }
                    }

                    GlassPanel(tint: RailDesign.Palette.amber.opacity(0.12)) {
                        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                            Image(systemName: "hammer.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(RailDesign.Palette.amber)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                                Text("Planned regions are roadmap entries")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(RailDesign.Palette.ink)
                                Text("They remain unavailable for search until credentials, fixtures, source labels, and provider adapters are complete.")
                                    .font(.caption)
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                }
                .padding(RailDesign.Spacing.m)
                .padding(.bottom, 148)
            }
            .background(RailGradientBackground().ignoresSafeArea())
            .navigationTitle("Trainy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: skip)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .safeAreaInset(edge: .bottom) {
                FirstRunActionBar(
                    startWithShinkansen: startWithShinkansen,
                    explorePlannedRegions: explorePlannedRegions
                )
            }
        }
    }
}

private struct FirstRunHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            Image(systemName: "checklist.checked")
                .font(.system(size: 46, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 58, height: 58)
                .background(RailDesign.Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                Text("Start with the Japan Shinkansen")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Trainy opens with one implemented provider and clear source labels. Global regions are visible in Settings as planned work, not searchable service.")
                    .font(.subheadline)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct FirstRunDefaultProviderCard: View {
    let provider: ProviderMetadata?

    var body: some View {
        GlassPanel(cornerRadius: 26, tint: RailDesign.Palette.accent.opacity(0.14)) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.m) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RailDesign.Palette.mint)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text(provider?.displayName ?? "Japan Shinkansen")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ProviderStatusPill(text: "Selected default", tint: RailDesign.Palette.mint)
                    }

                    Text("\(provider?.region.displayName ?? "Japan") / schedule-only search")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(provider?.availability.message ?? "Uses the Shinkansen starter catalog and official timetable sources when available.")
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Japan Shinkansen selected default")
    }
}

private struct FirstRunActionBar: View {
    let startWithShinkansen: () -> Void
    let explorePlannedRegions: () -> Void

    var body: some View {
        VStack(spacing: RailDesign.Spacing.s) {
            Button(action: startWithShinkansen) {
                Label("Start with Shinkansen", systemImage: "train.side.front.car")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RailDesign.Spacing.s)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(RailDesign.Palette.accent)
            .accessibilityHint("Uses Japan Shinkansen as the selected rail scope.")

            Button(action: explorePlannedRegions) {
                Label("Explore planned regions", systemImage: "globe.asia.australia")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, RailDesign.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(RailDesign.Palette.marine)
            .accessibilityHint("Opens provider settings with planned regions shown as unavailable.")
        }
        .padding(.horizontal, RailDesign.Spacing.m)
        .padding(.top, RailDesign.Spacing.s)
        .padding(.bottom, RailDesign.Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
                .background(RailDesign.Palette.hairline)
        }
    }
}

private struct FirstRunScopeRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

private struct TripRoute: Identifiable, Hashable {
    let id: TrainTrip.ID
}

private struct RailMapRoute: Identifiable, Hashable {
    let id: TrainTrip.ID
}

private struct TripsScreen: View {
    @ObservedObject var store: TrainStore
    @State private var bucket: TripBucket = .active
    @State private var isShowingAddTrip = false
    @State private var selectedTripRoute: TripRoute?
    @State private var selectedMapRoute: RailMapRoute?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayedTrips: [TrainTrip] {
        switch bucket {
        case .upcoming:
            return store.filteredTrips.filter { $0.progress <= 0.12 }
        case .active:
            return store.filteredTrips.filter { $0.progress > 0.12 && $0.progress < 0.95 }
        case .past:
            return store.filteredTrips.filter { $0.progress >= 0.95 }
        }
    }

    var body: some View {
        List {
            Section {
                TripsHeaderRow(statusText: store.liveStatusText.railFeedDisplayText) {
                    isShowingAddTrip = true
                }
                .listCardRow()

                if let offlineMessage = store.offlineMessage {
                    OfflineBanner(message: offlineMessage)
                        .listCardRow()
                }

                if store.liveLoadState == .loading && store.trips.isEmpty {
                    LoadingSkeletonView(rows: 3)
                        .listCardRow()
                } else if store.trips.isEmpty {
                    EmptyStateView(
                        title: "No saved journeys",
                        message: "Search by train number, route, station pair, operator, or time to start tracking.",
                        actionTitle: "Add Trip"
                    ) {
                        isShowingAddTrip = true
                    }
                    .listCardRow()
                } else if let selectedTrip = store.selectedTrip {
                    ActiveTripSummary(trip: selectedTrip, store: store) {
                        selectedMapRoute = RailMapRoute(id: selectedTrip.id)
                    }
                    .listCardRow()
                }
            }

            Section {
                RailSegmentedPicker(selection: $bucket)
                    .listCardRow()
            }

            Section {
                if displayedTrips.isEmpty && !store.trips.isEmpty {
                    EmptyStateView(
                        title: bucket.emptyTitle,
                        message: bucket.emptyMessage,
                        symbolName: bucket.emptySymbol,
                        actionTitle: "Search Rail"
                    ) {
                        isShowingAddTrip = true
                    }
                    .listCardRow()
                } else {
                    ForEach(displayedTrips) { trip in
                        Button {
                            selectedTripRoute = TripRoute(id: trip.id)
                        } label: {
                            TrainTripCard(trip: trip, role: bucket.cardRole)
                        }
                        .buttonStyle(.plain)
                        .listCardRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                store.togglePin(for: trip)
                            } label: {
                                Label(store.isPinned(trip) ? "Unfavorite" : "Favorite", systemImage: store.isPinned(trip) ? "star.slash" : "star")
                            }
                            .tint(RailDesign.Palette.amber)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                store.toggleNotification(for: trip)
                            } label: {
                                Label(store.isNotified(trip) ? "Mute" : "Notify", systemImage: store.isNotified(trip) ? "bell.slash" : "bell")
                            }
                            .tint(RailDesign.Palette.accent)
                        }
                        .contextMenu {
                            Button {
                                store.select(trip)
                            } label: {
                                Label("Make Active", systemImage: "scope")
                            }
                            Button {
                                store.toggleNotification(for: trip)
                            } label: {
                                Label(store.isNotified(trip) ? "Mute Updates" : "Notify Me", systemImage: "bell")
                            }
                            ShareLink(item: trip.shareText) {
                                Label("Share Trip", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                }
            } header: {
                SectionHeader(title: bucket.sectionTitle, subtitle: store.liveStatusText.railFeedDisplayText)
            }
        }
        .navigationDestination(item: $selectedTripRoute) { route in
            TrainDetailView(store: store, tripID: route.id)
        }
        .navigationDestination(item: $selectedMapRoute) { route in
            if let trip = store.trips.first(where: { $0.id == route.id }) ?? store.selectedTrip {
                RailJourneyMapScreen(trip: trip)
            } else {
                EmptyStateView(
                    title: "No map trip",
                    message: "Search and track a trip before opening the rail map.",
                    symbolName: "map"
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Trips")
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 104)
        }
        .refreshable {
            await store.searchLiveTrips(matching: store.query)
        }
        .sheet(isPresented: $isShowingAddTrip) {
            NavigationStack {
                SearchScreen(store: store, showsCloseButton: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .animation(reduceMotion ? nil : RailDesign.Motion.soft, value: bucket)
        .railScreenChrome()
    }
}

enum TripBucket: String, CaseIterable, Identifiable {
    case upcoming
    case active
    case past

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .active:
            return "Active"
        case .past:
            return "Past"
        }
    }

    var sectionTitle: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Ready to Depart"
        case .active:
            return "Current Journeys"
        case .past:
            return "Completed Journeys"
        }
    }

    var emptyTitle: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "No upcoming trips"
        case .active:
            return "No active trips"
        case .past:
            return "No completed trips"
        }
    }

    var emptyMessage: LocalizedStringKey {
        switch self {
        case .upcoming:
            return "Saved departures appear here before they leave the origin station."
        case .active:
            return "Journeys in motion show progress, the next stop, platforms, and transfer cautions."
        case .past:
            return "Completed journeys will move into history once arrival data is available."
        }
    }

    var emptySymbol: String {
        switch self {
        case .upcoming:
            return "calendar.badge.clock"
        case .active:
            return "tram"
        case .past:
            return "clock.arrow.circlepath"
        }
    }

    var cardRole: TrainTripCard.Role {
        switch self {
        case .upcoming:
            return .upcoming
        case .active:
            return .active
        case .past:
            return .past
        }
    }
}

private struct TripsHeaderRow: View {
    let statusText: String
    let addTrip: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: RailDesign.Spacing.m) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Trips")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(RailDesign.Palette.ink.opacity(0.70))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Button(action: addTrip) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .frame(width: 48, height: 48)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .railLiquidGlass(cornerRadius: 24, tint: .white.opacity(0.14), interactive: true, strokeOpacity: 0.30)
            .accessibilityLabel("Add trip")
        }
        .padding(.horizontal, RailDesign.Spacing.m)
        .padding(.vertical, RailDesign.Spacing.s)
        .railLiquidGlass(cornerRadius: 28, tint: .white.opacity(0.08), strokeOpacity: 0.24)
    }
}

private struct ActiveTripSummary: View {
    let trip: TrainTrip
    @ObservedObject var store: TrainStore
    let openMap: () -> Void
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue

    private var timeFormat: UserPreferences.TimeFormat {
        UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12
    }

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(in: trip.origin.timeZone, format: timeFormat)
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(in: trip.destination.timeZone, format: timeFormat)
    }

    private var formattedETA: String {
        trip.eta.formattedAsTime(in: trip.destination.timeZone, format: timeFormat)
    }

    var body: some View {
        GlassPanel(cornerRadius: 30, tint: .white.opacity(0.08), padding: 0) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Label(trip.sourceProvenance.liveSafeTripLabel, systemImage: "scope")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .padding(.horizontal, RailDesign.Spacing.s)
                            .padding(.vertical, 7)
                            .background(RailDesign.Palette.textSurface, in: Capsule())
                        SourceBadge(trip: trip)
                    }

                    Spacer()
                    ServiceStatusPill(status: RailServiceStatus.from(trip))
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    Text(trip.train)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                    Text("\(trip.origin.name) to \(trip.destination.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formattedOriginTime)
                                .font(.headline.monospacedDigit().weight(.bold))
                            Text(trip.origin.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formattedDestinationTime)
                                .font(.headline.monospacedDigit().weight(.bold))
                            Text(trip.destination.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .foregroundStyle(RailDesign.Palette.ink)

                    ProgressView(value: trip.progress)
                        .tint(RailServiceStatus.from(trip).tint)
                        .accessibilityLabel("Journey progress")
                        .accessibilityValue("\(Int(trip.progress * 100)) percent")
                }
                .padding(RailDesign.Spacing.m)
                .railLiquidGlass(cornerRadius: 22, tint: .white.opacity(0.13), strokeOpacity: 0.30)

                HStack(spacing: RailDesign.Spacing.xs) {
                    ControlMetricTile(title: "Next", value: trip.nextStop, symbol: "location.north.line.fill", tint: RailDesign.Palette.accent)
                    ControlMetricTile(title: "ETA", value: formattedETA, symbol: "clock", tint: RailDesign.Palette.violet)
                    ControlMetricTile(
                        title: "Platform",
                        value: trip.displayPlatform,
                        symbol: "rectangle.split.3x1.fill",
                        tint: trip.platformDisplayState.isKnown ? RailDesign.Palette.blue : RailDesign.Palette.secondaryText
                    )
                }

                Button(action: openMap) {
                    HStack(spacing: RailDesign.Spacing.s) {
                        Image(systemName: "map.fill")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.accent)
                            .frame(width: 34, height: 34)
                            .background(RailDesign.Palette.accent.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Open rail map")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(RailDesign.Palette.ink)
                            Text("Route line, map position, stops, and disruptions")
                                .font(.caption)
                                .foregroundStyle(RailDesign.Palette.ink.opacity(0.68))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                    .padding(RailDesign.Spacing.s)
                    .railLiquidGlass(cornerRadius: 22, tint: RailDesign.Palette.accent.opacity(0.12), interactive: true, strokeOpacity: 0.30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open rail map for \(trip.train)")

                HStack(spacing: RailDesign.Spacing.xs) {
                    Label("Trip tools", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Spacer(minLength: RailDesign.Spacing.xs)

                    Button {
                        store.refreshSelectedTrip()
                    } label: {
                        SummaryIconLabel(symbol: "arrow.clockwise", title: "Refresh")
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.toggleNotification(for: trip)
                    } label: {
                        SummaryIconLabel(symbol: store.isNotified(trip) ? "bell.fill" : "bell", title: "Alerts")
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: trip.shareText) {
                        SummaryIconLabel(symbol: "square.and.arrow.up", title: "Share")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, RailDesign.Spacing.xs)
            }
            .padding(RailDesign.Spacing.m)
        }
    }
}






private struct SearchScreen: View {
    @ObservedObject var store: TrainStore
    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchText = ""
    @State private var manualAddNotice = false

    private var results: [TrainTrip] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(store.discoveryTrips.prefix(8))
        }
        return store.searchableResults
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let offlineMessage = store.offlineMessage {
                    OfflineBanner(message: offlineMessage)
                }

                SearchHeroView(scopeText: store.searchScopeText, availability: store.activeProviderAvailability)

                if let notice = store.searchCapabilityNotice {
                    SearchCapabilityNoticeView(notice: notice)
                }

                if searchText.isEmpty {
                    RecentSearchesView(
                        examples: Array(store.searchExamples.prefix(4)),
                        providerName: store.activeProviderName
                    ) { value in
                        searchText = value
                    }
                    FavoriteStationsStrip(stations: store.stationSnapshots.prefix(6).map { $0.name }) { station in
                        searchText = station
                    }
                    SuggestedRoutesView(trips: Array(store.discoveryTrips.prefix(4))) { trip in
                        searchText = trip.service
                    }
                }

                SearchResultsSection(
                    title: searchText.isEmpty ? "Suggested services" : "Matching services",
                    isLoading: store.liveLoadState == .loading,
                    results: results,
                    query: searchText,
                    emptyState: store.searchEmptyState(for: searchText, results: results)
                ) { trip in
                    store.track(trip)
                    store.select(trip)
                    if showsCloseButton {
                        dismiss()
                    }
                } manualAdd: {
                    manualAddNotice = true
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Search")
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Train number, station pair, operator, route, or time"
        )
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: searchText) {
            await runSearch()
        }
        .alert("Manual trip note", isPresented: $manualAddNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Manual trip creation is not connected in this build. This note does not add or connect a provider trip; saved scheduled and starter catalog trips remain available.")
        }
        .animation(reduceMotion ? nil : RailDesign.Motion.quick, value: searchText)
        .railScreenChrome()
    }

    private func runSearch() async {
        let cleanQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        store.query = cleanQuery
        guard !cleanQuery.isEmpty else { return }
        try? await Task.sleep(for: .milliseconds(260))
        guard !Task.isCancelled else { return }
        await store.searchLiveTrips(matching: cleanQuery)
    }
}

private struct SearchHeroView: View {
    let scopeText: String
    let availability: ProviderAvailability

    var body: some View {
        GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.violet.opacity(0.14)) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.m) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 42))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RailDesign.Palette.accent)
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    Text("Find rail journeys")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                    Text("Search scheduled, saved, and starter catalog services by train number, station pair, operator, route, or departure time. Prediction labels appear only when a provider supplies them.")
                        .font(.subheadline)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: RailDesign.Spacing.xs) {
                        ProviderStatusPill(text: scopeText, tint: availability.status.tint)
                        ProviderStatusPill(text: availability.status.displayName, tint: availability.status.tint)
                    }
                }
            }
        }
    }
}

private struct SearchCapabilityNoticeView: View {
    let notice: TrainStore.SearchCapabilityNotice

    private var tint: Color {
        switch notice.kind {
        case .realtimeUnavailable:
            return RailDesign.Palette.marine
        case .scheduleUnavailable:
            return RailDesign.Palette.amber
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: notice.symbolName)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(notice.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(notice.message)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tint.opacity(0.12))
        .accessibilityElement(children: .combine)
    }
}

private struct RecentSearchesView: View {
    let examples: [String]
    let providerName: String
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Provider examples", subtitle: providerName)
            GlassPanel {
                VStack(spacing: 0) {
                    ForEach(examples, id: \.self) { item in
                        Button {
                            select(item)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                Text(item)
                                    .foregroundStyle(RailDesign.Palette.ink)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                            }
                            .font(.subheadline)
                            .padding(.vertical, RailDesign.Spacing.s)
                        }
                        .buttonStyle(.plain)

                        if item != examples.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct FavoriteStationsStrip: View {
    let stations: [String]
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Favorite stations", subtitle: "Fast station search")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: RailDesign.Spacing.s) {
                    ForEach(stations, id: \.self) { station in
                        Button {
                            select(station)
                        } label: {
                            StationBadge(name: station, code: String(station.prefix(3)))
                                .padding(RailDesign.Spacing.s)
                                .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: RailDesign.Palette.accent.opacity(0.12), interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SuggestedRoutesView: View {
    let trips: [TrainTrip]
    let select: (TrainTrip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Suggested routes", subtitle: "Popular saved corridors")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: RailDesign.Spacing.s)], spacing: RailDesign.Spacing.s) {
                ForEach(trips) { trip in
                    Button {
                        select(trip)
                    } label: {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                            Text(trip.service)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RailDesign.Palette.ink)
                                .lineLimit(2)
                            Text("\(trip.origin.name) to \(trip.destination.name)")
                                .font(.caption)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(RailDesign.Spacing.m)
                        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: RailDesign.Palette.marine.opacity(0.12), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SearchResultsSection: View {
    let title: LocalizedStringKey
    let isLoading: Bool
    let results: [TrainTrip]
    let query: String
    let emptyState: TrainStore.SearchEmptyState?
    let track: (TrainTrip) -> Void
    let manualAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: title, subtitle: "Departure, arrival, duration, transfers, operator, and status")

            if isLoading && !query.isEmpty {
                LoadingSkeletonView(rows: 2)
            } else if let emptyState {
                SearchEmptyStateView(emptyState: emptyState, manualAdd: manualAdd)
            } else {
                VStack(spacing: RailDesign.Spacing.s) {
                    ForEach(results) { trip in
                        SearchResultCard(trip: trip) {
                            track(trip)
                        }
                    }
                }
            }
        }
    }
}

private struct SearchEmptyStateView: View {
    let emptyState: TrainStore.SearchEmptyState
    let manualAdd: () -> Void

    var body: some View {
        if let actionTitle = emptyState.actionTitle {
            EmptyStateView(
                title: LocalizedStringKey(emptyState.title),
                message: LocalizedStringKey(emptyState.message),
                symbolName: emptyState.symbolName,
                actionTitle: LocalizedStringKey(actionTitle)
            ) {
                manualAdd()
            }
        } else {
            EmptyStateView(
                title: LocalizedStringKey(emptyState.title),
                message: LocalizedStringKey(emptyState.message),
                symbolName: emptyState.symbolName
            )
        }
    }
}

private struct SearchResultCard: View {
    let trip: TrainTrip
    let track: () -> Void
    @State private var sourceDetailTrip: TrainTrip?
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue

    private var timeFormat: UserPreferences.TimeFormat {
        UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12
    }

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(in: trip.origin.timeZone, format: timeFormat)
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(in: trip.destination.timeZone, format: timeFormat)
    }

    var body: some View {
        GlassPanel(tint: RailDesign.Palette.blue.opacity(0.10)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(trip.train)
                            .font(.headline)
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(trip.operatorName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Text("\(trip.sourceProvenance.sourceKind.riderTitle) · \(trip.sourceProvenance.freshness.displayName)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: RailDesign.Spacing.xs) {
                        ServiceStatusPill(status: RailServiceStatus.from(trip))
                        Button {
                            sourceDetailTrip = trip
                        } label: {
                            SourceBadge(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens source details")
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formattedOriginTime)
                            .font(.headline.monospacedDigit())
                        Text(trip.origin.name)
                            .font(.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                    Spacer()
                    Label(trip.duration, systemImage: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedDestinationTime)
                            .font(.headline.monospacedDigit())
                        Text(trip.destination.name)
                            .font(.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                }
                .foregroundStyle(RailDesign.Palette.ink)

                HStack {
                    PlatformChip(platform: trip.platform)
                    Label(trip.transferSummary, systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Spacer()
                    Button(action: track) {
                        Label("Track", systemImage: "plus.circle.fill")
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
    }
}

private struct StationsScreen: View {
    @ObservedObject var store: TrainStore
    @State private var stationQuery = ""

    private var stations: [StationSnapshot] {
        let cleanQuery = stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshots = store.stationSnapshots
        guard !cleanQuery.isEmpty else { return snapshots }
        return snapshots.filter { station in
            station.name.localizedCaseInsensitiveContains(cleanQuery) || station.code.localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    var body: some View {
        List {
            Section {
                StationOverviewPanel(stationCount: store.stationSnapshots.count, watchedPlatforms: store.watchedPlatformCount, riskCount: store.riskCount)
                    .listCardRow()
            }

            Section {
                if stations.isEmpty {
                    EmptyStateView(
                        title: "No station found",
                        message: "Search a station name, short code, platform, or route stop.",
                        symbolName: "tram.circle"
                    )
                    .listCardRow()
                } else {
                    ForEach(stations) { station in
                        NavigationLink {
                            StationDetailView(station: station)
                        } label: {
                            StationCard(station: station)
                        }
                        .buttonStyle(.plain)
                        .listCardRow()
                    }
                }
            } header: {
                SectionHeader(title: "Stations", subtitle: "Station boards, platforms, disruptions, facilities, and route shortcuts")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Stations")
        .searchable(text: $stationQuery, prompt: "Station, platform, or route")
        .railScreenChrome()
    }
}

private struct StationOverviewPanel: View {
    let stationCount: Int
    let watchedPlatforms: Int
    let riskCount: Int

    var body: some View {
        GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.accent.opacity(0.16)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                HStack {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text("Station watch")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                        Text("\(stationCount) stations")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                    }
                    Spacer()
                    Image(systemName: "tram.circle.fill")
                        .font(.system(size: 46))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(RailDesign.Palette.accent)
                }

                HStack(spacing: RailDesign.Spacing.s) {
                    MiniStat(title: "Platforms", value: "\(watchedPlatforms)", tint: RailDesign.Palette.blue)
                    MiniStat(title: "Alerts", value: "\(riskCount)", tint: riskCount > 0 ? RailDesign.Palette.amber : RailDesign.Palette.mint)
                }
            }
        }
    }
}

private struct StationCard: View {
    let station: StationSnapshot

    var body: some View {
        GlassPanel(tint: RailDesign.Palette.marine.opacity(0.10)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack {
                    StationBadge(name: station.name, code: station.code)
                    Spacer()
                    ServiceStatusPill(status: station.status)
                }

                HStack(spacing: RailDesign.Spacing.s) {
                    MiniStat(title: "Departures", value: "\(station.departureTrips.count)", tint: RailDesign.Palette.accent)
                    MiniStat(title: "Tracks", value: "\(station.platforms.count)", tint: RailDesign.Palette.blue)
                    MiniStat(title: "Routes", value: "\(station.routeNames.count)", tint: RailDesign.Palette.violet)
                }
            }
        }
    }
}

private struct StationDetailView: View {
    let station: StationSnapshot
    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.marine.opacity(0.18)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                        HStack(alignment: .top) {
                            StationBadge(name: station.name, code: station.code)
                            Spacer()
                            Button {
                                isFavorite.toggle()
                            } label: {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(isFavorite ? RailDesign.Palette.amber : RailDesign.Palette.secondaryText)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel(isFavorite ? "Remove favorite station" : "Favorite station")
                        }

                        HStack(spacing: RailDesign.Spacing.s) {
                            MetricTile(title: "Departures", value: "\(station.departureTrips.count)", subtitle: "tracked", symbolName: "arrow.up.right", tint: RailDesign.Palette.accent)
                            MetricTile(title: "Platforms", value: station.platforms.prefix(3).joined(separator: ", "), subtitle: "known", symbolName: "rectangle.split.3x1", tint: RailDesign.Palette.blue)
                        }
                    }
                }

                BoardSection(title: "Tracked departures", trips: station.departureTrips, empty: "No tracked departures for this station.")
                BoardSection(title: "Arrivals", trips: station.arrivalTrips, empty: "No tracked arrivals for this station.")

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(title: "Station notes", subtitle: "Facilities, access, disruptions, and popular route clues")
                    GlassPanel {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                            InfoLine(symbol: "figure.roll", title: "Accessibility", value: "Step-free route details are not connected yet.")
                            InfoLine(symbol: "cup.and.saucer", title: "Facilities", value: "Food, restrooms, and waiting areas depend on station data availability.")
                            InfoLine(symbol: "exclamationmark.triangle", title: "Disruptions", value: station.status == .onTime ? "No tracked disruption in saved trips." : "One or more tracked trips need attention.")
                            InfoLine(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Popular routes", value: station.routeNames.prefix(3).joined(separator: ", "))
                        }
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}

private struct BoardSection: View {
    let title: LocalizedStringKey
    let trips: [TrainTrip]
    let empty: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: title, subtitle: "Time, destination, platform, operator, and status")
            if trips.isEmpty {
                EmptyStateView(title: "No board items", message: empty, symbolName: "list.bullet.rectangle")
            } else {
                GlassPanel {
                    VStack(spacing: 0) {
                        ForEach(trips) { trip in
                            StationBoardRow(trip: trip)
                            if trip.id != trips.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct StationBoardRow: View {
    let trip: TrainTrip
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue

    private var timeFormat: UserPreferences.TimeFormat {
        UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12
    }

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            Text(trip.origin.time.formattedAsTime(in: trip.origin.timeZone, format: timeFormat))
                .font(.headline.monospacedDigit())
                .foregroundStyle(RailDesign.Palette.ink)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.destination.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text("\(trip.operatorName) · \(trip.train)")
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                SourceBadge(trip: trip)
            }
            Spacer()
            PlatformChip(platform: trip.platform, label: "Track")
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.train), \(trip.origin.name) to \(trip.destination.name), \(trip.sourceProvenance.sourceKind.riderTitle), \(trip.sourceProvenance.freshness.displayName)")
    }
}

private struct HistoryScreen: View {
    @ObservedObject var store: TrainStore
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue

    private var metrics: RailHistoryMetrics {
        RailHistoryMetrics(trips: store.trips, useMetric: unitSystemRaw != UserPreferences.UnitSystem.imperial.rawValue)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.violet.opacity(0.14)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                        HStack {
                            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                                Text("Rail dashboard")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                Text(metrics.yearSummary)
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(RailDesign.Palette.ink)
                            }
                            Spacer()
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 42))
                                .foregroundStyle(RailDesign.Palette.violet)
                        }

                        DelayBar(delayCount: metrics.delayCount, total: max(metrics.tripCount, 1))
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: RailDesign.Spacing.s)], spacing: RailDesign.Spacing.s) {
                    MetricTile(title: "Trips", value: "\(metrics.tripCount)", subtitle: "saved", symbolName: "train.side.front.car", tint: RailDesign.Palette.accent)
                    MetricTile(title: "Distance", value: metrics.distanceText, subtitle: "where known", symbolName: "ruler", tint: RailDesign.Palette.blue)
                    MetricTile(title: "Hours", value: metrics.hoursText, subtitle: "scheduled", symbolName: "clock", tint: RailDesign.Palette.violet)
                    MetricTile(title: "Stations", value: "\(metrics.stationCount)", subtitle: "visited", symbolName: "tram.circle", tint: RailDesign.Palette.mint)
                    MetricTile(title: "Operators", value: "\(metrics.operatorCount)", subtitle: "used", symbolName: "building.2", tint: RailDesign.Palette.copper)
                    MetricTile(title: "Regions", value: metrics.regionText, subtitle: "where known", symbolName: "map", tint: RailDesign.Palette.marine)
                }

                GlassPanel {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                        SectionHeader(title: "Journey highlights", subtitle: "Longest trip, most-used route, station visits, and delay totals")
                        InfoLine(symbol: "arrow.left.and.right", title: "Longest trip", value: metrics.longestTrip)
                        InfoLine(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Most-used route", value: metrics.mostUsedRoute)
                        InfoLine(symbol: "mappin.and.ellipse", title: "Most-visited station", value: metrics.mostVisitedStation)
                        InfoLine(symbol: "clock.badge.exclamationmark", title: "Delay total", value: metrics.delaySummary)
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("History")
        .railScreenChrome()
    }
}

private struct SettingsScreen: View {
    @ObservedObject var store: TrainStore
    @AppStorage("rail.appearance") private var appearance = "System"
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue
    @AppStorage("trainy.sourceLabelVerbosity") private var sourceLabelVerbosityRaw = UserPreferences.SourceLabelVerbosity.compact.rawValue
    @AppStorage("trainy.localDelayNoticesEnabled") private var delayNotifications = false
    @AppStorage("trainy.localPlatformNoticesEnabled") private var platformNotifications = false
    @AppStorage("trainy.diagnosticsConsent") private var diagnosticsConsent = false

    private var usesMetricUnits: Binding<Bool> {
        Binding(
            get: { unitSystemRaw != UserPreferences.UnitSystem.imperial.rawValue },
            set: { unitSystemRaw = $0 ? UserPreferences.UnitSystem.metric.rawValue : UserPreferences.UnitSystem.imperial.rawValue }
        )
    }

    private var activeProvider: ProviderMetadata? {
        store.providerDirectory.first { $0.id == store.activeProviderID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.accent.opacity(0.15)) {
                    HStack(spacing: RailDesign.Spacing.m) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(RailDesign.Palette.accent)
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                            Text("Rail companion")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(RailDesign.Palette.ink)
                            Text("\(store.trips.count) saved trips · \(store.stationSnapshots.count) watched stations")
                                .font(.subheadline)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                        }
                        Spacer()
                    }
                }

                SettingsGroup(title: "Notifications") {
                    SettingsToggleRow(symbol: "bell.badge", title: "Local delay notice preference", detail: "Prototype preference only. This build does not request system notification permission or schedule delay alerts.", isOn: $delayNotifications)
                    SettingsToggleRow(symbol: "rectangle.split.3x1", title: "Local platform notice preference", detail: "Prototype preference only. Platform-change notifications are not scheduled in this build.", isOn: $platformNotifications)
                }

                SettingsGroup(title: "Time and Units") {
                    SettingsPickerRow(symbol: "clock", title: "Time format", detail: "Applies to trip cards, station boards, detail timelines, ETA labels, and shared journey text.", selection: $timeFormatRaw, options: UserPreferences.TimeFormat.allCases.map(\.rawValue))
                    SettingsToggleRow(symbol: "ruler", title: "Metric units", detail: "Applies to source-backed speed and distance values when a provider supplies numeric metric data.", isOn: usesMetricUnits)
                    SettingsPickerRow(symbol: "tag", title: "Source labels", detail: "Controls whether source badges use compact labels or longer rider-facing source names.", selection: $sourceLabelVerbosityRaw, options: UserPreferences.SourceLabelVerbosity.allCases.map(\.rawValue))
                    SettingsPickerRow(symbol: "paintpalette", title: "Appearance", detail: "Stored as a display preference; app-wide appearance switching is not applied in this build.", selection: $appearance, options: ["System", "Light", "Dark"])
                    SettingsInfoRow(symbol: "calendar.badge.clock", title: "Calendar sync", detail: "Not connected in this build. Saved journeys stay inside Trainy unless you share them manually.")
                }

                SettingsGroup(title: "Providers") {
                    if let activeProvider {
                        ProviderActiveSummary(provider: activeProvider)
                        Divider()
                            .background(RailDesign.Palette.hairline)
                    }
                    ProviderProxyStatusSummary(store: store)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    SettingsNavigationRow(
                        symbol: "globe.asia.australia.fill",
                        title: "Supported regions",
                        detail: "Japan is active; the rest of the globe remains muted in this build."
                    ) {
                        SupportedRegionsScreen(store: store)
                    }
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    ProviderRegionPicker(store: store)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    ProviderDirectoryList(store: store)
                }

                SettingsGroup(title: "Privacy") {
                    SettingsToggleRow(symbol: "hand.raised", title: "Diagnostics sharing consent", detail: "Off by default and stored locally. This build sends no diagnostics; future diagnostics must exclude station names, trip IDs, notes, provider keys, and contact details.", isOn: $diagnosticsConsent)
                    SettingsInfoRow(symbol: "lock.shield", title: "Saved trip data", detail: "Tracked journeys, favorite stations, and alert choices are stored locally by this build.")
                }

                SettingsGroup(title: "Support") {
                    SettingsInfoRow(symbol: "questionmark.circle", title: "Help", detail: "Get guidance for train numbers, platforms, transfers, and offline saved journeys.")
                    SettingsInfoRow(symbol: "info.circle", title: "About", detail: "Trainy is an original rail companion interface built with system fonts, SF Symbols, and app-owned data.")
                }

                SettingsGroup(title: "Developer") {
                    SettingsActionRow(
                        symbol: "arrow.counterclockwise.circle",
                        title: "Reset first-run",
                        detail: "Show the data-scope onboarding again for fixture, copy, and simulator checks.",
                        actionTitle: "Reset"
                    ) {
                        store.resetFirstRun()
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Settings")
        .railScreenChrome()
    }
}

private struct SupportedRegionsScreen: View {
    @ObservedObject var store: TrainStore

    private var activeProviders: [ProviderMetadata] {
        store.providerDirectory.filter { $0.implementationStatus == .active }
    }

    private var plannedProviders: [ProviderMetadata] {
        store.providerDirectory.filter { $0.implementationStatus != .active }
    }

    private var activeRegionIDs: Set<String> {
        Set(activeProviders.map(\.region.id))
    }

    private var plannedRegionIDs: Set<String> {
        Set(plannedProviders.map(\.region.id))
    }

    private var plannedRegionNames: [String] {
        var seen: Set<String> = []
        return plannedProviders
            .map(\.region)
            .sorted { lhs, rhs in lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending }
            .compactMap { region in
                guard !seen.contains(region.id) else { return nil }
                seen.insert(region.id)
                return region.displayName
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.marine.opacity(0.18)) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                        HStack(alignment: .top, spacing: RailDesign.Spacing.m) {
                            Image(systemName: "globe.asia.australia.fill")
                                .font(.system(size: 42, weight: .semibold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(RailDesign.Palette.marine)
                                .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                                Text("Supported regions")
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(RailDesign.Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Japan is the active rail region. Planned providers stay muted until their adapters, credentials, fixtures, and source labels are ready.")
                                    .font(.subheadline)
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        SupportedRegionsMap(
                            activeRegionIDs: activeRegionIDs,
                            plannedRegionIDs: plannedRegionIDs
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 318)

                        HStack(spacing: RailDesign.Spacing.s) {
                            CoverageLegendItem(title: "Active", tint: RailDesign.Palette.mint)
                            CoverageLegendItem(title: "Muted", tint: RailDesign.Palette.secondaryText.opacity(0.55))
                        }
                    }
                }

                SettingsGroup(title: "Search coverage") {
                    ForEach(activeProviders) { provider in
                        SupportedRegionProviderRow(provider: provider, isActive: true)
                    }
                }

                SettingsGroup(title: "Muted regions") {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        Text("These regions are visible in the provider registry, but are not selectable or searchable in this build.")
                            .font(.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        SupportedRegionPillGrid(names: plannedRegionNames)
                    }
                    .padding(.vertical, RailDesign.Spacing.s)
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle("Supported Regions")
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}

private struct SupportedRegionsMap: View {
    let activeRegionIDs: Set<String>
    let plannedRegionIDs: Set<String>

    private var markers: [CoverageMapMarker] {
        activeRegionIDs
            .union(plannedRegionIDs)
            .compactMap(Self.marker)
            .sorted { lhs, rhs in
                let lhsActive = activeRegionIDs.contains(lhs.id)
                let rhsActive = activeRegionIDs.contains(rhs.id)
                if lhsActive != rhsActive { return lhsActive }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)

            ZStack {
                NativeCoverageGlobeView(markers: markers, activeRegionIDs: activeRegionIDs)
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(RailDesign.Palette.hairline.opacity(0.90), lineWidth: 1.2)
                    }
                    .shadow(color: RailDesign.Palette.ink.opacity(0.16), radius: 26, y: 18)

                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.86),
                                RailDesign.Palette.mint.opacity(0.24),
                                RailDesign.Palette.ink.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
                    .frame(width: diameter, height: diameter)
                    .allowsHitTesting(false)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Supported regions map")
        .accessibilityValue("Japan is highlighted with native Apple map data. Other regions are muted.")
    }

    private static func marker(for regionID: String) -> CoverageMapMarker? {
        switch regionID {
        case ProviderRegion.japan.id:
            return CoverageMapMarker(id: regionID, name: "Japan", coordinate: CLLocationCoordinate2D(latitude: 36.2, longitude: 138.2))
        case ProviderRegion.taiwan.id:
            return CoverageMapMarker(id: regionID, name: "Taiwan", coordinate: CLLocationCoordinate2D(latitude: 23.8, longitude: 121.0))
        case ProviderRegion.hongKong.id:
            return CoverageMapMarker(id: regionID, name: "Hong Kong", coordinate: CLLocationCoordinate2D(latitude: 22.32, longitude: 114.17))
        case ProviderRegion.germany.id:
            return CoverageMapMarker(id: regionID, name: "Germany", coordinate: CLLocationCoordinate2D(latitude: 51.2, longitude: 10.4))
        case ProviderRegion.switzerland.id:
            return CoverageMapMarker(id: regionID, name: "Switzerland", coordinate: CLLocationCoordinate2D(latitude: 46.8, longitude: 8.2))
        case ProviderRegion.unitedKingdom.id:
            return CoverageMapMarker(id: regionID, name: "United Kingdom", coordinate: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0))
        case ProviderRegion.australia.id:
            return CoverageMapMarker(id: regionID, name: "Australia", coordinate: CLLocationCoordinate2D(latitude: -33.9, longitude: 151.2))
        case ProviderRegion.unitedStates.id:
            return CoverageMapMarker(id: regionID, name: "United States", coordinate: CLLocationCoordinate2D(latitude: 40.75, longitude: -73.9))
        case ProviderRegion.netherlands.id:
            return CoverageMapMarker(id: regionID, name: "Netherlands", coordinate: CLLocationCoordinate2D(latitude: 52.2, longitude: 5.3))
        case ProviderRegion.southKorea.id:
            return CoverageMapMarker(id: regionID, name: "South Korea", coordinate: CLLocationCoordinate2D(latitude: 36.2, longitude: 127.8))
        case ProviderRegion.france.id:
            return CoverageMapMarker(id: regionID, name: "France", coordinate: CLLocationCoordinate2D(latitude: 46.2, longitude: 2.2))
        default:
            return nil
        }
    }
}

private struct CoverageMapMarker: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}

private struct NativeCoverageGlobeView: UIViewRepresentable {
    let markers: [CoverageMapMarker]
    let activeRegionIDs: Set<String>

    func makeCoordinator() -> Coordinator {
        Coordinator(activeRegionIDs: activeRegionIDs)
    }

    func makeUIView(context: Context) -> CoverageGlobeMapView {
        let mapView = CoverageGlobeMapView()
        mapView.apply(
            markers: markers,
            activeRegionIDs: activeRegionIDs,
            camera: Self.coverageCamera,
            coordinator: context.coordinator
        )
        return mapView
    }

    func updateUIView(_ mapView: CoverageGlobeMapView, context: Context) {
        context.coordinator.activeRegionIDs = activeRegionIDs
        mapView.apply(
            markers: markers,
            activeRegionIDs: activeRegionIDs,
            camera: Self.coverageCamera,
            coordinator: context.coordinator
        )
    }

    private static let coverageCamera = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 33.5, longitude: 127.6),
        fromDistance: 8_650_000,
        pitch: 16,
        heading: -8
    )

    final class Coordinator: NSObject, MKMapViewDelegate {
        static let activeMarkerReuseID = "activeCoverageMarker"
        static let mutedMarkerReuseID = "mutedCoverageMarker"

        var activeRegionIDs: Set<String>

        init(activeRegionIDs: Set<String>) {
            self.activeRegionIDs = activeRegionIDs
        }

        func apply(markers: [CoverageMapMarker], to mapView: MKMapView) {
            let annotations = markers.map { marker in
                CoverageMapAnnotation(marker: marker, isActive: activeRegionIDs.contains(marker.id))
            }
            let overlays = annotations.map { annotation in
                MKCircle(
                    center: annotation.coordinate,
                    radius: annotation.isActive ? 430_000 : 230_000
                )
            }

            mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? CoverageMapAnnotation })
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(overlays, level: .aboveLabels)
            mapView.addAnnotations(annotations)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKCircleRenderer(circle: circle)
            let isActive = circle.radius > 300_000
            renderer.fillColor = UIColor(isActive ? .clear : RailDesign.Palette.secondaryText.opacity(0.08))
            renderer.strokeColor = UIColor(isActive ? RailDesign.Palette.mint.opacity(0.82) : RailDesign.Palette.secondaryText.opacity(0.28))
            renderer.lineWidth = isActive ? 1.5 : 0.8
            renderer.alpha = isActive ? 0.78 : 0.30
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let coverageAnnotation = annotation as? CoverageMapAnnotation else {
                return nil
            }

            let reuseID = coverageAnnotation.isActive ? Self.activeMarkerReuseID : Self.mutedMarkerReuseID
            guard let markerView = mapView.dequeueReusableAnnotationView(
                withIdentifier: reuseID,
                for: coverageAnnotation
            ) as? MKMarkerAnnotationView else {
                return nil
            }

            markerView.annotation = coverageAnnotation
            markerView.canShowCallout = false
            markerView.animatesWhenAdded = false
            markerView.collisionMode = .circle
            markerView.displayPriority = coverageAnnotation.isActive ? .required : .defaultLow
            markerView.zPriority = coverageAnnotation.isActive ? .max : .min
            markerView.alpha = coverageAnnotation.isActive ? 1.0 : 0.28
            markerView.titleVisibility = coverageAnnotation.isActive ? .visible : .hidden
            markerView.subtitleVisibility = .hidden
            markerView.markerTintColor = UIColor(
                coverageAnnotation.isActive
                ? RailDesign.Palette.mint
                : RailDesign.Palette.secondaryText.opacity(0.44)
            )
            markerView.glyphTintColor = .white
            markerView.glyphImage = coverageAnnotation.isActive ? UIImage(systemName: "train.side.front.car.fill") : nil
            return markerView
        }
    }
}

private final class CoverageGlobeMapView: UIView {
    private let mapView = MKMapView(frame: .zero)
    private let unsupportedMaskLayer = CAShapeLayer()
    private let activeFocusLayer = CAShapeLayer()
    private var activeCoordinate: CLLocationCoordinate2D?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func apply(
        markers: [CoverageMapMarker],
        activeRegionIDs: Set<String>,
        camera: MKMapCamera,
        coordinator: NativeCoverageGlobeView.Coordinator
    ) {
        activeCoordinate = markers.first { activeRegionIDs.contains($0.id) }?.coordinate
        mapView.delegate = coordinator
        coordinator.activeRegionIDs = activeRegionIDs
        coordinator.apply(markers: markers, to: mapView)
        mapView.setCamera(camera, animated: false)

        setNeedsLayout()
        DispatchQueue.main.async { [weak self] in
            self?.updateRegionTreatment()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.masksToBounds = true
        updateRegionTreatment()
    }

    private func configure() {
        let configuration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false

        backgroundColor = .clear
        clipsToBounds = true
        mapView.preferredConfiguration = configuration
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isUserInteractionEnabled = false
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.layoutMargins = .zero
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NativeCoverageGlobeView.Coordinator.activeMarkerReuseID)
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NativeCoverageGlobeView.Coordinator.mutedMarkerReuseID)

        unsupportedMaskLayer.fillRule = .evenOdd
        unsupportedMaskLayer.fillColor = UIColor(RailDesign.Palette.ink).withAlphaComponent(0.56).cgColor

        activeFocusLayer.fillColor = UIColor.clear.cgColor
        activeFocusLayer.strokeColor = UIColor(RailDesign.Palette.mint.opacity(0.96)).cgColor
        activeFocusLayer.lineWidth = 1.7
        activeFocusLayer.shadowColor = UIColor(RailDesign.Palette.mint.opacity(0.55)).cgColor
        activeFocusLayer.shadowOpacity = 1.0
        activeFocusLayer.shadowRadius = 12
        activeFocusLayer.shadowOffset = CGSize(width: 0, height: 5)

        addSubview(mapView)
        layer.addSublayer(unsupportedMaskLayer)
        layer.addSublayer(activeFocusLayer)
    }

    private func updateRegionTreatment() {
        guard !bounds.isEmpty else { return }

        let diameter = min(bounds.width, bounds.height)
        let globeRect = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        ).insetBy(dx: 0.5, dy: 0.5)
        let maskPath = UIBezierPath(ovalIn: globeRect)

        if let spotlightRect {
            maskPath.append(UIBezierPath(roundedRect: spotlightRect, cornerRadius: spotlightRect.height / 2))
            activeFocusLayer.path = UIBezierPath(roundedRect: spotlightRect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: spotlightRect.height / 2).cgPath
        } else {
            activeFocusLayer.path = nil
        }

        unsupportedMaskLayer.frame = bounds
        unsupportedMaskLayer.path = maskPath.cgPath
        activeFocusLayer.frame = bounds
    }

    private var spotlightRect: CGRect? {
        guard let activeCoordinate else { return nil }

        let activePoint = mapView.convert(activeCoordinate, toPointTo: self)
        guard bounds.insetBy(dx: -80, dy: -80).contains(activePoint) else { return nil }

        let diameter = min(bounds.width, bounds.height)
        let width = max(78, diameter * 0.24)
        let height = max(118, diameter * 0.36)
        let rect = CGRect(
            x: activePoint.x - width * 0.50,
            y: activePoint.y - height * 0.50,
            width: width,
            height: height
        )
        return rect.intersection(bounds.insetBy(dx: 8, dy: 8))
    }
}

private final class CoverageMapAnnotation: NSObject, MKAnnotation {
    let id: String
    let name: String
    let isActive: Bool
    let coordinate: CLLocationCoordinate2D

    var title: String? { name }

    init(marker: CoverageMapMarker, isActive: Bool) {
        self.id = marker.id
        self.name = marker.name
        self.isActive = isActive
        self.coordinate = marker.coordinate
    }
}


private struct SupportedRegionProviderRow: View {
    let provider: ProviderMetadata
    let isActive: Bool

    private var tint: Color {
        isActive ? RailDesign.Palette.mint : RailDesign.Palette.secondaryText
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: isActive ? "checkmark.seal.fill" : "circle.dashed")
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(provider.region.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                    ProviderStatusPill(text: isActive ? "Active" : "Muted", tint: tint)
                }

                Text(provider.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(provider.availability.message)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

private struct SupportedRegionPillGrid: View {
    let names: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: RailDesign.Spacing.xs)], alignment: .leading, spacing: RailDesign.Spacing.xs) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RailDesign.Palette.hairline.opacity(0.78), in: Capsule())
            }
        }
    }
}

private struct TrainDetailView: View {
    @ObservedObject var store: TrainStore
    let tripID: TrainTrip.ID
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue

    private var trip: TrainTrip? {
        store.trips.first { $0.id == tripID } ?? store.selectedTrip
    }

    private var useMetric: Bool {
        unitSystemRaw != UserPreferences.UnitSystem.imperial.rawValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let trip {
                    RouteHeaderPanel(trip: trip)
                    StatusSummaryPanel(trip: trip)
                    SourceProvenancePanel(trip: trip)
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Rail map", subtitle: "Route line, map position, upcoming stops, transfer cues, and disruptions")
                        RailJourneyMapPanel(trip: trip, style: .detail)
                    }
                    JourneyProgressPanel(trip: trip)

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Stop timeline", subtitle: "Scheduled and estimated times, platforms, skipped stops, cancellations, and delay notes")
                        GlassPanel {
                            VStack(spacing: 0) {
                                ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                                    StopTimelineRow(stop: stop, isLast: index == trip.stops.count - 1)
                                }
                            }
                        }
                    }

                    TransferWarningCard(
                        title: trip.statusTone == .good ? "Transfer watch" : "Transfer caution",
                        detail: trip.transferWarningCopy,
                        tone: trip.statusTone == .good ? RailDesign.Palette.accent : RailDesign.Palette.amber
                    )

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Carriage and platform", subtitle: "Boarding position, train length, seat cue, and platform/track")
                        GlassPanel {
                            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                                InfoLine(symbol: "rectangle.split.3x1.fill", title: "Platform", value: trip.displayPlatform)
                                InfoLine(symbol: "train.side.front.car", title: "Carriage", value: "Car \(trip.bestCar) of \(trip.cars)")
                                InfoLine(symbol: "seat", title: "Seat note", value: trip.seat)
                                InfoLine(symbol: "speedometer", title: "Speed", value: UnitConverter.displaySpeed(trip.speed, useMetric: useMetric))
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Notes", subtitle: "Original route guidance from the connected data source")
                        GlassPanel {
                            Text(trip.callout)
                                .font(.subheadline)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        SectionHeader(title: "Alerts", subtitle: "Service notices and trip-specific reminders")
                        if trip.alerts.isEmpty {
                            EmptyStateView(title: "No active alerts", message: "Service updates will appear here when data is available.", symbolName: "bell")
                        } else {
                            VStack(spacing: RailDesign.Spacing.s) {
                                ForEach(trip.alerts) { alert in
                                    DisruptionBanner(alert: alert)
                                }
                            }
                        }
                    }

                    ShareLink(item: trip.shareText) {
                        Label("Share journey", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    EmptyStateView(
                        title: "Trip unavailable",
                        message: "This trip is no longer saved. Search and track a service to open a detail view.",
                        symbolName: "train.side.front.car"
                    )
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, 120)
        }
        .background(RailGradientBackground().ignoresSafeArea())
        .navigationTitle(trip?.train ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.refreshSelectedTrip()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.glass)

                if let trip {
                    ShareLink(item: trip.shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .onAppear {
            if let trip {
                store.select(trip)
            }
        }
        .railScreenChrome()
    }
}

private struct RouteHeaderPanel: View {
    let trip: TrainTrip

    var body: some View {
        GlassPanel(cornerRadius: RailDesign.Radius.hero, tint: RailDesign.Palette.marine.opacity(0.20), padding: 0) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(trip.operatorName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                        Text(trip.train)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                        Text(trip.service)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                    Spacer()
                    ServiceStatusPill(status: RailServiceStatus.from(trip))
                }

                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.s) {
                    HeaderStation(time: trip.origin.time, station: trip.origin.name, label: "Depart")
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    HeaderStation(time: trip.destination.time, station: trip.destination.name, label: "Arrive", alignment: .trailing)
                }
            }
            .padding(RailDesign.Spacing.l)
        }
    }
}

private struct HeaderStation: View {
    let time: String
    let station: String
    let label: LocalizedStringKey
    var alignment: HorizontalAlignment = .leading
    var timeZone: TimeZone = TimeZone(identifier: "Asia/Tokyo")!
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue

    private var timeFormat: UserPreferences.TimeFormat {
        UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12
    }

    var body: some View {
        VStack(alignment: alignment, spacing: RailDesign.Spacing.xxs) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
            Text(time.formattedAsTime(in: timeZone, format: timeFormat))
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(RailDesign.Palette.ink)
            Text(station)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct StatusSummaryPanel: View {
    let trip: TrainTrip

    var body: some View {
        GlassPanel {
            ViewThatFits {
                HStack(spacing: RailDesign.Spacing.m) {
                    StatusSummaryItem(title: "Status", value: trip.status, symbol: RailServiceStatus.from(trip).symbolName, tint: RailServiceStatus.from(trip).tint)
                    Divider()
                    StatusSummaryItem(
                        title: "Platform",
                        value: trip.displayPlatform,
                        symbol: "rectangle.split.3x1",
                        tint: trip.platformDisplayState.isKnown ? RailDesign.Palette.blue : RailDesign.Palette.secondaryText
                    )
                    Divider()
                    StatusSummaryItem(title: "Updated", value: trip.updated, symbol: "arrow.clockwise", tint: RailDesign.Palette.violet)
                }
                VStack(spacing: RailDesign.Spacing.m) {
                    StatusSummaryItem(title: "Status", value: trip.status, symbol: RailServiceStatus.from(trip).symbolName, tint: RailServiceStatus.from(trip).tint)
                    StatusSummaryItem(
                        title: "Platform",
                        value: trip.displayPlatform,
                        symbol: "rectangle.split.3x1",
                        tint: trip.platformDisplayState.isKnown ? RailDesign.Palette.blue : RailDesign.Palette.secondaryText
                    )
                    StatusSummaryItem(title: "Updated", value: trip.updated, symbol: "arrow.clockwise", tint: RailDesign.Palette.violet)
                }
            }
        }
    }
}

private struct SourceProvenancePanel: View {
    let trip: TrainTrip
    @State private var sourceDetailTrip: TrainTrip?

    private var provenance: SourceProvenance {
        trip.sourceProvenance
    }

    private var freshnessText: String {
        if let fetchedAt = provenance.fetchedAt {
            return "\(provenance.freshness.displayName), fetched \(Self.dateFormatter.string(from: fetchedAt))"
        }
        if let publishedAt = provenance.publishedAt {
            return "\(provenance.freshness.displayName), published \(Self.dateFormatter.string(from: publishedAt))"
        }
        return provenance.freshness.displayName
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Source", subtitle: "Source, type, confidence, freshness, and license for this trip's visible data")
            GlassPanel {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                    Button {
                        sourceDetailTrip = trip
                    } label: {
                        SourceBadge(trip: trip, style: .regular)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens source details")

                    if trip.sourceStateDisplayState.needsVisibleCallout {
                        SourceStateCallout(state: trip.sourceStateDisplayState)
                    }

                    InfoLine(symbol: "building.columns", title: "Provider", value: provenance.providerName)
                    InfoLine(symbol: "doc.text.magnifyingglass", title: "Source", value: provenance.sourceName)
                    InfoLine(symbol: "checkmark.seal", title: "Confidence", value: provenance.summaryText)
                    InfoLine(symbol: "clock.badge.checkmark", title: "Freshness", value: freshnessText)
                    InfoLine(symbol: trip.vehiclePositionDisplayState.symbolName, title: "Map marker", value: trip.vehiclePositionDisplayState.detailText)
                    InfoLine(symbol: "rectangle.split.3x1", title: "Platform", value: trip.platformDisplayState.detailText)
                    InfoLine(symbol: "info.circle", title: "Meaning", value: provenance.riderExplanation)
                    InfoLine(symbol: "doc.plaintext", title: "License", value: provenance.licenseAttributionText)
                    InfoLine(symbol: "list.bullet.rectangle", title: "Fact mix", value: trip.sourceBreakdownText)

                    VStack(spacing: RailDesign.Spacing.xs) {
                        ForEach(trip.factProvenance) { fact in
                            SourceFactRow(fact: fact)
                        }
                    }

                    if let sourceURL = provenance.sourceURL {
                        Link(destination: sourceURL) {
                            Label(sourceURL.host ?? sourceURL.absoluteString, systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RailDesign.Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .accessibilityLabel("Open source \(provenance.sourceName)")
                    }
                }
            }
        }
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
    }
}

private struct SourceStateCallout: View {
    let state: RailSourceStateDisplayState

    private var tint: Color {
        switch state.kind {
        case .current:
            return RailDesign.Palette.mint
        case .staleSaved:
            return RailDesign.Palette.amber
        case .expired:
            return RailDesign.Palette.red
        case .unknown:
            return RailDesign.Palette.secondaryText
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: state.symbolName)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(state.detailText)
                    .font(.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.s)
        .railLiquidGlass(cornerRadius: RailDesign.Radius.control, tint: tint.opacity(0.13), strokeOpacity: 0.24)
        .accessibilityElement(children: .combine)
    }
}


private struct JourneyProgressPanel: View {
    let trip: TrainTrip
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue

    private var timeFormat: UserPreferences.TimeFormat {
        UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12
    }

    private var formattedETA: String {
        trip.eta.formattedAsTime(in: trip.destination.timeZone, format: timeFormat)
    }

    var body: some View {
        GlassPanel(tint: RailDesign.Palette.accent.opacity(0.14)) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                SectionHeader(title: "Journey progress", subtitle: "Next stop, transfer risk, and estimated arrival")
                ProgressView(value: trip.progress)
                    .tint(RailServiceStatus.from(trip).tint)
                HStack {
                    InfoLine(symbol: "location.north.line.fill", title: "Next stop", value: trip.nextStop)
                    Spacer(minLength: RailDesign.Spacing.s)
                    InfoLine(symbol: "clock", title: "ETA", value: formattedETA)
                }
            }
        }
    }
}








private struct ProviderRegionPicker: View {
    @ObservedObject var store: TrainStore

    var body: some View {
        HStack(alignment: .center, spacing: RailDesign.Spacing.s) {
            SettingsRowLabel(symbol: "globe.asia.australia", title: "Registry region", detail: "Filter provider status by region.")
            Picker("", selection: Binding(
                get: { store.selectedRegionID },
                set: { store.selectRegion($0) }
            )) {
                ForEach(store.providerRegions) { region in
                    Text(region.displayName).tag(region.id)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.vertical, RailDesign.Spacing.s)
    }
}

private struct ProviderProxyStatusSummary: View {
    @ObservedObject var store: TrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                Image(systemName: statusSymbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusTint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text("Provider proxy")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                        ProviderStatusPill(text: statusText, tint: statusTint)
                    }

                    Text("Cloudflare Workers")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.ink)

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: RailDesign.Spacing.s)

                Button {
                    Task {
                        await store.refreshProviderProxyHealth()
                    }
                } label: {
                    Label("Check", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(!store.providerProxyConfiguration.isConfigured || store.providerProxyLoadState == .loading)
            }

            if !store.providerProxyHealthProviders.isEmpty {
                VStack(spacing: RailDesign.Spacing.xs) {
                    ForEach(store.providerProxyHealthProviders.prefix(6)) { health in
                        ProviderProxyHealthProviderRow(health: health)
                    }
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .task {
            guard store.providerProxyConfiguration.isConfigured, store.providerProxyHealth == nil else { return }
            await store.refreshProviderProxyHealth()
        }
    }

    private var statusText: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "No proxy"
        case .idle:
            return "Configured"
        case .loading:
            return "Checking"
        case .loaded:
            return hasAttention ? "Attention" : "Healthy"
        case .unavailable:
            return "Unavailable"
        }
    }

    private var detailText: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "No proxy base URL is configured. Planned proxy providers remain unavailable in this build."
        case .idle:
            return "Base host: \(store.providerProxyConfiguration.displayHost). Health has not been checked yet."
        case .loading:
            return "Checking app-safe provider health from \(store.providerProxyConfiguration.displayHost)."
        case .loaded(let generatedAt):
            let timestamp = generatedAt.map { Self.dateFormatter.string(from: $0) } ?? "unknown time"
            return "Health loaded at \(timestamp). Reports provider status only, not rider trips."
        case .unavailable(let message):
            return "Could not reach provider proxy health: \(message)"
        }
    }

    private var statusTint: Color {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return RailDesign.Palette.secondaryText
        case .idle, .loading:
            return RailDesign.Palette.blue
        case .loaded:
            return hasAttention ? RailDesign.Palette.amber : RailDesign.Palette.mint
        case .unavailable:
            return RailDesign.Palette.copper
        }
    }

    private var statusSymbol: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "lock.slash"
        case .idle:
            return "cloud"
        case .loading:
            return "arrow.clockwise"
        case .loaded:
            return hasAttention ? "exclamationmark.shield.fill" : "checkmark.shield.fill"
        case .unavailable:
            return "wifi.slash"
        }
    }

    private var hasAttention: Bool {
        store.providerProxyHealthProviders.contains { $0.status != .ok }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct ProviderProxyHealthProviderRow: View {
    let health: ProviderProxyProviderHealth

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: health.status.symbolName)
                .foregroundStyle(health.status.tint)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(health.id)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProviderStatusPill(text: health.status.displayName, tint: health.status.tint)
                }

                Text(health.message)
                    .font(.caption2)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let cache = health.cache {
                    Text("Static feed: \(cache.staticFeed.displayName)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RailDesign.Spacing.xs)
        .padding(.vertical, 6)
        .background(RailDesign.Palette.hairline.opacity(0.6), in: RoundedRectangle(cornerRadius: RailDesign.Radius.xs, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct ProviderDirectoryList: View {
    @ObservedObject var store: TrainStore

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.visibleProviderDirectory.enumerated()), id: \.element.id) { index, provider in
                if index > 0 {
                    Divider()
                        .background(RailDesign.Palette.hairline)
                }
                ProviderDirectoryRow(
                    provider: provider,
                    proxyHealth: store.providerProxyHealth(for: provider.id),
                    isActive: provider.id == store.activeProviderID,
                    isSelected: provider.id == store.selectedProviderID,
                    canSearch: store.providerCanSearch(provider.id),
                    selectProvider: {
                        store.selectProvider(provider.id)
                    }
                )
            }
        }
    }
}

private struct ProviderProxyProviderHealthBadge: View {
    let health: ProviderProxyProviderHealth

    var body: some View {
        Label("Proxy \(health.status.displayName): \(health.message)", systemImage: health.status.symbolName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(health.status.tint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, RailDesign.Spacing.xs)
            .padding(.vertical, 6)
            .background(health.status.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous))
            .accessibilityLabel("Provider proxy health")
            .accessibilityValue("\(health.status.displayName), \(health.message)")
    }
}

private struct ProviderDirectoryRow: View {
    let provider: ProviderMetadata
    let proxyHealth: ProviderProxyProviderHealth?
    let isActive: Bool
    let isSelected: Bool
    let canSearch: Bool
    let selectProvider: () -> Void

    private var statusTint: Color {
        if canSearch { return RailDesign.Palette.mint }
        switch provider.implementationStatus {
        case .active:
            return RailDesign.Palette.blue
        case .planned:
            return RailDesign.Palette.amber
        case .disabled:
            return RailDesign.Palette.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                Image(systemName: canSearch ? "tram.fill" : "tram")
                    .foregroundStyle(statusTint)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text(provider.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ProviderStatusPill(text: statusText, tint: statusTint)
                    }

                    Text("\(provider.region.displayName) / \(provider.authStrategy.displayName)")
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(provider.availability.message)
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !provider.capabilities.isEmpty {
                ProviderCapabilityStrip(capabilities: provider.capabilities)
            }

            ProviderRequirementSummary(provider: provider)

            ProviderSourceDisclosure(provider: provider)

            #if DEBUG
            ProviderDeveloperCredentialStatus(provider: provider)
            #endif

            if let proxyHealth {
                ProviderProxyProviderHealthBadge(health: proxyHealth)
            }

            if !canSearch {
                ProviderSearchGate(provider: provider)
            }

            if canSearch && !isSelected {
                Button(action: selectProvider) {
                    Label("Use provider", systemImage: "checkmark.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(RailDesign.Palette.accent)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
    }

    private var statusText: String {
        if isActive { return "Active" }
        if canSearch { return "Available" }
        return provider.implementationStatus.displayName
    }
}

private struct ProviderActiveSummary: View {
    let provider: ProviderMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RailDesign.Palette.mint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text("Active provider")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                        ProviderStatusPill(text: provider.availability.status.displayName, tint: provider.availability.status.tint)
                    }

                    Text(provider.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(provider.region.displayName) / \(provider.capabilitySummary)")
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(provider.availability.message)
                        .font(.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active provider \(provider.displayName), \(provider.region.displayName)")
    }
}

private struct ProviderStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, RailDesign.Spacing.xs)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct ProviderRequirementSummary: View {
    let provider: ProviderMetadata

    var body: some View {
        if !provider.operationalRequirements.isEmpty {
            ProviderPillGrid(
                items: provider.operationalRequirements,
                tint: RailDesign.Palette.secondaryText
            )
        }
    }
}

private struct ProviderCapabilityStrip: View {
    let capabilities: Set<ProviderCapability>

    private var sortedCapabilities: [ProviderCapability] {
        capabilities.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: RailDesign.Spacing.xs)], alignment: .leading, spacing: RailDesign.Spacing.xs) {
            ForEach(sortedCapabilities) { capability in
                Text(capability.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RailDesign.Palette.accent.opacity(0.10), in: Capsule())
            }
        }
    }
}

private struct ProviderSourceDisclosure: View {
    let provider: ProviderMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            if !provider.sourceLinks.isEmpty {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text("Sources")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    ForEach(Array(provider.sourceLinks.prefix(3))) { link in
                        Link(destination: link.url) {
                            Label(link.title, systemImage: "arrow.up.right.square")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(RailDesign.Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
            }

            if !provider.sourcePolicyRequirements.isEmpty {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text("Attribution and terms")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    ProviderPillGrid(
                        items: provider.sourcePolicyRequirements,
                        tint: RailDesign.Palette.marine
                    )
                }
            }
        }
    }
}

private struct ProviderDeveloperCredentialStatus: View {
    let provider: ProviderMetadata

    var body: some View {
        Label(credentialText, systemImage: credentialSymbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(credentialTint)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, RailDesign.Spacing.xs)
            .padding(.vertical, 6)
            .background(credentialTint.opacity(0.12), in: RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous))
            .accessibilityLabel("Developer credential status")
            .accessibilityValue(credentialText)
    }

    private var credentialText: String {
        switch provider.authStrategy {
        case .none:
            return "No provider credential required."
        case .localKey(let environmentVariable, _):
            switch provider.availability.status {
            case .degraded:
                return "\(environmentVariable) missing; starter catalog fallback is active."
            case .available:
                return "\(environmentVariable) configured for this build."
            default:
                return "\(environmentVariable) required before full provider coverage."
            }
        case .proxy:
            return "Requires a provider proxy; not selectable in this build."
        case .oauth:
            return "Requires OAuth/provider account setup before search."
        case .custom(let label):
            return "\(label) required before search."
        }
    }

    private var credentialSymbol: String {
        switch provider.availability.status {
        case .available:
            return "checkmark.shield.fill"
        case .degraded:
            return "exclamationmark.shield.fill"
        case .requiresConfiguration, .requiresProxy, .unavailable:
            return "lock.shield"
        }
    }

    private var credentialTint: Color {
        switch provider.availability.status {
        case .available:
            return RailDesign.Palette.mint
        case .degraded:
            return RailDesign.Palette.amber
        case .requiresConfiguration, .requiresProxy:
            return RailDesign.Palette.copper
        case .unavailable:
            return RailDesign.Palette.secondaryText
        }
    }
}

private struct ProviderSearchGate: View {
    let provider: ProviderMetadata

    var body: some View {
        Label(searchGateText, systemImage: "lock")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(RailDesign.Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, RailDesign.Spacing.xs)
            .padding(.vertical, 6)
            .background(RailDesign.Palette.hairline.opacity(0.75), in: RoundedRectangle(cornerRadius: RailDesign.Radius.sm, style: .continuous))
    }

    private var searchGateText: String {
        switch provider.implementationStatus {
        case .active:
            return "Search unavailable until required provider setup is complete."
        case .planned:
            return "Planned provider: not selectable or searchable in this build."
        case .disabled:
            return "Disabled provider: not selectable or searchable."
        }
    }
}

private struct ProviderPillGrid: View {
    let items: [String]
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: RailDesign.Spacing.xs)], alignment: .leading, spacing: RailDesign.Spacing.xs) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.10), in: Capsule())
            }
        }
    }
}

private extension ProviderMetadata {
    var sourcePolicyRequirements: [String] {
        requirements.compactMap { requirement in
            switch requirement {
            case .attribution(let label):
                return "Attribution: \(label)"
            case .terms(let label):
                return "Terms: \(label)"
            case .networkAccess, .localKey, .proxy, .providerAccount:
                return nil
            }
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var operationalRequirements: [String] {
        requirements.compactMap { requirement in
            switch requirement {
            case .networkAccess, .localKey, .proxy, .providerAccount:
                return requirement.displayName
            case .attribution, .terms:
                return nil
            }
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

private extension ProviderAvailability.Status {
    var displayName: String {
        switch self {
        case .available:
            return "Available"
        case .degraded:
            return "Fallback"
        case .requiresConfiguration:
            return "Needs setup"
        case .requiresProxy:
            return "Needs proxy"
        case .unavailable:
            return "Unavailable"
        }
    }

    var tint: Color {
        switch self {
        case .available:
            return RailDesign.Palette.mint
        case .degraded:
            return RailDesign.Palette.amber
        case .requiresConfiguration, .requiresProxy:
            return RailDesign.Palette.copper
        case .unavailable:
            return RailDesign.Palette.secondaryText
        }
    }
}

private extension ProviderProxyHealthStatus {
    var tint: Color {
        switch self {
        case .ok:
            return RailDesign.Palette.mint
        case .missingCredential, .rateLimited, .stale:
            return RailDesign.Palette.amber
        case .offline:
            return RailDesign.Palette.copper
        case .unsupported, .unknown:
            return RailDesign.Palette.secondaryText
        }
    }

    var symbolName: String {
        switch self {
        case .ok:
            return "checkmark.shield.fill"
        case .missingCredential:
            return "lock.shield"
        case .rateLimited:
            return "speedometer"
        case .offline:
            return "wifi.slash"
        case .stale:
            return "clock.badge.exclamationmark"
        case .unsupported:
            return "nosign"
        case .unknown:
            return "questionmark.circle"
        }
    }
}





private struct RailHistoryMetrics {
    let trips: [TrainTrip]
    let useMetric: Bool

    var tripCount: Int {
        trips.count
    }

    var stationCount: Int {
        Set(trips.flatMap { [$0.origin.name, $0.destination.name] + $0.stops.map(\.name) }).count
    }

    var operatorCount: Int {
        Set(trips.map(\.operatorName)).count
    }

    var delayCount: Int {
        trips.filter { $0.statusTone != .good || RailServiceStatus.from($0) == .delayed }.count
    }

    var yearSummary: String {
        tripCount == 1 ? "1 trip" : "\(tripCount) trips"
    }

    var distanceText: String {
        trips
            .compactMap(\.distanceText)
            .map { UnitConverter.displayDistance($0, useMetric: useMetric) }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? "Not logged"
    }

    var hoursText: String {
        let minutes = trips.reduce(0) { $0 + $1.durationMinutes }
        guard minutes > 0 else { return "Not logged" }
        return "\(minutes / 60)h"
    }

    var regionText: String {
        trips.isEmpty ? "Not logged" : "Japan"
    }

    var longestTrip: String {
        trips.max { $0.durationMinutes < $1.durationMinutes }
            .map { "\($0.train), \($0.duration)" } ?? "Not available"
    }

    var mostUsedRoute: String {
        mostFrequent(trips.map(\.service)) ?? "Not available"
    }

    var mostVisitedStation: String {
        mostFrequent(trips.flatMap { [$0.origin.name, $0.destination.name] + $0.stops.map(\.name) }) ?? "Not available"
    }

    var delaySummary: String {
        delayCount == 0 ? "No tracked delays" : "\(delayCount) tracked notice\(delayCount == 1 ? "" : "s")"
    }

    private func mostFrequent(_ values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 })
            .max { lhs, rhs in lhs.value.count < rhs.value.count }?
            .key
    }
}

private struct StationSnapshot: Identifiable, Hashable {
    let name: String
    let code: String
    let trips: [TrainTrip]

    var id: String { name }

    var departureTrips: [TrainTrip] {
        trips.filter { $0.origin.name == name || $0.stops.contains { $0.name == name && $0.state != .done } }
    }

    var arrivalTrips: [TrainTrip] {
        trips.filter { $0.destination.name == name || $0.stops.contains { $0.name == name && $0.state == .done } }
    }

    var platforms: [String] {
        Array(
            Set(
                trips.flatMap { trip in
                    ([trip.origin.name: trip.displayPlatform][name].map { [$0] } ?? []) +
                    trip.stops.filter { $0.name == name }.map(\.displayPlatform)
                }
            )
        )
        .sorted()
    }

    var routeNames: [String] {
        Array(Set(trips.map(\.service))).sorted()
    }

    var status: RailServiceStatus {
        if trips.contains(where: { RailServiceStatus.from($0) == .canceled }) {
            return .canceled
        }
        if trips.contains(where: { RailServiceStatus.from($0) == .delayed || RailServiceStatus.from($0) == .disruption }) {
            return .disruption
        }
        return .onTime
    }
}

private extension TrainStore {
    var offlineMessage: String? {
        if case .offline(let message) = liveLoadState {
            return message
        }
        return nil
    }

    var stationSnapshots: [StationSnapshot] {
        let stationNames = Set(
            trips.flatMap { trip in
                [trip.origin.name, trip.destination.name] + trip.stops.map(\.name)
            }
        )

        return stationNames.sorted().map { stationName in
            let matchingTrips = trips.filter { trip in
                trip.origin.name == stationName ||
                trip.destination.name == stationName ||
                trip.stops.contains { $0.name == stationName }
            }
            let code = matchingTrips
                .compactMap { trip in
                    if trip.origin.name == stationName { return trip.origin.code }
                    if trip.destination.name == stationName { return trip.destination.code }
                    return nil
                }
                .first ?? String(stationName.prefix(3))

            return StationSnapshot(name: stationName, code: code, trips: matchingTrips)
        }
    }
}

private extension TrainTrip {
    var shareText: String {
        let formattedETA = eta.formattedAsTime(in: destination.timeZone)
        return "\(train): \(origin.name) to \(destination.name), \(status), platform \(displayPlatform), ETA \(formattedETA). Source: \(sourceProvenance.sourceKind.riderTitle), \(sourceProvenance.freshness.displayName)."
    }

    var transferSummary: String {
        let transferStops = stops.filter { $0.note.localizedCaseInsensitiveContains("handoff") || $0.note.localizedCaseInsensitiveContains("transfer") }
        return transferStops.isEmpty ? "Direct" : "\(transferStops.count) transfer cue\(transferStops.count == 1 ? "" : "s")"
    }

    var transferWarningCopy: LocalizedStringKey {
        if statusTone == .good {
            return "No urgent transfer warning is attached to this trip. Recheck platform and stop notes before changing trains."
        }
        return "This service has an alert. Leave extra time for the next platform, route change, or operator handoff."
    }

    var durationMinutes: Int {
        var total = 0
        let pieces = duration.split(separator: " ")
        for piece in pieces {
            if piece.hasSuffix("h"), let hours = Int(piece.dropLast()) {
                total += hours * 60
            } else if piece.hasSuffix("m"), let minutes = Int(piece.dropLast()) {
                total += minutes
            }
        }
        return total
    }

    var vehicleCoordinate: CLLocationCoordinate2D? {
        guard let latitude = vehicleLatitude, let longitude = vehicleLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var previewRegion: MKCoordinateRegion {
        let coordinates = ([origin.coordinate, destination.coordinate, vehicleCoordinate] + stops.map { stop in
            if stop.name == origin.name {
                return origin.coordinate
            }
            if stop.name == destination.name {
                return destination.coordinate
            }
            return nil
        })
        .compactMap { $0 }

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
                latitudeDelta: max(0.8, (maxLatitude - minLatitude) * 1.8),
                longitudeDelta: max(0.8, (maxLongitude - minLongitude) * 1.8)
            )
        )
    }
}

private extension StationPoint {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension String {
    var railFeedDisplayText: String {
        replacingOccurrences(of: "updated 0s ago", with: "updated now")
            .replacingOccurrences(of: "updated 1s ago", with: "updated now")
    }
}

private extension View {
    func listCardRow() -> some View {
        listRowInsets(EdgeInsets(top: 8, leading: RailDesign.Spacing.m, bottom: 8, trailing: RailDesign.Spacing.m))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview("Trips") {
    ContentView()
}

#Preview("Detail") {
    NavigationStack {
        TrainDetailView(store: TrainStore(defaults: UserDefaults(suiteName: "preview.detail")!), tripID: TrainTrip.samples[0].id)
    }
}
