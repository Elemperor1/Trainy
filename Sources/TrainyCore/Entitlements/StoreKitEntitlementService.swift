#if canImport(StoreKit)
import Foundation
import StoreKit

/// The StoreKit 2 implementation of `EntitlementService`, and the only file in
/// the app that talks to StoreKit.
///
/// Only verified transactions count: an unverified result is never reported as a
/// grant and never finished.
actor StoreKitEntitlementService: EntitlementService {
    private var productsByID: [String: Product] = [:]

    func loadOffers(productIDs: [String]) async throws -> [PlusOffer] {
        let products: [Product]
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            throw Self.entitlementError(for: error)
        }
        let loaded = Dictionary(products.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for id in productIDs {
            productsByID[id] = loaded[id]
        }
        return productIDs.compactMap { id in
            loaded[id].flatMap(Self.offer(for:))
        }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        let storeProduct = try await resolveProduct(id: productID)
        let result: Product.PurchaseResult
        do {
            result = try await storeProduct.purchase()
        } catch {
            let mapped = Self.entitlementError(for: error)
            if mapped == .cancelled { return .cancelled }
            throw mapped
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw EntitlementError.unverifiedTransaction
            }
            await transaction.finish()
            return .purchased
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func syncPurchases() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw Self.entitlementError(for: error)
        }
    }

    func currentGrants() async -> [EntitlementGrant] {
        var grants: [EntitlementGrant] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            grants.append(Self.grant(for: transaction))
        }
        return grants
    }

    nonisolated func entitlementChanges() -> AsyncStream<[EntitlementGrant]> {
        AsyncStream { continuation in
            let listener = Task {
                for await result in Transaction.updates {
                    guard case .verified(let transaction) = result else { continue }
                    await transaction.finish()
                    continuation.yield(await self.currentGrants())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                listener.cancel()
            }
        }
    }

    private func resolveProduct(id: String) async throws -> Product {
        if let cached = productsByID[id] { return cached }
        let products: [Product]
        do {
            products = try await Product.products(for: [id])
        } catch {
            throw Self.entitlementError(for: error)
        }
        guard let found = products.first(where: { $0.id == id }) else {
            throw EntitlementError.offerUnavailable
        }
        productsByID[id] = found
        return found
    }

    private static func offer(for product: Product) -> PlusOffer? {
        guard let billing = billing(for: product) else { return nil }
        return PlusOffer(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            billing: billing
        )
    }

    /// A product whose renewal terms Trainy cannot describe accurately is not offered.
    private static func billing(for product: Product) -> PlusOffer.Billing? {
        guard let period = product.subscription?.subscriptionPeriod else { return .oneTime }
        let unit: PlusOffer.Period.Unit
        switch period.unit {
        case .day: unit = .day
        case .week: unit = .week
        case .month: unit = .month
        case .year: unit = .year
        @unknown default: return nil
        }
        return .recurring(PlusOffer.Period(unit: unit, value: period.value))
    }

    private static func grant(for transaction: Transaction) -> EntitlementGrant {
        EntitlementGrant(
            productID: transaction.productID,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate
        )
    }

    private static func entitlementError(for error: Error) -> EntitlementError {
        if let error = error as? EntitlementError { return error }
        if let error = error as? StoreKitError {
            switch error {
            case .userCancelled: return .cancelled
            case .networkError: return .offline
            case .notAvailableInStorefront: return .offerUnavailable
            default: return .unavailable
            }
        }
        if let error = error as? Product.PurchaseError {
            switch error {
            case .purchaseNotAllowed: return .purchasesNotAllowed
            case .productUnavailable: return .offerUnavailable
            default: return .unavailable
            }
        }
        return .unavailable
    }
}

extension EntitlementStore {
    /// The store the app runs with, backed by StoreKit.
    static func live(configuration: PlusConfiguration = .current) -> EntitlementStore {
        EntitlementStore(service: StoreKitEntitlementService(), configuration: configuration)
    }
}
#endif
