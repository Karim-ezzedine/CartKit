import Foundation

/// Default, stateless promotion engine used by the SDK.
///
/// Applies a simple set of cart-level rules on top of existing `CartTotals`:
/// - `.freeDelivery`          → sets `deliveryFee` to zero.
/// - `.percentageOffCart`    → applies a percentage discount on `subtotal` (clamped at 0).
/// - `.fixedAmountOffCart`   → subtracts a fixed amount from `subtotal` (clamped at 0).
/// - `.custom`               → ignored for now (no-op).
///
/// The engine then recomputes `grandTotal` as:
/// `subtotal + deliveryFee + serviceFee + tax`.
///
/// This is a pure domain service (no side effects) and the default
/// `PromotionEngine` implementation; apps can inject their own engine
/// via `MultiCartConfiguration` if they need different rules.
public struct DefaultPromotionEngine: PromotionEngine, Sendable {
    
    public init() {}
    
    public func applyPromotions(
        _ promotions: [PromotionKind : AppliedPromotion],
        to cartTotal: CartTotals
    ) async throws -> CartTotals {
        
        // Fast path: no promotions, return unchanged
        guard !promotions.isEmpty else { return cartTotal }
        
        let currency = cartTotal.subtotal.currencyCode
        
        var subtotal = cartTotal.subtotal
        var deliveryFee = cartTotal.deliveryFee
        let serviceFee = cartTotal.serviceFee
        let tax = cartTotal.tax
        
        // freeDelivery → deliveryFee = 0
        if let _ = promotions[PromotionKind.freeDelivery] {
            deliveryFee = .zero(currencyCode: currency)
        }
        
        // percentageOffCart → percentage discount on subtotal (clamped ≥ 0)
        if let percentKey = promotions.keys.compactMap(percentageValue).first {
            if percentKey > 0 {
                let discountAmount = subtotal.amount * percentKey
                let newAmount = subtotal.amount - discountAmount
                let clamped = max(newAmount, 0)
                subtotal = Money(amount: clamped, currencyCode: currency)
            }
        }
        
        // fixedAmountOffCart → fixed discount on subtotal (clamped ≥ 0)
        if let fixedMoney = promotions.keys.compactMap(fixedAmountValue).first {
            // Ignore negative discounts; clamp subtotal at zero.
            let discountAmount = max(fixedMoney.amount, 0)
            let newAmount = subtotal.amount - discountAmount
            let clamped = max(newAmount, 0)
            subtotal = Money(amount: clamped, currencyCode: currency)
        }
        
        // Recompute grandTotal = subtotal + fees + tax
        let grandTotalAmount =
        subtotal.amount +
        deliveryFee.amount +
        serviceFee.amount +
        tax.amount
        
        let grandTotal = Money(amount: grandTotalAmount, currencyCode: currency)
        
        return CartTotals(
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            serviceFee: serviceFee,
            tax: tax,
            grandTotal: grandTotal
        )
    }
    
    
    //MARK: - Helpers
    
    private func percentageValue(_ key: PromotionKind) -> Decimal? {
        if case let .percentageOffCart(value) = key { return value }
        return nil
    }
    
    private func fixedAmountValue(_ key: PromotionKind) -> Money? {
        if case let .fixedAmountOffCart(money) = key { return money }
        return nil
    }
}
