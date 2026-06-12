import Foundation

@MainActor
final class TrainStore: ObservableObject {
    enum LiveLoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty(String)
        case offline(String)

        var label: String {
            switch self {
            case .idle:
                return "Ready"
            case .loading:
                return "Updating"
            case .loaded:
                return "Live"
            case .empty:
                return "Saved"
            case .offline:
                return "Offline"
            }
        }
    }

    @Published var trips: [TrainTrip]
    @Published var selectedTripID: TrainTrip.ID
    @Published var query = ""
    @Published var filter: TripFilter = .all
    @Published private(set) var notifiedIDs: Set<TrainTrip.ID>
    @Published private(set) var pinnedIDs: Set<TrainTrip.ID>
    @Published private(set) var liveRoutes: [LiveTrainRoute] = []
    @Published private(set) var liveResults: [TrainTrip] = []
    @Published private(set) var liveLoadState: LiveLoadState = .idle
    @Published private(set) var lastLiveRefresh: Date?

    private let defaults: UserDefaults
    private let provider: ShinkansenTrainProvider
    private let catalog: [TrainTrip]
    private var hasBootstrapped = false
    private var hasSavedPayload = false

    init(defaults: UserDefaults = .standard, provider: ShinkansenTrainProvider = ShinkansenTrainProvider()) {
        self.defaults = defaults
        self.provider = provider
        let fullCatalog = provider.catalog
        self.catalog = fullCatalog
        let catalogIDs = Set(fullCatalog.map(\.id))
        let isCurrentDataScope = defaults.string(forKey: DefaultsKey.dataScope) == provider.dataScope
        let storedSelectedTripID = defaults.string(forKey: DefaultsKey.selectedTripID)

        let initialTrips: [TrainTrip]
        if
            isCurrentDataScope,
            let storedTrips = Self.decodeTrips(from: defaults.data(forKey: DefaultsKey.trackedTripsPayload))?.filter({ catalogIDs.contains($0.id) || $0.providerID == provider.providerID }),
            !storedTrips.isEmpty
        {
            initialTrips = storedTrips
            self.hasSavedPayload = true
        } else {
            let storedIDs = isCurrentDataScope ? defaults.stringArray(forKey: DefaultsKey.trackedTripIDs) : nil
            let defaultIDs = provider.defaultTrips.map(\.id)
            let trackedIDs = storedIDs?.isEmpty == false ? storedIDs ?? defaultIDs : defaultIDs
            let resolvedTrips = trackedIDs.compactMap { id in fullCatalog.first { $0.id == id } }
            initialTrips = resolvedTrips.isEmpty ? provider.defaultTrips : resolvedTrips
        }
        self.trips = initialTrips

        if let storedSelectedTripID, initialTrips.contains(where: { $0.id == storedSelectedTripID }) {
            self.selectedTripID = storedSelectedTripID
        } else {
            self.selectedTripID = initialTrips[0].id
        }

        self.notifiedIDs = Set(defaults.stringArray(forKey: DefaultsKey.notifiedIDs) ?? [])
        self.pinnedIDs = Set(defaults.stringArray(forKey: DefaultsKey.pinnedIDs) ?? [])
    }

    var selectedTrip: TrainTrip {
        trips.first { $0.id == selectedTripID } ?? trips[0]
    }

    var discoveryTrips: [TrainTrip] {
        catalog.filter { candidate in
            !trips.contains { $0.id == candidate.id }
        }
    }

    var searchableResults: [TrainTrip] {
        let live = liveResults.filter { candidate in
            !trips.contains { $0.id == candidate.id }
        }
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider.isODPTConfigured && !cleanQuery.isEmpty {
            return live
        }
        return live + discoveryResults(matching: query)
    }

    var filteredTrips: [TrainTrip] {
        trips.filter { trip in
            let filterMatch = filter == .all || trip.category == filter
            let queryMatch = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || searchableText(for: trip).localizedCaseInsensitiveContains(query)
            return filterMatch && queryMatch
        }
    }

    var watchedPlatformCount: Int {
        Set(trips.map(\.platform)).count
    }

    var riskCount: Int {
        trips.filter { $0.statusTone != .good }.count
    }

    var shareSummary: String {
        "\(selectedTrip.train): \(selectedTrip.origin.name) to \(selectedTrip.destination.name), \(selectedTrip.status), platform \(selectedTrip.platform), ETA \(selectedTrip.eta)."
    }

    var liveStatusText: String {
        switch liveLoadState {
        case .idle:
            return "Ready for live search"
        case .loading:
            return provider.isODPTConfigured ? "Refreshing ODPT Shinkansen data" : "Refreshing Japan Shinkansen data"
        case .loaded:
            if let lastLiveRefresh {
                return "\(provider.feedLabel) · updated \(Self.relativeTime(from: lastLiveRefresh))"
            }
            return "\(provider.feedLabel) ready"
        case .empty(let message):
            return "Saved live trip · \(message)"
        case .offline(let message):
            return "Saved trip available · \(message)"
        }
    }

    func bootstrapLiveData() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await loadLiveRoutes()
        await searchLiveTrips(matching: "Tokyo")

        guard !hasSavedPayload, !liveResults.isEmpty else { return }
        let initialLiveTrips = Array(liveResults.prefix(3))
        let fallbackSamples = provider.defaultTrips.filter { sample in
            !initialLiveTrips.contains { $0.id == sample.id }
        }
        trips = initialLiveTrips + fallbackSamples.prefix(2)
        selectedTripID = trips[0].id
        persistTrackedTrips()
    }

    func loadLiveRoutes() async {
        guard liveRoutes.isEmpty else { return }
        liveLoadState = .loading
        do {
            liveRoutes = try await provider.fetchRoutes()
            liveLoadState = .loaded
            lastLiveRefresh = Date()
        } catch {
            liveLoadState = .offline(error.localizedDescription)
        }
    }

    func searchLiveTrips(matching query: String) async {
        await loadLiveRoutes()
        liveLoadState = .loading
        do {
            liveResults = try await provider.fetchTrips(matching: query, knownRoutes: liveRoutes)
            liveLoadState = .loaded
            lastLiveRefresh = Date()
        } catch TrainDataProviderError.noLiveTrips {
            liveResults = []
            liveLoadState = .empty("no new departures for this search")
        } catch {
            liveResults = []
            liveLoadState = .offline(error.localizedDescription)
        }
    }

    func refreshSelectedTrip() {
        let trip = selectedTrip
        guard trip.providerID == provider.providerID else {
            refreshSampleTrip()
            return
        }

        liveLoadState = .loading
        Task {
            do {
                if let refreshedTrip = try await provider.refresh(trip, knownRoutes: liveRoutes) {
                    applyRefreshedTrip(refreshedTrip, replacing: trip)
                    liveLoadState = .loaded
                    lastLiveRefresh = Date()
                } else {
                    refreshSampleTrip()
                    liveLoadState = .loaded
                }
            } catch {
                liveLoadState = .offline(error.localizedDescription)
            }
        }
    }

    func select(_ trip: TrainTrip) {
        selectedTripID = trip.id
        defaults.set(trip.id, forKey: DefaultsKey.selectedTripID)
    }

    func discoveryResults(matching query: String) -> [TrainTrip] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return discoveryTrips }
        return discoveryTrips.filter { searchableText(for: $0).localizedCaseInsensitiveContains(cleanQuery) }
    }

    func track(_ trip: TrainTrip) {
        guard !trips.contains(where: { $0.id == trip.id }) else {
            select(trip)
            return
        }
        trips.insert(trip, at: 0)
        persistTrackedTrips()
        select(trip)
    }

    func toggleNotification(for trip: TrainTrip) {
        if notifiedIDs.contains(trip.id) {
            notifiedIDs.remove(trip.id)
        } else {
            notifiedIDs.insert(trip.id)
        }
        defaults.set(Array(notifiedIDs), forKey: DefaultsKey.notifiedIDs)
    }

    func togglePin(for trip: TrainTrip) {
        if pinnedIDs.contains(trip.id) {
            pinnedIDs.remove(trip.id)
        } else {
            pinnedIDs.insert(trip.id)
        }
        defaults.set(Array(pinnedIDs), forKey: DefaultsKey.pinnedIDs)
    }

    func isNotified(_ trip: TrainTrip) -> Bool {
        notifiedIDs.contains(trip.id)
    }

    func isPinned(_ trip: TrainTrip) -> Bool {
        pinnedIDs.contains(trip.id)
    }

    private func applyRefreshedTrip(_ refreshedTrip: TrainTrip, replacing oldTrip: TrainTrip) {
        if let index = trips.firstIndex(where: { $0.id == oldTrip.id }) {
            trips[index] = refreshedTrip
        } else {
            trips.insert(refreshedTrip, at: 0)
        }
        selectedTripID = refreshedTrip.id
        persistTrackedTrips()
    }

    private func refreshSampleTrip() {
        guard let index = trips.firstIndex(where: { $0.id == selectedTripID }) else { return }
        trips[index].updated = "just now"
        trips[index].progress = min(trips[index].progress + 0.01, 0.99)
        persistTrackedTrips()
    }

    private func searchableText(for trip: TrainTrip) -> String {
        [
            trip.train,
            trip.operatorName,
            trip.service,
            trip.origin.name,
            trip.destination.name,
            trip.nextStop,
            trip.status,
            trip.dataSource ?? ""
        ].joined(separator: " ")
    }

    private func persistTrackedTrips() {
        defaults.set(trips.map(\.id), forKey: DefaultsKey.trackedTripIDs)
        defaults.set(selectedTripID, forKey: DefaultsKey.selectedTripID)
        defaults.set(provider.dataScope, forKey: DefaultsKey.dataScope)
        if let data = try? JSONEncoder().encode(trips) {
            defaults.set(data, forKey: DefaultsKey.trackedTripsPayload)
        }
    }

    private static func decodeTrips(from data: Data?) -> [TrainTrip]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([TrainTrip].self, from: data)
    }

    private static func relativeTime(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 {
            return "\(seconds)s ago"
        }
        return "\(seconds / 60)m ago"
    }
}

private enum DefaultsKey {
    static let dataScope = "trainy.dataScope"
    static let trackedTripIDs = "trainy.trackedTripIDs"
    static let trackedTripsPayload = "trainy.trackedTripsPayload"
    static let selectedTripID = "trainy.selectedTripID"
    static let notifiedIDs = "trainy.notifiedIDs"
    static let pinnedIDs = "trainy.pinnedIDs"
}
