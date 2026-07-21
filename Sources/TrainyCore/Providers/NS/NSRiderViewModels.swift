import Combine
import Foundation

protocol NSRiderDataProviding: Sendable {
    func searchStations(matching query: String, limit: Int) async throws -> StationSearchPage
    func fetchStationBoard(stationID: String) async throws -> StationBoard
    func fetchServiceAlerts(stationID: String?) async throws -> ServiceAlertPage
}

extension NSTrainProvider: NSRiderDataProviding {}

enum NSRiderFailure: Equatable, Sendable {
    case notConfigured
    case offline
    case rateLimited(retryAfterSeconds: Int?)
    case unavailable

    static func resolve(_ error: Error) -> NSRiderFailure {
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

@MainActor
final class NSStationSearchViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case results
        case noMatches
        case failed(NSRiderFailure)
    }

    enum Notice: Equatable {
        case stale
        case offline
        case rateLimited(retryAfterSeconds: Int?)
        case unavailable
    }

    @Published var query = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var notice: Notice?
    @Published private(set) var stations: [ProviderStation] = []
    @Published private(set) var sourceProvenance: SourceProvenance?
    @Published private(set) var sourceFreshness: FreshnessState = .unknown
    @Published private(set) var accessibilityAnnouncement = ""

    let suggestedSearches = [
        "Utrecht Centraal",
        "Amsterdam Centraal",
        "Rotterdam Centraal",
        "Schiphol Airport"
    ]

    private let provider: any NSRiderDataProviding
    private let now: @Sendable () -> Date
    private var scheduledSearch: Task<Void, Never>?
    private var freshnessTask: Task<Void, Never>?
    private var lastSuccessfulQuery = ""

    init(
        provider: any NSRiderDataProviding,
        now: @escaping @Sendable () -> Date = Date.init,
        initialPhase: Phase = .idle
    ) {
        self.provider = provider
        self.now = now
        phase = initialPhase
    }

    deinit {
        scheduledSearch?.cancel()
        freshnessTask?.cancel()
    }

    func useSuggestion(_ suggestion: String) {
        query = suggestion
        submitSearch()
    }

    func scheduleSearch() {
        scheduledSearch?.cancel()
        let expectedQuery = cleanedQuery
        guard expectedQuery.count >= 2 else {
            stations = []
            sourceProvenance = nil
            sourceFreshness = .unknown
            notice = nil
            phase = .idle
            freshnessTask?.cancel()
            return
        }
        scheduledSearch = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, self.cleanedQuery == expectedQuery else { return }
            await self.search(expectedQuery)
        }
    }

    func submitSearch() {
        scheduledSearch?.cancel()
        let expectedQuery = cleanedQuery
        guard expectedQuery.count >= 2 else { return }
        scheduledSearch = Task { [weak self] in
            await self?.search(expectedQuery)
        }
    }

    func retry() {
        submitSearch()
    }

    func search(_ expectedQuery: String? = nil) async {
        let cleanQuery = expectedQuery ?? cleanedQuery
        guard cleanQuery.count >= 2 else { return }
        phase = .loading
        notice = nil

        do {
            let page = try await provider.searchStations(matching: cleanQuery, limit: 20)
            guard cleanedQuery == cleanQuery else { return }
            stations = page.stations
            sourceProvenance = page.sourceProvenance
            lastSuccessfulQuery = cleanQuery
            notice = nil
            refreshFreshnessForCurrentTime()
            scheduleFreshnessRefresh()
            if stations.isEmpty {
                phase = .noMatches
                accessibilityAnnouncement = "No NS stations matched \(cleanQuery)."
            } else {
                phase = .results
                accessibilityAnnouncement = "\(stations.count) NS stations found."
            }
        } catch {
            guard cleanedQuery == cleanQuery else { return }
            let failure = NSRiderFailure.resolve(error)
            if lastSuccessfulQuery == cleanQuery, !stations.isEmpty {
                notice = Self.notice(for: failure)
                phase = .results
            } else {
                stations = []
                sourceProvenance = nil
                phase = .failed(failure)
            }
            accessibilityAnnouncement = failure.message
        }
    }

    private var cleanedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func refreshFreshnessForCurrentTime() {
        sourceFreshness = sourceProvenance?.resolvedFreshness(at: now()) ?? .unknown
        if sourceFreshness.isOutsideFreshWindow {
            if notice == nil || notice == .stale { notice = .stale }
        } else if notice == .stale {
            notice = nil
        }
    }

    private func scheduleFreshnessRefresh() {
        freshnessTask?.cancel()
        guard let validUntil = sourceProvenance?.validUntil else { return }
        let delay = validUntil.timeIntervalSince(now())
        guard delay > 0 else { return }
        freshnessTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refreshFreshnessForCurrentTime()
        }
    }

    private static func notice(for failure: NSRiderFailure) -> Notice {
        switch failure {
        case .offline: return .offline
        case .rateLimited(let retryAfterSeconds): return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        case .notConfigured, .unavailable: return .unavailable
        }
    }
}

@MainActor
final class NSDepartureBoardViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(NSRiderFailure)
    }

    enum Notice: Equatable {
        case stale
        case offline
        case rateLimited(retryAfterSeconds: Int?)
        case unavailable
    }

    enum AlertPhase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(NSRiderFailure)
    }

    private enum AlertLoadResult: Sendable {
        case success(ServiceAlertPage)
        case failure(NSRiderFailure)
    }

    private enum LoadResult: Sendable {
        case boardSuccess(StationBoard)
        case boardFailure(NSRiderFailure)
        case alerts(AlertLoadResult)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var notice: Notice?
    @Published private(set) var board: StationBoard?
    @Published private(set) var boardFreshness: FreshnessState = .unknown
    @Published private(set) var alerts: [TrainAlert] = []
    @Published private(set) var alertPhase: AlertPhase = .idle
    @Published private(set) var alertNotice: Notice?
    @Published private(set) var alertSourceProvenance: SourceProvenance?
    @Published private(set) var alertFreshness: FreshnessState = .unknown
    @Published private(set) var accessibilityAnnouncement = ""

    let station: ProviderStation
    private let provider: any NSRiderDataProviding
    private let now: @Sendable () -> Date
    private var freshnessTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(
        station: ProviderStation,
        provider: any NSRiderDataProviding,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.station = station
        self.provider = provider
        self.now = now
    }

    deinit {
        freshnessTask?.cancel()
    }

    func load() async {
        loadGeneration &+= 1
        let generation = loadGeneration
        if board == nil { phase = .loading }
        if alertSourceProvenance == nil { alertPhase = .loading }
        notice = nil
        alertNotice = nil

        let provider = provider
        let stationCode = station.code
        await withTaskGroup(of: LoadResult.self) { group in
            group.addTask {
                do {
                    return .boardSuccess(try await provider.fetchStationBoard(stationID: stationCode))
                } catch {
                    return .boardFailure(NSRiderFailure.resolve(error))
                }
            }
            group.addTask {
                do {
                    return .alerts(.success(try await provider.fetchServiceAlerts(stationID: stationCode)))
                } catch {
                    return .alerts(.failure(NSRiderFailure.resolve(error)))
                }
            }

            for await result in group {
                guard generation == loadGeneration else {
                    group.cancelAll()
                    return
                }

                switch result {
                case .boardSuccess(let loadedBoard):
                    apply(loadedBoard)
                case .boardFailure(let failure):
                    applyBoardFailure(failure)
                case .alerts(let alertResult):
                    apply(alertResult)
                }
                refreshFreshnessForCurrentTime()
                scheduleFreshnessRefresh()
            }
        }
    }

    func retry() {
        Task { await load() }
    }

    func refreshFreshnessForCurrentTime() {
        boardFreshness = board?.sourceProvenance?.resolvedFreshness(at: now()) ?? .unknown
        if boardFreshness.isOutsideFreshWindow {
            if notice == nil || notice == .stale { notice = .stale }
        } else if notice == .stale {
            notice = nil
        }

        alertFreshness = alertSourceProvenance?.resolvedFreshness(at: now()) ?? .unknown
        if alertFreshness.isOutsideFreshWindow {
            if alertNotice == nil || alertNotice == .stale { alertNotice = .stale }
        } else if alertNotice == .stale {
            alertNotice = nil
        }
    }

    private func apply(_ loadedBoard: StationBoard) {
        board = StationBoard(
            id: loadedBoard.id,
            providerID: loadedBoard.providerID,
            stationID: loadedBoard.stationID,
            stationName: station.name,
            generatedAt: loadedBoard.generatedAt,
            departures: loadedBoard.departures,
            sourceProvenance: loadedBoard.sourceProvenance
        )
        phase = loadedBoard.departures.isEmpty ? .empty : .loaded
        let freshness = loadedBoard.sourceProvenance?.resolvedFreshness(at: now()) ?? .unknown
        let freshnessMessage = freshness.isOutsideFreshWindow
            ? " Saved data is outside its fresh window."
            : ""
        accessibilityAnnouncement = loadedBoard.departures.isEmpty
            ? "No departures were present in the NS response for \(station.name).\(freshnessMessage)"
            : "\(loadedBoard.departures.count) NS departures loaded for \(station.name).\(freshnessMessage)"
    }

    private func applyBoardFailure(_ failure: NSRiderFailure) {
        if board != nil {
            notice = Self.notice(for: failure)
        } else {
            phase = .failed(failure)
        }
        accessibilityAnnouncement = failure.message
    }

    private func apply(_ result: AlertLoadResult) {
        switch result {
        case .success(let page):
            alerts = page.alerts
            alertSourceProvenance = page.sourceProvenance
            alertPhase = page.alerts.isEmpty ? .empty : .loaded
        case .failure(let failure):
            if alertSourceProvenance != nil {
                alertPhase = alerts.isEmpty ? .empty : .loaded
                alertNotice = Self.notice(for: failure)
            } else {
                alerts = []
                alertPhase = .failed(failure)
            }
        }
    }

    private func scheduleFreshnessRefresh() {
        freshnessTask?.cancel()
        let currentTime = now()
        let deadlines = [
            board?.sourceProvenance?.validUntil,
            alertSourceProvenance?.validUntil
        ].compactMap { $0 }.filter { $0 > currentTime }
        guard let nextDeadline = deadlines.min() else { return }
        freshnessTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(nextDeadline.timeIntervalSince(currentTime)))
            guard !Task.isCancelled else { return }
            self?.refreshFreshnessForCurrentTime()
            self?.scheduleFreshnessRefresh()
        }
    }

    private static func notice(for failure: NSRiderFailure) -> Notice {
        switch failure {
        case .offline: return .offline
        case .rateLimited(let retryAfterSeconds): return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        case .notConfigured, .unavailable: return .unavailable
        }
    }
}

private extension FreshnessState {
    var isOutsideFreshWindow: Bool {
        self == .stale || self == .expired
    }
}
