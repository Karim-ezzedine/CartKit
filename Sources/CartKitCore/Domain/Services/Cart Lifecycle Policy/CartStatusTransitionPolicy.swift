/// Encapsulates lifecycle transition rules for carts.
///
/// This policy centralizes status-transition invariants so facade orchestration
/// can delegate rule decisions to the domain layer.
struct CartStatusTransitionPolicy {

    /// Ensures a status transition is allowed for the provided cart.
    ///
    /// Rules:
    /// - A transition must satisfy `CartStatus.canTransition(to:)`.
    /// - Transitioning to `.checkedOut` requires a non-guest cart (`profileID != nil`).
    ///
    /// - Parameters:
    ///   - cart: Current cart snapshot.
    ///   - newStatus: Candidate status.
    /// - Throws:
    ///   - `CartError.conflict` when the status transition is invalid.
    ///   - `CartError.validationFailed` when checkout is requested for a guest cart.
    func validateTransition(
        for cart: Cart,
        to newStatus: CartStatus
    ) throws {
        guard cart.status.canTransition(to: newStatus) else {
            throw CartError.conflict(reason: "Invalid cart status transition")
        }

        if newStatus == .checkedOut, cart.profileID == nil {
            throw CartError.validationFailed(
                reason: "Profile ID is missing, cannot update cart status to checkedOut"
            )
        }
    }

    /// Indicates whether active-cart tracking should be cleared for a transition.
    ///
    /// - Parameters:
    ///   - oldStatus: Previous status.
    ///   - newStatus: Next status.
    /// - Returns: `true` when transitioning from active to archived.
    func shouldClearActiveCart(
        from oldStatus: CartStatus,
        to newStatus: CartStatus
    ) -> Bool {
        oldStatus.isActive && newStatus.isArchived
    }

    /// Indicates whether a transition requires full-cart validation before save.
    ///
    /// - Parameters:
    ///   - oldStatus: Previous status.
    ///   - newStatus: Next status.
    /// - Returns: `true` when transitioning from active to checked out.
    func requiresFullValidation(
        from oldStatus: CartStatus,
        to newStatus: CartStatus
    ) -> Bool {
        oldStatus.isActive && newStatus == .checkedOut
    }
}
