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
                    provider: rootDependencies.stationProvider,
                    favorites: rootDependencies.stationFavorites,
                    startsLoading: rootDependencies.stationsStartLoading
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

// // // // // // // #Preview("Trips") {
// // // // // // //     ContentView()
// // // // // // // }

// // // // // // // #Preview("Detail") {
// // // // // // //     NavigationStack {
// // // // // // //         TrainDetailView(store: TrainStore(defaults: UserDefaults(suiteName: "preview.detail")!), tripID: TrainTrip.samples[0].id)
// // // // // // //     }
// // // // // // // }
