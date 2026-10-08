import Combine
import Foundation

/// Drives station search on the Stations tab for whichever provider it is given.
@MainActor
final class StationDirectoryViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case results
        case noMatches
        case failed(StationDataFailure)
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

    private let provider: any StationDataProviding
    private let clock: RailClock
    private var scheduledSearch: Task<Void, Never>?
    private var freshnessTask: Task<Void, Never>?
    private var lastSuccessfulQuery = ""

    init(
        provider: any StationDataProviding,
        clock: RailClock = .system,
        initialPhase: Phase = .idle
    ) {
        self.provider = provider
        self.clock = clock
        phase = initialPhase
    }

    deinit {
        scheduledSearch?.cancel()
        freshnessTask?.cancel()
    }

    /// Station names the provider offers as one-tap searches.
    var suggestedSearches: [String] {
        provider.suggestedSearches
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
            // A search the rider replaced is cancelled, and its error is not a failure to show.
            guard !Task.isCancelled, cleanedQuery == cleanQuery else { return }
            let failure = StationDataFailure.resolve(error)
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
        sourceFreshness = sourceProvenance?.resolvedFreshness(at: clock.now) ?? .unknown
        if sourceFreshness.isOutsideFreshWindow {
            if notice == nil || notice == .stale { notice = .stale }
        } else if notice == .stale {
            notice = nil
        }
    }

    private func scheduleFreshnessRefresh() {
        freshnessTask?.cancel()
        guard let validUntil = sourceProvenance?.validUntil else { return }
        let delay = validUntil.timeIntervalSince(clock.now)
        guard delay > 0 else { return }
        freshnessTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refreshFreshnessForCurrentTime()
        }
    }

    private static func notice(for failure: StationDataFailure) -> Notice {
        switch failure {
        case .offline: return .offline
        case .rateLimited(let retryAfterSeconds): return .rateLimited(retryAfterSeconds: retryAfterSeconds)
        case .notConfigured, .unavailable: return .unavailable
        }
    }
}

extension FreshnessState {
    /// True once the proxy's fresh window has passed, whether or not a saved copy is still allowed.
    var isOutsideFreshWindow: Bool {
        self == .stale || self == .expired
    }
}
