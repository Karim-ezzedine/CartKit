/// High-level state of a cart.
public enum CartStatus: String, Hashable, Codable, Sendable {
    case active
    case checkedOut
    case cancelled
    case expired
}

public extension CartStatus {

    /// Indicates whether the cart is currently active.
    var isActive: Bool {
        self == .active
    }

    /// Indicates whether the cart is in an archived (non-active) state.
    var isArchived: Bool {
        !isActive
    }

    /// Indicates whether a transition to a new status is allowed.
    ///
    /// Rules:
    /// - A status can always transition to itself.
    /// - An `.active` cart can transition to any non-active status.
    /// - Archived statuses are terminal and cannot transition to a different status.
    ///
    /// - Parameter newStatus: Candidate next status.
    /// - Returns: `true` when the transition is valid.
    func canTransition(to newStatus: CartStatus) -> Bool {
        if self == newStatus {
            return true
        }

        return isActive && newStatus.isArchived
    }
}
