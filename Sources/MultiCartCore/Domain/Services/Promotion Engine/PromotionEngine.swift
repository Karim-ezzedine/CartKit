/// Applies promotions / discounts to a cart before pricing.
///
/// Used by:
/// - Pricing flows inside `CartManager` prior to `CartPricingEngine`.
///
/// The promotion engine is an extension point:
/// - It can attach or update promotions on the cart,
/// - and/or adjust the `CartPricingContext` (e.g. override delivery fee,
///   add a promo-specific discount), without assuming the user is logged in.
public protocol PromotionEngine: Sendable {
    
    /// Returns a modified cart and pricing context with promotions applied.
    ///
    /// Typical responsibilities:
    /// - read store/profile/campaign information from the cart and context,
    /// - decide which promotions apply for this cart,
    /// - update `cart.appliedPromotions` and/or the `pricingContext`
    ///   (fees, discounts, tax rate, etc.).
    ///
    /// - Parameters:
    ///   - cart: The current cart snapshot.
    ///   - context: The incoming pricing context (scope + fees/tax/discounts).
    /// - Returns: A tuple of `(cart, pricingContext)` after promotions.
    /// - Throws: Any error if promotion evaluation fails.
    func applyPromotions(
        _ promotions: [PromotionKind: AppliedPromotion],
        to cartTotals: CartTotals
    ) async throws -> CartTotals
}
