import MapKit
import SwiftUI
import UIKit

public struct ContentView: View {
    @ObservedObject private var rootDependencies: TrainyRootDependencies
    @ObservedObject private var store: TrainStore
    @State private var selectedTab: RailTab = .trips
    @State private var presentedSheet: RailSheet?
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue
    @AppStorage("trainy.sourceLabelVerbosity") private var sourceLabelVerbosityRaw = UserPreferences.SourceLabelVerbosity.compact.rawValue
    @AppStorage("trainy.diagnosticsConsent") private var diagnosticsConsent = false

    public init(rootDependencies: TrainyRootDependencies) {
        _rootDependencies = ObservedObject(wrappedValue: rootDependencies)
        _store = ObservedObject(wrappedValue: rootDependencies.store)
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
                StationsScreen(
                    store: store,
                    nsProvider: rootDependencies.nsProvider,
                    nsStartsLoading: rootDependencies.nsStartsLoading
                )
            }
            .tabItem { Label(RailTab.stations.title, systemImage: RailTab.stations.symbolName) }
            .tag(RailTab.stations)

            NavigationStack {
                HistoryScreen(store: store)
            }
            .tabItem { Label(RailTab.history.title, systemImage: RailTab.history.symbolName) }
            .tag(RailTab.history)

            NavigationStack {
                SettingsScreen(store: store, diagnosticsConsent: $diagnosticsConsent)
            }
            .tabItem { Label(RailTab.settings.title, systemImage: RailTab.settings.symbolName) }
            .tag(RailTab.settings)
        }
        .environment(\.railInterfacePreferences, interfacePreferences)
        .tint(RailDesign.Palette.accent.opacity(0.78))
        .railTabBarChrome()
        .task {
            await store.bootstrapLiveData()
        }
        .onAppear {
            presentFirstRunIfNeeded()
        }
        .onChange(of: store.shouldShowFirstRun) { _, shouldShowFirstRun in
            presentedSheet = shouldShowFirstRun ? .firstRun : nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainyFocusSearch)) { _ in
            selectedTab = .search
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
                    browseProviders: {
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

    private var interfacePreferences: RailInterfacePreferences {
        RailInterfacePreferences(
            timeFormat: UserPreferences.TimeFormat(rawValue: timeFormatRaw) ?? .hour12,
            unitSystem: UserPreferences.UnitSystem(rawValue: unitSystemRaw) ?? .metric,
            sourceLabelVerbosity: UserPreferences.SourceLabelVerbosity(rawValue: sourceLabelVerbosityRaw) ?? .compact,
            diagnosticsConsent: diagnosticsConsent
        )
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
    let browseProviders: () -> Void
    let skip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        RailIconBadge(symbol: "checkmark.seal.fill", tint: RailDesign.Palette.accent, size: .hero)
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Welcome to Trainy")
                                .font(RailDesign.Typography.h1)
                                .foregroundStyle(RailDesign.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Japan Shinkansen and Netherlands station boards are ready. Every status includes its source and freshness context.")
                                .font(RailDesign.Typography.body)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        SectionHeader(title: "What each label means", subtitle: "Trainy never overclaims live data; the source is always labeled.")
                        RailSurface {
                            VStack(spacing: 0) {
                                FirstRunScopeRow(symbol: "books.vertical.fill", title: "Starter catalog", detail: "Curated Shinkansen examples are available without provider credentials")
                                RailDivider()
                                FirstRunScopeRow(symbol: "calendar.badge.checkmark", title: "Official timetable", detail: "ODPT and JR timetable data is shown as scheduled when those sources return trips")
                                RailDivider()
                                FirstRunScopeRow(symbol: "dot.radiowaves.left.and.right", title: "Realtime", detail: "Predictions and vehicle positions only appear when a provider supplies those feeds")
                            }
                        }
                    }
                }
                .padding(RailDesign.Spacing.m)
                .padding(.bottom, RailDesign.Layout.deepScrollBottomInset)
            }
            .background(RailGradientBackground().ignoresSafeArea())
            .navigationTitle("Trainy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: skip)
                        .font(RailDesign.Typography.h3)
                        .frame(minHeight: 44)
                        .accessibilityHint("Skip the data-scope onboarding for now")
                }
            }
            .safeAreaInset(edge: .bottom) {
                FirstRunActionBar(
                    startWithShinkansen: startWithShinkansen,
                    browseProviders: browseProviders
                )
            }
        }
        .accessibilityIdentifier("onboarding.screen")
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
        let trips: [TrainTrip]
        switch bucket {
        case .upcoming:
            trips = store.filteredTrips.filter { $0.progress <= 0.12 }
        case .active:
            trips = store.filteredTrips.filter { $0.progress > 0.12 && $0.progress < 0.95 }
        case .past:
            trips = store.filteredTrips.filter { $0.progress >= 0.95 }
        }

        guard bucket == .active, let selectedTrip = activeHeroTrip else {
            return trips
        }
        return trips.filter { $0.id != selectedTrip.id }
    }

    private var activeHeroTrip: TrainTrip? {
        guard bucket == .active, let selectedTrip = store.selectedTrip else { return nil }
        guard selectedTrip.progress > 0.12 && selectedTrip.progress < 0.95 else { return nil }
        return selectedTrip
    }

    private var listSectionTitle: LocalizedStringKey {
        bucket == .active && activeHeroTrip != nil ? "More active journeys" : bucket.sectionTitle
    }

    var body: some View {
        List {
            Section {
                TripsHeaderRow(statusText: store.liveStatusText.railFeedDisplayText) {
                    isShowingAddTrip = true
                }
                .railListCardRow()

                RailSegmentedControl(
                    options: TripBucket.allCases,
                    selection: $bucket,
                    title: \.title
                )
                    .railListCardRow()

                if let offlineMessage = store.offlineMessage {
                    OfflineBanner(message: offlineMessage) {
                        Task { await store.searchLiveTrips(matching: store.query) }
                    }
                    .railListCardRow()
                }

                if store.liveLoadState == .loading && store.trips.isEmpty {
                    LoadingSkeletonView(rows: 3)
                        .railListCardRow()
                } else if store.trips.isEmpty {
                    EmptyStateView(
                        title: "No saved journeys",
                        message: "Search by train number, route, station pair, operator, or time to start tracking.",
                        actionTitle: "Add Trip"
                    ) {
                        isShowingAddTrip = true
                    }
                    .railListCardRow()
                } else if let selectedTrip = activeHeroTrip {
                    ActiveTripSummary(trip: selectedTrip, store: store) {
                        selectedMapRoute = RailMapRoute(id: selectedTrip.id)
                    }
                    .railListCardRow()
                }
            }

            Section {
                if !displayedTrips.isEmpty {
                    SectionHeader(title: listSectionTitle, subtitle: store.liveStatusText.railFeedDisplayText)
                        .railListCardRow()
                }

                if displayedTrips.isEmpty && !store.trips.isEmpty && activeHeroTrip == nil {
                    EmptyStateView(
                        title: bucket.emptyTitle,
                        message: bucket.emptyMessage,
                        symbolName: bucket.emptySymbol,
                        actionTitle: "Search Rail"
                    ) {
                        isShowingAddTrip = true
                    }
                    .railListCardRow()
                } else {
                    ForEach(displayedTrips) { trip in
                        Button {
                            selectedTripRoute = TripRoute(id: trip.id)
                        } label: {
                            TrainTripCard(trip: trip, role: bucket.cardRole)
                        }
                        .buttonStyle(.plain)
                        .railListCardRow()
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                store.togglePin(for: trip)
                            } label: {
                                Label(store.isPinned(trip) ? "Unfavorite" : "Favorite", systemImage: store.isPinned(trip) ? "star.slash" : "star")
                            }
                            .tint(RailDesign.Palette.warning)
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
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
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
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Label("Japan Shinkansen", systemImage: "train.side.front.car")
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(statusText)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Button(action: addTrip) {
                Image(systemName: "plus")
                    .font(RailDesign.Typography.h3.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle())
            .background(RailDesign.Palette.panel.opacity(0.72), in: Circle())
            .overlay(Circle().stroke(RailDesign.Palette.hairline, lineWidth: 1))
            .accessibilityLabel("Add trip")
            .accessibilityHint("Search for a new train to track")
        }
        .padding(.vertical, RailDesign.Spacing.xs)
    }
}

private struct ActiveTripSummary: View {
    let trip: TrainTrip
    @ObservedObject var store: TrainStore
    let openMap: () -> Void
    @State private var activeStatusMessage: LocalizedStringKey?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    /// Presents a transient action status message to the rider.
    private func showStatus(_ message: LocalizedStringKey) {
        updateStatus(message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            updateStatus(nil)
        }
    }

    /// Replaces or clears the current transient action status message.
    private func updateStatus(_ message: LocalizedStringKey?) {
        if reduceMotion {
            activeStatusMessage = message
        } else {
            withAnimation(RailDesign.Motion.quick) {
                activeStatusMessage = message
            }
        }
    }

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(
            in: trip.origin.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedETA: String {
        trip.eta.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(trip.train)
                            .font(RailDesign.Typography.h2.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.fromTo)
                            .font(RailDesign.Typography.h3)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: RailDesign.Spacing.s)
                    VStack(alignment: .trailing, spacing: RailDesign.Spacing.xs) {
                        ServiceStatusPill(status: RailServiceStatus.from(trip))
                        SourceBadge(trip: trip)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                        Text(formattedOriginTime)
                            .font(RailDesign.Typography.display.monospacedDigit())
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.origin.name)
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: RailDesign.Spacing.xs)
                    Image(systemName: "arrow.right")
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .accessibilityHidden(true)
                    Spacer(minLength: RailDesign.Spacing.xs)
                    VStack(alignment: .trailing, spacing: RailDesign.Spacing.xxs) {
                        Text(formattedDestinationTime)
                            .font(RailDesign.Typography.display.monospacedDigit())
                            .foregroundStyle(RailDesign.Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(trip.destination.name)
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }

                ProgressView(value: trip.progress)
                    .tint(RailServiceStatus.from(trip).tint)
                    .accessibilityLabel("Journey progress")
                    .accessibilityValue("\(Int(trip.progress * 100)) percent")
            }
            .padding(RailDesign.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(RailDesign.Palette.hairline)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(spacing: RailDesign.Spacing.xs) {
                    ControlMetricTile(title: "Next", value: trip.nextStop, symbol: "location.north.line.fill", tint: RailDesign.Palette.accent)
                    ControlMetricTile(title: "ETA", value: formattedETA, symbol: "clock", tint: RailDesign.Palette.info)
                    ControlMetricTile(
                        title: "Platform",
                        value: trip.displayPlatform,
                        symbol: "rectangle.split.3x1.fill",
                        tint: trip.platformDisplayState.isKnown ? RailDesign.Palette.info : RailDesign.Palette.secondaryText
                    )
                }

                Button(action: openMap) {
                    HStack(spacing: RailDesign.Spacing.s) {
                        Image(systemName: "map.fill")
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.accent)
                            .frame(width: 34, height: 34)
                            .background(RailDesign.Palette.accent.opacity(0.12), in: Circle())

                        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                            Text("Open rail map")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.ink)
                            Text("Route line, map position, stops, and disruptions")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.ink.opacity(0.68))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(RailDesign.Typography.caption.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                    .padding(RailDesign.Spacing.s)
                    .background(RailDesign.Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                            .stroke(RailDesign.Palette.accent.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel(Text("Open rail map for " + trip.train))

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    if let message = activeStatusMessage {
                        SuccessBanner(symbol: "checkmark.circle.fill", title: message)
                            .transition(
                                reduceMotion
                                    ? .identity
                                    : .opacity.combined(with: .move(edge: .top))
                            )
                    }
                    HStack(spacing: RailDesign.Spacing.s) {
                        Button {
                            store.refreshSelectedTrip()
                            showStatus("Refreshed \(trip.train)")
                        } label: {
                            TripToolButton(symbol: "arrow.clockwise", title: "Refresh")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel("Refresh trip")

                        Button {
                            store.toggleNotification(for: trip)
                            showStatus(store.isNotified(trip) ? "Alerts enabled for \(trip.train)" : "Alerts muted for \(trip.train)")
                        } label: {
                            TripToolButton(symbol: store.isNotified(trip) ? "bell.fill" : "bell", title: store.isNotified(trip) ? "Alerts on" : "Alerts off")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel(Text(store.isNotified(trip) ? ("Turn off alerts for " + trip.train) : ("Turn on alerts for " + trip.train)))

                        ShareLink(item: trip.shareText) {
                            TripToolButton(symbol: "square.and.arrow.up", title: "Share")
                        }
                        .buttonStyle(PressableButtonStyle())
                        .accessibilityLabel(Text("Share " + trip.train))
                        .simultaneousGesture(TapGesture().onEnded {
                            showStatus("Share sheet opened for \(trip.train)")
                        })
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
        }
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                .stroke(RailDesign.Palette.hairline, lineWidth: 1)
        )
    }
}






private struct SearchScreen: View {
    @ObservedObject var store: TrainStore
    var showsCloseButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFieldFocused: Bool
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
                    OfflineBanner(message: offlineMessage) {
                        Task { await store.searchLiveTrips(matching: searchText) }
                    }
                }

                SearchHeroView(scopeText: store.searchScopeText)

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
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Train number, station pair, operator, route, or time"
        )
        .searchFocused($searchFieldFocused)
        .onReceive(NotificationCenter.default.publisher(for: .trainyFocusSearch)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                searchFieldFocused = true
            }
        }
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

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: "scope")
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 32, height: 32)
                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(scopeText)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                    .lineLimit(1)
                Text("Search scheduled and saved services by train, station pair, route, operator, or departure time.")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


private struct SearchCapabilityNoticeView: View {
    let notice: TrainStore.SearchCapabilityNotice

    private var tint: Color {
        switch notice.kind {
        case .realtimeUnavailable:
            return RailDesign.Palette.info
        case .scheduleUnavailable:
            return RailDesign.Palette.warning
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: notice.symbolName)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(notice.title)
                    .font(RailDesign.Typography.h3.weight(.bold))
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(notice.message)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(RailDesign.Spacing.m)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
                .padding(.horizontal, RailDesign.Layout.progressStrokeInset)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RecentSearchesView: View {
    let examples: [String]
    let providerName: String
    let select: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            SectionHeader(title: "Try a search", subtitle: providerName)
            VStack(spacing: 0) {
                ForEach(examples, id: \.self) { item in
                    Button {
                        select(item)
                    } label: {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                            Text(item)
                                .foregroundStyle(RailDesign.Palette.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                        }
                        .font(RailDesign.Typography.small)
                        .padding(.vertical, RailDesign.Spacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Search for " + item))
                    if item != examples.last {
                        Divider().background(RailDesign.Palette.hairline)
                    }
                }
            }
            .padding(.horizontal, RailDesign.Spacing.m)
            .background(
                RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                    .fill(RailDesign.Palette.panel)
            )
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
                                .background(RailDesign.Palette.panel, in: RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: RailDesign.Radius.control, style: .continuous)
                                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, RailDesign.Spacing.xxs)
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
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(
            in: trip.origin.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(trip.train)
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text(trip.operatorName)
                        .font(RailDesign.Typography.caption.weight(.semibold))
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
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(formattedOriginTime)
                        .font(RailDesign.Typography.h3.monospacedDigit())
                    Text(trip.origin.name)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: RailDesign.Spacing.xxs) {
                    Text(formattedDestinationTime)
                        .font(RailDesign.Typography.h3.monospacedDigit())
                    Text(trip.destination.name)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(RailDesign.Palette.ink)

            HStack {
                PlatformChip(platform: trip.platform)
                Spacer()
                Button(action: track) {
                    Label("Track", systemImage: "plus.circle")
                }
                .font(RailDesign.Typography.h3)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(RailDesign.Palette.accent)
                .accessibilityIdentifier("search.track.\(trip.id)")
            }
        }
        .padding(RailDesign.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                .fill(RailDesign.Palette.panel)
        )
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
        .accessibilityIdentifier("search.result.\(trip.id)")
    }
}


private struct StationsScreen: View {
    @ObservedObject var store: TrainStore
    let nsProvider: any NSRiderDataProviding
    let nsStartsLoading: Bool
    @State private var stationQuery = ""

    private var stations: [StationSnapshot] {
        let cleanQuery = stationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let snapshots = store.stationSnapshots
        guard !cleanQuery.isEmpty else { return snapshots }
        return snapshots.filter { station in
            station.name.localizedCaseInsensitiveContains(cleanQuery) || station.code.localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    private var overview: String {
        let platforms = store.watchedPlatformCount
        let risks = store.riskCount
        return "\(store.stationSnapshots.count) stations · \(platforms) platforms · \(risks) need watch"
    }

    /// Builds one accessible station-navigation row for the station directory.
    @ViewBuilder
    private func stationRow(for station: StationSnapshot) -> some View {
        NavigationLink {
            StationDetailView(station: station)
        } label: {
            StationCard(station: station)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(station.name), \(station.code), \(station.departureTrips.count) departures, \(station.platforms.count) tracks"
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                NavigationLink {
                    NSStationSearchView(provider: nsProvider, startsLoading: nsStartsLoading)
                } label: {
                    RailSurface(role: .accent(RailDesign.Palette.accent)) {
                        RailNavigationCard(
                            symbol: "train.side.front.car",
                            title: "NS departures",
                            detail: store.providerProxyConfiguration.isConfigured
                                ? "Search Dutch stations and open proxy-backed departure boards."
                                : "Rider surface ready; a configured provider proxy is required for NS data.",
                            tint: RailDesign.Palette.accent
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens NS station search and freshness-labelled departure boards")
                .accessibilityIdentifier("stations.nsDepartures")
                .padding(.horizontal, RailDesign.Spacing.m)
                .padding(.top, RailDesign.Spacing.s)

                HStack {
                    Text(overview)
                        .font(RailDesign.Typography.small.weight(.medium))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Spacer()
                    if !stations.isEmpty {
                        Text("\(stations.count) shown")
                            .font(RailDesign.Typography.caption)
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)
                .padding(.top, RailDesign.Spacing.s)

                LazyVStack(spacing: RailDesign.Spacing.xs) {
                    ForEach(stations) { station in
                        stationRow(for: station)
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)

                if stations.isEmpty {
                    EmptyStateView(
                        title: "No station found",
                        message: "Search a station name, short code, platform, or route stop.",
                        symbolName: "tram.circle",
                        actionTitle: "Search a train"
                    ) {
                        // Focus the searchable field by sending a notification
                        // that SearchScreen listens for and re-focuses itself.
                        NotificationCenter.default.post(name: .trainyFocusSearch, object: nil)
                    }
                    .padding(.horizontal, RailDesign.Spacing.m)
                }
            }
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Stations")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $stationQuery, prompt: "Station, platform, or route")
        .railScreenChrome()
    }
}


private struct StationCard: View {
    let station: StationSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
            HStack {
                StationBadge(name: station.name, code: station.code)
                Spacer()
                ServiceStatusPill(status: station.status)
                Image(systemName: "chevron.right")
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
            }

            Text("\(station.departureTrips.count) departures · \(station.platforms.count) tracks · \(station.routeNames.count) routes")
                .font(RailDesign.Typography.small)
                .foregroundStyle(RailDesign.Palette.secondaryText)
                .monospacedDigit()
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
}

private struct StationDetailView: View {
    let station: StationSnapshot
    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                    HStack(alignment: .top) {
                        StationBadge(name: station.name, code: station.code)
                        Spacer()
                        Button {
                            isFavorite.toggle()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(isFavorite ? RailDesign.Palette.warning : RailDesign.Palette.secondaryText)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(RailDesign.Palette.panel, in: Circle())
                        .overlay(Circle().stroke(RailDesign.Palette.hairline, lineWidth: 1))
                        .accessibilityLabel(isFavorite ? "Remove favorite station" : "Favorite station")
                        .accessibilityHint("Stars this station for quick access on the Stations tab")
                    }

                    HStack(spacing: RailDesign.Spacing.s) {
                        MetricTile(title: "Departures", value: "\(station.departureTrips.count)", subtitle: "tracked", symbolName: "arrow.up.right", tint: RailDesign.Palette.accent)
                        MetricTile(title: "Platforms", value: station.platforms.prefix(3).joined(separator: ", "), subtitle: "known", symbolName: "rectangle.split.3x1", tint: RailDesign.Palette.info)
                    }
                }
                .padding(RailDesign.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                )

                BoardSection(title: "Tracked departures", trips: station.departureTrips, empty: "No tracked departures for this station.")
                BoardSection(title: "Arrivals", trips: station.arrivalTrips, empty: "No tracked arrivals for this station.")

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(title: "Station notes", subtitle: "Facilities, access, disruptions, and popular route clues")
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                        RailValueRow(symbol: "figure.roll", title: "Accessibility", value: "Step-free route details are not connected yet.", layout: .stacked)
                        RailValueRow(symbol: "cup.and.saucer", title: "Facilities", value: "Food, restrooms, and waiting areas depend on station data availability.", layout: .stacked)
                        RailValueRow(symbol: "exclamationmark.triangle", title: "Disruptions", value: station.status == .onTime ? "No tracked disruption in saved trips." : "One or more tracked trips need attention.", layout: .stacked)
                        RailValueRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Popular routes", value: station.routeNames.prefix(3).joined(separator: ", "), layout: .stacked)
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
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
                    .padding(.vertical, RailDesign.Spacing.l)
            } else {
                VStack(spacing: 0) {
                    ForEach(trips) { trip in
                        StationBoardRow(trip: trip)
                        if trip.id != trips.last?.id {
                            Divider().background(RailDesign.Palette.hairline)
                        }
                    }
                }
                .padding(.horizontal, RailDesign.Spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                )
            }
        }
    }
}

private struct StationBoardRow: View {
    let trip: TrainTrip
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    var body: some View { stationBoardContent }

    @ViewBuilder
    private var stationBoardContent: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            originTimeColumn
            columnStack
            Spacer()
            PlatformChip(platform: trip.platform, label: "Track")
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    private var originTimeColumn: some View {
        Text(
            trip.origin.time.formattedAsTime(
                in: trip.origin.timeZone,
                format: interfacePreferences.timeFormat
            )
        )
            .font(RailDesign.Typography.h3.monospacedDigit())
            .foregroundStyle(RailDesign.Palette.ink)
            .frame(width: 58, alignment: .leading)
    }

    private var columnStack: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
            Text(trip.destination.name)
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.ink)
            Text(trip.operatorName + " · " + trip.train)
                .font(RailDesign.Typography.caption)
                .foregroundStyle(RailDesign.Palette.secondaryText)
            SourceBadge(trip: trip)
        }
    }

    private var accessibilitySummary: String {
        trip.train + ", " + trip.origin.name + " to " + trip.destination.name + ", " + trip.sourceProvenance.sourceKind.riderTitle + ", " + trip.sourceProvenance.freshness.displayName
    }
}

private struct HistoryScreen: View {
    @ObservedObject var store: TrainStore


    private var longestTripSummary: String {
        guard let trip = store.trips.max(by: { $0.durationMinutes < $1.durationMinutes }) else {
            return "Not available"
        }
        return "\(trip.train), \(trip.duration)"
    }

    private var summary: String {
        let count = store.trips.count
        let stationCount = Set(store.trips.flatMap { [$0.origin.name, $0.destination.name] + $0.stops.map(\.name) }).count
        let operatorCount = Set(store.trips.map(\.operatorName)).count
        return "\(count) trips · \(stationCount) stations · \(operatorCount) operators"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                    Text(summary)
                        .font(RailDesign.Typography.h3)
                        .foregroundStyle(RailDesign.Palette.ink)
                    Text("Trip history is stored locally on this device until you share it.")
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
                .padding(RailDesign.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: RailDesign.Radius.card, style: .continuous)
                        .fill(RailDesign.Palette.panel)
                )

                SettingsGroup(title: "Highlights") {
                    RailValueRow(symbol: "arrow.left.and.right", title: "Longest trip", value: longestTripSummary)
                        .padding(.vertical, RailDesign.Spacing.xs)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    RailValueRow(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Most-used route", value: store.trips.isEmpty ? "Not available" : "Japan Shinkansen")
                        .padding(.vertical, RailDesign.Spacing.xs)
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    RailValueRow(symbol: "clock.badge.exclamationmark", title: "Delays tracked", value: store.trips.filter { RailServiceStatus.from($0) == .delayed }.count == 0 ? "No tracked delays" : "Some tracked delays")
                        .padding(.vertical, RailDesign.Spacing.xs)
                }

                if !store.trips.isEmpty {
                    SettingsGroup(title: "Recent journeys") {
                        ForEach(Array(store.trips.prefix(3))) { trip in
                            NavigationLink {
                                TrainDetailView(store: store, tripID: trip.id)
                            } label: {
                                HistoryTripRow(trip: trip)
                            }
                            .buttonStyle(.plain)

                            if trip.id != store.trips.prefix(3).last?.id {
                                Divider()
                                    .background(RailDesign.Palette.hairline)
                            }
                        }
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}


/// Compact history row that preserves the trip's route and duration context.
private struct HistoryTripRow: View {
    let trip: TrainTrip

    var body: some View {
        HStack(spacing: RailDesign.Spacing.s) {
            Image(systemName: "train.side.front.car")
                .font(RailDesign.Typography.h3)
                .foregroundStyle(RailDesign.Palette.accent)
                .frame(width: 32, height: 32)
                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(trip.train)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text("\(trip.origin.name) → \(trip.destination.name) · \(trip.duration)")
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: RailDesign.Spacing.s)

            Image(systemName: "chevron.right")
                .font(RailDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(RailDesign.Palette.secondaryText)
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.train), \(trip.origin.name) to \(trip.destination.name), \(trip.duration)")
    }
}


private struct SettingsScreen: View {
    @ObservedObject var store: TrainStore
    @Binding var diagnosticsConsent: Bool
    @AppStorage("trainy.timeFormat") private var timeFormatRaw = UserPreferences.TimeFormat.hour12.rawValue
    @AppStorage("trainy.unitSystem") private var unitSystemRaw = UserPreferences.UnitSystem.metric.rawValue

    private var usesMetricUnits: Binding<Bool> {
        Binding(
            get: { unitSystemRaw != UserPreferences.UnitSystem.imperial.rawValue },
            set: { unitSystemRaw = $0 ? UserPreferences.UnitSystem.metric.rawValue : UserPreferences.UnitSystem.imperial.rawValue }
        )
    }

    /// Returns rider-facing setup guidance without exposing credential names.
    private func providerDetail(for provider: ProviderMetadata) -> LocalizedStringKey {
        if provider.availability.message.contains("ODPT_CONSUMER_KEY") {
            return "Starter catalog is active. Add an ODPT consumer key in the developer configuration for official timetable and alert feeds."
        }
        if provider.id == "netherlands-ns" {
            return LocalizedStringKey(provider.availability.message)
        }
        return LocalizedStringKey(provider.availability.message)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                SettingsGroup(title: "Display") {
                    SettingsPickerRow(symbol: "clock", title: "Time format", detail: "Applies to trip cards, station boards, and shared trip text", selection: $timeFormatRaw, options: UserPreferences.TimeFormat.allCases.map(\.rawValue))
                    SettingsToggleRow(symbol: "ruler", title: "Metric units", detail: "Used for source-backed speed and distance values", isOn: usesMetricUnits)
                }

                SettingsGroup(title: "Providers") {
                    if let active = store.providerDirectory.first(where: { $0.id == store.activeProviderID }) {
                        SettingsNavigationRow(
                            symbol: "globe.asia.australia.fill",
                            title: LocalizedStringKey(active.displayName),
                            detail: providerDetail(for: active)
                        ) {
                            SupportedRegionsScreen(store: store)
                        }
                    } else {
                        SettingsInfoRow(symbol: "exclamationmark.triangle", title: "No active provider", detail: "Configured provider keys were not found.")
                    }
                    if store.providerProxyConfiguration.isConfigured {
                        Divider()
                            .background(RailDesign.Palette.hairline)
                        ProviderProxyStatusSummary(store: store)
                    }
                }

                SettingsGroup(title: "Privacy") {
                    SettingsInfoRow(
                        symbol: "internaldrive",
                        title: "On-device data",
                        detail: "Saved trips, pins, notification choices, provider and region choices, and display settings stay in Trainy's on-device storage."
                    )
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    SettingsToggleRow(
                        symbol: "stethoscope",
                        title: "Share crash diagnostics",
                        detail: "Opt in to Firebase Crashlytics crash reports. Trainy adds no trip details, searches, or user identifier. Changes take effect on the next launch.",
                        isOn: $diagnosticsConsent
                    )
                }

                SettingsGroup(title: "About") {
                    SettingsInfoRow(symbol: "info.circle", title: "Trainy", detail: "An original rail companion interface built with system fonts, SF Symbols, and app-owned data.")
                    Divider()
                        .background(RailDesign.Palette.hairline)
                    SettingsActionRow(
                        symbol: "sparkles.rectangle.stack",
                        title: "Onboarding guide",
                        detail: "Review how Trainy labels starter, scheduled, and realtime data.",
                        actionTitle: "Open"
                    ) {
                        store.resetFirstRun()
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .railScreenChrome()
    }
}


/// Displays configured proxy availability, per-provider health, and recovery controls.
private struct ProviderProxyStatusSummary: View {
    @ObservedObject var store: TrainStore

    var body: some View {
        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
            HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
                Image(systemName: statusSymbol)
                    .font(RailDesign.Typography.h3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusTint)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text("Provider proxy")
                            .font(RailDesign.Typography.h3)
                            .foregroundStyle(RailDesign.Palette.ink)
                        ProviderStatusPill(text: statusText, tint: statusTint)
                    }
                    Text(detailText)
                        .font(RailDesign.Typography.caption)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: RailDesign.Spacing.xs)

                Button {
                    Task {
                        await store.refreshProviderProxyHealth()
                    }
                } label: {
                    Label(actionTitle, systemImage: "arrow.clockwise")
                }
                .font(RailDesign.Typography.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(store.providerProxyLoadState == .loading)
                .accessibilityHint("Checks provider, cache, and proxy availability again")
            }

            if !store.providerProxyHealthProviders.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(store.providerProxyHealthProviders.prefix(6).enumerated()), id: \.element.id) { index, health in
                        if index > 0 {
                            Divider()
                                .background(RailDesign.Palette.hairline)
                        }
                        ProviderProxyHealthProviderRow(health: health)
                    }
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .task {
            guard store.providerProxyHealth == nil else { return }
            await store.refreshProviderProxyHealth()
        }
    }

    private var statusText: String {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return "Not configured"
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
            return "No provider proxy base URL is configured."
        case .idle:
            return "Ready to check app-safe provider health at \(store.providerProxyConfiguration.displayHost)."
        case .loading:
            return "Checking provider and cache health at \(store.providerProxyConfiguration.displayHost)."
        case .loaded(let generatedAt):
            let timestamp = generatedAt.map { Self.dateFormatter.string(from: $0) } ?? "an unknown time"
            return "Provider health was generated at \(timestamp)."
        case .unavailable(let message):
            return "Could not load provider health: \(message)"
        }
    }

    private var actionTitle: LocalizedStringKey {
        switch store.providerProxyLoadState {
        case .loading:
            return "Checking"
        case .unavailable:
            return "Retry"
        case .notConfigured, .idle, .loaded:
            return "Check"
        }
    }

    private var statusTint: Color {
        switch store.providerProxyLoadState {
        case .notConfigured:
            return RailDesign.Palette.secondaryText
        case .idle, .loading:
            return RailDesign.Palette.info
        case .loaded:
            return hasAttention ? RailDesign.Palette.warning : RailDesign.Palette.success
        case .unavailable:
            return RailDesign.Palette.danger
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

/// One proxy provider's reported health and static-feed cache state.
private struct ProviderProxyHealthProviderRow: View {
    let health: ProviderProxyProviderHealth

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: health.status.symbolName)
                .foregroundStyle(health.status.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(health.id)
                        .font(RailDesign.Typography.caption.weight(.bold))
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    ProviderStatusPill(text: health.status.displayName, tint: health.status.tint)
                }
                Text(health.message)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let cache = health.cache {
                    Text("Static feed: \(cache.staticFeed.displayName)")
                        .font(RailDesign.Typography.caption.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                }
            }
        }
        .padding(.vertical, RailDesign.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}


/// Provider-coverage directory grouped by rider availability and implementation readiness.
private struct SupportedRegionsScreen: View {
    @ObservedObject var store: TrainStore

    private var riderAvailableProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter(\.isRiderAvailable)
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var configurationRequiredProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter { $0.implementationStatus == .active && !$0.availability.canSearch }
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var adapterReadyProviders: [ProviderMetadata] {
        store.providerDirectory
            .filter { $0.implementationStatus == .adapterReady }
            .sorted { $0.region.displayName.localizedStandardCompare($1.region.displayName) == .orderedAscending }
    }

    private var selectedProvider: ProviderMetadata? {
        store.providerDirectory.first { $0.id == store.activeProviderID }
    }

    private var plannedRegionNames: [String] {
        let implementedRegionIDs = Set(
            (riderAvailableProviders + configurationRequiredProviders + adapterReadyProviders).map(\.region.id)
        )
        return store.providerRegions
            .filter { $0.id != ProviderRegion.all.id && !implementedRegionIDs.contains($0.id) }
            .map(\.displayName)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let selectedProvider {
                    SettingsGroup(title: "Search scope") {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "scope")
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.accent)
                                .frame(width: 32, height: 32)
                                .background(RailDesign.Palette.accent.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                                Text(selectedProvider.displayName)
                                    .font(RailDesign.Typography.h3)
                                    .foregroundStyle(RailDesign.Palette.ink)
                                Text("\(selectedProvider.region.displayName) · \(selectedProvider.capabilities.map(\.displayName).joined(separator: ", "))")
                                    .font(RailDesign.Typography.small)
                                    .foregroundStyle(RailDesign.Palette.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                    SectionHeader(title: "Coverage", subtitle: "Bright markers are rider-available now. Adapter-ready and planned regions remain muted.")
                    SupportedRegionsGlobe(activeRegions: riderAvailableProviders.map(\.region.displayName))
                }

                SettingsGroup(title: "Available now") {
                    ForEach(riderAvailableProviders) { provider in
                        SupportedRegionProviderRow(
                            provider: provider,
                            isActive: provider.id == store.activeProviderID
                        )
                        if provider.id != riderAvailableProviders.last?.id {
                            Divider()
                                .background(RailDesign.Palette.hairline)
                        }
                    }
                }

                if !configurationRequiredProviders.isEmpty {
                    SettingsGroup(title: "Needs setup") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("These rider-ready providers need their required proxy or local configuration before they can be used in this build.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(configurationRequiredProviders) { provider in
                                SupportedRegionProviderRow(provider: provider, isActive: false)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                if !adapterReadyProviders.isEmpty {
                    SettingsGroup(title: "Adapter ready") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Implemented and fixture-tested, but not rider-available until a secure data path and dedicated product surface are connected.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(adapterReadyProviders) { provider in
                                SupportedRegionProviderRow(provider: provider, isActive: false)
                            }
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }

                if !plannedRegionNames.isEmpty {
                    SettingsGroup(title: "Planned regions") {
                        VStack(alignment: .leading, spacing: RailDesign.Spacing.s) {
                            Text("Visible for roadmap transparency, but not selectable or searchable in this build.")
                                .font(RailDesign.Typography.small)
                                .foregroundStyle(RailDesign.Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            SupportedRegionPillGrid(names: plannedRegionNames)
                        }
                        .padding(.vertical, RailDesign.Spacing.s)
                    }
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle("Supported regions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .railScreenChrome()
    }
}


/// Decorative globe that summarizes only regions riders can currently use.
private struct SupportedRegionsGlobe: View {
    let activeRegions: [String]

    /// Normalized marker position on the decorative globe.
    private struct Marker: Identifiable {
        let id: String
        let x: CGFloat
        let y: CGFloat
    }

    private var markers: [Marker] {
        activeRegions.compactMap { region in
            switch region {
            case "Japan":
                return Marker(id: region, x: 0.78, y: 0.43)
            case "Netherlands":
                return Marker(id: region, x: 0.46, y: 0.31)
            default:
                return nil
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: RailDesign.Radius.panel, style: .continuous)
                    .fill(RailDesign.Palette.panel)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                RailDesign.Palette.inset,
                                RailDesign.Palette.backgroundLift
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(RailDesign.Palette.hairline, lineWidth: 1)
                    )
                    .frame(width: 190, height: 190)

                Image(systemName: "globe.asia.australia.fill")
                    .font(RailDesign.Typography.regionGlobe)
                    .foregroundStyle(RailDesign.Palette.secondaryText.opacity(0.18))
                    .symbolRenderingMode(.hierarchical)

                ForEach(markers) { marker in
                    ZStack {
                        Circle()
                            .fill(RailDesign.Palette.accent.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Circle()
                            .fill(RailDesign.Palette.accent)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(RailDesign.Palette.onAccent, lineWidth: 2))
                    }
                    .position(
                        x: proxy.size.width * marker.x,
                        y: proxy.size.height * marker.y
                    )
                }

                VStack {
                    Spacer()
                    HStack(spacing: RailDesign.Spacing.xs) {
                        Circle()
                            .fill(RailDesign.Palette.accent)
                            .frame(width: 8, height: 8)
                        Text("\(activeRegions.count) rider-available \(activeRegions.count == 1 ? "region" : "regions")")
                            .font(RailDesign.Typography.small.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.ink)
                    }
                    .padding(.horizontal, RailDesign.Spacing.s)
                    .padding(.vertical, RailDesign.Spacing.xs)
                    .railMaterialCapsule()
                    .padding(.bottom, RailDesign.Spacing.s)
                }
            }
        }
        .frame(height: 232)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rider-available regions: \(activeRegions.joined(separator: ", "))")
    }
}


/// One provider's region, readiness, and honest availability explanation.
private struct SupportedRegionProviderRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let provider: ProviderMetadata
    let isActive: Bool

    private var tint: Color {
        if isActive {
            return RailDesign.Palette.success
        }
        if !provider.availability.canSearch {
            return provider.availability.status.tint
        }
        return provider.implementationStatus == .adapterReady
            ? RailDesign.Palette.info
            : RailDesign.Palette.accent
    }

    private var statusText: String {
        if isActive {
            return "Selected"
        }
        if !provider.availability.canSearch {
            return provider.availability.status.displayName
        }
        return provider.implementationStatus.displayName
    }

    private var availabilityMessage: String {
        if provider.availability.message.contains("ODPT_CONSUMER_KEY") {
            return "Starter catalog is active. Add an ODPT consumer key in the developer configuration for official timetable and alert feeds."
        }
        if provider.id == "netherlands-ns" {
            if provider.availability.canSearch {
                return "Proxy-backed NS station search, departures, and service alerts are rider-available in this configured build."
            }
            return provider.availability.message
        }
        return provider.availability.message
    }

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: isActive ? "checkmark.seal.fill" : "circle.dashed")
                .font(RailDesign.Typography.h3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: RailDesign.Spacing.xs) {
                        Text(provider.region.displayName)
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        ProviderStatusPill(text: statusText, tint: tint)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                        Text(provider.region.displayName)
                            .font(RailDesign.Typography.h3.weight(.bold))
                            .foregroundStyle(RailDesign.Palette.ink)
                        ProviderStatusPill(text: statusText, tint: tint)
                    }
                }

                Text(provider.displayName)
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(availabilityMessage)
                    .font(RailDesign.Typography.caption)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// Compact grid for regions that remain outside the rider-available directory.
private struct SupportedRegionPillGrid: View {
    let names: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: RailDesign.Spacing.xs)], alignment: .leading, spacing: RailDesign.Spacing.xs) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(RailDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, RailDesign.Spacing.xs)
                    .padding(.vertical, RailDesign.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RailDesign.Palette.hairline.opacity(0.78), in: Capsule())
            }
        }
    }
}

/// Complete rider-facing detail surface for one selected trip.
private struct TrainDetailView: View {
    @ObservedObject var store: TrainStore
    let tripID: TrainTrip.ID
    @Environment(\.railInterfacePreferences) private var interfacePreferences
    @State private var sourceDetailTrip: TrainTrip?

    private var trip: TrainTrip? {
        store.trips.first { $0.id == tripID } ?? store.selectedTrip
    }

    private var useMetric: Bool {
        interfacePreferences.usesMetricUnits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.l) {
                if let trip {
                    TrainDetailHero(trip: trip)

                    SectionHeader(title: "Rail map", subtitle: "See the route, upcoming stops, and any disruption markers.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    NavigationLink {
                        RailJourneyMapScreen(trip: trip)
                    } label: {
                        TrainDetailMapLink(trip: trip)
                    }
                    .buttonStyle(PressableButtonStyle())

                    SectionHeader(title: "Next stops", subtitle: "Scheduled times, platforms, and the operator-handoff cue for this train.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    StopTimelineList(trip: trip)

                    SectionHeader(title: "Boarding and platform", subtitle: "Platform, carriage, seat, and current speed where the source supplies them.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    TrainDetailBoardingCard(trip: trip, useMetric: useMetric)

                    SectionHeader(title: "Source and freshness", subtitle: "Every fact on this card is labeled with its source, confidence, and freshness.")
                        .padding(.horizontal, RailDesign.Spacing.xs)

                    CompactSourcePanel(trip: trip) {
                        sourceDetailTrip = trip
                    }
                } else {
                    EmptyStateView(
                        title: "Trip unavailable",
                        message: "This trip is no longer saved. Search and track a service to open a detail view.",
                        symbolName: "train.side.front.car"
                    )
                }
            }
            .padding(RailDesign.Spacing.m)
            .padding(.bottom, RailDesign.Spacing.xxl)
        }
        .navigationTitle(trip?.train ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                RailToolbarIconButton(
                    symbol: "arrow.clockwise",
                    accessibilityLabel: "Refresh trip"
                ) {
                    store.refreshSelectedTrip()
                }

                if let trip {
                    RailToolbarShareLink(item: trip.shareText)
                }
            }
        }
        .onAppear {
            if let trip {
                store.select(trip)
            }
        }
        .sheet(item: $sourceDetailTrip) { trip in
            SourceDetailSheet(trip: trip)
        }
        .railScreenChrome()
    }
}


/// Navigation surface that opens the selected trip's full rail map.
private struct TrainDetailMapLink: View {
    let trip: TrainTrip

    var body: some View {
        RailSurface {
            RailNavigationCard(
                symbol: "map.fill",
                title: "Open rail map",
                detail: "Next: \(trip.nextStop) · \(trip.vehiclePositionDisplayState.mapLabel)"
            )
        }
        .accessibilityLabel("Open rail map for \(trip.train). Next stop \(trip.nextStop). \(trip.vehiclePositionDisplayState.mapLabel).")
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
            return RailDesign.Palette.success
        case .degraded:
            return RailDesign.Palette.warning
        case .requiresConfiguration, .requiresProxy:
            return RailDesign.Palette.info
        case .unavailable:
            return RailDesign.Palette.secondaryText
        }
    }
}

private extension ProviderProxyHealthStatus {
    var tint: Color {
        switch self {
        case .ok:
            return RailDesign.Palette.success
        case .missingCredential, .rateLimited, .stale:
            return RailDesign.Palette.warning
        case .offline:
            return RailDesign.Palette.danger
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
        let formattedETA = eta.formattedAsTime(
            in: destination.timeZone,
            format: UserPreferences.shared.timeFormat
        )
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

// MARK: - TrainDetail refactor

/// Rider-facing trip summary with route times and current service status.
struct TrainDetailHero: View {
    let trip: TrainTrip
    @Environment(\.railInterfacePreferences) private var interfacePreferences

    private var formattedOriginTime: String {
        trip.origin.time.formattedAsTime(
            in: trip.origin.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedDestinationTime: String {
        trip.destination.time.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    private var formattedETA: String {
        trip.eta.formattedAsTime(
            in: trip.destination.timeZone,
            format: interfacePreferences.timeFormat
        )
    }

    var body: some View {
        RailSurface(cornerRadius: RailDesign.Radius.panel, padding: RailDesign.Spacing.l) {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(trip.operatorName)
                        .font(RailDesign.Typography.small.weight(.semibold))
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .textCase(.uppercase)
                        .lineLimit(1)
                    Spacer(minLength: RailDesign.Spacing.s)
                    ServiceStatusPill(status: RailServiceStatus.from(trip))
                }

                HStack(alignment: .firstTextBaseline, spacing: RailDesign.Spacing.xs) {
                    Text(formattedOriginTime)
                        .font(RailDesign.Typography.display.monospacedDigit())
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("→")
                        .font(RailDesign.Typography.h2)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                    Text(formattedDestinationTime)
                        .font(RailDesign.Typography.display.monospacedDigit())
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                    Text(trip.train)
                        .font(RailDesign.Typography.h2)
                        .foregroundStyle(RailDesign.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(trip.fromTo)
                        .font(RailDesign.Typography.small)
                        .foregroundStyle(RailDesign.Palette.secondaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private extension TrainTrip {
    var fromTo: String { "\(origin.name) → \(destination.name)" }
}

/// Flat timeline of the stops belonging to a selected trip.
struct StopTimelineList: View {
    let trip: TrainTrip

    var body: some View {
        RailSurface {
            VStack(spacing: 0) {
                ForEach(Array(trip.stops.enumerated()), id: \.element.id) { index, stop in
                    StopTimelineRow(stop: stop, isLast: index == trip.stops.count - 1)
                }
            }
        }
    }
}

/// Source-backed boarding, carriage, seat, and speed facts for a trip.
struct TrainDetailBoardingCard: View {
    let trip: TrainTrip
    let useMetric: Bool

    var body: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                RailValueRow(symbol: "rectangle.split.3x1.fill", title: "Platform", value: trip.displayPlatform)
                RailDivider()
                RailValueRow(symbol: "train.side.front.car", title: "Carriage", value: "Car \(trip.bestCar) of \(trip.cars)")
                RailDivider()
                RailValueRow(symbol: "seat", title: "Seat", value: trip.seat)
                RailDivider()
                RailValueRow(symbol: "speedometer", title: "Speed", value: UnitConverter.displaySpeed(trip.speed, useMetric: useMetric))
            }
        }
    }
}

/// Compact provenance summary with a route to the complete source disclosure.
struct CompactSourcePanel: View {
    let trip: TrainTrip
    let showDetails: () -> Void

    var body: some View {
        RailSurface {
            VStack(alignment: .leading, spacing: RailDesign.Spacing.m) {
                Button(action: showDetails) {
                    HStack(spacing: RailDesign.Spacing.s) {
                        SourceBadge(trip: trip, style: .regular)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(RailDesign.Typography.caption.weight(.semibold))
                            .foregroundStyle(RailDesign.Palette.secondaryText)
                    }
                }
                .buttonStyle(PressableButtonStyle())
                .contentShape(Rectangle())
                .accessibilityHint("Opens source details")

                RailDivider()

                VStack(spacing: RailDesign.Spacing.s) {
                    RailValueRow(symbol: "building.columns", title: "Provider", value: trip.sourceProvenance.providerName)
                    RailValueRow(symbol: "doc.text.magnifyingglass", title: "Source", value: trip.sourceProvenance.sourceName)
                    RailValueRow(symbol: "checkmark.seal", title: "Confidence", value: trip.sourceProvenance.summaryText)
                    RailValueRow(symbol: "clock.badge.checkmark", title: "Freshness", value: trip.sourceProvenance.freshness.displayName)
                }
                if let sourceURL = trip.sourceProvenance.sourceURL {
                    Link(destination: sourceURL) {
                        HStack(spacing: RailDesign.Spacing.s) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(RailDesign.Palette.accent)
                            Text(sourceURL.host ?? sourceURL.absoluteString)
                                .font(RailDesign.Typography.h3)
                                .foregroundStyle(RailDesign.Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }
                    }
                    .accessibilityLabel("Open source \(trip.sourceProvenance.sourceName)")
                }
            }
        }
    }
}

/// One explanation row in the first-run data-scope contract.
private struct FirstRunScopeRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: RailDesign.Spacing.s) {
            Image(systemName: symbol)
                .foregroundStyle(RailDesign.Palette.accent)
                .font(RailDesign.Typography.h3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: RailDesign.Spacing.xxs) {
                Text(title)
                    .font(RailDesign.Typography.h3)
                    .foregroundStyle(RailDesign.Palette.ink)
                Text(detail)
                    .font(RailDesign.Typography.small)
                    .foregroundStyle(RailDesign.Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, RailDesign.Spacing.s)
        .accessibilityElement(children: .combine)
    }
}

/// First-run actions for starting with the flagship service or browsing providers.
private struct FirstRunActionBar: View {
    let startWithShinkansen: () -> Void
    let browseProviders: () -> Void

    var body: some View {
        VStack(spacing: RailDesign.Spacing.s) {
            RailActionButton(
                title: "Start with Shinkansen",
                symbol: "train.side.front.car",
                role: .primary,
                action: startWithShinkansen
            )
            .accessibilityIdentifier("onboarding.start")
            .accessibilityLabel("Start with Shinkansen")
            .accessibilityHint("Use Japan Shinkansen as the active rail scope")

            RailActionButton(
                title: "Browse providers",
                symbol: "globe.asia.australia",
                action: browseProviders
            )
            .accessibilityIdentifier("onboarding.providers")
            .accessibilityLabel("Browse providers")
            .accessibilityHint("Review supported, setup-required, and planned rail providers")
        }
        .padding(.horizontal, RailDesign.Spacing.m)
        .padding(.top, RailDesign.Spacing.s)
        .padding(.bottom, RailDesign.Spacing.xs)
        .railBottomMaterialBar()
    }
}

// // // // // // // #Preview("Trips") {
// // // // // // //     ContentView()
// // // // // // // }

// // // // // // // #Preview("Detail") {
// // // // // // //     NavigationStack {
// // // // // // //         TrainDetailView(store: TrainStore(defaults: UserDefaults(suiteName: "preview.detail")!), tripID: TrainTrip.samples[0].id)
// // // // // // //     }
// // // // // // // }
