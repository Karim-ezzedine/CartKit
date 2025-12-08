/// Strategy for computing **base** cart totals from a cart snapshot + pricing context.
///
/// Used by:
/// - `CartManager` pricing APIs (e.g. `getTotals(for:context:with:)`,
///   `getTotalsForActiveCart(context:with:)`).
/// - Any flow that needs up-to-date totals for a given cart without
///   mutating the cart itself.
public protocol CartPricingEngine: Sendable {
    
    /// Computes base totals for the given cart under the provided pricing context.
    ///
    /// - Parameters:
    ///   - cart: The cart snapshot to price (usually already validated).
    ///   - context: External pricing inputs (fees, tax rates, store/profile scope).
    /// - Returns: Calculated base `CartTotals` for this cart + context.
    func computeTotals(
        for cart: Cart,
        context: CartPricingContext
    ) async throws -> CartTotals
}
