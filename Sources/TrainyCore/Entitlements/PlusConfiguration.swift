import Foundation

/// Everything the app needs to know about the paid Plus tier, in one place.
///
/// `current` is the only place that names the App Store Connect product, so
/// settling the pricing decision changes this file and nothing else. Tests and
/// previews build their own configuration instead of reading `current`.
struct PlusConfiguration: Equatable, Sendable {
    /// App Store Connect product identifiers that grant Plus, in the order a
    /// paywall should list them.
    let productIDs: [String]

    /// Whether `FeatureGate` locks Plus features for riders who do not have Plus.
    ///
    /// Stays `false` until Plus can actually be bought, so no call site can lock a
    /// rider out of a feature while there is no way to unlock it.
    let enforcesFeatureGates: Bool

    /// How many trips a rider without Plus can track at once.
    let freeTrackedTripLimit: Int

    /// The configuration the app ships with.
    ///
    /// Both values below are placeholders until the pricing decision is made.
    /// Product identifiers are permanent once the product exists in App Store
    /// Connect, so settle the name before creating it there.
    static let current = PlusConfiguration(
        productIDs: ["com.jacobcyber.Trainy.plus"],
        enforcesFeatureGates: false,
        freeTrackedTripLimit: 3
    )
}
