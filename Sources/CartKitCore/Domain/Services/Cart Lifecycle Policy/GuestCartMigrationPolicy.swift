import Foundation

/// Encapsulates business invariants for guest-to-profile cart migration.
///
/// This policy keeps migration rules in the domain layer while leaving
/// persistence and event orchestration to the application facade.
struct GuestCartMigrationPolicy {

    /// Ensures there is an active guest cart available to migrate.
    ///
    /// - Parameters:
    ///   - guestActiveCart: Active guest cart candidate for the migration scope.
    ///   - storeID: Store scope for error reporting.
    /// - Returns: The active guest cart when present.
    /// - Throws: `CartError.conflict` when no active guest cart is available.
    func requireGuestActiveCart(
        _ guestActiveCart: Cart?,
        storeID: StoreID
    ) throws -> Cart {
        guard let guestActiveCart else {
            throw CartError.conflict(
                reason: "No active guest cart found for store \(storeID.rawValue)"
            )
        }
        return guestActiveCart
    }

    /// Ensures the target profile scope does not already have an active cart.
    ///
    /// - Parameters:
    ///   - activeProfileCart: Existing active cart in target profile scope.
    ///   - storeID: Store scope for error reporting.
    ///   - profileID: Target profile scope.
    /// - Throws: `CartError.conflict` when target scope is already occupied.
    func validateTargetScopeIsEmpty(
        activeProfileCart: Cart?,
        storeID: StoreID,
        profileID: UserProfileID
    ) throws {
        guard activeProfileCart == nil else {
            throw CartError.conflict(
                reason: "Profile \(profileID.rawValue) already has an active cart for store \(storeID.rawValue)"
            )
        }
    }

    /// Creates the moved-cart state used by the `.move` migration strategy.
    ///
    /// - Parameters:
    ///   - guestActiveCart: Source active guest cart.
    ///   - profileID: Target profile scope.
    ///   - now: Timestamp used for `updatedAt`.
    /// - Returns: A re-scoped active cart preserving source data and identity.
    func makeMovedCart(
        from guestActiveCart: Cart,
        to profileID: UserProfileID,
        now: Date = Date()
    ) -> Cart {
        Cart(
            id: guestActiveCart.id,
            storeID: guestActiveCart.storeID,
            profileID: profileID,
            sessionID: guestActiveCart.sessionID,
            items: guestActiveCart.items,
            status: .active,
            createdAt: guestActiveCart.createdAt,
            updatedAt: now,
            metadata: guestActiveCart.metadata,
            displayName: guestActiveCart.displayName,
            context: guestActiveCart.context,
            storeImageURL: guestActiveCart.storeImageURL,
            minSubtotal: guestActiveCart.minSubtotal,
            maxItemCount: guestActiveCart.maxItemCount,
            savedPromotionKinds: guestActiveCart.savedPromotionKinds
        )
    }
}
