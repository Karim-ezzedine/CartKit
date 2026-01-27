/// Use-case input for pricing a cart.
public struct PricingRequest: Hashable, Sendable {

    /// Optional pricing context.
    ///
    /// - For pricing by `cartID`, `nil` means: build `.plain(...)` from the cart.
    /// - For pricing an active cart / group, callers should pass a context (or we’ll build `.plain(...)` per cart).
    public var context: CartPricingContext?

    /// Promotions explicitly provided by the caller.
    /// If non-nil, this overrides any persisted cart-level promotion kinds.
    public var promotionOverride: [PromotionKind]?

    public init(
        context: CartPricingContext? = nil,
        promotionOverride: [PromotionKind]? = nil,
    ) {
        self.context = context
        self.promotionOverride = promotionOverride
    }
}
