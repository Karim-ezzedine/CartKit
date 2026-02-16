import Foundation

public extension CartManager {
    // MARK: - Cart lifecycle
    
    /// Simple read helper (keeps consumers talking to the facade).
    func getCart(id: CartID) async throws -> Cart? {
        try await config.cartStore.loadCart(id: id)
    }

    /// Returns carts matching a query without exposing storage adapters to callers.
    ///
    /// - Parameters:
    ///   - query: Scope, status, and sort criteria.
    ///   - limit: Optional maximum number of carts to return. `nil` means no limit.
    /// - Returns: Carts that match the provided query.
    /// - Throws: Any error thrown by the underlying `CartStore`.
    func queryCarts(
        matching query: CartQuery,
        limit: Int? = nil
    ) async throws -> [Cart] {
        try await config.cartStore.fetchCarts(matching: query, limit: limit)
    }
    
    /// Ensures there is a single active cart for the given scope.
    ///
    /// If an active cart already exists, it is returned.
    /// If not, a new empty active cart is created.
    @discardableResult
    func setActiveCart(
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID? = nil,
        displayName: String? = nil,
        context: String? = nil,
        storeImageURL: URL? = nil,
        metadata: [String: String] = [:],
        minSubtotal: Money? = nil,
        maxItemCount: Int? = nil,
        savedPromotionKinds: [PromotionKind] = []
    ) async throws -> Cart {
        // Try to find an existing active cart for this scope.
        if let cart = try await getActiveCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID
        ) {
            return cart
        }
        
        // No active cart? Create a new one.
        let newCart = try await createCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            displayName: displayName,
            context: context,
            storeImageURL: storeImageURL,
            metadata: metadata,
            minSubtotal: minSubtotal,
            maxItemCount: maxItemCount,
            status: .active,
            savedPromotionKinds: savedPromotionKinds
        )
        
        return newCart
    }
    
    /// Returns active carts grouped by `sessionID` for the given profile (or guest).
    ///
    /// This is a discovery API used to support flows where multiple active checkout groups can exist
    /// concurrently (e.g., GroupA, GroupB, GroupC). Each returned group contains only `.active` carts,
    /// sorted by most recent activity, and groups are ordered by their latest `updatedAt`.
    ///
    /// - Parameter profileID: The user profile to fetch carts for. Pass `nil` to fetch guest carts.
    /// - Returns: An array of `ActiveCartGroup` where each group corresponds to a `sessionID` (including `nil`),
    ///            and contains the active carts in that group.
    /// - Throws: Any error thrown by the underlying `CartStore`.
    func getActiveCartGroups(
        profileID: UserProfileID? = nil
    ) async throws -> [ActiveCartGroup] {
        try await discoveryService.activeCartGroups(profileID: profileID)
    }
    
    /// Returns the active cart for a given scope, if any.
    func getActiveCart(
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID? = nil
    ) async throws -> Cart? {
        try await discoveryService.activeCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID
        )
    }
    
    /// Updates the status of a cart, enforcing lifecycle and validation rules.
    ///
    /// Allowed transitions:
    /// - `.active` → `.checkedOut`, `.cancelled`, `.expired`
    /// - Any status → same status (no-op)
    ///
    /// Once a cart is non-active, it is treated as terminal and its status cannot be
    /// changed again. This rule applies equally to guest and logged-in carts.
    ///
    /// When transitioning to `.checkedOut`, the cart is first validated via
    /// the configured `CartValidationEngine.validate(cart:)`. If validation
    /// fails, a `CartError.validationFailed` is thrown.
    @discardableResult
    func updateStatus(
        for cartID: CartID,
        to newStatus: CartStatus
    ) async throws -> Cart {
        var cart = try await loadCartForStatusChange(id: cartID)
        
        let oldStatus = cart.status
        try ensureValidStatusTransition(from: oldStatus, to: newStatus)
        
        // If nothing changes, short-circuit.
        if oldStatus == newStatus {
            return cart
        }
        
        // If we're checking out, enforce full-cart validation first.
        if newStatus == .checkedOut {
            
            guard cart.profileID != nil else {
                throw CartError.validationFailed(
                    reason: "Profile ID is missing, cannot update cart status to checkedOut"
                )
            }
            
            let result = await config.validationEngine.validate(cart: cart)
            switch result {
            case .valid:
                break
            case .invalid(let error):
                throw CartError.validationFailed(reason: error.message)
            }
        }
        
        cart.status = newStatus
        let updatedCart = try await saveCartAfterMutation(cart)
        
        // If we are moving away from `.active`, signal that there is no
        // longer an active cart for this scope. (A new one can be created
        // later via `setActiveCart`.)
        if oldStatus == .active, newStatus != .active {
            signalActiveCartChanged(
                storeID: updatedCart.storeID,
                profileID: updatedCart.profileID,
                newActiveCartID: nil,
                sessionId: updatedCart.sessionID
            )
        }
        
        return updatedCart
    }

    /// Updates cart-level metadata (name, context, image, metadata).
    ///
    /// This only operates on active carts; non-active carts will cause a conflict error.
    /// Passing `nil` for parameters keeps the existing value as-is.
    @discardableResult
    func updateCartDetails(
        cartID: CartID,
        displayName: String? = nil,
        context: String? = nil,
        storeImageURL: URL? = nil,
        metadata: [String: String]? = nil,
        minSubtotal: Money? = nil,
        maxItemCount: Int? = nil,
        savedPromotionKinds: [PromotionKind]? = nil
    ) async throws -> Cart {
        var cart = try await loadMutableCart(for: cartID)
        
        if let displayName {
            cart.displayName = displayName
        }
        if let context {
            cart.context = context
        }
        if let storeImageURL {
            cart.storeImageURL = storeImageURL
        }
        if let metadata {
            cart.metadata = metadata
        }
        if let minSubtotal {
            cart.minSubtotal = minSubtotal
        }
        if let maxItemCount {
            cart.maxItemCount = maxItemCount
        }
        if let savedPromotionKinds {
            cart.savedPromotionKinds = savedPromotionKinds
        }
        
        let updatedCart = try await saveCartAfterMutation(cart)
        return updatedCart
    }
    
    /// Deletes a cart by its identifier.
    ///
    /// - Behavior:
    ///   - If the cart does not exist, the operation is a no-op (idempotent).
    ///   - If it exists, it is removed from storage and `cartDeleted` is emitted.
    ///   - If the deleted cart was active for its scope, `activeCartChanged`
    ///     is emitted with `newActiveCartId == nil`.
    func deleteCart(id: CartID) async throws {
        guard let cart = try await config.cartStore.loadCart(id: id) else {
            // Already gone; treat as successful.
            return
        }
        
        _ = try await deleteCartAndEmit(id)
        
        if cart.status == .active {
            signalActiveCartChanged(
                storeID: cart.storeID,
                profileID: cart.profileID,
                newActiveCartID: nil,
                sessionId: cart.sessionID
            )
        }
    }
    
    /// Creates a new active cart by copying a source cart (reorder use case).
    ///
    /// The reorder flow:
    /// - expires the current active cart for the same scope (if any),
    /// - creates a new cart with regenerated `CartItemID`s,
    /// - persists it and emits `activeCartChanged`.
    func reorder(from sourceCartID: CartID) async throws -> Cart {
        let source = try await loadCartOrThrow(sourceCartID)
        // Enforce one-active-per-scope by expiring the current active cart (if any)
        try await expireActiveCartIfNeeded(
            storeID: source.storeID,
            profileID: source.profileID,
            sessionID: source.sessionID
        )
        let newCart = makeActiveCartCopy(from: source, profileID: source.profileID)
        return try await persistNewCart(newCart, setAsActive: true)
    }

    /// Migrates the active guest cart to a logged-in profile for a given store and session scope.
    ///
    /// Strategies:
    /// - `.move`: re-scopes the same cart to the profile (same `CartID`).
    /// - `.copyAndDelete`: creates a new profile cart copy and deletes the guest cart.
    ///
    /// If the profile already has an active cart for the store+session scope, the migration fails with a conflict error.
    ///
    /// - Important:
    ///   - `.move` must emit `activeCartChanged` for both the old (guest) scope and the new (profile) scope,
    ///     because the cart’s scope changes without deletion.
    func migrateGuestActiveCart(
        storeID: StoreID,
        to profileID: UserProfileID,
        strategy: GuestMigrationStrategy,
        sessionID: CartSessionID? = nil
    ) async throws -> Cart {

        // Find active guest cart in this scope.
        guard let guestActive = try await getActiveCart(
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID
        ) else {
            throw CartError.conflict(
                reason: "No active guest cart found for store \(storeID.rawValue)"
            )
        }

        // Enforce invariant: profile must not already have an active cart in the same scope.
        if try await getActiveCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID
        ) != nil {
            throw CartError.conflict(
                reason: "Profile \(profileID.rawValue) already has an active cart for store \(storeID.rawValue)"
            )
        }

        switch strategy {
        case .move:
            // Capture old scope (guest) before changing it.
            let oldStoreID = guestActive.storeID
            let oldSessionID = guestActive.sessionID   // should match sessionID input, but use the source of truth

            let moved = Cart(
                id: guestActive.id,
                storeID: guestActive.storeID,
                profileID: profileID,
                sessionID: guestActive.sessionID,
                items: guestActive.items,
                status: .active,
                createdAt: guestActive.createdAt,
                updatedAt: Date(),
                metadata: guestActive.metadata,
                displayName: guestActive.displayName,
                context: guestActive.context,
                storeImageURL: guestActive.storeImageURL,
                minSubtotal: guestActive.minSubtotal,
                maxItemCount: guestActive.maxItemCount,
                savedPromotionKinds: guestActive.savedPromotionKinds
            )

            let saved = try await saveCartAfterMutation(moved)

            // Old scope (guest) no longer has an active cart.
            signalActiveCartChanged(
                storeID: oldStoreID,
                profileID: nil,
                newActiveCartID: nil,
                sessionId: oldSessionID
            )

            // New scope (profile) now has an active cart.
            signalActiveCartChanged(
                storeID: saved.storeID,
                profileID: profileID,
                newActiveCartID: saved.id,
                sessionId: saved.sessionID
            )

            return saved

        case .copyAndDelete:
            // Copy strategy already emits:
            // - persistNewCart(..., setAsActive: true) => activeCartChanged for the NEW profile scope
            // - deleteCart(guestActive.id)            => activeCartChanged(nil) for the OLD guest scope
            let newCart = makeActiveCartCopy(from: guestActive, profileID: profileID)
            let saved = try await persistNewCart(newCart, setAsActive: true)

            try await deleteCart(id: guestActive.id)
            return saved
        }
    }
}
