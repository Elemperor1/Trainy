import Foundation
import SwiftUI

enum TrainStatusTone: String, Codable, CaseIterable, Sendable {
    case good
    case watch
    case late

    var tint: Color {
        switch self {
        case .good:
            return TrainyColor.green
        case .watch:
            return TrainyColor.amber
        case .late:
            return TrainyColor.red
        }
    }

    var softFill: Color {
        tint.opacity(0.14)
    }
}

enum TripFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case departing
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .departing:
            return "Departing"
        case .attention:
            return "Needs Watch"
        }
    }
}

enum SourceKind: String, Codable, CaseIterable, Sendable {
    case starterCatalog
    case officialTimetable
    case realtimePrediction
    case vehiclePosition
    case alertFeed
    case inferred

    var displayName: String {
        switch self {
        case .starterCatalog:
            return "Starter catalog"
        case .officialTimetable:
            return "Official timetable"
        case .realtimePrediction:
            return "Realtime prediction"
        case .vehiclePosition:
            return "Vehicle position"
        case .alertFeed:
            return "Alert feed"
        case .inferred:
            return "Inferred source"
        }
    }

    var compactTitle: String {
        switch self {
        case .starterCatalog:
            return "Starter"
        case .officialTimetable:
            return "Scheduled"
        case .realtimePrediction:
            return "Prediction"
        case .vehiclePosition:
            return "Position"
        case .alertFeed:
            return "Alert"
        case .inferred:
            return "Saved"
        }
    }

    var riderTitle: String {
        switch self {
        case .starterCatalog:
            return "Starter catalog"
        case .officialTimetable:
            return "Scheduled timetable"
        case .realtimePrediction:
            return "Realtime prediction"
        case .vehiclePosition:
            return "Vehicle position"
        case .alertFeed:
            return "Service alert"
        case .inferred:
            return "Saved source"
        }
    }

    var riderExplanation: String {
        switch self {
        case .starterCatalog:
            return "This is Trainy's curated starter catalog for Japan Shinkansen routes. It is useful for orientation and product validation, but it is not an operating feed."
        case .officialTimetable:
            return "This uses scheduled timetable data from an official source. It can confirm planned times, stops, and platforms when supplied, but it does not provide vehicle position."
        case .realtimePrediction:
            return "This uses realtime prediction data, such as provider trip updates or delay estimates. It is a prediction layer on top of the schedule, not a vehicle-position feed."
        case .vehiclePosition:
            return "This source reports actual vehicle position data from a provider feed for the trip or vehicle."
        case .alertFeed:
            return "This source provides service alerts or disruption notices. It may not include a full schedule or vehicle position."
        case .inferred:
            return "This was restored from saved or inferred source metadata. Refresh from a configured provider before relying on it for travel."
        }
    }
}

enum FreshnessState: String, Codable, CaseIterable, Sendable {
    case fresh
    case stale
    case expired
    case unknown

    var displayName: String {
        switch self {
        case .fresh:
            return "Fresh"
        case .stale:
            return "Stale"
        case .expired:
            return "Expired"
        case .unknown:
            return "Unknown freshness"
        }
    }

    var riderExplanation: String {
        switch self {
        case .fresh:
            return "The source was fetched recently or is still within its valid window."
        case .stale:
            return "This is stale saved data. Use it as a reference only and refresh before travel."
        case .expired:
            return "This source is past its valid window. Refresh before using it for a trip."
        case .unknown:
            return "Trainy does not have a freshness timestamp for this source."
        }
    }

    static func resolved(fetchedAt: Date?, validUntil: Date?, now: Date = Date()) -> FreshnessState {
        if let validUntil, validUntil < now {
            return .expired
        }
        if let fetchedAt {
            return now.timeIntervalSince(fetchedAt) > 86_400 ? .stale : .fresh
        }
        return .unknown
    }
}

enum ConfidenceLevel: String, Codable, CaseIterable, Sendable {
    case confirmed
    case estimated
    case inferred
    case unknown

    var displayName: String {
        switch self {
        case .confirmed:
            return "Confirmed"
        case .estimated:
            return "Estimated"
        case .inferred:
            return "Inferred"
        case .unknown:
            return "Unknown"
        }
    }
}

struct SourceAttribution: Hashable, Codable, Sendable {
    let providerID: String
    let providerName: String
    let sourceName: String
    let attributionText: String?
    let sourceURL: URL?
}

struct LicenseNotice: Hashable, Codable, Sendable {
    let licenseName: String?
    let attributionText: String?
    let sourceURL: URL?
}

struct SourceProvenance: Hashable, Codable, Sendable {
    let providerID: String
    let providerName: String
    let sourceName: String
    let sourceKind: SourceKind
    let confidence: ConfidenceLevel
    let freshness: FreshnessState
    let fetchedAt: Date?
    let publishedAt: Date?
    let validUntil: Date?
    let licenseName: String?
    let attributionText: String?
    let sourceURL: URL?
    let attribution: SourceAttribution
    let licenseNotice: LicenseNotice?

    init(
        providerID: String,
        providerName: String,
        sourceName: String,
        sourceKind: SourceKind,
        confidence: ConfidenceLevel,
        freshness: FreshnessState? = nil,
        fetchedAt: Date? = nil,
        publishedAt: Date? = nil,
        validUntil: Date? = nil,
        licenseName: String? = nil,
        attributionText: String? = nil,
        sourceURL: URL? = nil
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.confidence = confidence
        self.freshness = freshness ?? FreshnessState.resolved(fetchedAt: fetchedAt, validUntil: validUntil)
        self.fetchedAt = fetchedAt
        self.publishedAt = publishedAt
        self.validUntil = validUntil
        self.licenseName = licenseName
        self.attributionText = attributionText
        self.sourceURL = sourceURL
        self.attribution = SourceAttribution(
            providerID: providerID,
            providerName: providerName,
            sourceName: sourceName,
            attributionText: attributionText,
            sourceURL: sourceURL
        )

        if licenseName != nil || attributionText != nil || sourceURL != nil {
            self.licenseNotice = LicenseNotice(
                licenseName: licenseName,
                attributionText: attributionText,
                sourceURL: sourceURL
            )
        } else {
            self.licenseNotice = nil
        }
    }

    var summaryText: String {
        "\(sourceKind.riderTitle) - \(confidence.displayName)"
    }

    var detailText: String {
        if let attributionText, !attributionText.isEmpty {
            return attributionText
        }
        return "\(providerName) \(sourceName)"
    }

    var riderExplanation: String {
        if sourceKind == .inferred || freshness == .stale || freshness == .expired {
            return "\(freshness.riderExplanation) \(sourceKind.riderExplanation)"
        }
        return sourceKind.riderExplanation
    }

    var freshnessExplanation: String {
        freshness.riderExplanation
    }

    var licenseAttributionText: String {
        if sourceKind == .starterCatalog {
            return "Trainy-owned starter catalog. No external provider feed is represented."
        }

        var parts: [String] = []
        if let licenseName, !licenseName.isEmpty {
            parts.append("License: \(licenseName)")
        }
        if let attributionText, !attributionText.isEmpty {
            parts.append("Attribution: \(attributionText)")
        }
        if let sourceURL {
            parts.append("Source link: \(sourceURL.absoluteString)")
        }
        return parts.isEmpty ? "No license or attribution notice is attached to this source yet." : parts.joined(separator: ". ")
    }

    var liveSafeTripLabel: String {
        switch sourceKind {
        case .realtimePrediction, .vehiclePosition:
            return "Live trip"
        case .officialTimetable:
            return "Scheduled trip"
        case .starterCatalog:
            return "Starter catalog trip"
        case .alertFeed:
            return "Alert-backed trip"
        case .inferred:
            return "Saved trip"
        }
    }

    static func providerUnavailableText(message: String) -> String {
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanMessage.isEmpty {
            return "Source provider unavailable. Saved trips remain visible, but Trainy could not refresh the source data."
        }
        return "Source provider unavailable. Saved trips remain visible, but Trainy could not refresh the source data: \(cleanMessage)."
    }

    static func starterCatalog() -> SourceProvenance {
        SourceProvenance(
            providerID: "trainy",
            providerName: "Trainy",
            sourceName: "Japan Shinkansen starter catalog",
            sourceKind: .starterCatalog,
            confidence: .estimated,
            freshness: .unknown,
            licenseName: "App-owned starter data",
            attributionText: "Trainy curated Shinkansen starter catalog"
        )
    }

    static func odptTimetable(fetchedAt: Date? = Date(), publishedAt: Date? = nil, validUntil: Date? = nil) -> SourceProvenance {
        SourceProvenance(
            providerID: "odpt",
            providerName: "Open Data Public Transportation Council",
            sourceName: "ODPT TrainTimetable API",
            sourceKind: .officialTimetable,
            confidence: .confirmed,
            fetchedAt: fetchedAt,
            publishedAt: publishedAt,
            validUntil: validUntil,
            licenseName: "ODPT developer terms",
            attributionText: "Timetable data from ODPT TrainTimetable",
            sourceURL: URL(string: "https://developer.odpt.org/")
        )
    }

    static func jrEastTimetable(sourceName: String, sourceURL: URL?, fetchedAt: Date? = Date()) -> SourceProvenance {
        SourceProvenance(
            providerID: "jr-east",
            providerName: "JR East",
            sourceName: sourceName,
            sourceKind: .officialTimetable,
            confidence: .confirmed,
            fetchedAt: fetchedAt,
            attributionText: sourceName,
            sourceURL: sourceURL
        )
    }

    static func legacy(dataSource: String?, providerID: String?, providerName: String?) -> SourceProvenance {
        let sourceName = dataSource?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = sourceName?.lowercased() ?? ""

        if normalized.contains("japan shinkansen starter") {
            return starterCatalog()
        }

        if normalized.contains("odpt") && normalized.contains("traintimetable") {
            return odptTimetable(fetchedAt: nil)
        }

        if normalized.contains("official timetable") || normalized.contains("jr east") {
            return jrEastTimetable(
                sourceName: sourceName?.isEmpty == false ? sourceName! : "Official timetable",
                sourceURL: nil,
                fetchedAt: nil
            )
        }

        return SourceProvenance(
            providerID: providerID ?? "unknown",
            providerName: providerName ?? "Unknown provider",
            sourceName: sourceName?.isEmpty == false ? sourceName! : "Unknown source",
            sourceKind: .inferred,
            confidence: .unknown,
            freshness: .unknown,
            attributionText: sourceName
        )
    }

    static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum RailFactKind: String, Codable, CaseIterable, Sendable {
    case schedule
    case platform
    case route
    case stopOrder
    case speed
    case vehiclePosition
    case carriageCue
    case seatCue

    var displayName: String {
        switch self {
        case .schedule:
            return "Schedule"
        case .platform:
            return "Platform"
        case .route:
            return "Route"
        case .stopOrder:
            return "Stop order"
        case .speed:
            return "Speed"
        case .vehiclePosition:
            return "Map position"
        case .carriageCue:
            return "Car cue"
        case .seatCue:
            return "Seat cue"
        }
    }
}

struct FactProvenance: Identifiable, Hashable, Codable, Sendable {
    let fact: RailFactKind
    let sourceName: String
    let sourceKind: SourceKind
    let confidence: ConfidenceLevel
    let note: String

    var id: String { fact.rawValue }

    var summaryText: String {
        "\(confidence.displayName) - \(sourceKind.riderTitle)"
    }

    init(
        fact: RailFactKind,
        sourceName: String,
        sourceKind: SourceKind,
        confidence: ConfidenceLevel,
        note: String
    ) {
        self.fact = fact
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.confidence = confidence
        self.note = note
    }

    init(fact: RailFactKind, source: SourceProvenance, confidence: ConfidenceLevel? = nil, note: String) {
        self.init(
            fact: fact,
            sourceName: source.sourceName,
            sourceKind: source.sourceKind,
            confidence: confidence ?? source.confidence,
            note: note
        )
    }

    static func starterCatalogFacts(source: SourceProvenance = .starterCatalog()) -> [FactProvenance] {
        [
            FactProvenance(fact: .schedule, source: source, confidence: .estimated, note: "Representative starter schedule, not an operating feed."),
            FactProvenance(fact: .platform, source: source, confidence: .estimated, note: "Representative starter platform."),
            FactProvenance(fact: .route, source: source, confidence: .estimated, note: "Curated Shinkansen route metadata."),
            FactProvenance(fact: .stopOrder, source: source, confidence: .estimated, note: "Curated major-stop sequence."),
            FactProvenance(fact: .speed, sourceName: source.sourceName, sourceKind: .inferred, confidence: .unknown, note: "No speed source is connected."),
            FactProvenance(fact: .vehiclePosition, sourceName: source.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Map marker uses station/corridor geometry, not a vehicle-position feed."),
            FactProvenance(fact: .carriageCue, sourceName: source.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Boarding car cue is starter guidance."),
            FactProvenance(fact: .seatCue, sourceName: source.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Seat cue is starter guidance.")
        ]
    }

    static func timetableFacts(source: SourceProvenance, starterSource: SourceProvenance = .starterCatalog(), hasPlatform: Bool = true) -> [FactProvenance] {
        var facts = [
            FactProvenance(fact: .schedule, source: source, confidence: .confirmed, note: "Departure and arrival times supplied by the timetable source."),
            FactProvenance(fact: .stopOrder, source: source, confidence: .confirmed, note: "Stop sequence supplied by the timetable source."),
            FactProvenance(fact: .speed, sourceName: source.sourceName, sourceKind: source.sourceKind, confidence: .unknown, note: "Displayed as timetable-only; no speed source is supplied.")
        ]

        if hasPlatform {
            facts.append(FactProvenance(fact: .platform, source: source, confidence: .confirmed, note: "Platform or track supplied by the timetable source."))
        } else {
            facts.append(FactProvenance(fact: .platform, sourceName: source.sourceName, sourceKind: source.sourceKind, confidence: .unknown, note: "Platform was not supplied by the timetable source."))
        }

        facts.append(contentsOf: [
            FactProvenance(fact: .route, sourceName: "Trainy route mapping", sourceKind: .inferred, confidence: .inferred, note: "Route label is normalized from Trainy's Shinkansen mapping."),
            FactProvenance(fact: .vehiclePosition, sourceName: starterSource.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Map marker uses station/corridor geometry, not a vehicle-position feed."),
            FactProvenance(fact: .carriageCue, sourceName: starterSource.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Boarding car cue is carried from starter guidance."),
            FactProvenance(fact: .seatCue, sourceName: starterSource.sourceName, sourceKind: .inferred, confidence: .inferred, note: "Seat cue is carried from starter guidance.")
        ])

        return facts
    }

    static func legacyFacts(for source: SourceProvenance) -> [FactProvenance] {
        switch source.sourceKind {
        case .starterCatalog:
            return starterCatalogFacts(source: source)
        case .officialTimetable:
            return timetableFacts(source: source)
        case .realtimePrediction, .vehiclePosition, .alertFeed, .inferred:
            return [
                FactProvenance(fact: .schedule, source: source, confidence: source.confidence, note: "Derived from legacy source metadata."),
                FactProvenance(fact: .speed, sourceName: source.sourceName, sourceKind: source.sourceKind, confidence: .unknown, note: "No separate speed source was persisted.")
            ]
        }
    }
}

struct StationPoint: Hashable, Codable, Sendable {
    let name: String
    let code: String
    let time: String
    let latitude: Double?
    let longitude: Double?

    init(name: String, code: String, time: String, latitude: Double? = nil, longitude: Double? = nil) {
        self.name = name
        self.code = code
        self.time = time
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct StationStop: Identifiable, Hashable, Codable, Sendable {
    enum StopState: String, Codable, Sendable {
        case done
        case current
        case pending
    }

    let id = UUID()
    let name: String
    let time: String
    let platform: String
    let note: String
    let state: StopState

    private enum CodingKeys: String, CodingKey {
        case name
        case time
        case platform
        case note
        case state
    }
}

struct TrainAlert: Identifiable, Hashable, Codable, Sendable {
    let id = UUID()
    let title: String
    let detail: String
    let tone: TrainStatusTone

    private enum CodingKeys: String, CodingKey {
        case title
        case detail
        case tone
    }
}

struct TrainTrip: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let providerID: String?
    let routeID: String?
    let liveTripID: String?
    let train: String
    let operatorName: String
    let service: String
    let origin: StationPoint
    let destination: StationPoint
    let duration: String
    let status: String
    let statusTone: TrainStatusTone
    let category: TripFilter
    let platform: String
    let nextStop: String
    let eta: String
    let speed: String
    var progress: Double
    let bestCar: Int
    let cars: Int
    let seat: String
    var updated: String
    let callout: String
    let signal: Int
    let signalCopy: String
    let stops: [StationStop]
    let alerts: [TrainAlert]
    let pulse: String
    let vehicleLatitude: Double?
    let vehicleLongitude: Double?
    let distanceText: String?
    let dataSource: String?
    let sourceProvenance: SourceProvenance
    let factProvenance: [FactProvenance]

    init(
        id: String,
        providerID: String? = nil,
        routeID: String? = nil,
        liveTripID: String? = nil,
        train: String,
        operatorName: String,
        service: String,
        origin: StationPoint,
        destination: StationPoint,
        duration: String,
        status: String,
        statusTone: TrainStatusTone,
        category: TripFilter,
        platform: String,
        nextStop: String,
        eta: String,
        speed: String,
        progress: Double,
        bestCar: Int,
        cars: Int,
        seat: String,
        updated: String,
        callout: String,
        signal: Int,
        signalCopy: String,
        stops: [StationStop],
        alerts: [TrainAlert],
        pulse: String,
        vehicleLatitude: Double? = nil,
        vehicleLongitude: Double? = nil,
        distanceText: String? = nil,
        dataSource: String? = nil,
        sourceProvenance: SourceProvenance? = nil,
        factProvenance: [FactProvenance]? = nil
    ) {
        let resolvedSourceProvenance = sourceProvenance ?? SourceProvenance.legacy(
            dataSource: dataSource,
            providerID: providerID,
            providerName: operatorName
        )

        self.id = id
        self.providerID = providerID
        self.routeID = routeID
        self.liveTripID = liveTripID
        self.train = train
        self.operatorName = operatorName
        self.service = service
        self.origin = origin
        self.destination = destination
        self.duration = duration
        self.status = status
        self.statusTone = statusTone
        self.category = category
        self.platform = platform
        self.nextStop = nextStop
        self.eta = eta
        self.speed = speed
        self.progress = progress
        self.bestCar = bestCar
        self.cars = cars
        self.seat = seat
        self.updated = updated
        self.callout = callout
        self.signal = signal
        self.signalCopy = signalCopy
        self.stops = stops
        self.alerts = alerts
        self.pulse = pulse
        self.vehicleLatitude = vehicleLatitude
        self.vehicleLongitude = vehicleLongitude
        self.distanceText = distanceText
        self.dataSource = dataSource ?? resolvedSourceProvenance.sourceName
        self.sourceProvenance = resolvedSourceProvenance
        self.factProvenance = factProvenance ?? FactProvenance.legacyFacts(for: resolvedSourceProvenance)
    }

    var sourceBreakdownText: String {
        let confirmedFacts = factProvenance
            .filter { $0.confidence == .confirmed }
            .map { $0.fact.displayName.lowercased() }
        let inferredFacts = factProvenance
            .filter { $0.confidence == .inferred }
            .map { $0.fact.displayName.lowercased() }
        let unknownFacts = factProvenance
            .filter { $0.confidence == .unknown }
            .map { $0.fact.displayName.lowercased() }

        var parts: [String] = []
        if !confirmedFacts.isEmpty {
            parts.append("Confirmed: \(Self.compactFactList(confirmedFacts))")
        }
        if !inferredFacts.isEmpty {
            parts.append("Inferred: \(Self.compactFactList(inferredFacts))")
        }
        if !unknownFacts.isEmpty {
            parts.append("Unknown: \(Self.compactFactList(unknownFacts))")
        }
        return parts.isEmpty ? sourceProvenance.summaryText : parts.joined(separator: ". ")
    }

    private static func compactFactList(_ facts: [String]) -> String {
        facts.prefix(4).joined(separator: ", ") + (facts.count > 4 ? ", more" : "")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case providerID
        case routeID
        case liveTripID
        case train
        case operatorName
        case service
        case origin
        case destination
        case duration
        case status
        case statusTone
        case category
        case platform
        case nextStop
        case eta
        case speed
        case progress
        case bestCar
        case cars
        case seat
        case updated
        case callout
        case signal
        case signalCopy
        case stops
        case alerts
        case pulse
        case vehicleLatitude
        case vehicleLongitude
        case distanceText
        case dataSource
        case sourceProvenance
        case factProvenance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let providerID = try container.decodeIfPresent(String.self, forKey: .providerID)
        let operatorName = try container.decode(String.self, forKey: .operatorName)
        let dataSource = try container.decodeIfPresent(String.self, forKey: .dataSource)
        let sourceProvenance = try container.decodeIfPresent(SourceProvenance.self, forKey: .sourceProvenance)
        let factProvenance = try container.decodeIfPresent([FactProvenance].self, forKey: .factProvenance)

        self.init(
            id: try container.decode(String.self, forKey: .id),
            providerID: providerID,
            routeID: try container.decodeIfPresent(String.self, forKey: .routeID),
            liveTripID: try container.decodeIfPresent(String.self, forKey: .liveTripID),
            train: try container.decode(String.self, forKey: .train),
            operatorName: operatorName,
            service: try container.decode(String.self, forKey: .service),
            origin: try container.decode(StationPoint.self, forKey: .origin),
            destination: try container.decode(StationPoint.self, forKey: .destination),
            duration: try container.decode(String.self, forKey: .duration),
            status: try container.decode(String.self, forKey: .status),
            statusTone: try container.decode(TrainStatusTone.self, forKey: .statusTone),
            category: try container.decode(TripFilter.self, forKey: .category),
            platform: try container.decode(String.self, forKey: .platform),
            nextStop: try container.decode(String.self, forKey: .nextStop),
            eta: try container.decode(String.self, forKey: .eta),
            speed: try container.decode(String.self, forKey: .speed),
            progress: try container.decode(Double.self, forKey: .progress),
            bestCar: try container.decode(Int.self, forKey: .bestCar),
            cars: try container.decode(Int.self, forKey: .cars),
            seat: try container.decode(String.self, forKey: .seat),
            updated: try container.decode(String.self, forKey: .updated),
            callout: try container.decode(String.self, forKey: .callout),
            signal: try container.decode(Int.self, forKey: .signal),
            signalCopy: try container.decode(String.self, forKey: .signalCopy),
            stops: try container.decode([StationStop].self, forKey: .stops),
            alerts: try container.decode([TrainAlert].self, forKey: .alerts),
            pulse: try container.decode(String.self, forKey: .pulse),
            vehicleLatitude: try container.decodeIfPresent(Double.self, forKey: .vehicleLatitude),
            vehicleLongitude: try container.decodeIfPresent(Double.self, forKey: .vehicleLongitude),
            distanceText: try container.decodeIfPresent(String.self, forKey: .distanceText),
            dataSource: dataSource,
            sourceProvenance: sourceProvenance,
            factProvenance: factProvenance
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(providerID, forKey: .providerID)
        try container.encodeIfPresent(routeID, forKey: .routeID)
        try container.encodeIfPresent(liveTripID, forKey: .liveTripID)
        try container.encode(train, forKey: .train)
        try container.encode(operatorName, forKey: .operatorName)
        try container.encode(service, forKey: .service)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        try container.encode(duration, forKey: .duration)
        try container.encode(status, forKey: .status)
        try container.encode(statusTone, forKey: .statusTone)
        try container.encode(category, forKey: .category)
        try container.encode(platform, forKey: .platform)
        try container.encode(nextStop, forKey: .nextStop)
        try container.encode(eta, forKey: .eta)
        try container.encode(speed, forKey: .speed)
        try container.encode(progress, forKey: .progress)
        try container.encode(bestCar, forKey: .bestCar)
        try container.encode(cars, forKey: .cars)
        try container.encode(seat, forKey: .seat)
        try container.encode(updated, forKey: .updated)
        try container.encode(callout, forKey: .callout)
        try container.encode(signal, forKey: .signal)
        try container.encode(signalCopy, forKey: .signalCopy)
        try container.encode(stops, forKey: .stops)
        try container.encode(alerts, forKey: .alerts)
        try container.encode(pulse, forKey: .pulse)
        try container.encodeIfPresent(vehicleLatitude, forKey: .vehicleLatitude)
        try container.encodeIfPresent(vehicleLongitude, forKey: .vehicleLongitude)
        try container.encodeIfPresent(distanceText, forKey: .distanceText)
        try container.encodeIfPresent(dataSource, forKey: .dataSource)
        try container.encode(sourceProvenance, forKey: .sourceProvenance)
        try container.encode(factProvenance, forKey: .factProvenance)
    }
}

enum TrainyColor {
    static let ink = Color(red: 16.0 / 255.0, green: 20.0 / 255.0, blue: 25.0 / 255.0)
    static let muted = Color(red: 96.0 / 255.0, green: 109.0 / 255.0, blue: 122.0 / 255.0)
    static let paper = Color(red: 247.0 / 255.0, green: 249.0 / 255.0, blue: 250.0 / 255.0)
    static let line = Color(red: 217.0 / 255.0, green: 222.0 / 255.0, blue: 228.0 / 255.0)
    static let red = Color(red: 216.0 / 255.0, green: 74.0 / 255.0, blue: 58.0 / 255.0)
    static let green = Color(red: 31.0 / 255.0, green: 143.0 / 255.0, blue: 103.0 / 255.0)
    static let amber = Color(red: 197.0 / 255.0, green: 122.0 / 255.0, blue: 22.0 / 255.0)
    static let blue = Color(red: 40.0 / 255.0, green: 104.0 / 255.0, blue: 199.0 / 255.0)
    static let teal = Color(red: 15.0 / 255.0, green: 143.0 / 255.0, blue: 149.0 / 255.0)
}

extension TrainTrip {
    private static let shinkansenProvider = ShinkansenTrainProvider()

    static let samples: [TrainTrip] = shinkansenProvider.defaultTrips
    static let discoverable: [TrainTrip] = Array(shinkansenProvider.catalog.dropFirst(shinkansenProvider.defaultTrips.count))
}
