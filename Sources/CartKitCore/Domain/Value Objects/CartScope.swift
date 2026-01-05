/// Identifies the "scope" of a cart: one store, optionally one profile.
///
/// CartKit guarantees **at most one active cart per scope**:
/// - (storeID, profileID) for logged-in users
/// - (storeID, nil)       for guest users
///
/// Other carts for the same scope may exist with non-active statuses
/// (e.g., `.checkedOut`, `.cancelled`, `.expired`).
public struct CartScopeKey: Hashable, Codable, Sendable {
    public let storeID: StoreID
    public let profileID: UserProfileID?

    public init(storeID: StoreID, profileID: UserProfileID?) {
        self.storeID = storeID
        self.profileID = profileID
    }

    /// Convenience constructor for a guest scope (no profile).
    public static func guest(storeID: StoreID) -> CartScopeKey {
        CartScopeKey(storeID: storeID, profileID: nil)
    }

    /// `true` when this scope represents a guest (no profile attached).
    public var isGuest: Bool {
        profileID == nil
    }
}

public extension Cart {

    /// Scope key derived from this cart's store and profile.
    ///
    /// This is what `CartManager` and storage implementations will
    /// use to enforce "one active cart per store/profile combination".
    var scopeKey: CartScopeKey {
        CartScopeKey(storeID: storeID, profileID: profileID)
    }
}

