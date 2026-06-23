import Foundation

// MARK: - Departures (GET /reisinformatie-api/api/v2/departures?station=UT)

struct NSDeparturesResponse: Decodable, Sendable {
    let source: String?
    let departures: [NSDeparture]
}

struct NSDeparture: Decodable, Sendable {
    let direction: String?
    let name: String?
    let plannedDateTime: String?
    let actualDateTime: String?
    let plannedTrack: String?
    let actualTrack: String?
    let product: NSProduct?
    let trainCategory: String?
    let cancelled: Bool?
    let routeStations: [NSRouteStation]?
    let messages: [NSDepartureMessage]?
    let departureStatus: String?

    var effectiveTrack: String? {
        actualTrack ?? plannedTrack
    }

    var displayName: String {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? name! : (product?.shortCategoryName ?? "NS")
    }

    var categoryLabel: String {
        product?.longCategoryName ?? product?.shortCategoryName ?? trainCategory ?? "Train"
    }

    var isCancelled: Bool {
        cancelled == true
    }
}

struct NSProduct: Decodable, Sendable {
    let number: String?
    let categoryCode: String?
    let shortCategoryName: String?
    let longCategoryName: String?
    let operatorName: String?
    let operatorCode: String?
    let type: String?
}

struct NSRouteStation: Decodable, Sendable {
    let uicCode: String?
    let mediumName: String?
    let name: String?
}

struct NSDepartureMessage: Decodable, Sendable {
    let message: String?
    let style: String?
}

// MARK: - Disruptions (GET /reisinformatie-api/api/v3/disruptions?isActive=true)

struct NSDisruptionsResponse: Decodable, Sendable {
    let disruptions: [NSDisruption]
}

struct NSDisruption: Decodable, Sendable {
    let id: String?
    let title: String?
    let isActive: Bool?
    let phase: NSDisruptionPhase?
    let impact: NSDisruptionImpact?
    let expectedDuration: NSExpectedDuration?
    let timespans: [NSDisruptionTimespan]?
    let publicationSections: [NSPublicationSection]?

    var primarySituationText: String? {
        timespans?.compactMap { $0.situation?.label }.first
    }

    var primaryCauseText: String? {
        timespans?.compactMap { $0.cause?.label }.first
    }
}

struct NSDisruptionPhase: Decodable, Sendable {
    let id: String?
    let label: String?
}

struct NSDisruptionImpact: Decodable, Sendable {
    let value: Int?
}

struct NSExpectedDuration: Decodable, Sendable {
    let description: String?
    let endTime: String?
}

struct NSDisruptionTimespan: Decodable, Sendable {
    let start: String?
    let end: String?
    let situation: NSDisruptionSituation?
    let cause: NSDisruptionCause?
}

struct NSDisruptionSituation: Decodable, Sendable {
    let label: String?
}

struct NSDisruptionCause: Decodable, Sendable {
    let label: String?
    let type: String?
}

struct NSPublicationSection: Decodable, Sendable {
    let section: NSDisruptionSection?
    let consequence: NSDisruptionConsequence?
    let sectionType: String?
}

struct NSDisruptionSection: Decodable, Sendable {
    let stations: [NSDisruptionStation]?
    let direction: String?
    let operators: [String]?
}

struct NSDisruptionStation: Decodable, Sendable {
    let name: String?
    let stationCode: String?
    let uicCode: String?
    let coordinate: NSCoordinate?
    let countryCode: String?
}

struct NSDisruptionConsequence: Decodable, Sendable {
    let description: String?
    let level: String?
}

struct NSCoordinate: Decodable, Sendable {
    let lat: Double?
    let lng: Double?
}

// MARK: - Station lookup (GET /reisinformatie-api/api/v2/stations)

struct NSStationsResponse: Decodable, Sendable {
    let payload: NSStationsPayload?
}

struct NSStationsPayload: Decodable, Sendable {
    let stations: [NSStation]
}

struct NSStation: Decodable, Sendable {
    let code: String?
    let stationType: String?
    let names: NSStationNames?
    let lat: Double?
    let lng: Double?
    let country: String?
    let uicCode: String?
}

struct NSStationNames: Decodable, Sendable {
    let lang: String?
    let medium: String?
    let long: String?
    let short: String?
}
