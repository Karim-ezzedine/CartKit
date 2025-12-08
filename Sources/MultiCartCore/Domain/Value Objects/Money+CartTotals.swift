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
