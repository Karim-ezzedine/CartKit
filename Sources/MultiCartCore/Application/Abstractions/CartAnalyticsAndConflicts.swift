import Foundation

/// Receives cart-related events so the host app can plug into analytics/logging.
///
/// Called by CartManager **after successful operations**:
/// - cartCreated / cartUpdated / cartDeleted
/// - active cart switches
/// - item added/updated/removed.
///
/// Methods are synchronous and non-throwing on purpose; implementations
/// should offload heavy work to their own queues if needed.
public protocol CartAnalyticsSink: Sendable {
    
    // MARK: - Cart lifecycle
    
    func cartCreated(_ cart: Cart)
    func cartUpdated(_ cart: Cart)
    func cartDeleted(id: CartID)
    
    func activeCartChanged(
        newActiveCartId: CartID?,
        storeId: StoreID,
        profileId: UserProfileID?
    )
    
    // MARK: - Items
    
    func itemAdded(_ item: CartItem, in cart: Cart)
    func itemUpdated(_ item: CartItem, in cart: Cart)
    func itemRemoved(
        itemId: CartItemID,
        from cart: Cart
    )
}

/// Handles situations where the cart becomes inconsistent with the
/// current business / catalog state (removed items, price changes, etc.).
///
/// Called by CartManager in flows that detect conflicts, for example:
/// - after refreshing catalog data and finding missing products,
/// - when prices have diverged from the current store catalog,
/// - when new business rules invalidate the cart configuration.
public protocol CartConflictResolver: Sendable {
    
    /// Given a conflicting cart + reason, decide how to proceed.
    func resolveConflict(
        for cart: Cart,
        reason: MultiCartError
    ) async -> CartConflictResolution
}

