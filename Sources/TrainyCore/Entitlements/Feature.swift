import Foundation

/// A feature that needs Trainy Plus.
///
/// This lists only gated features: anything not listed here is free. Add a case
/// here, and a line in `FeatureGate.isUnlocked(_:)`, to put another feature behind
/// Plus. Locking a feature never deletes the rider's data; it only stops new use.
enum Feature: String, CaseIterable, Sendable {
    /// Tracking more trips at once than `PlusConfiguration.freeTrackedTripLimit`.
    case unlimitedTrackedTrips
    case tripReminders
    case widgets
    case liveActivities
    case tripHistory
}

/// The one place that decides whether a `Feature` is available to the rider.
///
/// It is a plain value so it can be read anywhere, including from code that
/// cannot reach the main-actor `EntitlementStore`.
struct FeatureGate: Equatable, Sendable {
    let entitlement: EntitlementState
    let configuration: PlusConfiguration

    func isUnlocked(_ feature: Feature) -> Bool {
        guard configuration.enforcesFeatureGates else { return true }
        switch feature {
        case .unlimitedTrackedTrips, .tripReminders, .widgets, .liveActivities, .tripHistory:
            return entitlement.isPlus
        }
    }

    /// Whether the rider may start tracking one more trip.
    ///
    /// A rider whose Plus lapsed can be over the free limit. Their tracked trips
    /// stay, and they simply cannot add more until they are back under the limit.
    func canTrackAnotherTrip(currentCount: Int) -> Bool {
        isUnlocked(.unlimitedTrackedTrips) || currentCount < configuration.freeTrackedTripLimit
    }
}
