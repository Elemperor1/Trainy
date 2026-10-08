import Foundation

/// What the Stations tab needs from a station-board provider.
///
/// The directory, the board, and their view models depend on this protocol
/// instead of on `NSTrainProvider`, so a second provider with station boards is
/// a new conformance rather than a new screen. Conformances live here, next to
/// the screens, so provider files stay free of UI-layer types.
protocol StationDataProviding: Sendable {
    /// Matches `ProviderStation.providerID` for the stations this provider returns.
    var providerID: String { get }
    var displayName: String { get }
    /// False when this build cannot reach the provider at all, so the tab can
    /// say so up front instead of after a failed search.
    var isConfigured: Bool { get }
    /// Station names offered as one-tap searches before the rider types anything.
    var suggestedSearches: [String] { get }

    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage
    func fetchStationBoard(stationID: String) async throws -> StationBoard
    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage
}

extension StationDataProviding {
    var isConfigured: Bool { true }
    var suggestedSearches: [String] { [] }
}

extension NSTrainProvider: StationDataProviding {
    static let commonStationSearches = [
        "Utrecht Centraal",
        "Amsterdam Centraal",
        "Rotterdam Centraal",
        "Schiphol Airport"
    ]

    var suggestedSearches: [String] {
        Self.commonStationSearches
    }
}

/// How a station request failed, in the terms the Stations screens show.
enum StationDataFailure: Equatable, Sendable {
    case notConfigured
    case offline
    case rateLimited(retryAfterSeconds: Int?)
    case unavailable

    /// Provider clients throw their own error types. NS is the only one mapped
    /// so far; anything unrecognised is reported as unavailable.
    static func resolve(_ error: Error) -> StationDataFailure {
        guard let error = error as? NSClientError else { return .unavailable }
        switch error {
        case .invalidProxyConfiguration, .notConfigured:
            return .notConfigured
        case .offline, .timedOut:
            return .offline
        case .rateLimited(let retryAfterSeconds):
            return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        case .invalidRequest, .unavailable, .badResponse:
            return .unavailable
        }
    }

    var message: String {
        switch self {
        case .notConfigured:
            return "NS departures are not configured in this build."
        case .offline:
            return "Trainy could not reach NS. Check your connection and try again."
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds {
                return "NS is busy. Try again in about \(retryAfterSeconds) seconds."
            }
            return "NS is busy. Try again shortly."
        case .unavailable:
            return "NS departures are temporarily unavailable."
        }
    }
}
