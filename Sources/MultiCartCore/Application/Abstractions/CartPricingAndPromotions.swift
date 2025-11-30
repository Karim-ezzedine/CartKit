import Foundation

/// Computes cart totals from a given cart snapshot.
///
/// Used by:
/// - CartManager.computeTotals(for:)
/// - Any flow that needs up-to-date totals for a cart.
///
/// Typical flow:
/// 1. Start from persisted cart.
/// 2. Optionally run PromotionEngine.applyPromotions(to:).
/// 3. Call CartPricingEngine.computeTotals(for:).
public protocol CartPricingEngine: Sendable {
    func computeTotals(for cart: Cart) async throws -> CartTotals
}

/// Applies promotions / discounts to a cart before pricing.
///
/// Used by:
/// - Pricing flows inside CartManager prior to CartPricingEngine.
///
/// Default implementation in the SDK will be a no-op engine that returns
/// the cart unchanged, so promos are opt-in.
public protocol PromotionEngine: Sendable {
    
    /// Return a modified cart with promotions applied (e.g. adjusted prices,
    /// attached promo metadata, etc.).
    func applyPromotions(to cart: Cart) async throws -> Cart
}

