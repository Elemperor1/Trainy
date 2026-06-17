import Foundation

enum ProviderError: LocalizedError, Equatable, Sendable {
    case providerNotFound(String)
    case unsupportedCapability(providerID: String, capability: ProviderCapability)
    case providerUnavailable(providerID: String, reason: String)
    case missingRequirement(providerID: String, requirement: ProviderRequirement)
    case badResponse(providerID: String)
    case noResults(providerID: String)

    var errorDescription: String? {
        switch self {
        case .providerNotFound(let providerID):
            return "Trainy could not find provider '\(providerID)'."
        case .unsupportedCapability(let providerID, let capability):
            return "Provider '\(providerID)' does not support \(capability.displayName.lowercased())."
        case .providerUnavailable(let providerID, let reason):
            return "Provider '\(providerID)' is unavailable: \(reason)."
        case .missingRequirement(let providerID, let requirement):
            return "Provider '\(providerID)' needs \(requirement.displayName)."
        case .badResponse(let providerID):
            return "Provider '\(providerID)' returned an unexpected response."
        case .noResults(let providerID):
            return "Provider '\(providerID)' did not return matching trips."
        }
    }
}
