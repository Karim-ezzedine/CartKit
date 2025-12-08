import Foundation

/// Simple default pricing implementation:
/// - `subtotal`  = sum of `unitPrice * quantity` for all items.
/// - `tax`  = `subtotal * taxRate` from the context.
/// - `deliveryFee` = `context.deliveryFee` (or zero if `nil`).
/// - `serviceFee`  = `context.serviceFee` (or zero if `nil`).
/// - `grandTotal`  = `subtotal + deliveryFee + serviceFee + tax`.
///
/// The resulting `CartTotals` exposes:
/// - `subtotal`  (line items),
/// - `deliveryFee` (delivery-related charges),
/// - `serviceFee` (service-related charges),
/// - `tax`,
/// - `grandTotal` (final payable amount).
///
/// This implementation does not interpret promotions; those are applied
/// separately by `PromotionEngine` on top of these base totals.
public struct DefaultCartPricingEngine: CartPricingEngine, Sendable {
    
    public init() {}
    
    public func computeTotals(
        for cart: Cart,
        context: CartPricingContext
    ) async throws -> CartTotals {
        
        // Pick a currency (assume all line items share it).
        let currencyCode =
        cart.items.first?.unitPrice.currencyCode ??
        context.serviceFee?.currencyCode ??
        context.deliveryFee?.currencyCode ?? "USD"
        
        // Subtotal of line items
        var subtotalAmount = Decimal(0)
        for item in cart.items {
            subtotalAmount += item.unitPrice.amount * Decimal(item.quantity)
        }
        let subtotal = Money(amount: subtotalAmount, currencyCode: currencyCode)
        
        // Tax
        let taxAmount = subtotal.amount * context.taxRate
        let tax = Money(amount: taxAmount, currencyCode: currencyCode)
        
        // Fees (service + delivery)
        let feesAmount =
        (context.serviceFee?.amount ?? 0) +
        (context.deliveryFee?.amount ?? 0)
                
        // Grand total
        let grandAmount =
        subtotal.amount +
        tax.amount +
        feesAmount
        
        let grandTotal = Money(amount: grandAmount, currencyCode: currencyCode)
        
        return CartTotals(
            subtotal: subtotal,
            deliveryFee: context.deliveryFee,
            serviceFee: context.serviceFee,
            tax: tax,
            grandTotal: grandTotal
        )
    }
}
