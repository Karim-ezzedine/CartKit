public extension CartManager {
    // MARK: - Pricing
    
    /// Computes totals for a specific cart ID using the configured
    /// pricing and promotion engines.
    ///
    /// - Parameters:
    ///   - cartID: The identifier of the cart to price.
    ///   - context: Optional pricing context (fees, tax, discounts, scope). If `nil`,
    ///              a plain context is built from the cart’s `storeID` and `profileID`.
    ///   - promotions: Optional map of promotion kinds to their applied metadata. If non-`nil`,
    ///                 promotions will be applied on top of the base totals via the `PromotionEngine`.
    /// - Returns: The final `CartTotals` after pricing and any applied promotions.
    /// - Throws:
    ///   - `CartError.conflict` if the cart does not exist.
    ///   - Any error thrown by the configured `CartPricingEngine` or `PromotionEngine`.
    func getTotals(
        for cartID: CartID,
        context: CartPricingContext? = nil,
        with promotions: [PromotionKind]? = nil
    ) async throws -> CartTotals {
        let cart = try await loadCartOrThrow(cartID)
        
        // If caller didn’t provide a context, build a plain one from the cart.
        let effectiveContext = context ?? .plain(
            storeID: cart.storeID,
            profileID: cart.profileID,
            sessionID: cart.sessionID
        )
        
        let cartTotals = try await config.pricingEngine.computeTotals(
            for: cart,
            context: effectiveContext
        )
        
        return try await self.applyPromotionsIfAvailable(
            promotions,
            to: cartTotals
        )
    }
    
    /// Computes totals for the active cart in a given scope using the
    /// configured pricing and promotion engines.
    ///
    /// - Parameters:
    ///   - context: Pricing context describing the scope (`storeID` / `profileID`)
    ///              and any fees, tax, or discounts.
    ///   - promotions: Optional map of promotion kinds to their applied metadata.
    ///                 If non-`nil`, promotions will be applied on top of the base
    ///                 totals via the `PromotionEngine`.
    /// - Returns: `CartTotals` for the active cart in that scope (after any promotions),
    ///            or `nil` if no active cart exists.
    /// - Throws: Any error thrown by the configured `CartPricingEngine` or
    ///           `PromotionEngine`.
    func getTotalsForActiveCart(
        context: CartPricingContext,
        with promotions: [PromotionKind]? = nil
    ) async throws -> CartTotals? {
        let cart = try await getActiveCart(
            storeID: context.storeID,
            profileID: context.profileID,
            sessionID: context.sessionID
        )
        
        guard let cart else { return nil }
        
        let cartTotals = try await config.pricingEngine.computeTotals(
            for: cart,
            context: context
        )
        
        return try await self.applyPromotionsIfAvailable(
            promotions,
            to: cartTotals
        )
    }
    
    /// Computes totals for the active cart group identified by `(profileID, sessionID)`.
    ///
    /// - Fetches `.active` carts across stores for the given group.
    /// - Prices each cart independently (store-scoped).
    /// - Applies promotions per store (`promotionsByStore[storeID]`).
    /// - Excludes empty carts by default.
    /// - Aggregates totals by summing per-store results (same currency assumption).
    ///
    /// - Throws:
    ///   - Any error from `CartStore`, `CartPricingEngine`, or `PromotionEngine`.
    ///   - `CartError.validationFailed` if currencies are mixed within the group.
    ///   - `CartError.conflict` if multiple active carts exist for the same store in the group.
    func getTotalsForActiveCartGroup(
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID?,
        contextsByStore: [StoreID: CartPricingContext] = [:],
        promotionsByStore: [StoreID: [PromotionKind]] = [:],
        includeEmptyCarts: Bool = false
    ) async throws -> CheckoutTotals {
        
        let query = CartQuery.activeAcrossStores(
            profileID: profileID,
            sessionID: sessionID
        )
        
        let carts = try await config.cartStore.fetchCarts(matching: query, limit: nil)
        let eligible = includeEmptyCarts ? carts : carts.filter { !$0.items.isEmpty }
        
        var perStore: [StoreID: CartTotals] = [:]
        perStore.reserveCapacity(eligible.count)
        
        for cart in eligible {
            if perStore[cart.storeID] != nil {
                throw CartError.conflict(
                    reason: "Multiple active carts found for store=\(cart.storeID.rawValue) in the same session group."
                )
            }
            
            let context = contextsByStore[cart.storeID] ?? .plain(
                storeID: cart.storeID,
                profileID: cart.profileID,
                sessionID: cart.sessionID
            )
            
            let baseTotals = try await config.pricingEngine.computeTotals(
                for: cart,
                context: context
            )
            
            let promos = promotionsByStore[cart.storeID]
            let finalTotals = try await applyPromotionsIfAvailable(promos, to: baseTotals)
            
            perStore[cart.storeID] = finalTotals
        }
        
        let aggregate = try aggregateGroupTotals(perStore.values)
        
        return CheckoutTotals(
            profileID: profileID,
            sessionID: sessionID,
            perStore: perStore,
            aggregate: aggregate
        )
    }
    
    /// Applies promotions to already-computed cart totals, if any are provided.
    ///
    /// This is a small orchestration helper:
    /// - If `promotions` is `nil`, the input `cartTotals` are returned unchanged.
    /// - If `promotions` is non-`nil`, the call is delegated to the configured
    ///   `PromotionEngine.applyPromotions(_:,to:)`.
    ///
    /// This keeps `CartManager` responsible for the flow (pricing → promotions)
    /// while `PromotionEngine` encapsulates the promotion math.
    ///
    /// - Parameters:
    ///   - promotions: Optional map of promotion kinds to applied promotions.
    ///   - cartTotals: Base totals computed by the `CartPricingEngine`.
    /// - Returns: Final `CartTotals` after applying promotions, or the original
    ///            totals when no promotions are provided.
    /// - Throws: Any error thrown by the configured `PromotionEngine`.
    func applyPromotionsIfAvailable(
        _ promotions: [PromotionKind]? = nil,
        to cartTotals: CartTotals
    ) async throws -> CartTotals {
        if let promotions = promotions {
            return try await config.promotionEngine.applyPromotions(promotions, to: cartTotals)
        }
        else {
            return cartTotals
        }
    }
    
    /// Validates the cart before checkout using the configured validation engine.
    ///
    /// This does **not** change the cart status; it only reports whether the
    /// cart satisfies the current rules (min subtotal, max items, etc.).
    ///
    /// - Parameter cartID: Identifier of the cart to validate.
    /// - Returns: `CartValidationResult` describing whether the cart is valid
    ///            for checkout and, if not, why.
    /// - Throws: `CartError.conflict` if the cart cannot be loaded.
    func validateBeforeCheckout(
        cartID: CartID
    ) async throws -> CartValidationResult {
        let cart = try await loadCartOrThrow(cartID)
        return await config.validationEngine.validate(cart: cart)
    }
    
    /// Validates the active cart group identified by `(profileID, sessionID)`
    /// before allowing checkout.
    ///
    /// - Fetches `.active` carts across stores for the given group.
    /// - Excludes empty carts by default.
    /// - Validates each store cart using the configured `CartValidationEngine`.
    /// - Returns per-store results and a summary via `CheckoutGroupValidationResult.isValid`.
    ///
    /// - Throws: Any error thrown by the underlying `CartStore` fetch.
    func validateBeforeCheckoutForActiveCartGroup(
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID?,
        includeEmptyCarts: Bool = false
    ) async throws -> CheckoutGroupValidationResult {

        let query = CartQuery.activeAcrossStores(profileID: profileID, sessionID: sessionID)
        let carts = try await config.cartStore.fetchCarts(matching: query, limit: nil)

        let eligible = includeEmptyCarts ? carts : carts.filter { !$0.items.isEmpty }

        var perStore: [StoreID: CartValidationResult] = [:]
        perStore.reserveCapacity(eligible.count)

        for cart in eligible {
            if perStore[cart.storeID] != nil {
                // Same uniqueness guard as totals (keeps behavior consistent)
                perStore[cart.storeID] = .invalid(
                    error: .custom(message: "Multiple active carts found for the same store in one group.")
                )
                continue
            }

            let result = await config.validationEngine.validate(cart: cart)
            perStore[cart.storeID] = result
        }

        return CheckoutGroupValidationResult(
            profileID: profileID,
            sessionID: sessionID,
            perStore: perStore
        )
    }
}
