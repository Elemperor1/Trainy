import Foundation
import XCTest
@testable import TrainyCore

private let productID = "plus.test"
private let purchased = Date(timeIntervalSince1970: 1_800_000_000)
private let renewed = Date(timeIntervalSince1970: 1_802_592_000)

private let enforcing = PlusConfiguration(
    productIDs: [productID],
    enforcesFeatureGates: true,
    freeTrackedTripLimit: 3
)

private let dormant = PlusConfiguration(
    productIDs: [productID],
    enforcesFeatureGates: false,
    freeTrackedTripLimit: 3
)

private func grant(
    _ id: String = productID,
    purchasedAt: Date = purchased,
    expiresAt: Date? = renewed,
    revokedAt: Date? = nil
) -> EntitlementGrant {
    EntitlementGrant(
        productID: id,
        purchaseDate: purchasedAt,
        expirationDate: expiresAt,
        revocationDate: revokedAt
    )
}

private func plusState(expiresAt: Date? = renewed) -> EntitlementState {
    .plus(PlusEntitlement(productID: productID, purchaseDate: purchased, expirationDate: expiresAt))
}

@MainActor
final class FeatureGateTests: XCTestCase {
    func testNothingIsLockedWhileGatingIsNotEnforced() {
        for entitlement in [EntitlementState.unknown, .free, plusState()] {
            let gate = FeatureGate(entitlement: entitlement, configuration: dormant)
            for feature in Feature.allCases {
                XCTAssertTrue(gate.isUnlocked(feature), "\(feature) locked for \(entitlement) while gating is dormant")
            }
            XCTAssertTrue(gate.canTrackAnotherTrip(currentCount: 50))
        }
    }

    func testPlusFeaturesStayLockedUntilTheRiderIsKnownToHavePlus() {
        for entitlement in [EntitlementState.unknown, .free] {
            let gate = FeatureGate(entitlement: entitlement, configuration: enforcing)
            for feature in Feature.allCases {
                XCTAssertFalse(gate.isUnlocked(feature), "\(feature) unlocked for \(entitlement)")
            }
        }
    }

    func testPlusUnlocksEveryFeature() {
        let gate = FeatureGate(entitlement: plusState(), configuration: enforcing)
        for feature in Feature.allCases {
            XCTAssertTrue(gate.isUnlocked(feature), "\(feature) locked for a Plus rider")
        }
    }

    func testFreeRidersTrackTripsUpToTheLimitAndNoFurther() {
        let gate = FeatureGate(entitlement: .free, configuration: enforcing)

        XCTAssertTrue(gate.canTrackAnotherTrip(currentCount: 0))
        XCTAssertTrue(gate.canTrackAnotherTrip(currentCount: 2))
        XCTAssertFalse(gate.canTrackAnotherTrip(currentCount: 3))
    }

    func testARiderWhosePlusLapsedKeepsTheirTripsButCannotAddMore() {
        let tracked = 7
        let plus = FeatureGate(entitlement: plusState(), configuration: enforcing)
        let lapsed = FeatureGate(entitlement: .free, configuration: enforcing)

        XCTAssertTrue(plus.canTrackAnotherTrip(currentCount: tracked))
        XCTAssertFalse(lapsed.canTrackAnotherTrip(currentCount: tracked))
        // The gate only answers whether one more trip may be added. It has no way
        // to ask for existing trips to be removed, so a lapse cannot cost data.
        XCTAssertTrue(lapsed.canTrackAnotherTrip(currentCount: 2))
    }
}

@MainActor
final class PlusConfigurationTests: XCTestCase {
    func testShippedConfigurationNamesOneWellFormedProduct() {
        let ids = PlusConfiguration.current.productIDs

        XCTAssertEqual(ids.count, 1)
        XCTAssertEqual(Set(ids).count, ids.count)
        for id in ids {
            XCTAssertFalse(id.isEmpty)
            XCTAssertEqual(id, id.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    func testLocalStoreKitConfigurationOffersTheShippedProduct() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let configurationURL = repositoryRoot.appendingPathComponent("TrainyIOS/StoreKit/Trainy.storekit")
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: configurationURL)) as? [String: Any]
        )

        var declared: Set<String> = []
        for product in root["products"] as? [[String: Any]] ?? [] {
            declared.formUnion([product["productID"] as? String].compactMap { $0 })
        }
        for group in root["subscriptionGroups"] as? [[String: Any]] ?? [] {
            for subscription in group["subscriptions"] as? [[String: Any]] ?? [] {
                declared.formUnion([subscription["productID"] as? String].compactMap { $0 })
            }
        }

        for id in PlusConfiguration.current.productIDs {
            XCTAssertTrue(declared.contains(id), "\(id) is missing from TrainyIOS/StoreKit/Trainy.storekit")
        }
    }

    func testShippedConfigurationStaysDormantUntilPlusIsOnSale() {
        XCTAssertFalse(
            PlusConfiguration.current.enforcesFeatureGates,
            "Flip enforcesFeatureGates only in the release that ships the paywall with a real product in App Store Connect, and update this test with it."
        )
        XCTAssertGreaterThan(PlusConfiguration.current.freeTrackedTripLimit, 0)
    }
}

@MainActor
final class EntitlementResolutionTests: XCTestCase {
    private let ids = [productID]

    func testNoGrantsMeansFree() {
        XCTAssertEqual(EntitlementState.resolving([], productIDs: ids), .free)
    }

    func testGrantsForOtherProductsDoNotCount() {
        XCTAssertEqual(EntitlementState.resolving([grant("other.product")], productIDs: ids), .free)
    }

    func testRevokedGrantsDoNotCount() {
        let refunded = grant(revokedAt: purchased.addingTimeInterval(60))
        XCTAssertEqual(EntitlementState.resolving([refunded], productIDs: ids), .free)
    }

    func testAnActiveGrantBecomesPlusWithItsDates() {
        XCTAssertEqual(EntitlementState.resolving([grant()], productIDs: ids), plusState())
    }

    func testARenewalReplacesThePeriodItRenews() {
        let first = grant(purchasedAt: purchased, expiresAt: renewed)
        let second = grant(purchasedAt: renewed, expiresAt: renewed.addingTimeInterval(2_592_000))

        XCTAssertEqual(
            EntitlementState.resolving([second, first], productIDs: ids),
            .plus(PlusEntitlement(productID: productID, purchaseDate: renewed, expirationDate: second.expirationDate))
        )
    }

    func testAGrantThatNeverExpiresBeatsOneThatDoes() {
        let lifetime = grant(expiresAt: nil)
        let monthly = grant(expiresAt: renewed)

        XCTAssertEqual(
            EntitlementState.resolving([monthly, lifetime], productIDs: ids),
            plusState(expiresAt: nil)
        )
    }

    func testARevokedGrantDoesNotHideAnotherActiveOne() {
        let refunded = grant(expiresAt: renewed.addingTimeInterval(2_592_000), revokedAt: purchased)
        let active = grant()

        XCTAssertEqual(EntitlementState.resolving([refunded, active], productIDs: ids), plusState())
    }
}

@MainActor
final class EntitlementStoreTests: XCTestCase {
    private func makeStore(
        _ service: FakeEntitlementService,
        configuration: PlusConfiguration = enforcing
    ) -> EntitlementStore {
        EntitlementStore(service: service, configuration: configuration)
    }

    private func makeService(grants: [EntitlementGrant] = []) -> FakeEntitlementService {
        FakeEntitlementService(
            offers: [FakeEntitlementService.sampleOffer(id: productID)],
            grants: grants,
            clock: .fixed(purchased)
        )
    }

    /// Waits for a main-actor state change that follows from work the store started itself.
    private func eventually(
        _ description: String,
        timeout: Duration = .seconds(5),
        _ condition: () -> Bool
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out waiting for \(description)")
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - Entitlement

    func testStoreStartsUnresolvedAndKeepsPlusFeaturesLocked() {
        let store = makeStore(makeService())

        XCTAssertEqual(store.entitlement, .unknown)
        XCTAssertFalse(store.entitlement.isResolved)
        XCTAssertFalse(store.isUnlocked(.tripReminders))
    }

    func testRefreshWithNoPurchaseResolvesToFree() async {
        let service = makeService()
        let store = makeStore(service)

        await store.refresh()

        XCTAssertEqual(store.entitlement, .free)
        XCTAssertTrue(store.entitlement.isResolved)
        XCTAssertFalse(store.isUnlocked(.widgets))
        XCTAssertEqual(service.currentGrantsCount, 1)
    }

    func testRefreshWithAnActiveGrantUnlocksPlus() async {
        let store = makeStore(makeService(grants: [grant()]))

        await store.refresh()

        XCTAssertEqual(store.entitlement, plusState())
        XCTAssertTrue(store.isUnlocked(.widgets))
        XCTAssertTrue(store.featureGate.canTrackAnotherTrip(currentCount: 10))
    }

    func testStartReadsTheEntitlementWithoutAnyPurchase() async {
        let store = makeStore(makeService(grants: [grant()]))

        store.start()
        await eventually("the first entitlement read") { store.entitlement.isResolved }

        XCTAssertEqual(store.entitlement, plusState())
    }

    func testUpdatesUnlockRenewalsAndRelockRefunds() async {
        let service = makeService()
        let store = makeStore(service)
        store.start()
        await eventually("the first entitlement read") { store.entitlement == .free }

        service.emit([grant()])
        await eventually("a purchase made on another device") { store.entitlement.isPlus }

        let renewal = grant(purchasedAt: renewed, expiresAt: renewed.addingTimeInterval(2_592_000))
        service.emit([renewal])
        await eventually("the renewal") { store.entitlement == .plus(PlusEntitlement(productID: productID, purchaseDate: renewed, expirationDate: renewal.expirationDate)) }

        service.emit([grant(revokedAt: renewed)])
        await eventually("the refund") { store.entitlement == .free }
        XCTAssertFalse(store.isUnlocked(.tripHistory))
    }

    func testASlowOlderReadCannotOverwriteANewerResult() async {
        let service = makeService()
        service.holdsNextGrantsRead = true
        let store = makeStore(service)

        // This read takes its snapshot while the rider is free, then stalls.
        let slowRead = Task { await store.refresh() }
        await eventually("the slow read to begin") { service.hasHeldRead }

        // Meanwhile the rider's purchase arrives and is read in full.
        service.emit([grant()])
        store.start()
        await eventually("the newer read") { store.entitlement.isPlus }

        service.releaseHeldRead()
        await slowRead.value

        XCTAssertTrue(store.entitlement.isPlus, "A read that started earlier overwrote a newer result")
    }

    // MARK: - Offers

    func testLoadOffersPublishesOnlyTheConfiguredProducts() async {
        let service = FakeEntitlementService(
            offers: [
                FakeEntitlementService.sampleOffer(id: productID),
                FakeEntitlementService.sampleOffer(id: "unrelated.product")
            ]
        )
        let store = makeStore(service)

        await store.loadOffers()

        XCTAssertEqual(store.offers.map(\.id), [productID])
        XCTAssertEqual(store.offersPhase, .loaded)
        XCTAssertEqual(service.loadOffersRequests, [[productID]])
    }

    func testLoadOffersReportsUnavailableWhenTheAppStoreHasNoProduct() async {
        let store = makeStore(FakeEntitlementService(offers: []))

        await store.loadOffers()

        XCTAssertTrue(store.offers.isEmpty)
        XCTAssertEqual(store.offersPhase, .failed(.offerUnavailable))
    }

    func testLoadOffersFailureIsReportedAndKeepsEarlierOffers() async {
        let service = makeService()
        let store = makeStore(service)
        await store.loadOffers()

        service.loadOffersError = .offline
        await store.loadOffers()

        XCTAssertEqual(store.offersPhase, .failed(.offline))
        XCTAssertEqual(store.offers.map(\.id), [productID])
    }

    // MARK: - Purchase

    func testPurchaseUnlocksPlus() async throws {
        let service = makeService()
        let store = makeStore(service)
        await store.loadOffers()
        let offer = try XCTUnwrap(store.offers.first)

        await store.purchase(offer)

        XCTAssertEqual(service.purchaseRequests, [productID])
        XCTAssertTrue(store.entitlement.isPlus)
        XCTAssertTrue(store.isUnlocked(.liveActivities))
        XCTAssertEqual(store.purchasePhase, .idle)
    }

    func testACancelledPurchaseLeavesTheRiderFreeWithoutAnError() async throws {
        let service = makeService()
        service.purchaseOutcome = .cancelled
        let store = makeStore(service)
        await store.loadOffers()
        await store.refresh()

        await store.purchase(try XCTUnwrap(store.offers.first))

        XCTAssertEqual(store.entitlement, .free)
        XCTAssertEqual(store.purchasePhase, .idle)
    }

    func testAPurchaseThatThrowsCancelledIsSilentToo() async throws {
        let service = makeService()
        service.purchaseError = .cancelled
        let store = makeStore(service)
        await store.loadOffers()

        await store.purchase(try XCTUnwrap(store.offers.first))

        XCTAssertEqual(store.purchasePhase, .idle)
    }

    func testAPendingPurchaseWaitsThenUnlocksWhenItIsApproved() async throws {
        let service = makeService()
        service.purchaseOutcome = .pending
        let store = makeStore(service)
        store.start()
        await store.loadOffers()
        await eventually("the first entitlement read") { store.entitlement == .free }

        await store.purchase(try XCTUnwrap(store.offers.first))
        XCTAssertEqual(store.purchasePhase, .pending)
        XCTAssertFalse(store.entitlement.isPlus)

        service.emit([grant()])
        await eventually("the approval") { store.entitlement.isPlus }
        XCTAssertEqual(store.purchasePhase, .idle)
    }

    func testAFailedPurchaseIsReportedAndLeavesTheRiderFree() async throws {
        let service = makeService()
        service.purchaseError = .offline
        let store = makeStore(service)
        await store.loadOffers()
        await store.refresh()

        await store.purchase(try XCTUnwrap(store.offers.first))

        XCTAssertEqual(store.purchasePhase, .failed(.offline))
        XCTAssertEqual(store.entitlement, .free)
    }

    func testAnUnverifiedPurchaseIsReportedAndDoesNotUnlockPlus() async throws {
        let service = makeService()
        service.purchaseError = .unverifiedTransaction
        let store = makeStore(service)
        await store.loadOffers()
        await store.refresh()

        await store.purchase(try XCTUnwrap(store.offers.first))

        XCTAssertEqual(store.purchasePhase, .failed(.unverifiedTransaction))
        XCTAssertFalse(store.isUnlocked(.tripReminders))
    }

    // MARK: - Restore

    func testRestoreFindsAnExistingPurchase() async {
        let service = makeService(grants: [grant()])
        let store = makeStore(service)

        await store.restorePurchases()

        XCTAssertEqual(service.syncCount, 1)
        XCTAssertEqual(store.restorePhase, .restored)
        XCTAssertTrue(store.entitlement.isPlus)
    }

    func testRestoreWithNothingToRestoreSaysSo() async {
        let service = makeService()
        let store = makeStore(service)

        await store.restorePurchases()

        XCTAssertEqual(store.restorePhase, .nothingToRestore)
        XCTAssertEqual(store.entitlement, .free)
    }

    func testDismissingTheSignInPromptDuringRestoreIsSilent() async {
        let service = makeService()
        service.syncError = .cancelled
        let store = makeStore(service)

        await store.restorePurchases()

        XCTAssertEqual(store.restorePhase, .idle)
    }

    func testARestoreFailureIsReported() async {
        let service = makeService()
        service.syncError = .offline
        let store = makeStore(service)

        await store.restorePurchases()

        XCTAssertEqual(store.restorePhase, .failed(.offline))
    }
}
