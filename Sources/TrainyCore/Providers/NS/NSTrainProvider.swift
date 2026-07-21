import Foundation

/// Netherlands NS station-search and departure-board provider backed only by
/// Trainy's credential-safe provider proxy.
struct NSTrainProvider: StationBoardProvider, StationSearchProvider, ServiceAlertProvider {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"
    let dataScope = "nl-ns-reisinformatie-v2"
    let region = ProviderRegion.netherlands

    private let client: NSClient?

    init(
        proxyBaseURL: URL? = ProviderProxyConfiguration.current().baseURL,
        session: URLSession = .shared
    ) {
        self.client = proxyBaseURL.map { NSClient(baseURL: $0, session: session) }
    }

    var isConfigured: Bool {
        client != nil
    }

    var authStrategy: ProviderAuthStrategy {
        .proxy(reason: "The NS provider credential stays in Trainy's server-side proxy configuration.")
    }

    var requirements: Set<ProviderRequirement> {
        authStrategy.requirements.union([
            .networkAccess,
            .attribution("Data from Nederlandse Spoorwegen (NS)"),
            .terms("NS API terms review")
        ])
    }

    var sourceLinks: [ProviderSourceLink] {
        [
            ProviderSourceLink(title: "NS API portal", url: URL(string: "https://apiportal.ns.nl/")!),
            ProviderSourceLink(title: "NS starter guide", url: URL(string: "https://apiportal.ns.nl/startersguide")!),
            ProviderSourceLink(title: "NS App API product", url: URL(string: "https://apiportal.ns.nl/product#product=NsApp")!),
            ProviderSourceLink(title: "NS disclaimer", url: URL(string: "https://www.ns.nl/disclaimer.html")!)
        ]
    }

    var capabilities: Set<ProviderCapability> {
        [.stationBoard, .serviceAlerts]
    }

    var availability: ProviderAvailability {
        if isConfigured {
            return .available(
                "This build has proxy-backed NS station search, departures, and active disruptions configured.",
                requirements: requirements
            )
        }
        return .requiresProxy(
            "Configure Trainy's provider proxy base URL to use NS station search and departures.",
            requirements: requirements
        )
    }

    var feedLabel: String {
        isConfigured ? "Proxy-backed NS station search and departures" : "NS proxy not configured"
    }

    var implementationStatus: ProviderImplementationStatus {
        // This status records the verified production path; it is not inferred
        // from whether a particular build happens to contain a proxy URL.
        .active
    }

    var includesCatalogResultsInSearch: Bool {
        false
    }

    func searchStations(matching query: String, limit: Int = 20) async throws -> StationSearchPage {
        guard let client else { throw NSClientError.notConfigured }
        let response = try await client.searchStations(query: query, limit: limit)
        return StationSearchPage(
            providerID: providerID,
            query: query,
            generatedAt: response.meta.fetchedAt,
            stations: response.data.stations.map {
                ProviderStation(
                    providerID: providerID,
                    code: $0.code,
                    name: $0.name,
                    shortName: $0.shortName,
                    countryCode: $0.countryCode,
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            },
            sourceProvenance: Self.provenance(meta: response.meta, sourceKind: .officialTimetable)
        )
    }

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        guard let client else { throw NSClientError.notConfigured }
        let response = try await client.fetchDepartures(stationCode: stationID)
        return StationBoard(
            providerID: providerID,
            stationID: response.data.station.code,
            stationName: Self.stationDisplayName(for: response.data.station.code),
            generatedAt: response.meta.fetchedAt,
            departures: response.data.departures.map(Self.boardEntry),
            sourceProvenance: Self.provenance(meta: response.meta, sourceKind: .realtimePrediction)
        )
    }

    func fetchServiceAlerts(stationID: String? = nil) async throws -> ServiceAlertPage {
        guard let client else { throw NSClientError.notConfigured }
        let response = try await client.fetchDisruptions(stationCode: stationID)
        return ServiceAlertPage(
            providerID: providerID,
            stationID: stationID,
            generatedAt: response.meta.fetchedAt,
            alerts: response.data.disruptions.map(Self.alert),
            sourceProvenance: Self.provenance(meta: response.meta, sourceKind: .alertFeed)
        )
    }

    func health() async -> ProviderAvailability {
        availability
    }

    static func boardEntry(from departure: NSProxyDeparture) -> StationBoardDeparture {
        StationBoardDeparture(
            tripID: departure.id,
            trainName: departure.service,
            destinationName: departure.destination,
            scheduledDeparture: shortTime(from: departure.scheduledAt) ?? "Time unavailable",
            estimatedDeparture: shortTime(from: departure.expectedAt),
            platform: departure.platform,
            status: statusText(for: departure.status)
        )
    }

    static func alert(from disruption: NSProxyDisruption) -> TrainAlert {
        TrainAlert(
            title: disruption.title,
            detail: disruption.detail,
            tone: disruption.severity == .major ? .late : .watch
        )
    }

    static func provenance(
        meta: NSProxyMetadata? = nil,
        sourceKind: SourceKind = .realtimePrediction,
        fetchedAt: Date? = nil
    ) -> SourceProvenance {
        SourceProvenance(
            providerID: "netherlands-ns",
            providerName: "Nederlandse Spoorwegen (NS)",
            sourceName: NSClient.sourceName,
            sourceKind: sourceKind,
            confidence: .confirmed,
            freshness: meta?.freshness == .stale ? .stale : (meta == nil && fetchedAt == nil ? .unknown : .fresh),
            fetchedAt: meta?.fetchedAt ?? fetchedAt,
            validUntil: meta?.expiresAt,
            licenseName: "NS API terms",
            attributionText: "Data from Nederlandse Spoorwegen (NS)",
            sourceURL: URL(string: "https://apiportal.ns.nl/")
        )
    }

    static let stationCodeNames: [String: String] = [
        "UT": "Utrecht Centraal",
        "ASD": "Amsterdam Centraal",
        "RTD": "Rotterdam Centraal",
        "SHL": "Schiphol Airport",
        "EHV": "Eindhoven Centraal",
        "GVC": "Den Haag Centraal",
        "BD": "Breda",
        "MT": "Maastricht",
        "LL": "Leiden Centraal",
        "HT": "'s-Hertogenbosch",
        "AMF": "Amersfoort Centraal",
        "ZL": "Zwolle",
        "GN": "Groningen",
        "STD": "Sittard",
        "TB": "Tilburg",
        "AMR": "Alkmaar",
        "HLM": "Haarlem",
        "AH": "Arnhem Centraal",
        "NM": "Nijmegen"
    ]

    static func stationDisplayName(for stationCode: String) -> String {
        stationCodeNames[stationCode.uppercased()] ?? stationCode.uppercased()
    }

    static func shortTime(from isoString: String?) -> String? {
        guard let isoString, let date = NSProxyTimestamp.date(from: isoString) else { return nil }
        return amsterdamFormatter.string(from: date)
    }

    private static let amsterdamFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func statusText(for status: NSProxyDeparture.Status) -> String {
        switch status {
        case .scheduled: return "Scheduled"
        case .onTime: return "On time"
        case .delayed: return "Delayed"
        case .boarding: return "Boarding"
        case .arriving: return "Arriving"
        case .atPlatform: return "At platform"
        case .departed: return "Departed"
        case .cancelled: return "Cancelled"
        }
    }
}
