import Foundation

/// A Plus product the App Store is offering, reduced to what a paywall shows.
struct PlusOffer: Equatable, Identifiable, Sendable {
    struct Period: Equatable, Sendable {
        enum Unit: Equatable, Sendable {
            case day
            case week
            case month
            case year
        }

        let unit: Unit
        let value: Int
    }

    enum Billing: Equatable, Sendable {
        case oneTime
        case recurring(Period)
    }

    /// The App Store Connect product identifier.
    let id: String
    let displayName: String
    let description: String
    /// The price as the App Store formats it for the rider's storefront.
    let displayPrice: String
    let billing: Billing
}

/// A rider's active Plus access.
struct PlusEntitlement: Equatable, Sendable {
    let productID: String
    let purchaseDate: Date
    /// When the paid period ends, or `nil` for a purchase that does not expire.
    let expirationDate: Date?
}

enum EntitlementState: Equatable, Sendable {
    /// StoreKit has not been read yet this launch.
    case unknown
    /// StoreKit was read and the rider has no Plus access.
    case free
    case plus(PlusEntitlement)

    var isResolved: Bool {
        self != .unknown
    }

    var isPlus: Bool {
        guard case .plus = self else { return false }
        return true
    }
}

/// One verified App Store transaction that may entitle the rider, free of
/// StoreKit types so the rest of the app and its tests never import StoreKit.
struct EntitlementGrant: Equatable, Sendable {
    let productID: String
    let purchaseDate: Date
    let expirationDate: Date?
    let revocationDate: Date?
}

extension EntitlementState {
    /// Chooses the access to show from every transaction StoreKit reports as
    /// currently entitling the rider.
    ///
    /// Grants for other products and refunded or revoked grants never count.
    /// Among the rest, a grant that does not expire wins, then the one that ends
    /// last, so a renewal replaces the period it renews. StoreKit has already
    /// dropped lapsed subscriptions from the set it reports (and keeps those in a
    /// billing grace period), so the expiration date here is informational and is
    /// deliberately not compared with the clock.
    static func resolving(_ grants: [EntitlementGrant], productIDs: [String]) -> EntitlementState {
        let active = grants.filter { grant in
            productIDs.contains(grant.productID) && grant.revocationDate == nil
        }
        let best = active.max { lhs, rhs in
            (lhs.expirationDate ?? .distantFuture, lhs.purchaseDate)
                < (rhs.expirationDate ?? .distantFuture, rhs.purchaseDate)
        }
        guard let best else { return .free }
        return .plus(
            PlusEntitlement(
                productID: best.productID,
                purchaseDate: best.purchaseDate,
                expirationDate: best.expirationDate
            )
        )
    }
}

enum PurchaseOutcome: Equatable, Sendable {
    /// The App Store completed the purchase and StoreKit verified the transaction.
    case purchased
    /// The rider dismissed the purchase sheet.
    case cancelled
    /// The purchase needs approval (Ask to Buy) or more authentication. If it
    /// goes through, it arrives later as an update.
    case pending
}

enum EntitlementError: Error, Equatable, Sendable {
    case offerUnavailable
    case unverifiedTransaction
    case purchasesNotAllowed
    /// The rider dismissed a system prompt, such as the App Store sign-in sheet.
    case cancelled
    case offline
    case unavailable

    static func resolve(_ error: Error) -> EntitlementError {
        (error as? EntitlementError) ?? .unavailable
    }

    var message: String {
        switch self {
        case .offerUnavailable:
            return "Trainy Plus is not available right now."
        case .unverifiedTransaction:
            return "The App Store could not verify this purchase, so Plus was not unlocked. Try Restore Purchases."
        case .purchasesNotAllowed:
            return "Purchases are turned off on this device."
        case .cancelled:
            return "The request was cancelled."
        case .offline:
            return "Trainy could not reach the App Store. Check your connection and try again."
        case .unavailable:
            return "The App Store is temporarily unavailable. Try again shortly."
        }
    }
}
