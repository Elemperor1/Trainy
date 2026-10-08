#if DEBUG
import Foundation

/// An in-memory `EntitlementService` for unit tests, previews, and Debug UI
/// automation.
///
/// As far as `EntitlementStore` can tell it behaves like StoreKit: a purchase adds
/// a grant, `emit(_:)` plays the part of `Transaction.updates`, and every call is
/// recorded so tests can assert on it.
@MainActor
final class FakeEntitlementService: EntitlementService {
    /// Every product the fake App Store knows. `loadOffers` returns the requested ones.
    var offers: [PlusOffer]
    var loadOffersError: EntitlementError?
    var purchaseOutcome: PurchaseOutcome = .purchased
    var purchaseError: EntitlementError?
    var syncError: EntitlementError?
    /// When a purchase succeeds, the grant it adds expires after this long, or never if `nil`.
    var purchasedGrantLifetime: TimeInterval? = 30 * 24 * 60 * 60

    /// Suspends the next `currentGrants()` call after it has taken its snapshot,
    /// until `releaseHeldRead()`. This is how a test makes a read slow.
    var holdsNextGrantsRead = false

    private(set) var grants: [EntitlementGrant]
    private(set) var loadOffersRequests: [[String]] = []
    private(set) var purchaseRequests: [String] = []
    private(set) var syncCount = 0
    private(set) var currentGrantsCount = 0

    private let clock: RailClock
    private var heldRead: CheckedContinuation<Void, Never>?
    nonisolated private let changes: AsyncStream<[EntitlementGrant]>
    nonisolated private let changesContinuation: AsyncStream<[EntitlementGrant]>.Continuation

    init(
        offers: [PlusOffer] = [FakeEntitlementService.sampleOffer()],
        grants: [EntitlementGrant] = [],
        clock: RailClock = .system
    ) {
        self.offers = offers
        self.grants = grants
        self.clock = clock
        let stream = AsyncStream.makeStream(of: [EntitlementGrant].self)
        self.changes = stream.stream
        self.changesContinuation = stream.continuation
    }

    /// A monthly Plus offer under the first configured product identifier.
    nonisolated static func sampleOffer(id: String? = nil) -> PlusOffer {
        PlusOffer(
            id: id ?? PlusConfiguration.current.productIDs.first ?? "plus",
            displayName: "Trainy Plus",
            description: "Unlimited tracked trips, reminders, widgets, and history.",
            displayPrice: "$3.99",
            billing: .recurring(PlusOffer.Period(unit: .month, value: 1))
        )
    }

    var hasHeldRead: Bool {
        heldRead != nil
    }

    func releaseHeldRead() {
        heldRead?.resume()
        heldRead = nil
    }

    /// Changes the grants the way the App Store would on a renewal, a refund, or
    /// a purchase on another device, and notifies the listener.
    func emit(_ grants: [EntitlementGrant]) {
        self.grants = grants
        changesContinuation.yield(grants)
    }

    func loadOffers(productIDs: [String]) async throws -> [PlusOffer] {
        loadOffersRequests.append(productIDs)
        if let loadOffersError { throw loadOffersError }
        return productIDs.compactMap { id in
            offers.first { $0.id == id }
        }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        purchaseRequests.append(productID)
        if let purchaseError { throw purchaseError }
        if purchaseOutcome == .purchased {
            let now = clock.now
            grants.append(
                EntitlementGrant(
                    productID: productID,
                    purchaseDate: now,
                    expirationDate: purchasedGrantLifetime.map { now.addingTimeInterval($0) },
                    revocationDate: nil
                )
            )
        }
        return purchaseOutcome
    }

    func syncPurchases() async throws {
        syncCount += 1
        if let syncError { throw syncError }
    }

    func currentGrants() async -> [EntitlementGrant] {
        currentGrantsCount += 1
        let snapshot = grants
        if holdsNextGrantsRead {
            holdsNextGrantsRead = false
            await withCheckedContinuation { continuation in
                heldRead = continuation
            }
        }
        return snapshot
    }

    nonisolated func entitlementChanges() -> AsyncStream<[EntitlementGrant]> {
        changes
    }
}
#endif
