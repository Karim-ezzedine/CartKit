import CartKitCore

public struct NoOpPricingEngine: CartPricingEngine, Sendable {
    public init() {}
    
    public func computeTotals(
        for cart: Cart,
        context: CartPricingContext
    ) async throws -> CartTotals {
        CartTotals(
            subtotal: Money(amount: 0, currencyCode: "USD"),
            grandTotal: Money(amount: 0, currencyCode: "USD")
        )
    }
}

public struct NoOpPromotionEngine: PromotionEngine, Sendable {
    public init() {}
    
    public func applyPromotions(
        _ promotions: [PromotionKind],
        to cartTotals: CartTotals
    ) async throws -> CartTotals {
        cartTotals
    }
}

public struct AllowAllValidationEngine: CartValidationEngine, Sendable {
    public init() {}
    
    public func validate(cart: Cart) async -> CartValidationResult { .valid }
    
    public func validateItemChange(
        in cart: Cart,
        proposedItem: CartItem
    ) async -> CartValidationResult { .valid }
}

public struct NoOpConflictResolver: CartConflictResolver, Sendable {
    public init() {}
    
    public func resolveConflict(
        for cart: Cart,
        reason: CartError
    ) async -> CartConflictResolution {
        .acceptModifiedCart(cart)
    }
}

