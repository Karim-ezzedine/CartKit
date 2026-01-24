/// Events emitted by `CartManager` after successful persistence.
/// Intended for UI refresh, caching, and integrations.
public enum CartEvent: Sendable, Equatable {
    case cartCreated(CartID)
    case cartUpdated(CartID)
    case cartDeleted(CartID)
    
    /// Active cart changed for a specific scope.
    case activeCartChanged(
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID?,
        cartID: CartID?
    )
}
