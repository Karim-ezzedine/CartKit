public extension CartManager {
    // MARK: - Pricing
    
    /// Computes totals for a specific cart ID using the configured pricing and promotion engines.
    ///
    /// Promotion selection precedence:
    /// 1) If `request.promotionOverride` is non-`nil`, it is used.
    /// 2) Otherwise, the cart’s persisted `savedPromotionKinds` are used (if any).
    /// 3) Otherwise, totals are returned without applying promotions.
    ///
    /// - Parameters:
    ///   - cartID: The identifier of the cart to price.
    ///   - request: Pricing input that can include an optional context, an optional promotion override,
    ///              and a flag indicating whether the override should be persisted to the cart.
    ///              If `request.context` is `nil`, a plain context is built from the cart’s identifiers.
    /// - Returns: The final `CartTotals` after pricing and any applied promotions.
    /// - Throws:
    ///   - `CartError.conflict` if the cart does not exist.
    ///   - Any error thrown by the configured `CartPricingEngine`, `PromotionEngine`, or persistence layer.
    func totals(
        for cartID: CartID,
        request: PricingRequest = .init()
    ) async throws -> CartTotals {
        
        let cart = try await loadCartOrThrow(cartID)
        
        let effectiveContext = request.context ?? .plain(
            storeID: cart.storeID,
            profileID: cart.profileID,
            sessionID: cart.sessionID
        )
        
        let baseTotals = try await config.pricingEngine.computeTotals(
            for: cart,
            context: effectiveContext
        )
        
        let effectivePromotions = request.promotionOverride
        ?? (cart.savedPromotionKinds.isEmpty ? nil : cart.savedPromotionKinds)
        
        return try await applyPromotionsIfAvailable(effectivePromotions, to: baseTotals)
    }
    
    /// Computes totals for the active cart in the scope described by `request.context`
    /// using the configured pricing engine and (optionally) the promotion engine.
    ///
    /// Promotion selection follows a deterministic precedence rule:
    /// 1) If `request.promotionOverride` is non-`nil`, it is used.
    /// 2) Otherwise, the cart’s persisted `savedPromotionKinds` are used (if any).
    /// 3) Otherwise, totals are returned without applying promotions.
    ///
    /// - Parameter request: A `PricingRequest` describing:
    ///   - `context`: Required. Defines the scope (`storeID`, `profileID`, `sessionID`) and pricing inputs
    ///              (fees, taxes, etc.).
    ///   - `promotionOverride`: Optional. If provided, overrides persisted cart promotion kinds for this call.
    ///
    /// - Returns: `CartTotals` for the active cart (after applying any effective promotions),
    ///           or `nil` if no active cart exists for the requested scope.
    ///
    /// - Throws:
    ///   - `CartError.validationFailed` if `request.context` is missing.
    ///   - Any error thrown by the configured `CartPricingEngine` or `PromotionEngine`.
    func totalsForActiveCart(
        request: PricingRequest
    ) async throws -> CartTotals? {
        
        guard let context = request.context else {
            throw CartError.validationFailed(reason: "PricingRequest.context is required for totalsForActiveCart")
        }
        
        let cart = try await getActiveCart(
            storeID: context.storeID,
            profileID: context.profileID,
            sessionID: context.sessionID
        )
        
        guard let cart else { return nil }
        
        let baseTotals = try await config.pricingEngine.computeTotals(
            for: cart,
            context: context
        )
        
        let effectivePromotions = request.promotionOverride
        ?? (cart.savedPromotionKinds.isEmpty ? nil : cart.savedPromotionKinds)
        
        return try await applyPromotionsIfAvailable(effectivePromotions, to: baseTotals)
    }
    
    /// Computes totals for the active cart group identified by `(profileID, sessionID)`.
    ///
    /// - Fetches `.active` carts across stores for the given group.
    /// - Prices each cart independently (store-scoped).
    /// - For each store, uses `requestsByStore[storeID]` when provided; otherwise uses a default `PricingRequest()`.
    ///
    /// - Pricing context resolution per cart:
    ///   - Uses `request.context` if provided.
    ///   - Otherwise builds a default `.plain(storeID:profileID:sessionID:)` from the cart.
    ///
    /// - Promotion resolution per cart (deterministic precedence):
    ///   1) If `request.promotionOverride` is non-nil → apply it.
    ///   2) Else, if `cart.savedPromotionKinds` is non-empty → apply it.
    ///   3) Else → compute base totals only (no promotions).
    ///
    /// - Excludes empty carts by default (`includeEmptyCarts == false`).
    /// - Aggregates totals by summing per-store results, and validates currency consistency.
    ///
    /// - Throws:
    ///   - Any error from `CartStore`, `CartPricingEngine`, or `PromotionEngine`.
    ///   - `CartError.validationFailed` if currencies are mixed within the group.
    ///   - `CartError.conflict` if multiple active carts exist for the same store in the group.
    func totalsForActiveCartGroup(
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID?,
        requestsByStore: [StoreID: PricingRequest] = [:],
        includeEmptyCarts: Bool = false
    ) async throws -> CheckoutTotals {
        
        let query = CartQuery.activeAcrossStores(profileID: profileID, sessionID: sessionID)
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
            
            let request = requestsByStore[cart.storeID] ?? .init()
            
            let context = request.context ?? .plain(
                storeID: cart.storeID,
                profileID: cart.profileID,
                sessionID: cart.sessionID
            )
            
            let baseTotals = try await config.pricingEngine.computeTotals(for: cart, context: context)
            
            let effectivePromotions =
            request.promotionOverride
            ?? (cart.savedPromotionKinds.isEmpty ? nil : cart.savedPromotionKinds)
            
            let finalTotals = try await applyPromotionsIfAvailable(effectivePromotions, to: baseTotals)
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
    
    /// Persist the promotion kinds that should be applied by default when pricing this cart.
    ///
    /// - Important: This is a cart-level configuration stored in local persistence and used only when
    ///   the caller does not provide a `promotionOverride` in the pricing request.
    /// - Throws: Re-throws load/save errors and fails if the cart is not mutable (e.g., non-active),
    ///   according to `loadMutableCart(for:)` / mutation rules.
    /// - Returns: The updated, persisted `Cart`.
    @discardableResult
    func updateSavedPromotionKinds(
        cartID: CartID,
        promotionKinds: [PromotionKind]
    ) async throws -> Cart {
        var cart = try await loadMutableCart(for: cartID)
        cart.savedPromotionKinds = promotionKinds
        return try await saveCartAfterMutation(cart)
    }
    
    /// Clear any persisted promotion kinds for this cart.
    ///
    /// - Note: After clearing, pricing falls back to “no promotions” unless a caller provides a
    ///   `promotionOverride` in the pricing request.
    /// - Throws: Re-throws load/save errors and fails if the cart is not mutable (e.g., non-active),
    ///   according to `loadMutableCart(for:)` / mutation rules.
    /// - Returns: The updated, persisted `Cart`.
    @discardableResult
    func clearSavedPromotionKinds(cartID: CartID) async throws -> Cart {
        var cart = try await loadMutableCart(for: cartID)
        cart.savedPromotionKinds = []
        return try await saveCartAfterMutation(cart)
    }
}
