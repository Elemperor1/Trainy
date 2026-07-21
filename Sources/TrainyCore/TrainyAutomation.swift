import Combine
import Foundation

#if DEBUG
/// Deterministic launch configurations used to exercise the app's normal UI
/// against injected provider implementations instead of network services.
public enum TrainyAutomationScenario: String, CaseIterable, Sendable {
    case fixture = "fixture"
    case searchFailureRecovery = "search-failure-recovery"
    case loading = "loading"
    case credentialNeutral = "credential-neutral"

    /// Reads the explicit launch argument shared by simulator automation and local diagnostics.
    public static func fromLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        guard let index = arguments.firstIndex(of: "--trainy-automation"),
              arguments.indices.contains(index + 1)
        else {
            return nil
        }
        return Self(rawValue: arguments[index + 1])
    }
}

@MainActor
struct TrainyAutomationDependencies {
    let store: TrainStore
    let nsProvider: any NSRiderDataProviding
    let nsStartsLoading: Bool

    static func make(for scenario: TrainyAutomationScenario) -> Self {
        let defaults = UserDefaults(suiteName: "TrainyAutomation-\(scenario.rawValue)")!
        defaults.removePersistentDomain(forName: "TrainyAutomation-\(scenario.rawValue)")
        defaults.set(true, forKey: "trainy.firstRunCompleted")

        if scenario == .credentialNeutral {
            let registry = ProviderRegistry(
                providers: [
                    ShinkansenTrainProvider(consumerKey: nil),
                    NSTrainProvider(proxyBaseURL: nil)
                ],
                defaultProviderID: "shinkansen"
            )
            return Self(
                store: TrainStore(
                    defaults: defaults,
                    registry: registry,
                    proxyConfiguration: ProviderProxyConfiguration(baseURL: nil)
                ),
                nsProvider: NSTrainProvider(proxyBaseURL: nil),
                nsStartsLoading: false
            )
        }

        let proxyURL = URL(string: "https://fixture.trainy.invalid")!
        let registry = ProviderRegistry(
            providers: [
                ShinkansenTrainProvider(consumerKey: nil),
                NSTrainProvider(proxyBaseURL: proxyURL)
            ],
            defaultProviderID: "shinkansen"
        )
        return Self(
            store: TrainStore(
                defaults: defaults,
                registry: registry,
                proxyConfiguration: ProviderProxyConfiguration(baseURL: proxyURL),
                proxyHealthFetcher: AutomationProxyHealthFetcher()
            ),
            nsProvider: AutomationNSRiderProvider(scenario: scenario),
            nsStartsLoading: scenario == .loading
        )
    }
}
#endif

/// Owns the app's root dependencies for one SwiftUI app lifecycle.
///
/// Keeping this container in `TrainyApp` prevents automation fixture setup
/// from being recreated as `ContentView` values are rebuilt.
@MainActor
public final class TrainyRootDependencies: ObservableObject {
    let store: TrainStore
    let nsProvider: any NSRiderDataProviding
    let nsStartsLoading: Bool

    private init(
        store: TrainStore,
        nsProvider: any NSRiderDataProviding,
        nsStartsLoading: Bool
    ) {
        self.store = store
        self.nsProvider = nsProvider
        self.nsStartsLoading = nsStartsLoading
    }

    /// Creates the production dependency graph without automation fixtures.
    public convenience init() {
        let store = TrainStore()
        self.init(
            store: store,
            nsProvider: NSTrainProvider(proxyBaseURL: store.providerProxyConfiguration.baseURL),
            nsStartsLoading: false
        )
    }

    #if DEBUG
    /// Creates a deterministic dependency graph for Debug-only UI automation.
    public convenience init(automationScenario: TrainyAutomationScenario?) {
        guard let automationScenario else {
            self.init()
            return
        }
        let dependencies = TrainyAutomationDependencies.make(for: automationScenario)
        self.init(
            store: dependencies.store,
            nsProvider: dependencies.nsProvider,
            nsStartsLoading: dependencies.nsStartsLoading
        )
    }
    #endif
}

#if DEBUG
private struct AutomationProxyHealthFetcher: ProviderProxyHealthFetching {
    func fetchProviderHealth(from baseURL: URL) async throws -> ProviderProxyHealthResponse {
        ProviderProxyHealthResponse(
            generatedAt: Date(),
            providers: [
                ProviderProxyProviderHealth(
                    id: "ns",
                    region: "Netherlands",
                    configured: true,
                    status: .ok,
                    capabilities: ["station-board", "service-alerts"],
                    cache: ProviderProxyCacheHealth(staticFeed: .fresh, updatedAt: Date()),
                    checkedAt: Date(),
                    message: "Fixture proxy healthy."
                )
            ]
        )
    }
}

private struct AutomationNSRiderProvider: NSRiderDataProviding {
    private let scenario: TrainyAutomationScenario
    private let attempts = AutomationSearchAttempts()

    init(scenario: TrainyAutomationScenario) {
        self.scenario = scenario
    }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage {
        if scenario == .searchFailureRecovery, await attempts.shouldFail() {
            throw NSClientError.unavailable
        }

        let stations = query.localizedCaseInsensitiveContains("utrecht") || query.localizedCaseInsensitiveContains("ut")
            ? [Self.utrecht]
            : []
        return StationSearchPage(
            providerID: "netherlands-ns",
            query: query,
            generatedAt: Date(),
            stations: stations,
            sourceProvenance: Self.stationSource
        )
    }

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        StationBoard(
            providerID: "netherlands-ns",
            stationID: stationID,
            stationName: "Utrecht Centraal",
            generatedAt: Date(),
            departures: [
                StationBoardDeparture(
                    tripID: "fixture-sprinter-7400",
                    trainName: "Sprinter 7400",
                    destinationName: "Den Haag Centraal",
                    scheduledDeparture: "12:04",
                    estimatedDeparture: "12:06",
                    platform: "5",
                    status: "Delayed"
                ),
                StationBoardDeparture(
                    tripID: "fixture-intercity-2800",
                    trainName: "Intercity 2800",
                    destinationName: "Rotterdam Centraal",
                    scheduledDeparture: "12:12",
                    platform: "8",
                    status: "On time"
                )
            ],
            sourceProvenance: Self.boardSource
        )
    }

    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage {
        ServiceAlertPage(
            providerID: "netherlands-ns",
            stationID: stationID,
            generatedAt: Date(),
            alerts: [
                TrainAlert(
                    title: "Platform change",
                    detail: "Check the station display before boarding.",
                    tone: .watch
                )
            ],
            sourceProvenance: Self.alertSource
        )
    }

    private static let utrecht = ProviderStation(
        providerID: "netherlands-ns",
        code: "UT",
        name: "Utrecht Centraal",
        shortName: "Utrecht",
        countryCode: "NL",
        latitude: 52.0894,
        longitude: 5.1100
    )

    private static var stationSource: SourceProvenance { source(kind: .officialTimetable) }
    private static var boardSource: SourceProvenance { source(kind: .realtimePrediction) }
    private static var alertSource: SourceProvenance { source(kind: .alertFeed) }

    private static func source(kind: SourceKind) -> SourceProvenance {
        SourceProvenance(
            providerID: "netherlands-ns",
            providerName: "Nederlandse Spoorwegen (NS)",
            sourceName: "NS Reisinformatie API",
            sourceKind: kind,
            confidence: .confirmed,
            freshness: .fresh,
            fetchedAt: Date(),
            validUntil: Date().addingTimeInterval(3_600),
            licenseName: "NS API terms",
            attributionText: "Data from Nederlandse Spoorwegen (NS)",
            sourceURL: URL(string: "https://apiportal.ns.nl/")
        )
    }
}

private actor AutomationSearchAttempts {
    private var attempts = 0

    func shouldFail() -> Bool {
        defer { attempts += 1 }
        return attempts == 0
    }
}
#endif
