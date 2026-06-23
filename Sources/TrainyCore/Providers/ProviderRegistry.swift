import Foundation

struct ProviderSourceLink: Hashable, Identifiable, Sendable {
    let title: String
    let url: URL

    var id: String { url.absoluteString }
}

enum ProviderImplementationStatus: String, Hashable, Sendable {
    case active
    case planned
    case disabled

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .planned:
            return "Planned"
        case .disabled:
            return "Disabled"
        }
    }
}

struct ProviderMetadata: Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let region: ProviderRegion
    let authStrategy: ProviderAuthStrategy
    let requirements: Set<ProviderRequirement>
    let capabilities: Set<ProviderCapability>
    let sourceLinks: [ProviderSourceLink]
    let availability: ProviderAvailability
    let implementationStatus: ProviderImplementationStatus
    let notes: String

    var isSearchable: Bool {
        implementationStatus == .active && capabilities.contains(.schedule) && availability.canSearch
    }

    var capabilitySummary: String {
        capabilities.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        .map(\.displayName)
        .joined(separator: ", ")
    }

    var requirementSummary: String {
        let allRequirements = requirements.union(authStrategy.requirements)
        guard !allRequirements.isEmpty else { return "No provider auth required" }
        return allRequirements.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        .map(\.displayName)
        .joined(separator: ", ")
    }
}

struct ProviderRegistry: Sendable {
    private let providersByID: [String: any TrainProvider]
    private let plannedProvidersByID: [String: ProviderMetadata]
    let defaultProviderID: String

    init(
        providers: [any TrainProvider],
        plannedProviders: [ProviderMetadata] = [],
        defaultProviderID: String? = nil
    ) {
        var providersByID: [String: any TrainProvider] = [:]
        for provider in providers {
            providersByID[provider.providerID] = provider
        }

        var plannedProvidersByID: [String: ProviderMetadata] = [:]
        for provider in plannedProviders {
            plannedProvidersByID[provider.id] = provider
        }

        self.providersByID = providersByID
        self.plannedProvidersByID = plannedProvidersByID
        self.defaultProviderID = defaultProviderID ?? providers.first?.providerID ?? ""
    }

    static var `default`: ProviderRegistry {
        ProviderRegistry(
            providers: [ShinkansenTrainProvider(), NSTrainProvider()],
            plannedProviders: Self.defaultPlannedProviders,
            defaultProviderID: "shinkansen"
        )
    }

    var providers: [any TrainProvider] {
        providersByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var activeProviderMetadata: [ProviderMetadata] {
        providers.map(Self.metadata)
    }

    var plannedProviders: [ProviderMetadata] {
        plannedProvidersByID.values.sorted { lhs, rhs in
            lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var providerDirectory: [ProviderMetadata] {
        (activeProviderMetadata + plannedProviders).sorted { lhs, rhs in
            if lhs.implementationStatus != rhs.implementationStatus {
                return lhs.implementationStatus == .active
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    var regions: [ProviderRegion] {
        let concreteRegions = providerDirectory.map(\.region)
        var seen: Set<String> = []
        let sortedRegions = concreteRegions
            .sorted { lhs, rhs in lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending }
            .filter { region in
                guard !seen.contains(region.id) else { return false }
                seen.insert(region.id)
                return true
            }
        return [ProviderRegion.all] + sortedRegions
    }

    var defaultProvider: (any TrainProvider)? {
        provider(id: defaultProviderID) ?? providers.first
    }

    var defaultScheduleProvider: (any ScheduleFeedProvider)? {
        scheduleProvider(id: defaultProviderID)
    }

    var defaultActiveProvider: (any ActiveTrainProvider)? {
        activeProvider(id: defaultProviderID)
    }

    func provider(id providerID: String) -> (any TrainProvider)? {
        providersByID[providerID]
    }

    func metadata(id providerID: String) -> ProviderMetadata? {
        if let provider = providersByID[providerID] {
            return Self.metadata(for: provider)
        }
        return plannedProvidersByID[providerID]
    }

    func visibleProviderDirectory(selectedRegionID: ProviderRegion.ID, activeProviderID: String) -> [ProviderMetadata] {
        guard selectedRegionID != ProviderRegion.all.id else { return providerDirectory }
        return providerDirectory.filter { provider in
            provider.region.id == selectedRegionID || provider.id == activeProviderID
        }
    }

    func providers(supporting capability: ProviderCapability) -> [any TrainProvider] {
        providers.filter { $0.supports(capability) }
    }

    func providers(supportingAll capabilities: Set<ProviderCapability>) -> [any TrainProvider] {
        providers.filter { $0.supportsAll(capabilities) }
    }

    func supports(_ capability: ProviderCapability, providerID: String) -> Bool {
        provider(id: providerID)?.supports(capability) ?? false
    }

    func canSearch(providerID: String) -> Bool {
        guard let provider = scheduleProvider(id: providerID) else { return false }
        return metadata(id: providerID)?.isSearchable == true && provider.supports(.schedule)
    }

    func scheduleProvider(id providerID: String? = nil) -> (any ScheduleFeedProvider)? {
        if let providerID {
            return provider(id: providerID) as? any ScheduleFeedProvider
        }

        if let provider = provider(id: defaultProviderID) as? any ScheduleFeedProvider {
            return provider
        }

        return providers.compactMap { $0 as? any ScheduleFeedProvider }.first
    }

    func activeProvider(id providerID: String? = nil) -> (any ActiveTrainProvider)? {
        if let providerID {
            return provider(id: providerID) as? any ActiveTrainProvider
        }

        if let provider = provider(id: defaultProviderID) as? any ActiveTrainProvider {
            return provider
        }

        return providers.compactMap { $0 as? any ActiveTrainProvider }.first
    }

    private static func metadata(for provider: any TrainProvider) -> ProviderMetadata {
        ProviderMetadata(
            id: provider.providerID,
            displayName: provider.displayName,
            region: provider.region,
            authStrategy: provider.authStrategy,
            requirements: provider.requirements,
            capabilities: provider.capabilities,
            sourceLinks: provider.sourceLinks,
            availability: provider.availability,
            implementationStatus: provider.implementationStatus,
            notes: provider.feedLabel
        )
    }

    private static var defaultPlannedProviders: [ProviderMetadata] {
        [
            plannedProvider(
                id: "taiwan-tdx",
                displayName: "Taiwan TDX",
                region: .taiwan,
                authStrategy: .proxy(reason: "TDX client ID and client secret should stay server-side."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("TDX client ID and client secret"),
                    .attribution("TDX attribution"),
                    .terms("TDX API terms review")
                ],
                capabilities: [.schedule, .stationBoard, .serviceAlerts],
                sourceLinks: [
                    ProviderSourceLink(title: "TDX platform", url: URL(string: "https://tdx.transportdata.tw/")!)
                ],
                message: "Needs a proxy-backed OAuth token flow, railway mappings, fixtures, and attribution before search can be enabled.",
                notes: "First planned expansion target."
            ),
            plannedProvider(
                id: "hong-kong-mtr",
                displayName: "Hong Kong MTR",
                region: .hongKong,
                authStrategy: .none,
                requirements: [
                    .networkAccess,
                    .attribution("DATA.GOV.HK and MTR attribution"),
                    .terms("DATA.GOV.HK API terms review")
                ],
                capabilities: [.stationBoard],
                sourceLinks: [
                    ProviderSourceLink(title: "MTR next train data", url: URL(string: "https://data.gov.hk/en-data/dataset/mtr-data2-nexttrain-data")!)
                ],
                message: "Needs line and station mapping plus live-board fixtures before station boards can be enabled.",
                notes: "Planned live-board provider only; not a trip search provider yet."
            ),
            plannedProvider(
                id: "deutsche-bahn",
                displayName: "Deutsche Bahn",
                region: .germany,
                authStrategy: .proxy(reason: "DB API credentials should be brokered outside the app binary."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("DB API marketplace credentials"),
                    .attribution("Deutsche Bahn attribution"),
                    .terms("DB API terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .serviceAlerts, .journeyPlanning],
                sourceLinks: [
                    ProviderSourceLink(title: "DB API marketplace", url: URL(string: "https://developers.deutschebahn.com/")!)
                ],
                message: "Needs credential brokering, schedule/realtime adapter, licensing review, and fixtures before search can be enabled."
            ),
            plannedProvider(
                id: "switzerland-opentransportdata",
                displayName: "Switzerland opentransportdata.swiss",
                region: .switzerland,
                authStrategy: .proxy(reason: "Swiss transport API tokens should be handled by a backend or proxy."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("opentransportdata.swiss API access"),
                    .attribution("opentransportdata.swiss attribution"),
                    .terms("Swiss public transport data terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .serviceAlerts, .journeyPlanning],
                sourceLinks: [
                    ProviderSourceLink(title: "opentransportdata.swiss", url: URL(string: "https://opentransportdata.swiss/")!)
                ],
                message: "Needs API access validation, Swiss route/station normalization, and realtime fixture coverage before search can be enabled."
            ),
            plannedProvider(
                id: "uk-national-rail-darwin",
                displayName: "UK National Rail and Darwin",
                region: .unitedKingdom,
                authStrategy: .proxy(reason: "Darwin credentials and push feeds should be handled by server infrastructure."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("National Rail Darwin access"),
                    .attribution("National Rail and Network Rail attribution"),
                    .terms("Darwin and Network Rail terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .serviceAlerts],
                sourceLinks: [
                    ProviderSourceLink(title: "National Rail data portal", url: URL(string: "https://www.nationalrail.co.uk/developers/")!),
                    ProviderSourceLink(title: "Network Rail open data", url: URL(string: "https://www.networkrail.co.uk/who-we-are/transparency-and-ethics/transparency/open-data-feeds/")!)
                ],
                message: "Needs Darwin access, Network Rail feed handling, a backend parser, and delay semantics before search can be enabled."
            ),
            plannedProvider(
                id: "transport-for-nsw",
                displayName: "Transport for NSW",
                region: .australia,
                authStrategy: .proxy(reason: "TfNSW API keys should not ship in the app."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("Transport for NSW Open Data API key"),
                    .attribution("Transport for NSW attribution"),
                    .terms("TfNSW Open Data terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .vehiclePositions, .serviceAlerts],
                sourceLinks: [
                    ProviderSourceLink(title: "Transport for NSW Open Data", url: URL(string: "https://opendata.transport.nsw.gov.au/")!)
                ],
                message: "Needs API-key proxying, GTFS/GTFS-RT ingestion, station-board mapping, and source labels before search can be enabled."
            ),
            plannedProvider(
                id: "mta-lirr-metro-north",
                displayName: "MTA LIRR and Metro-North",
                region: .unitedStates,
                authStrategy: .proxy(reason: "MTA API credentials should be brokered outside the app binary."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("MTA developer access"),
                    .attribution("MTA attribution"),
                    .terms("MTA terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .serviceAlerts],
                sourceLinks: [
                    ProviderSourceLink(title: "MTA developer resources", url: URL(string: "https://new.mta.info/developers")!)
                ],
                message: "Needs GTFS/GTFS-RT feed selection, commuter rail route mapping, and license review before search can be enabled."
            ),
            plannedProvider(
                id: "south-korea-tago-topis",
                displayName: "South Korea TAGO and Seoul TOPIS",
                region: .southKorea,
                authStrategy: .proxy(reason: "Public data service keys should be kept outside the app binary."),
                requirements: [
                    .networkAccess,
                    .proxy,
                    .providerAccount("TAGO and TOPIS service keys"),
                    .attribution("Korea public data attribution"),
                    .terms("Public data API terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .vehiclePositions],
                sourceLinks: [
                    ProviderSourceLink(title: "TAGO portal", url: URL(string: "https://www.tago.go.kr/")!),
                    ProviderSourceLink(title: "Seoul TOPIS", url: URL(string: "https://topis.seoul.go.kr/")!)
                ],
                message: "Needs service-key proxying, Korean station/operator normalization, and data-contract review before search can be enabled."
            ),
            plannedProvider(
                id: "france-sncf-transport-data-gouv",
                displayName: "France SNCF and transport.data.gouv.fr",
                region: .france,
                authStrategy: .custom("Dataset-specific access review"),
                requirements: [
                    .networkAccess,
                    .providerAccount("SNCF or transport.data.gouv.fr dataset access"),
                    .attribution("SNCF and transport.data.gouv.fr attribution"),
                    .terms("French transport data terms review")
                ],
                capabilities: [.schedule, .stationBoard, .realtimeTripUpdates, .serviceAlerts],
                sourceLinks: [
                    ProviderSourceLink(title: "transport.data.gouv.fr", url: URL(string: "https://transport.data.gouv.fr/")!),
                    ProviderSourceLink(title: "SNCF open data", url: URL(string: "https://ressources.data.sncf.com/")!)
                ],
                message: "Needs dataset selection, license review, French station normalization, and fixtures before search can be enabled."
            )
        ]
    }

    private static func plannedProvider(
        id: String,
        displayName: String,
        region: ProviderRegion,
        authStrategy: ProviderAuthStrategy,
        requirements: Set<ProviderRequirement>,
        capabilities: Set<ProviderCapability>,
        sourceLinks: [ProviderSourceLink],
        message: String,
        notes: String = "Planned provider."
    ) -> ProviderMetadata {
        let allRequirements = requirements.union(authStrategy.requirements)
        let availability: ProviderAvailability
        if allRequirements.contains(.proxy) || authStrategy.requiresProxy {
            availability = .requiresProxy(message, requirements: allRequirements)
        } else {
            availability = .requiresConfiguration(message, requirements: allRequirements)
        }

        return ProviderMetadata(
            id: id,
            displayName: displayName,
            region: region,
            authStrategy: authStrategy,
            requirements: allRequirements,
            capabilities: capabilities,
            sourceLinks: sourceLinks,
            availability: availability,
            implementationStatus: .planned,
            notes: notes
        )
    }
}
