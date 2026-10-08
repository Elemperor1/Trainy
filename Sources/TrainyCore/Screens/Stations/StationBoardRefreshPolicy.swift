import Foundation

/// Decides how long an open station board waits before it asks again.
///
/// The cadence is set against Trainy's provider proxy, which caches NS
/// departures for 20 seconds and spends a shared upstream budget (240 requests
/// per rolling five minutes, across every rider) only on cache misses. One board
/// polling every 30 seconds costs at most two upstream departure requests a
/// minute, and the disruptions feed is cached for 60 seconds across all
/// stations, so a few open boards stay far inside that budget. Failures back
/// off exponentially, and a `Retry-After` from the proxy is honoured as a floor.
///
/// The policy is pure: tests pin every row of it without a clock.
struct StationBoardRefreshPolicy: Equatable, Sendable {
    /// What the last refresh told us about the data.
    enum Outcome: Equatable, Sendable {
        /// Both responses arrived inside the proxy's fresh window.
        case fresh
        /// The proxy answered, but from its saved fallback copy. That copy only
        /// exists because the upstream request failed, so back off like a failure.
        case degraded
        /// A request failed outright.
        case failed(StationDataFailure)
    }

    /// Seconds between refreshes while every response is fresh.
    var interval: TimeInterval = 30
    /// Seconds past the proxy's fresh window during which an open, self-refreshing
    /// board is still labelled fresh. The proxy window (20 s) is shorter than the
    /// refresh interval, so without this the label would flip to stale for part
    /// of every cycle.
    var freshnessGrace: TimeInterval = 40
    /// Longest wait after a failed or saved-copy refresh.
    var failureCeiling: TimeInterval = 120
    /// Longest wait after the proxy reports it is busy.
    var rateLimitCeiling: TimeInterval = 300
    /// Wait used when a busy response carries no `Retry-After`.
    var rateLimitFallback: TimeInterval = 60

    static let standard = StationBoardRefreshPolicy()

    /// Seconds to wait before the next refresh, or nil when asking again cannot help.
    ///
    /// - Parameters:
    ///   - outcome: How the refresh that just finished went.
    ///   - consecutiveSetbacks: Refreshes in a row that were not fresh, counting this one.
    func delay(after outcome: Outcome, consecutiveSetbacks: Int) -> TimeInterval? {
        switch outcome {
        case .fresh:
            return interval
        case .degraded:
            return backoff(consecutiveSetbacks, ceiling: failureCeiling)
        case .failed(let failure):
            switch failure {
            case .notConfigured:
                return nil
            case .offline, .unavailable:
                return backoff(consecutiveSetbacks, ceiling: failureCeiling)
            case .rateLimited(let retryAfterSeconds):
                let advised = retryAfterSeconds.map { TimeInterval($0) } ?? rateLimitFallback
                let backedOff = backoff(consecutiveSetbacks, ceiling: rateLimitCeiling)
                return min(rateLimitCeiling, max(backedOff, advised))
            }
        }
    }

    private func backoff(_ consecutiveSetbacks: Int, ceiling: TimeInterval) -> TimeInterval {
        let doublings = Double(max(0, consecutiveSetbacks - 1))
        return min(ceiling, interval * pow(2, doublings))
    }
}
