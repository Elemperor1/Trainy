import Combine
import Foundation

/// Owns what Trainy knows about the rider's Plus access and runs the product,
/// purchase, restore, and App Store update flows behind `EntitlementService`.
///
/// Create one store at launch and call `start()` once. Ask it, or the
/// `FeatureGate` it vends, whether a feature is unlocked. It presents no UI.
@MainActor
final class EntitlementStore: ObservableObject {
    enum OffersPhase: Equatable {
        case idle
        case loading
        case loaded
        case failed(EntitlementError)
    }

    enum PurchasePhase: Equatable {
        case idle
        case purchasing
        /// Waiting on approval or further authentication; Plus unlocks if it comes through.
        case pending
        case failed(EntitlementError)
    }

    enum RestorePhase: Equatable {
        case idle
        case restoring
        case restored
        case nothingToRestore
        case failed(EntitlementError)
    }

    @Published private(set) var entitlement: EntitlementState = .unknown
    @Published private(set) var offers: [PlusOffer] = []
    @Published private(set) var offersPhase: OffersPhase = .idle
    @Published private(set) var purchasePhase: PurchasePhase = .idle
    @Published private(set) var restorePhase: RestorePhase = .idle

    let configuration: PlusConfiguration

    private let service: any EntitlementService
    private var updatesTask: Task<Void, Never>?
    private var latestSequence = 0
    private var appliedSequence = 0

    init(service: any EntitlementService, configuration: PlusConfiguration = .current) {
        self.service = service
        self.configuration = configuration
    }

    deinit {
        updatesTask?.cancel()
    }

    var featureGate: FeatureGate {
        FeatureGate(entitlement: entitlement, configuration: configuration)
    }

    /// The choke point every Plus feature asks. See `FeatureGate`.
    func isUnlocked(_ feature: Feature) -> Bool {
        featureGate.isUnlocked(feature)
    }

    /// Starts listening for App Store transaction updates and reads the rider's
    /// current entitlement. Call it once, at launch, before any UI depends on it.
    func start() {
        guard updatesTask == nil else { return }
        let changes = service.entitlementChanges()
        updatesTask = Task { [weak self] in
            await self?.refresh()
            for await grants in changes {
                guard let self else { return }
                self.apply(grants, sequence: self.nextSequence())
            }
        }
    }

    /// Re-reads the rider's current entitlement from StoreKit.
    ///
    /// Also call it when the app returns to the foreground: StoreKit sends no
    /// update when a subscription simply runs out.
    func refresh() async {
        let sequence = nextSequence()
        let grants = await service.currentGrants()
        apply(grants, sequence: sequence)
    }

    func loadOffers() async {
        guard offersPhase != .loading else { return }
        offersPhase = .loading
        do {
            let loaded = try await service.loadOffers(productIDs: configuration.productIDs)
            offers = loaded
            offersPhase = loaded.isEmpty ? .failed(.offerUnavailable) : .loaded
        } catch {
            offersPhase = .failed(EntitlementError.resolve(error))
        }
    }

    func purchase(_ offer: PlusOffer) async {
        guard purchasePhase != .purchasing else { return }
        purchasePhase = .purchasing
        do {
            switch try await service.purchase(productID: offer.id) {
            case .purchased:
                await refresh()
                purchasePhase = .idle
            case .cancelled:
                purchasePhase = .idle
            case .pending:
                purchasePhase = .pending
            }
        } catch EntitlementError.cancelled {
            purchasePhase = .idle
        } catch {
            purchasePhase = .failed(EntitlementError.resolve(error))
        }
    }

    func restorePurchases() async {
        guard restorePhase != .restoring else { return }
        restorePhase = .restoring
        do {
            try await service.syncPurchases()
            await refresh()
            restorePhase = entitlement.isPlus ? .restored : .nothingToRestore
        } catch EntitlementError.cancelled {
            restorePhase = .idle
        } catch {
            restorePhase = .failed(EntitlementError.resolve(error))
        }
    }

    private func nextSequence() -> Int {
        latestSequence += 1
        return latestSequence
    }

    /// Applies a result unless a newer one has already been applied, so a slow
    /// read cannot overwrite what a purchase or an App Store update just reported.
    private func apply(_ grants: [EntitlementGrant], sequence: Int) {
        guard sequence > appliedSequence else { return }
        appliedSequence = sequence
        let resolved = EntitlementState.resolving(grants, productIDs: configuration.productIDs)
        if resolved != entitlement {
            entitlement = resolved
        }
        if resolved.isPlus, purchasePhase == .pending {
            purchasePhase = .idle
        }
    }
}
