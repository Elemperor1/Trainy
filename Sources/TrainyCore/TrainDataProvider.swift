import Foundation

struct LiveTrainRoute: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let summary: String
    let destinations: [String]
}

enum TrainDataProviderError: LocalizedError, Sendable {
    case badURL
    case badResponse
    case noLiveTrips

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Trainy could not build the Shinkansen data request."
        case .badResponse:
            return "The Shinkansen source returned an unexpected response."
        case .noLiveTrips:
            return "No scheduled Shinkansen departures matched that search."
        }
    }
}

enum TrainyAPIConfig {
    static var odptConsumerKey: String? {
        cleanODPTKey(ProcessInfo.processInfo.environment["ODPT_CONSUMER_KEY"])
            ?? cleanODPTKey(Bundle.main.object(forInfoDictionaryKey: "ODPTConsumerKey") as? String)
    }

    static func cleanODPTKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
