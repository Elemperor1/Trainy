import Foundation

/// The StoreKit-shaped seam behind `EntitlementStore`.
///
/// `StoreKitEntitlementService` is the real implementation. Everything else, such
/// as unit tests, previews, and Debug UI automation, uses `FakeEntitlementService`.
/// Methods throw `EntitlementError` and report only verified transactions.
protocol EntitlementService: Sendable {
    /// Loads the products the App Store is currently offering, in the order of
    /// `productIDs`. Identifiers the App Store does not know are left out.
    func loadOffers(productIDs: [String]) async throws -> [PlusOffer]

    /// Buys a product previously returned by `loadOffers`.
    func purchase(productID: String) async throws -> PurchaseOutcome

    /// Asks the App Store to re-sync the rider's purchases. This can show a
    /// sign-in prompt; if the rider dismisses it, it throws `.cancelled`.
    func syncPurchases() async throws

    /// Every verified transaction that currently entitles the rider.
    func currentGrants() async -> [EntitlementGrant]

    /// Emits the full set of current grants whenever the App Store reports a new
    /// or changed transaction: a renewal, a refund, an Ask to Buy approval, or a
    /// purchase made on another device. Call it once, as early in launch as
    /// possible, because StoreKit only delivers these transactions to a listener.
    func entitlementChanges() -> AsyncStream<[EntitlementGrant]>
}
