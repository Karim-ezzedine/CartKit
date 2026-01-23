import Foundation

/// Represents a monetary amount in a given currency.
///
/// - `amount`: stored as `Decimal`
/// - `currencyCode`: an ISO 4217-style code (e.g., "USD", "EUR", "LBP").
public struct Money: Hashable, Codable, Sendable {
    public let amount: Decimal
    public let currencyCode: String
    
    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
    }
    
    /// Convenience factory for a zero amount in the given currency.
    public static func zero(currencyCode: String) -> Money {
        Money(amount: .zero, currencyCode: currencyCode)
    }
}

/// Aggregated totals for a cart.
///
/// - `subtotal`   : sum of line items before fees/discounts/tax
/// - `fees`       : delivery/service fees
/// - `tax`        : tax/VAT
/// - `grandTotal` : final amount charged (subtotal + fees + tax - discount)
public struct CartTotals: Hashable, Codable, Sendable {
    public var subtotal: Money
    public var deliveryFee: Money
    public var serviceFee: Money
    public var tax: Money
    public var grandTotal: Money
    
    /// Initializes cart totals.
    ///
    /// - Parameters:
    ///   - subtotal: Required base amount.
    ///   - fees: Optional; defaults to zero in the same currency as `subtotal`.
    ///   - tax: Optional; defaults to zero in the same currency as `subtotal`.
    ///   - grandTotal: Optional; if omitted, it is derived as:
    ///                 `subtotal + fees + tax - discount`.
    public init(
        subtotal: Money,
        deliveryFee: Money? = nil,
        serviceFee: Money? = nil,
        tax: Money? = nil,
        grandTotal: Money? = nil
    ) {
        let currency = subtotal.currencyCode
        
        self.subtotal = subtotal
        self.deliveryFee = deliveryFee ?? .zero(currencyCode: currency)
        self.serviceFee = serviceFee ?? .zero(currencyCode: currency)
        self.tax = tax ?? .zero(currencyCode: currency)
        
        if let grandTotal = grandTotal {
            self.grandTotal = grandTotal
        } else {
            // NOTE: We assume all components share the same currency.
            let totalAmount = self.subtotal.amount
            + self.deliveryFee.amount
            + self.serviceFee.amount
            + self.tax.amount
            
            self.grandTotal = Money(amount: totalAmount, currencyCode: currency)
        }
    }
}

/// Aggregated totals for a unified checkout group (multi-store session).
///
/// A checkout group is identified by `(profileID, sessionID)` and may contain
/// multiple active carts, each scoped to a different `storeID`.
///
/// Policies:
/// - Pricing is computed per store-cart.
/// - Promotions are applied per store-cart.
/// - The group `aggregate` is a sum of `perStore` totals (assumes same currency).
public struct CheckoutTotals: Hashable, Codable, Sendable {
    
    /// Optional user profile scope (nil = guest).
    public let profileID: UserProfileID?
    
    /// Optional session scope (nil = legacy single-store flow treated as a group).
    public let sessionID: CartSessionID?
    
    /// Totals for each store cart in the group.
    public let perStore: [StoreID: CartTotals]
    
    /// Sum of all `perStore` totals (same currency assumption).
    public let aggregate: CartTotals
    
    public init(
        profileID: UserProfileID?,
        sessionID: CartSessionID?,
        perStore: [StoreID: CartTotals],
        aggregate: CartTotals
    ) {
        self.profileID = profileID
        self.sessionID = sessionID
        self.perStore = perStore
        self.aggregate = aggregate
    }
}
