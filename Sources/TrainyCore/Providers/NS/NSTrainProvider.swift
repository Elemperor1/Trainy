import Foundation

// Netherlands NS provider: the first non-Japan provider on the new architecture.
//
// MVP scope is station departures (v2/departures) plus active disruptions / service
// alerts (v3/disruptions). Station lookup (v2/stations) is supported only as a helper
// for station-code normalization. Trip planning and journey detail are deferred until
// authenticated v3/trips and v2/journey fixtures are captured.
struct NSTrainProvider: StationBoardProvider {
    let providerID = "netherlands-ns"
    let displayName = "Netherlands NS"
    let dataScope = "nl-ns-reisinformatie-v2"
    let region = ProviderRegion.netherlands

    private let client: NSClient?

    init(subscriptionKey: String? = TrainyAPIConfig.nsSubscriptionKey, session: URLSession = .shared) {
        if let key = TrainyAPIConfig.cleanSubscriptionKey(subscriptionKey) {
            self.client = NSClient(subscriptionKey: key, session: session)
        } else {
            self.client = nil
        }
    }

    var isConfigured: Bool {
        client != nil
    }

    var authStrategy: ProviderAuthStrategy {
        .localKey(environmentVariable: "NS_SUBSCRIPTION_KEY", infoPlistKey: "NSSubscriptionKey")
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
            return .available("NS departures and active disruptions are configured.", requirements: requirements)
        }
        return .requiresConfiguration("Configure NS_SUBSCRIPTION_KEY for departures and disruption feeds.", requirements: requirements)
    }

    var feedLabel: String {
        isConfigured ? "NS Reisinformatie departures and disruptions" : "NS not configured"
    }

    var implementationStatus: ProviderImplementationStatus {
        .active
    }

    var includesCatalogResultsInSearch: Bool {
        false
    }

    // MARK: - Station Board

    func fetchStationBoard(stationID: String) async throws -> StationBoard {
        guard let client else {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS subscription key is not configured.")
        }

        let departures: [NSDeparture]
        do {
            departures = try await client.fetchDepartures(stationCode: stationID)
        } catch NSClientError.missingCredential {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS subscription key was rejected.")
        } catch NSClientError.rateLimited {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS API rate limit reached. Try again shortly.")
        }

        let boardDepartures = departures.map { Self.boardEntry(from: $0) }
        let provenance = Self.provenance(fetchedAt: Date())

        return StationBoard(
            providerID: providerID,
            stationID: stationID,
            stationName: Self.stationDisplayName(for: stationID),
            generatedAt: Date(),
            departures: boardDepartures,
            sourceProvenance: provenance
        )
    }

    // MARK: - Service Alerts

    func fetchServiceAlerts() async throws -> [TrainAlert] {
        guard let client else {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS subscription key is not configured.")
        }

        let disruptions: [NSDisruption]
        do {
            disruptions = try await client.fetchActiveDisruptions()
        } catch NSClientError.missingCredential {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS subscription key was rejected.")
        } catch NSClientError.rateLimited {
            throw ProviderError.providerUnavailable(providerID: providerID, reason: "NS API rate limit reached. Try again shortly.")
        }

        return disruptions.prefix(6).map { Self.alert(from: $0) }
    }

    func health() async -> ProviderAvailability {
        availability
    }

    // MARK: - Mapping

    static func boardEntry(from departure: NSDeparture) -> StationBoardDeparture {
        let scheduledTime = shortTime(from: departure.plannedDateTime) ?? departure.plannedDateTime ?? ""
        let estimatedTime = shortTime(from: departure.actualDateTime)
        let status = departureStatusText(for: departure)
        let destination = departure.direction ?? departure.routeStations?.last?.mediumName ?? departure.routeStations?.last?.name ?? "Destination"

        return StationBoardDeparture(
            tripID: departure.product?.number ?? departure.name,
            trainName: departure.displayName,
            destinationName: destination,
            scheduledDeparture: scheduledTime,
            estimatedDeparture: estimatedTime,
            platform: departure.effectiveTrack,
            status: status
        )
    }

    static func alert(from disruption: NSDisruption) -> TrainAlert {
        let title = disruption.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? disruption.title! : "NS service disruption"

        var detailParts: [String] = []
        if let situation = disruption.primarySituationText {
            detailParts.append(situation)
        }
        if let cause = disruption.primaryCauseText, !detailParts.contains(where: { $0.localizedCaseInsensitiveContains(cause) }) {
            detailParts.append("Cause: \(cause)")
        }
        if let duration = disruption.expectedDuration?.description, !duration.isEmpty {
            detailParts.append(duration)
        }
        let detail = detailParts.isEmpty ? "Active NS disruption reported." : detailParts.joined(separator: ". ")

        let tone: TrainStatusTone = {
            let impact = disruption.impact?.value ?? 0
            if impact >= 3 || disruption.publicationSections?.contains(where: { ($0.consequence?.level ?? "") == "NO_TRAINS" }) == true {
                return .late
            }
            if impact >= 2 {
                return .watch
            }
            return .watch
        }()

        return TrainAlert(title: title, detail: detail, tone: tone)
    }

    static func provenance(fetchedAt: Date?) -> SourceProvenance {
        SourceProvenance(
            providerID: "netherlands-ns",
            providerName: "Nederlandse Spoorwegen (NS)",
            sourceName: NSClient.sourceName,
            sourceKind: .realtimePrediction,
            confidence: .confirmed,
            fetchedAt: fetchedAt,
            licenseName: "NS API terms",
            attributionText: "Data from Nederlandse Spoorwegen (NS)",
            sourceURL: URL(string: "https://apiportal.ns.nl/")
        )
    }

    // MARK: - Station Code Normalization

    // Curated short map of common NS station codes to display names. Used so the board
    // header can show a friendly station name even before the v2/stations lookup is wired
    // into the UI. Station lookup remains a support capability, not a search surface.
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
        "GD": "Groningen",
        "STD": "Sittard",
        "T": "Tilburg",
        "AL": "Alkmaar",
        "HLM": "Haarlem",
        "ARN": "Arnhem Centraal",
        "NMB": "Nijmegen"
    ]

    static func stationDisplayName(for stationCode: String) -> String {
        stationCodeNames[stationCode.uppercased()] ?? stationCode.uppercased()
    }

    // MARK: - Time Parsing

    // NS returns ISO 8601 timestamps with a numeric offset, e.g. "2026-06-17T15:37:00+0200".
    // Convert to a local HH:MM string for board display.
    static func shortTime(from isoString: String?) -> String? {
        guard let isoString, !isoString.isEmpty else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: isoString) {
            return Self.amsterdamFormatter.string(from: date)
        }

        // Some variants include a colon in the offset (e.g. +02:00). Normalize and retry.
        if isoString.range(of: #"[+-]\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            let normalized = isoString.replacingOccurrences(of: ":", with: "", options: .regularExpression, range: isoString.range(of: #"\+\d{2}:\d{2}$"#, options: .regularExpression))
            if let date = formatter.date(from: normalized) {
                return Self.amsterdamFormatter.string(from: date)
            }
        }

        // Fall back to extracting the HH:MM portion directly.
        if isoString.count >= 16 {
            let start = isoString.index(isoString.startIndex, offsetBy: 11)
            let end = isoString.index(isoString.startIndex, offsetBy: 16)
            return String(isoString[start..<end])
        }
        return nil
    }

    private static let amsterdamFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static func departureStatusText(for departure: NSDeparture) -> String {
        if departure.isCancelled {
            return "Cancelled"
        }
        switch departure.departureStatus {
        case "ON_STATION":
            return "At platform"
        case "LEFT":
            return "Departed"
        case "BOARDING":
            return "Boarding"
        case "ARRIVING":
            return "Arriving"
        default:
            if let actual = departure.actualDateTime, let planned = departure.plannedDateTime {
                if shortTime(from: actual) == shortTime(from: planned) {
                    return "On time"
                }
                return "Delayed"
            }
            return "Scheduled"
        }
    }
}
