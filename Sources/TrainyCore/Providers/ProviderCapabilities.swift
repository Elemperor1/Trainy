import Foundation

enum ProviderCapability: String, CaseIterable, Hashable, Identifiable, Sendable {
    case schedule
    case realtimeTripUpdates = "realtime-trip-updates"
    case serviceAlerts = "service-alerts"
    case stationBoard = "station-board"
    case journeyPlanning = "journey-planning"
    case vehiclePositions = "vehicle-positions"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .schedule:
            return "Schedule"
        case .realtimeTripUpdates:
            return "Realtime trip updates"
        case .serviceAlerts:
            return "Service alerts"
        case .stationBoard:
            return "Station board"
        case .journeyPlanning:
            return "Journey planning"
        case .vehiclePositions:
            return "Vehicle positions"
        }
    }
}

struct ProviderAvailability: Hashable, Sendable {
    enum Status: String, Hashable, Sendable {
        case available
        case degraded
        case requiresConfiguration
        case requiresProxy
        case unavailable
    }

    let status: Status
    let message: String
    let checkedAt: Date?
    let requirements: Set<ProviderRequirement>

    init(
        status: Status,
        message: String,
        checkedAt: Date? = nil,
        requirements: Set<ProviderRequirement> = []
    ) {
        self.status = status
        self.message = message
        self.checkedAt = checkedAt
        self.requirements = requirements
    }

    var canSearch: Bool {
        switch status {
        case .available, .degraded:
            return true
        case .requiresConfiguration, .requiresProxy, .unavailable:
            return false
        }
    }

    static func available(_ message: String, requirements: Set<ProviderRequirement> = []) -> ProviderAvailability {
        ProviderAvailability(status: .available, message: message, requirements: requirements)
    }

    static func degraded(_ message: String, requirements: Set<ProviderRequirement> = []) -> ProviderAvailability {
        ProviderAvailability(status: .degraded, message: message, requirements: requirements)
    }

    static func requiresConfiguration(_ message: String, requirements: Set<ProviderRequirement>) -> ProviderAvailability {
        ProviderAvailability(status: .requiresConfiguration, message: message, requirements: requirements)
    }

    static func requiresProxy(_ message: String, requirements: Set<ProviderRequirement> = [.proxy]) -> ProviderAvailability {
        ProviderAvailability(status: .requiresProxy, message: message, requirements: requirements)
    }

    static func unavailable(_ message: String, requirements: Set<ProviderRequirement> = []) -> ProviderAvailability {
        ProviderAvailability(status: .unavailable, message: message, requirements: requirements)
    }
}

enum ProviderAuthStrategy: Hashable, Sendable {
    case none
    case localKey(environmentVariable: String, infoPlistKey: String?)
    case proxy(reason: String?)
    case oauth(setupURL: URL?)
    case custom(String)

    var requiresLocalKey: Bool {
        if case .localKey = self {
            return true
        }
        return false
    }

    var requiresProxy: Bool {
        if case .proxy = self {
            return true
        }
        return false
    }

    var requirements: Set<ProviderRequirement> {
        switch self {
        case .none:
            return []
        case .localKey(let environmentVariable, _):
            return [.localKey(environmentVariable)]
        case .proxy:
            return [.proxy]
        case .oauth:
            return [.providerAccount("OAuth sign-in")]
        case .custom(let label):
            return [.providerAccount(label)]
        }
    }

    var displayName: String {
        switch self {
        case .none:
            return "No auth"
        case .localKey(let environmentVariable, _):
            return "Local key: \(environmentVariable)"
        case .proxy:
            return "Provider proxy"
        case .oauth:
            return "OAuth"
        case .custom(let label):
            return label
        }
    }
}

enum ProviderRequirement: Hashable, Identifiable, Sendable {
    case networkAccess
    case localKey(String)
    case proxy
    case providerAccount(String)
    case attribution(String)
    case terms(String)

    var id: String {
        switch self {
        case .networkAccess:
            return "network"
        case .localKey(let name):
            return "local-key:\(name)"
        case .proxy:
            return "proxy"
        case .providerAccount(let label):
            return "account:\(label)"
        case .attribution(let label):
            return "attribution:\(label)"
        case .terms(let label):
            return "terms:\(label)"
        }
    }

    var displayName: String {
        switch self {
        case .networkAccess:
            return "Network access"
        case .localKey(let name):
            return "Local key: \(name)"
        case .proxy:
            return "Provider proxy"
        case .providerAccount(let label):
            return label
        case .attribution(let label):
            return label
        case .terms(let label):
            return label
        }
    }
}

struct ProviderRegion: Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String

    static let all = ProviderRegion(id: "all", displayName: "All regions")
    static let global = ProviderRegion(id: "global", displayName: "Global")
    static let japan = ProviderRegion(id: "jp", displayName: "Japan")
    static let taiwan = ProviderRegion(id: "tw", displayName: "Taiwan")
    static let hongKong = ProviderRegion(id: "hk", displayName: "Hong Kong")
    static let germany = ProviderRegion(id: "de", displayName: "Germany")
    static let switzerland = ProviderRegion(id: "ch", displayName: "Switzerland")
    static let unitedKingdom = ProviderRegion(id: "uk", displayName: "United Kingdom")
    static let australia = ProviderRegion(id: "au", displayName: "Australia")
    static let unitedStates = ProviderRegion(id: "us", displayName: "United States")
    static let netherlands = ProviderRegion(id: "nl", displayName: "Netherlands")
    static let southKorea = ProviderRegion(id: "kr", displayName: "South Korea")
    static let france = ProviderRegion(id: "fr", displayName: "France")
    static let europe = ProviderRegion(id: "eu", displayName: "Europe")
    static let northAmerica = ProviderRegion(id: "na", displayName: "North America")
}
