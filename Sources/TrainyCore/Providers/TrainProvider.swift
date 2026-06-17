import Foundation

typealias ActiveTrainProvider = ScheduleFeedProvider & RealtimeFeedProvider

protocol TrainProvider: Sendable {
    var providerID: String { get }
    var displayName: String { get }
    var dataScope: String { get }
    var region: ProviderRegion { get }
    var capabilities: Set<ProviderCapability> { get }
    var availability: ProviderAvailability { get }
    var authStrategy: ProviderAuthStrategy { get }
    var requirements: Set<ProviderRequirement> { get }
    var sourceLinks: [ProviderSourceLink] { get }
    var implementationStatus: ProviderImplementationStatus { get }
    var feedLabel: String { get }
    var catalog: [TrainTrip] { get }
    var defaultTrips: [TrainTrip] { get }
    var includesCatalogResultsInSearch: Bool { get }

    func health() async -> ProviderAvailability
}

extension TrainProvider {
    var displayName: String { providerID }
    var dataScope: String { providerID }
    var region: ProviderRegion { .global }
    var capabilities: Set<ProviderCapability> { [] }
    var availability: ProviderAvailability {
        .available("\(displayName) is available.", requirements: requirements)
    }
    var authStrategy: ProviderAuthStrategy { .none }
    var requirements: Set<ProviderRequirement> { authStrategy.requirements }
    var sourceLinks: [ProviderSourceLink] { [] }
    var implementationStatus: ProviderImplementationStatus { .active }
    var feedLabel: String { displayName }
    var catalog: [TrainTrip] { [] }
    var defaultTrips: [TrainTrip] { Array(catalog.prefix(4)) }
    var includesCatalogResultsInSearch: Bool { true }

    func supports(_ capability: ProviderCapability) -> Bool {
        capabilities.contains(capability)
    }

    func supportsAll(_ requiredCapabilities: Set<ProviderCapability>) -> Bool {
        requiredCapabilities.isSubset(of: capabilities)
    }

    func health() async -> ProviderAvailability {
        availability
    }
}

protocol ScheduleFeedProvider: TrainProvider {
    func fetchRoutes() async throws -> [LiveTrainRoute]
    func fetchTrips(matching query: String, knownRoutes: [LiveTrainRoute]) async throws -> [TrainTrip]
}

protocol RealtimeFeedProvider: TrainProvider {
    func refresh(_ trip: TrainTrip, knownRoutes: [LiveTrainRoute]) async throws -> TrainTrip?
}

protocol StationBoardProvider: TrainProvider {
    func fetchStationBoard(stationID: String) async throws -> StationBoard
}

protocol JourneyPlanningProvider: TrainProvider {
    func fetchJourneyPlans(
        from originStationID: String,
        to destinationStationID: String,
        departureDate: Date
    ) async throws -> [JourneyPlan]
}

struct StationBoard: Identifiable, Hashable, Sendable {
    let id: String
    let providerID: String
    let stationID: String
    let stationName: String
    let generatedAt: Date?
    let departures: [StationBoardDeparture]
    let sourceProvenance: SourceProvenance?

    init(
        id: String? = nil,
        providerID: String,
        stationID: String,
        stationName: String,
        generatedAt: Date? = Date(),
        departures: [StationBoardDeparture],
        sourceProvenance: SourceProvenance? = nil
    ) {
        self.id = id ?? "\(providerID):\(stationID)"
        self.providerID = providerID
        self.stationID = stationID
        self.stationName = stationName
        self.generatedAt = generatedAt
        self.departures = departures
        self.sourceProvenance = sourceProvenance
    }
}

struct StationBoardDeparture: Identifiable, Hashable, Sendable {
    let id: String
    let tripID: String?
    let trainName: String
    let destinationName: String
    let scheduledDeparture: String
    let estimatedDeparture: String?
    let platform: String?
    let status: String?

    init(
        id: String? = nil,
        tripID: String? = nil,
        trainName: String,
        destinationName: String,
        scheduledDeparture: String,
        estimatedDeparture: String? = nil,
        platform: String? = nil,
        status: String? = nil
    ) {
        self.id = id ?? [tripID, trainName, destinationName, scheduledDeparture].compactMap { $0 }.joined(separator: ":")
        self.tripID = tripID
        self.trainName = trainName
        self.destinationName = destinationName
        self.scheduledDeparture = scheduledDeparture
        self.estimatedDeparture = estimatedDeparture
        self.platform = platform
        self.status = status
    }
}

struct JourneyPlan: Identifiable, Hashable, Sendable {
    let id: String
    let providerID: String
    let originStationID: String
    let destinationStationID: String
    let departureTime: Date?
    let arrivalTime: Date?
    let legs: [JourneyLeg]
    let sourceProvenance: SourceProvenance?
}

struct JourneyLeg: Identifiable, Hashable, Sendable {
    let id: String
    let routeID: String?
    let trainName: String?
    let originStationID: String
    let destinationStationID: String
    let departureTime: Date?
    let arrivalTime: Date?
}
