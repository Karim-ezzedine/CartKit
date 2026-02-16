import Foundation

/// Coordinates pricing and promotion application for cart totals.
///
/// This service keeps pricing flow logic in one place:
/// - resolve effective pricing context,
/// - compute base totals,
/// - resolve effective promotions,
/// - apply promotions when available.
struct CartPricingOrchestrator {

    /// Engine that computes base cart totals.
    let pricingEngine: CartPricingEngine

    /// Engine that applies promotions to base totals.
    let promotionEngine: PromotionEngine

    /// Creates a new pricing orchestrator.
    ///
    /// - Parameters:
    ///   - pricingEngine: Engine used to compute base totals.
    ///   - promotionEngine: Engine used to apply promotions.
    init(
        pricingEngine: CartPricingEngine,
        promotionEngine: PromotionEngine
    ) {
        self.pricingEngine = pricingEngine
        self.promotionEngine = promotionEngine
    }

    /// Computes totals for a cart using the provided pricing request.
    ///
    /// - Parameters:
    ///   - cart: Cart to price.
    ///   - request: Pricing request with optional context and promotion override.
    /// - Returns: Final totals after optional promotion application.
    func totals(
        for cart: Cart,
        request: PricingRequest
    ) async throws -> CartTotals {
        let effectiveContext = request.context ?? .plain(
            storeID: cart.storeID,
            profileID: cart.profileID,
            sessionID: cart.sessionID
        )

        let baseTotals = try await pricingEngine.computeTotals(
            for: cart,
            context: effectiveContext
        )

        let effectivePromotions = request.promotionOverride
            ?? (cart.savedPromotionKinds.isEmpty ? nil : cart.savedPromotionKinds)

        return try await applyPromotionsIfAvailable(effectivePromotions, to: baseTotals)
    }

    /// Aggregates per-store totals into one checkout totals value.
    ///
    /// - Parameter totals: Per-store totals.
    /// - Returns: Aggregated totals.
    /// - Throws: `CartError.validationFailed` when currencies are mixed.
    func aggregateGroupTotals(_ totals: Dictionary<StoreID, CartTotals>.Values) throws -> CartTotals {
        guard let first = totals.first else {
            return CartTotals(subtotal: .zero(currencyCode: "USD"))
        }

        let currency = first.subtotal.currencyCode

        func ensureCurrency(_ money: Money) throws {
            guard money.currencyCode == currency else {
                throw CartError.validationFailed(reason: "Mixed currencies in checkout group.")
            }
        }

        var subtotal: Decimal = 0
        var delivery: Decimal = 0
        var service: Decimal = 0
        var tax: Decimal = 0
        var grand: Decimal = 0

        for totalsByStore in totals {
            try ensureCurrency(totalsByStore.subtotal)
            try ensureCurrency(totalsByStore.deliveryFee)
            try ensureCurrency(totalsByStore.serviceFee)
            try ensureCurrency(totalsByStore.tax)
            try ensureCurrency(totalsByStore.grandTotal)

            subtotal += totalsByStore.subtotal.amount
            delivery += totalsByStore.deliveryFee.amount
            service += totalsByStore.serviceFee.amount
            tax += totalsByStore.tax.amount
            grand += totalsByStore.grandTotal.amount
        }

        return CartTotals(
            subtotal: Money(amount: subtotal, currencyCode: currency),
            deliveryFee: Money(amount: delivery, currencyCode: currency),
            serviceFee: Money(amount: service, currencyCode: currency),
            tax: Money(amount: tax, currencyCode: currency),
            grandTotal: Money(amount: grand, currencyCode: currency)
        )
    }

    /// Applies promotions when present.
    ///
    /// - Parameters:
    ///   - promotions: Optional promotions to apply.
    ///   - cartTotals: Base totals.
    /// - Returns: Final totals.
    private func applyPromotionsIfAvailable(
        _ promotions: [PromotionKind]?,
        to cartTotals: CartTotals
    ) async throws -> CartTotals {
        if let promotions {
            return try await promotionEngine.applyPromotions(promotions, to: cartTotals)
        }
        return cartTotals
    }
}
