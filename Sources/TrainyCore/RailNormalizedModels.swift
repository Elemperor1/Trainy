//  This file was generated as part of Phase 3: Normalized Rail Data Layer
//  Goal: Stop feeding provider-specific fields directly into UI cards

import SwiftUI

// MARK: - RailProviderID

/// Identifies a rail data provider with normalized metadata.
/// Wraps the raw provider ID string for type safety while preserving source provenance.
struct RailProviderID: Hashable, Codable, Sendable {
    let rawValue: String
    let displayName: String
    let region: RailRegion

    init(rawValue: String, displayName: String, region: RailRegion) {
        self.rawValue = rawValue
        self.displayName = displayName
        self.region = region
    }

    init(from provenance: SourceProvenance) {
        self.rawValue = provenance.providerID
        self.displayName = provenance.providerName
        self.region = RailRegion(id: provenance.providerID, displayName: provenance.providerName)
    }

    var sourceProvenance: SourceProvenance {
        SourceProvenance(
            providerID: rawValue,
            providerName: displayName,
            sourceName: displayName,
            sourceKind: .officialTimetable,
            confidence: .confirmed
        )
    }
}

// MARK: - RailRegion

/// Represents a geographic region for rail data providers.
struct RailRegion: Hashable, Codable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let timeZone: TimeZone?

    init(id: String, displayName: String, timeZone: TimeZone? = nil) {
        self.id = id
        self.displayName = displayName
        self.timeZone = timeZone
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
        self.timeZone = TimeZone(identifier: "UTC")
    }

    static let all = RailRegion(id: "all", displayName: "All regions")
    static let global = RailRegion(id: "global", displayName: "Global", timeZone: TimeZone(identifier: "UTC"))
    static let japan = RailRegion(id: "jp", displayName: "Japan", timeZone: TimeZone(identifier: "Asia/Tokyo"))
    static let taiwan = RailRegion(id: "tw", displayName: "Taiwan", timeZone: TimeZone(identifier: "Asia/Taipei"))
    static let hongKong = RailRegion(id: "hk", displayName: "Hong Kong", timeZone: TimeZone(identifier: "Asia/Hong_Kong"))
    static let germany = RailRegion(id: "de", displayName: "Germany", timeZone: TimeZone(identifier: "Europe/Berlin"))
    static let switzerland = RailRegion(id: "ch", displayName: "Switzerland", timeZone: TimeZone(identifier: "Europe/Zurich"))
    static let unitedKingdom = RailRegion(id: "uk", displayName: "United Kingdom", timeZone: TimeZone(identifier: "Europe/London"))
    static let australia = RailRegion(id: "au", displayName: "Australia", timeZone: TimeZone(identifier: "Australia/Sydney"))
    static let unitedStates = RailRegion(id: "us", displayName: "United States", timeZone: TimeZone(identifier: "America/New_York"))
    static let netherlands = RailRegion(id: "nl", displayName: "Netherlands", timeZone: TimeZone(identifier: "Europe/Amsterdam"))
    static let southKorea = RailRegion(id: "kr", displayName: "South Korea", timeZone: TimeZone(identifier: "Asia/Seoul"))
    static let france = RailRegion(id: "fr", displayName: "France", timeZone: TimeZone(identifier: "Europe/Paris"))
    static let europe = RailRegion(id: "eu", displayName: "Europe", timeZone: TimeZone(identifier: "Europe/Brussels"))
    static let northAmerica = RailRegion(id: "na", displayName: "North America", timeZone: TimeZone(identifier: "America/Chicago"))
}

// MARK: - RailSource

/// Represents a specific data source from a rail provider, including provenance metadata.
struct RailSource: Hashable, Codable, Identifiable, Sendable {
    let id: String
    let providerID: RailProviderID
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

    init(
        id: String,
        providerID: RailProviderID,
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
        self.id = id
        self.providerID = providerID
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.confidence = confidence
        self.freshness = freshness ?? FreshnessState.resolved(fetchedAt: fetchedAt, validUntil: validUntil, now: fetchedAt ?? Date())
        self.fetchedAt = fetchedAt
        self.publishedAt = publishedAt
        self.validUntil = validUntil
        self.licenseName = licenseName
        self.attributionText = attributionText
        self.sourceURL = sourceURL
    }

    init(from provenance: SourceProvenance) {
        self.id = provenance.providerID
        self.providerID = RailProviderID(from: provenance)
        self.sourceName = provenance.sourceName
        self.sourceKind = provenance.sourceKind
        self.confidence = provenance.confidence
        self.freshness = provenance.freshness
        self.fetchedAt = provenance.fetchedAt
        self.publishedAt = provenance.publishedAt
        self.validUntil = provenance.validUntil
        self.licenseName = provenance.licenseName
        self.attributionText = provenance.attributionText
        self.sourceURL = provenance.sourceURL
    }

    var summaryText: String {
        sourceKind.riderTitle + " - " + confidence.displayName
    }

    /// Returns a normalized display name for the source.
    var displayName: String {
        providerID.displayName + " " + sourceName
    }

    var detailText: String {
        if let attributionText, !attributionText.isEmpty {
            return attributionText
        }
        return displayName
    }
}

// MARK: - RailStation

/// Normalized representation of a rail station with provider-native ID and localized names.
struct RailStation: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let providerID: RailProviderID
    let displayName: String
    let localizedNames: [String: String]?
    let latitude: Double?
    let longitude: Double?
    let region: RailRegion
    let source: RailSource?

    init(
        id: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        displayName: String,
        localizedNames: [String: String]? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        region: RailRegion? = nil,
        source: RailSource? = nil
    ) {
        self.id = id ?? nativeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.displayName = displayName
        self.localizedNames = localizedNames
        self.latitude = latitude
        self.longitude = longitude
        self.region = region ?? providerID.region
        self.source = source
    }

    /// Returns the localized name for a given locale, falling back to displayName.
    func displayName(for locale: String) -> String {
        localizedNames?[locale] ?? displayName
    }

    /// Returns the station's position, if available.
    var coordinate: Coordinate? {
        guard let latitude, let longitude else { return nil }
        return Coordinate(latitude: latitude, longitude: longitude)
    }
}

// MARK: - RailRoute

/// Normalized representation of a rail route (line/service) with provider mappings.
struct RailRoute: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let providerID: RailProviderID
    let displayName: String
    let localizedNames: [String: String]?
    let color: String?
    let destinations: [String]
    let region: RailRegion
    let source: RailSource?

    init(
        id: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        displayName: String,
        localizedNames: [String: String]? = nil,
        color: String? = nil,
        destinations: [String] = [],
        region: RailRegion? = nil,
        source: RailSource? = nil
    ) {
        self.id = id ?? nativeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.displayName = displayName
        self.localizedNames = localizedNames
        self.color = color
        self.destinations = destinations
        self.region = region ?? providerID.region
        self.source = source
    }

    /// Returns the localized name for a given locale, falling back to displayName.
    func displayName(for locale: String) -> String {
        localizedNames?[locale] ?? displayName
    }
}

// MARK: - RailStopTime

/// Normalized stop time for a station on a rail trip, including time zone.
struct RailStopTime: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let stationID: String
    let providerID: RailProviderID?
    let scheduledTime: Date?
    let estimatedTime: Date?
    let platform: String?
    let stopSequence: Int
    let timeZone: TimeZone
    let source: RailSource?

    init(
        id: String? = nil,
        nativeID: String? = nil,
        stationID: String,
        providerID: RailProviderID? = nil,
        scheduledTime: Date? = nil,
        estimatedTime: Date? = nil,
        platform: String? = nil,
        stopSequence: Int = 0,
        timeZone: TimeZone = .current,
        source: RailSource? = nil
    ) {
        self.id = id ?? UUID().uuidString
        self.nativeID = nativeID ?? stationID
        self.stationID = stationID
        self.providerID = providerID
        self.scheduledTime = scheduledTime
        self.estimatedTime = estimatedTime
        self.platform = platform
        self.stopSequence = stopSequence
        self.timeZone = timeZone
        self.source = source
    }

    enum StopState: String, Codable, Sendable {
        case done
        case current
        case pending
    }

    var state: StopState {
        guard let scheduledTime else { return .pending }
        let now = Date()
        return scheduledTime.timeIntervalSince(now) > 0 ? .pending : .done
    }

    /// Returns the effective time (estimated if available, otherwise scheduled).
    var effectiveTime: Date? {
        estimatedTime ?? scheduledTime
    }

    /// Formats the time using the associated time zone.
    func formattedTime(style: DateFormatter.Style = .short) -> String? {
        guard let effectiveTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        formatter.timeZone = timeZone
        return formatter.string(from: effectiveTime)
    }

    /// Returns a normalized display name for this stop time.
    var displayName: String {
        "Stop \(stopSequence)"
    }
}

// MARK: - ScheduledRailTrip

/// A scheduled rail trip with normalized station stops and source provenance.
struct ScheduledRailTrip: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let providerID: RailProviderID
    let routeID: String?
    let displayName: String
    let localizedNames: [String: String]?
    let originStationID: String
    let destinationStationID: String
    let scheduledDeparture: Date
    let scheduledArrival: Date
    let timeZone: TimeZone
    let stopTimes: [RailStopTime]
    let source: RailSource

    init(
        id: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        routeID: String? = nil,
        displayName: String,
        localizedNames: [String: String]? = nil,
        originStationID: String,
        destinationStationID: String,
        scheduledDeparture: Date,
        scheduledArrival: Date,
        timeZone: TimeZone? = nil,
        stopTimes: [RailStopTime] = [],
        source: RailSource
    ) {
        self.id = id ?? nativeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.routeID = routeID
        self.displayName = displayName
        self.localizedNames = localizedNames
        self.originStationID = originStationID
        self.destinationStationID = destinationStationID
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.timeZone = timeZone ?? providerID.region.timeZone ?? TimeZone.current
        self.stopTimes = stopTimes
        self.source = source
    }

    /// Returns the localized name for a given locale, falling back to displayName.
    func displayName(for locale: String) -> String {
        localizedNames?[locale] ?? displayName
    }

    /// Calculates trip duration in seconds.
    var duration: TimeInterval {
        scheduledArrival.timeIntervalSince(scheduledDeparture)
    }
}

// MARK: - RealtimeTripOverlay

/// Realtime data overlay for a scheduled trip (delays, cancellations, etc.).
struct RealtimeTripOverlay: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let tripID: String
    let providerID: RailProviderID
    let delaySeconds: Int?
    let status: TripStatus
    let updatedAt: Date
    let timeZone: TimeZone
    let source: RailSource
    let estimatedDeparture: Date?
    let estimatedArrival: Date?
    let stopTimeOverlays: [RailStopTimeOverlay]

    enum TripStatus: String, Codable, Sendable {
        case onTime
        case delayed
        case canceled
        case platformChanged
        case boardingOpen
        case unknown

        var displayName: String {
            switch self {
            case .onTime: return "On time"
            case .delayed: return "Delayed"
            case .canceled: return "Canceled"
            case .platformChanged: return "Platform changed"
            case .boardingOpen: return "Boarding open"
            case .unknown: return "Unknown"
            }
        }

        var tone: TrainStatusTone {
            switch self {
            case .onTime: return .good
            case .delayed, .platformChanged, .boardingOpen: return .watch
            case .canceled, .unknown: return .late
            }
        }
    }

    init(
        id: String? = nil,
        nativeID: String? = nil,
        tripID: String,
        providerID: RailProviderID,
        delaySeconds: Int? = nil,
        status: TripStatus,
        updatedAt: Date = Date(),
        timeZone: TimeZone? = nil,
        source: RailSource,
        estimatedDeparture: Date? = nil,
        estimatedArrival: Date? = nil,
        stopTimeOverlays: [RailStopTimeOverlay] = []
    ) {
        self.id = id ?? tripID
        self.nativeID = nativeID ?? tripID
        self.tripID = tripID
        self.providerID = providerID
        self.delaySeconds = delaySeconds
        self.status = status
        self.updatedAt = updatedAt
        self.timeZone = timeZone ?? providerID.region.timeZone ?? TimeZone.current
        self.source = source
        self.estimatedDeparture = estimatedDeparture
        self.estimatedArrival = estimatedArrival
        self.stopTimeOverlays = stopTimeOverlays
    }

    /// Returns a normalized display name for this overlay.
    var displayName: String {
        "Realtime: \(status.displayName)"
    }
}

// MARK: - RailStopTimeOverlay

/// Realtime overlay for a specific stop time.
struct RailStopTimeOverlay: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let stopTimeIndex: Int
    let estimatedTime: Date?
    let platform: String?
    let status: TripStatus

    init(
        id: String? = nil,
        stopTimeIndex: Int,
        estimatedTime: Date? = nil,
        platform: String? = nil,
        status: TripStatus
    ) {
        self.id = id ?? "stop:\(stopTimeIndex)"
        self.stopTimeIndex = stopTimeIndex
        self.estimatedTime = estimatedTime
        self.platform = platform
        self.status = status
    }
}

// MARK: - RailVehiclePosition

/// Normalized vehicle position with provider-native ID and geographic coordinates.
struct RailVehiclePosition: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let providerID: RailProviderID
    let tripID: String?
    let latitude: Double
    let longitude: Double
    let heading: Double?
    let speed: Double?
    let recordedAt: Date
    let timeZone: TimeZone
    let source: RailSource
    let coordinate: Coordinate

    init(
        id: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        tripID: String? = nil,
        latitude: Double,
        longitude: Double,
        heading: Double? = nil,
        speed: Double? = nil,
        recordedAt: Date = Date(),
        timeZone: TimeZone? = nil,
        source: RailSource
    ) {
        self.id = id ?? nativeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.tripID = tripID
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.speed = speed
        self.recordedAt = recordedAt
        self.timeZone = timeZone ?? providerID.region.timeZone ?? TimeZone.current
        self.source = source
        self.coordinate = Coordinate(latitude: latitude, longitude: longitude)
    }

    /// Returns a normalized display name for this vehicle position.
    var displayName: String {
        "Vehicle at \(latitude), \(longitude)"
    }
}

// MARK: - RailServiceAlert

/// Normalized service alert with localized content and affected entities.
struct RailServiceAlert: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let nativeID: String
    let providerID: RailProviderID
    let headline: String
    let localizedHeadlines: [String: String]?
    let detail: String
    let localizedDetails: [String: String]?
    let affectedRoutes: [String]
    let affectedStations: [String]
    let effectiveFrom: Date?
    let effectiveUntil: Date?
    let postedAt: Date
    let timeZone: TimeZone?
    let source: RailSource
    let severity: AlertSeverity

    enum AlertSeverity: String, Codable, Sendable {
        case info
        case warning
        case severe
        case critical

        var displayName: String {
            switch self {
            case .info: return "Information"
            case .warning: return "Warning"
            case .severe: return "Severe"
            case .critical: return "Critical"
            }
        }

        var tone: TrainStatusTone {
            switch self {
            case .info: return .good
            case .warning: return .watch
            case .severe, .critical: return .late
            }
        }
    }

    init(
        id: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        headline: String,
        localizedHeadlines: [String: String]? = nil,
        detail: String,
        localizedDetails: [String: String]? = nil,
        affectedRoutes: [String] = [],
        affectedStations: [String] = [],
        effectiveFrom: Date? = nil,
        effectiveUntil: Date? = nil,
        postedAt: Date = Date(),
        timeZone: TimeZone? = nil,
        source: RailSource,
        severity: AlertSeverity = .info
    ) {
        self.id = id ?? nativeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.headline = headline
        self.localizedHeadlines = localizedHeadlines
        self.detail = detail
        self.localizedDetails = localizedDetails
        self.affectedRoutes = affectedRoutes
        self.affectedStations = affectedStations
        self.effectiveFrom = effectiveFrom
        self.effectiveUntil = effectiveUntil
        self.postedAt = postedAt
        self.timeZone = timeZone
        self.source = source
        self.severity = severity
    }

    /// Returns the localized headline for a given locale, falling back to headline.
    func headline(for locale: String) -> String {
        localizedHeadlines?[locale] ?? headline
    }

    /// Returns the localized detail for a given locale, falling back to detail.
    func detail(for locale: String) -> String {
        localizedDetails?[locale] ?? detail
    }

    /// Returns a normalized display name for this alert.
    var displayName: String {
        headline
    }
}

// MARK: - RailBoardEntry

/// Entry for a station departure/arrival board, linking to trip and route.
struct RailBoardEntry: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let tripID: String
    let routeID: String?
    let nativeID: String
    let providerID: RailProviderID
    let displayName: String
    let localizedNames: [String: String]?
    let destinationStationID: String
    let destinationName: String
    let scheduledDeparture: Date
    let estimatedDeparture: Date?
    let platform: String?
    let status: TripStatus
    let timeZone: TimeZone
    let source: RailSource

    init(
        id: String? = nil,
        tripID: String,
        routeID: String? = nil,
        nativeID: String,
        providerID: RailProviderID,
        displayName: String,
        localizedNames: [String: String]? = nil,
        destinationStationID: String,
        destinationName: String,
        scheduledDeparture: Date,
        estimatedDeparture: Date? = nil,
        platform: String? = nil,
        status: TripStatus = .unknown,
        timeZone: TimeZone? = nil,
        source: RailSource
    ) {
        self.id = id ?? tripID
        self.tripID = tripID
        self.routeID = routeID
        self.nativeID = nativeID
        self.providerID = providerID
        self.displayName = displayName
        self.localizedNames = localizedNames
        self.destinationStationID = destinationStationID
        self.destinationName = destinationName
        self.scheduledDeparture = scheduledDeparture
        self.estimatedDeparture = estimatedDeparture
        self.platform = platform
        self.status = status
        self.timeZone = timeZone ?? providerID.region.timeZone ?? TimeZone.current
        self.source = source
    }

    /// Returns the localized name for a given locale, falling back to displayName.
    func displayName(for locale: String) -> String {
        localizedNames?[locale] ?? displayName
    }

    /// Returns the effective departure time.
    var effectiveDeparture: Date {
        estimatedDeparture ?? scheduledDeparture
    }
}

// MARK: - RailTripCandidate

/// A candidate trip suggestion combining scheduled and realtime data.
struct RailTripCandidate: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let scheduledTrip: ScheduledRailTrip
    let realtimeOverlay: RealtimeTripOverlay?
    let serviceAlerts: [RailServiceAlert]
    let vehiclePosition: RailVehiclePosition?

    init(
        id: String? = nil,
        scheduledTrip: ScheduledRailTrip,
        realtimeOverlay: RealtimeTripOverlay? = nil,
        serviceAlerts: [RailServiceAlert] = [],
        vehiclePosition: RailVehiclePosition? = nil
    ) {
        self.id = id ?? scheduledTrip.id
        self.scheduledTrip = scheduledTrip
        self.realtimeOverlay = realtimeOverlay
        self.serviceAlerts = serviceAlerts
        self.vehiclePosition = vehiclePosition
    }

    // MARK: - Required properties (delegated to scheduledTrip)

    /// Provider ID for this candidate (delegated to scheduled trip).
    var providerID: RailProviderID {
        scheduledTrip.providerID
    }

    /// Source provenance for this candidate (delegated to scheduled trip).
    var source: RailSource {
        scheduledTrip.source
    }

    /// Provider-native ID for this candidate (delegated to scheduled trip).
    var nativeID: String {
        scheduledTrip.nativeID
    }

    /// Normalized display name for this candidate (delegated to scheduled trip).
    var displayName: String {
        scheduledTrip.displayName
    }

    /// Localized names for this candidate (delegated to scheduled trip).
    var localizedNames: [String: String]? {
        scheduledTrip.localizedNames
    }

    /// Time zone for this candidate (delegated to scheduled trip).
    var timeZone: TimeZone {
        scheduledTrip.timeZone
    }

    // MARK: - Convenience computed properties

    /// Returns the effective departure time (realtime if available, otherwise scheduled).
    var effectiveDeparture: Date {
        realtimeOverlay?.estimatedDeparture ?? scheduledTrip.scheduledDeparture
    }

    /// Returns the effective arrival time (realtime if available, otherwise scheduled).
    var effectiveArrival: Date {
        realtimeOverlay?.estimatedArrival ?? scheduledTrip.scheduledArrival
    }

    /// Returns the current status, preferring realtime data.
    var status: RealtimeTripOverlay.TripStatus {
        realtimeOverlay?.status ?? .onTime
    }
}

// MARK: - Supporting Types

/// Geographic coordinate representation.
struct Coordinate: Hashable, Codable, Sendable {
    let latitude: Double
    let longitude: Double
}

// Re-export TripStatus for convenience
typealias TripStatus = RealtimeTripOverlay.TripStatus

// MARK: - Factory Methods

extension RailProviderID {
    static func odpt() -> RailProviderID {
        RailProviderID(
            rawValue: "odpt",
            displayName: "Open Data Public Transportation Council",
            region: .japan
        )
    }

    static func jrEast() -> RailProviderID {
        RailProviderID(
            rawValue: "jr-east",
            displayName: "JR East",
            region: .japan
        )
    }

    static func trainy() -> RailProviderID {
        RailProviderID(
            rawValue: "trainy",
            displayName: "Trainy",
            region: .global
        )
    }
}