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
    case badSourceResponse(source: String, statusCode: Int?)
    case unreadableSourceResponse(source: String)
    case sourceChainFailed(primary: String, fallback: String)
    case noLiveTrips

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Trainy could not build the Shinkansen data request."
        case .badResponse:
            return "The Shinkansen source returned an unexpected response."
        case .badSourceResponse(let source, let statusCode):
            if let statusCode {
                return "The \(source) returned HTTP \(statusCode)."
            }
            return "The \(source) returned an unexpected response."
        case .unreadableSourceResponse(let source):
            return "Trainy could not read the \(source) response."
        case .sourceChainFailed(let primary, let fallback):
            return "Scheduled Shinkansen lookup failed. Primary source: \(primary) Fallback source: \(fallback)"
        case .noLiveTrips:
            return "No scheduled Shinkansen departures matched that search."
        }
    }

    static func userFacingDescription(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

enum TrainyAPIConfig {
    static var odptConsumerKey: String? {
        cleanODPTKey(ProcessInfo.processInfo.environment["ODPT_CONSUMER_KEY"])
            ?? cleanODPTKey(Bundle.main.object(forInfoDictionaryKey: "ODPTConsumerKey") as? String)
    }

    static func cleanODPTKey(_ value: String?) -> String? {
        cleanSubscriptionKey(value)
    }

    // Shared cleanup for any provider subscription key / consumer key.
    // Rejects empty strings and unresolved build-time placeholders like "$(VAR)".
    static func cleanSubscriptionKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else { return nil }
        return trimmed
    }
}
