import Combine
import Foundation

/// Loads one station's departure board and service alerts, and keeps both
/// current while the board is on screen.
///
/// `load()` is a single requested refresh (first appearance, pull to refresh,
/// Try again). `keepFresh()` is the cadence: it loads when the board is due and
/// sleeps until the next refresh, following `StationBoardRefreshPolicy`. The
/// view runs it from a task tied to the screen and the scene phase, so
/// cancelling that task is how refreshing pauses.
@MainActor
final class StationBoardViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(StationDataFailure)
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
        case failed(StationDataFailure)
    }

    private enum AlertLoadResult: Sendable {
        case success(ServiceAlertPage)
        case failure(StationDataFailure)
    }

    private enum LoadResult: Sendable {
        case boardSuccess(StationBoard)
        case boardFailure(StationDataFailure)
        case alerts(AlertLoadResult)
    }

    /// Who started a load. Requested loads show placeholders and announce their
    /// result; scheduled loads refresh in place without either.
    private enum LoadReason {
        case requested
        case scheduled
    }

    private enum LoadEnding {
        /// Both responses were handled. Carries the failure that decides the next wait, if any.
        case completed(failure: StationDataFailure?)
        /// A newer load started and owns the result and the schedule.
        case superseded
        /// The caller's task was cancelled. Nothing arriving after that was applied.
        case cancelled
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
    /// When the next scheduled refresh is due. Nil before the first load and
    /// once refreshing has stopped.
    private(set) var nextRefreshAt: Date?
    /// Refreshes in a row that were not fresh, counting the latest one.
    private(set) var consecutiveSetbacks = 0
    /// True once the provider reported that asking again cannot help, such as
    /// an unconfigured build.
    private(set) var refreshStopped = false

    private let provider: any StationDataProviding
    private let clock: RailClock
    private let refreshPolicy: StationBoardRefreshPolicy
    private let refreshSleep: @Sendable (Duration) async throws -> Void
    private var freshnessTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var keepFreshDepth = 0

    init(
        station: ProviderStation,
        provider: any StationDataProviding,
        clock: RailClock = .system,
        refreshPolicy: StationBoardRefreshPolicy = .standard,
        refreshSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.station = station
        self.provider = provider
        self.clock = clock
        self.refreshPolicy = refreshPolicy
        self.refreshSleep = refreshSleep
    }

    deinit {
        freshnessTask?.cancel()
    }

    var providerName: String {
        provider.displayName
    }

    /// Loads the board and alerts once, as a requested refresh.
    func load() async {
        await performLoad(reason: .requested)
    }

    func retry() {
        Task { await load() }
    }

    /// Keeps the board current until the calling task is cancelled or the
    /// provider reports that refreshing cannot help.
    ///
    /// Loads right away when nothing has loaded yet or the next refresh is
    /// already due, which is what makes returning from the background refresh
    /// at once. Otherwise it sleeps until the next refresh is due. A refresh
    /// requested in the meantime moves that time, so a pull to refresh is not
    /// followed by a scheduled one a moment later.
    func keepFresh() async {
        keepFreshDepth += 1
        refreshFreshnessForCurrentTime()
        scheduleFreshnessRefresh()
        defer {
            keepFreshDepth -= 1
            refreshFreshnessForCurrentTime()
            scheduleFreshnessRefresh()
        }

        while !Task.isCancelled && !refreshStopped {
            let current = clock.now
            guard phase != .idle, let due = nextRefreshAt, due > current else {
                await performLoad(reason: phase == .idle ? .requested : .scheduled)
                continue
            }
            do {
                try await refreshSleep(.seconds(due.timeIntervalSince(current)))
            } catch {
                return
            }
        }
    }

    @discardableResult
    private func performLoad(reason: LoadReason) async -> LoadEnding {
        loadGeneration &+= 1
        let generation = loadGeneration
        let announcing = reason == .requested
        if announcing {
            if board == nil { phase = .loading }
            if alertSourceProvenance == nil { alertPhase = .loading }
            notice = nil
            alertNotice = nil
        }
        // A load that never finishes still leaves a next attempt behind. A cancelled one puts back the
        // schedule it replaced, so the board counts as due as soon as refreshing resumes.
        let scheduleBeforeLoad = nextRefreshAt
        nextRefreshAt = clock.now.addingTimeInterval(refreshPolicy.interval)

        let provider = provider
        let stationCode = station.code
        let ending = await withTaskGroup(of: LoadResult.self, returning: LoadEnding.self) { group in
            group.addTask {
                do {
                    return .boardSuccess(try await provider.fetchStationBoard(stationID: stationCode))
                } catch {
                    return .boardFailure(StationDataFailure.resolve(error))
                }
            }
            group.addTask {
                do {
                    return .alerts(.success(try await provider.fetchServiceAlerts(stationID: stationCode)))
                } catch {
                    return .alerts(.failure(StationDataFailure.resolve(error)))
                }
            }

            var boardFailure: StationDataFailure?
            var alertFailure: StationDataFailure?
            for await result in group {
                guard generation == loadGeneration else {
                    group.cancelAll()
                    return .superseded
                }
                // A cancelled request reports as a failure. It is not one, so drop it.
                guard !Task.isCancelled else {
                    group.cancelAll()
                    return .cancelled
                }

                switch result {
                case .boardSuccess(let loadedBoard):
                    apply(loadedBoard, announcing: announcing)
                case .boardFailure(let failure):
                    boardFailure = failure
                    applyBoardFailure(failure, announcing: announcing)
                case .alerts(let alertResult):
                    if case .failure(let failure) = alertResult { alertFailure = failure }
                    apply(alertResult)
                }
                refreshFreshnessForCurrentTime()
                scheduleFreshnessRefresh()
            }
            return .completed(failure: boardFailure ?? alertFailure)
        }

        switch ending {
        case .completed(let failure):
            scheduleNextRefresh(after: failure)
        case .cancelled:
            // Nothing is loading any more, and nothing arrived: let the next appearance load again.
            nextRefreshAt = scheduleBeforeLoad
            if phase == .loading { phase = .idle }
            if alertPhase == .loading { alertPhase = .idle }
        case .superseded:
            break
        }
        return ending
    }

    /// Reads the clock after the responses arrived, so the wait counts from when
    /// the board was actually refreshed.
    private func scheduleNextRefresh(after failure: StationDataFailure?) {
        let outcome: StationBoardRefreshPolicy.Outcome
        if let failure {
            outcome = .failed(failure)
        } else if board?.sourceProvenance?.freshness == .stale || alertSourceProvenance?.freshness == .stale {
            outcome = .degraded
        } else {
            outcome = .fresh
        }
        consecutiveSetbacks = outcome == .fresh ? 0 : consecutiveSetbacks + 1

        if let delay = refreshPolicy.delay(after: outcome, consecutiveSetbacks: consecutiveSetbacks) {
            nextRefreshAt = clock.now.addingTimeInterval(delay)
            refreshStopped = false
        } else {
            nextRefreshAt = nil
            refreshStopped = true
        }
    }

    func refreshFreshnessForCurrentTime() {
        let reference = freshnessReference
        boardFreshness = board?.sourceProvenance?.resolvedFreshness(at: reference) ?? .unknown
        if boardFreshness.isOutsideFreshWindow {
            if notice == nil || notice == .stale { notice = .stale }
        } else if notice == .stale {
            notice = nil
        }

        alertFreshness = alertSourceProvenance?.resolvedFreshness(at: reference) ?? .unknown
        if alertFreshness.isOutsideFreshWindow {
            if alertNotice == nil || alertNotice == .stale { alertNotice = .stale }
        } else if alertNotice == .stale {
            alertNotice = nil
        }
    }

    /// While the board refreshes itself, the proxy's fresh window is shorter
    /// than the refresh interval, so a board is still labelled fresh for the
    /// policy's grace period after that window closes. A board that is not
    /// being refreshed gets no grace.
    private var freshnessGrace: TimeInterval {
        keepFreshDepth > 0 ? refreshPolicy.freshnessGrace : 0
    }

    private var freshnessReference: Date {
        clock.now.addingTimeInterval(-freshnessGrace)
    }

    private func apply(_ loadedBoard: StationBoard, announcing: Bool) {
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
        notice = nil
        guard announcing else { return }

        let freshness = loadedBoard.sourceProvenance?.resolvedFreshness(at: freshnessReference) ?? .unknown
        let freshnessMessage = freshness.isOutsideFreshWindow
            ? " Saved data is outside its fresh window."
            : ""
        accessibilityAnnouncement = loadedBoard.departures.isEmpty
            ? "No departures were present in the NS response for \(station.name).\(freshnessMessage)"
            : "\(loadedBoard.departures.count) NS departures loaded for \(station.name).\(freshnessMessage)"
    }

    private func applyBoardFailure(_ failure: StationDataFailure, announcing: Bool) {
        if board != nil {
            notice = Self.notice(for: failure)
        } else {
            phase = .failed(failure)
        }
        if announcing { accessibilityAnnouncement = failure.message }
    }

    private func apply(_ result: AlertLoadResult) {
        switch result {
        case .success(let page):
            alerts = page.alerts
            alertSourceProvenance = page.sourceProvenance
            alertPhase = page.alerts.isEmpty ? .empty : .loaded
            alertNotice = nil
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
        let currentTime = clock.now
        let grace = freshnessGrace
        let deadlines = [
            board?.sourceProvenance?.validUntil,
            alertSourceProvenance?.validUntil
        ].compactMap { $0?.addingTimeInterval(grace) }.filter { $0 > currentTime }
        guard let nextDeadline = deadlines.min() else { return }
        freshnessTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(nextDeadline.timeIntervalSince(currentTime)))
            guard !Task.isCancelled else { return }
            self?.refreshFreshnessForCurrentTime()
            self?.scheduleFreshnessRefresh()
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
