/// Aggregated validation result for a unified checkout group (multi-store session).
///
/// A checkout group is identified by `(profileID, sessionID)` and may contain
/// multiple active carts, each scoped to a different `storeID`.
///
/// Policies:
/// - Validation is evaluated per store-cart using `CartValidationEngine`.
/// - Empty carts (no items) are excluded by default.
/// - `isValid` is true only if all included carts are valid.
public struct CheckoutGroupValidationResult: Hashable, Codable, Sendable {

    /// Optional user profile scope (nil = guest).
    public let profileID: UserProfileID?

    /// Optional session scope (nil = legacy sessionless group).
    public let sessionID: CartSessionID?

    /// Validation result for each store cart in the group.
    public let perStore: [StoreID: CartValidationResult]

    /// Convenience summary over `perStore`.
    public var isValid: Bool {
        for result in perStore.values {
            if case .invalid = result { return false }
        }
        return true
    }

    public init(
        profileID: UserProfileID?,
        sessionID: CartSessionID?,
        perStore: [StoreID: CartValidationResult]
    ) {
        self.profileID = profileID
        self.sessionID = sessionID
        self.perStore = perStore
    }
}
