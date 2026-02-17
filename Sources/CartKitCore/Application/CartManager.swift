import Foundation
import Combine

/// High-level facade / application service for working with carts.
///
/// Responsibilities:
/// - Enforce "one active cart per (storeID, profileID?, sessionID? )" at the API level
/// - Orchestrate domain services (validation, promotions, pricing, conflicts).
/// - Persist changes via CartStore and emit analytics events.
///
/// `CartManager` is implemented as an `actor` to provide safe concurrent
/// access from multiple tasks.
public actor CartManager {
    
    // MARK: - Dependencies
    
    let config: CartConfiguration

    /// Discovery collaborator for read/query use cases.
    var discoveryService: CartDiscoveryService {
        CartDiscoveryService(cartStore: config.cartStore)
    }

    /// Pricing collaborator for totals orchestration.
    var pricingOrchestrator: CartPricingOrchestrator {
        CartPricingOrchestrator(
            pricingEngine: config.pricingEngine,
            promotionEngine: config.promotionEngine
        )
    }

    /// Domain policy for active cart-group eligibility and uniqueness rules.
    var activeCartGroupPolicy: ActiveCartGroupPolicy {
        ActiveCartGroupPolicy()
    }

    /// Domain policy for cart lifecycle status transitions.
    var cartStatusTransitionPolicy: CartStatusTransitionPolicy {
        CartStatusTransitionPolicy()
    }

    /// Domain policy for guest-to-profile migration invariants.
    var guestCartMigrationPolicy: GuestCartMigrationPolicy {
        GuestCartMigrationPolicy()
    }
    
    // MARK: - Init
    
    public init(configuration: CartConfiguration) {
        self.config = configuration
    }
    
    // MARK: - Observes

    private typealias ObserverID = UUID
    private var eventObservers: [ObserverID: AsyncStream<CartEvent>.Continuation] = [:]
    
    /// Observes cart events emitted by this `CartManager` instance.
    ///
    /// Events are emitted only after successful persistence (save/delete).
    public func observeEvents() -> AsyncStream<CartEvent> {
        AsyncStream { continuation in
            let id = ObserverID()
            eventObservers[id] = continuation

            continuation.onTermination = { [id] _ in
                Task { await self.removeObserver(id) }
            }
        }
    }
    
    /// Combine wrapper for `observeEvents()`.
    /// - Note: `async` is required because `CartManager` is an actor and this calls an actor-isolated method.
    public func eventsPublisher() async -> AnyPublisher<CartEvent, Never> {
        let stream = observeEvents()
        return AsyncStreamPublisher(stream).eraseToAnyPublisher()
    }
    
    private func removeObserver(_ id: ObserverID) {
        eventObservers[id] = nil
    }

    private func emit(_ event: CartEvent) {
        for continuation in eventObservers.values {
            continuation.yield(event)
        }
    }
    
    // MARK: - Helpers
    
    /// Creates a new cart for the given store + optional profile.
    @discardableResult
    func createCart(
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID? = nil,
        displayName: String? = nil,
        context: String? = nil,
        storeImageURL: URL? = nil,
        metadata: [String: String] = [:],
        minSubtotal: Money? = nil,
        maxItemCount: Int? = nil,
        status: CartStatus,
        savedPromotionKinds: [PromotionKind] = []
    ) async throws -> Cart {
        let now = Date()
        
        let cart = Cart(
            id: CartID.generate(),
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            items: [],
            status: status,
            createdAt: now,
            updatedAt: now,
            metadata: metadata,
            displayName: displayName,
            context: context,
            storeImageURL: storeImageURL,
            minSubtotal: minSubtotal,
            maxItemCount: maxItemCount,
            savedPromotionKinds: savedPromotionKinds
        )
        
        return try await persistNewCart(cart, setAsActive: status == .active)
    }
    
    /// Loads a cart and enforces that it is present and mutable.
    ///
    /// Currently this means:
    /// - The cart exists in the underlying store.
    /// - The cart has `status == .active`.
    ///
    /// Non-existing or non-active carts result in a `CartError.conflict`
    /// so that callers know the operation cannot proceed on this cart.
    func loadMutableCart(for id: CartID) async throws -> Cart {
        let cart = try await loadCartOrThrow(id)
        
        guard cart.status.isActive else {
            throw CartError.conflict(reason: "Cart is not active")
        }
        
        return cart
    }
    
    /// Validates a proposed item change against the configured validation engine.
    ///
    /// This helper calls `CartValidationEngine.validateItemChange(in:proposedItem:)`
    /// and translates the resulting `CartValidationResult` into a `CartError`
    /// when the change is not allowed.
    ///
    /// - Parameters:
    ///   - cart: The current cart snapshot before applying the change.
    ///   - item: The item state we want to apply to the cart.
    /// - Throws: `CartError.validationFailed` when the validation engine
    ///           reports an invalid change.
    func validateItemChange(
        in cart: Cart,
        item: CartItem
    ) async throws {
        let result = await config.validationEngine.validateItemChange(
            in: cart,
            proposedItem: item
        )
        
        switch result {
        case .valid:
            return
        case .invalid(let error):
            throw CartError.validationFailed(reason: error.message)
        }
    }
    
    /// Persists a mutated cart and emits a `cartUpdated` analytics event.
    ///
    /// This helper is responsible for:
    /// - bumping `updatedAt` to the current time,
    /// - saving the cart through the configured `CartStore`,
    /// - notifying the `CartAnalyticsSink` that the cart was updated.
    ///
    /// - Parameter cart: The cart after in-memory mutations.
    /// - Returns: The saved cart, with its `updatedAt` field refreshed.
    /// - Throws: Any error thrown by the underlying `CartStore`.
    func saveCartAfterMutation(_ cart: Cart) async throws -> Cart {
        var mutableCart = cart
        mutableCart.updatedAt = Date()
        try await config.cartStore.saveCart(mutableCart)
        config.analyticsSink.cartUpdated(mutableCart)
        emit(.cartUpdated(mutableCart.id))
        return mutableCart
    }
    
    /// Clones cart items while regenerating their identities.
    ///
    /// Used during cart duplication/reorder to preserve item contents
    /// while avoiding identity coupling between the source and new cart.
    private func cloneItemsRegeneratingIDs(from items: [CartItem]) -> [CartItem] {
        items.map { item in
            CartItem(
                id: CartItemID.generate(),
                productID: item.productID,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                totalPrice: item.totalPrice,
                modifiers: item.modifiers,
                imageURL: item.imageURL,
                availableStock: item.availableStock
            )
        }
    }
    
    /// Creates a new active cart by copying the contents of an existing cart.
    ///
    /// Used by:
    /// - Reorder flows.
    /// - Guest → profile migration (copy strategy).
    ///
    /// The new cart:
    /// - Has a new `CartID`,
    /// - Regenerates all `CartItemID`s,
    /// - Resets timestamps,
    /// - Preserves cart-level metadata and configuration.
    func makeActiveCartCopy(
        from source: Cart,
        profileID: UserProfileID?
    ) -> Cart {
        let now = Date()
        return Cart(
            id: CartID.generate(),
            storeID: source.storeID,
            profileID: profileID,
            sessionID: source.sessionID,
            items: cloneItemsRegeneratingIDs(from: source.items),
            status: .active,
            createdAt: now,
            updatedAt: now,
            metadata: source.metadata,
            displayName: source.displayName,
            context: source.context,
            storeImageURL: source.storeImageURL,
            minSubtotal: source.minSubtotal,
            maxItemCount: source.maxItemCount,
            savedPromotionKinds: source.savedPromotionKinds
        )
    }
    
    /// Persists a newly-created cart and emits creation analytics.
    ///
    /// Optionally emits `activeCartChanged` when the cart should become
    /// the active cart for its scope.
    @discardableResult
    func persistNewCart(
        _ cart: Cart,
        setAsActive: Bool
    ) async throws -> Cart {
        try await config.cartStore.saveCart(cart)
        config.analyticsSink.cartCreated(cart)
        emit(.cartCreated(cart.id))
        config.logger.log("Cart created: \(cart.id.rawValue)")

        if setAsActive {
            signalActiveCartChanged(
                storeID: cart.storeID,
                profileID: cart.profileID,
                newActiveCartID: cart.id,
                sessionId: cart.sessionID
            )
        }

        return cart
    }

    /// Deletes a cart by id and emits deletion side-effects.
    ///
    /// - Important:
    ///   - Does NOT handle active-cart semantics.
    ///   - Caller is responsible for active-cart logic if needed.
    @discardableResult
    func deleteCartAndEmit(_ id: CartID) async throws -> CartID {
        try await config.cartStore.deleteCart(id: id)
        config.analyticsSink.cartDeleted(id: id)
        emit(.cartDeleted(id))
        config.logger.log("Cart deleted: \(id.rawValue)")
        return id
    }
    
    /// Expires the currently active cart for the given scope, if one exists.
    ///
    /// Used to enforce the invariant:
    /// - Only one active cart per `(storeID, profileID?, sessionID?)` scope.
    func expireActiveCartIfNeeded(
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID?
    ) async throws {
        if let active = try await getActiveCart(storeID: storeID, profileID: profileID, sessionID: sessionID) {
            var expired = active
            expired.status = .expired
            _ = try await saveCartAfterMutation(expired)
        }
    }
    
    /// Loads a cart by ID or throws a conflict error if it does not exist.
    ///
    /// Centralizes the \"cart not found\" error handling.
    func loadCartOrThrow(_ id: CartID) async throws -> Cart {
        guard let cart = try await config.cartStore.loadCart(id: id) else {
            throw CartError.conflict(reason: "Cart not found")
        }
        return cart
    }
    
    /// Detects catalog conflicts for a proposed cart and optionally resolves them.
    ///
    /// - Returns:
    ///   - `cartToPersist`: the cart that should be persisted (original or resolved),
    ///   - `conflicts`: the detected catalog conflicts (always returned when present).
    func detectAndResolveCatalogConflictsIfNeeded(
        for proposedCart: Cart
    ) async throws -> (cartToPersist: Cart, conflicts: [CartCatalogConflict]) {

        let conflicts = await config.catalogConflictDetector.detectConflicts(for: proposedCart)

        // No conflicts → persist as-is.
        guard !conflicts.isEmpty else {
            return (proposedCart, [])
        }
        
        config.logger.log(
            "Catalog conflicts detected:\ncart=\(proposedCart.id.rawValue),\nstore=\(proposedCart.storeID.rawValue), profile=\(proposedCart.profileID?.rawValue ?? "guest"),\ncount=\(conflicts.count),\nsessionID= \(proposedCart.sessionID?.rawValue ?? "nil")"
        )


        // Conflicts, but no resolver configured → persist as-is and report conflicts.
        guard let resolver = config.conflictResolver else {
            config.logger.log(
                "Catalog conflicts present, no resolver configured:\npersisting as-is (cart=\(proposedCart.id.rawValue))"
            )
            return (proposedCart, conflicts)
        }

        // Conflicts + resolver → let client decide the policy.
        let reason = CartError.conflict(reason: "Cart has catalog conflicts")
        let resolution = await resolver.resolveConflict(for: proposedCart, reason: reason)

        switch resolution {
        case .acceptModifiedCart(let resolvedCart):
            let modified = resolvedCart.id != proposedCart.id
                || resolvedCart.items != proposedCart.items
                || resolvedCart.status != proposedCart.status

            config.logger.log(
                "Catalog conflicts resolved:\ndecision=acceptModifiedCart,\nmodified=\(modified),\ncart=\(proposedCart.id.rawValue)"
            )
            return (resolvedCart, conflicts)

        case .rejectWithError(let error):
            config.logger.log(
                "Catalog conflicts resolved:\ndecision=rejectWithError,\ncart=\(proposedCart.id.rawValue),\nerror=\(String(describing: error))"
            )
            throw error
        }
    }

    /// Emits the active-cart change side-effects (analytics + event) for a given scope.
    func signalActiveCartChanged(
        storeID: StoreID,
        profileID: UserProfileID?,
        newActiveCartID: CartID?,
        sessionId: CartSessionID?
    ) {
        config.analyticsSink.activeCartChanged(
            newActiveCartId: newActiveCartID,
            storeId: storeID,
            profileId: profileID,
            sessionId: sessionId
        )
        emit(.activeCartChanged(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionId,
            cartID: newActiveCartID
        ))
        config.logger.log(
            "Active cart changed:\nstore=\(storeID.rawValue),\nprofile=\(profileID?.rawValue ?? "guest"),\ncart=\(newActiveCartID?.rawValue ?? "nil"),\nsessionID=\(sessionId?.rawValue ?? "nil")"
        )
    }
    
    /// Deletes carts by ID and emits the corresponding lifecycle events.
    ///
    /// - Returns: A deterministic `CartCleanupResult` (IDs sorted ascending).
    /// - Throws: Any error thrown by the underlying store deletion path.
    func deleteCarts(_ ids: Set<CartID>) async throws -> CartCleanupResult {
        var deleted: [CartID] = []
        deleted.reserveCapacity(ids.count)
        
        for id in ids {
            try await deleteCartAndEmit(id)
            deleted.append(id)
        }
        
        deleted.sort { $0.rawValue < $1.rawValue }
        return CartCleanupResult(deletedCartIDs: deleted)
    }
    
}
