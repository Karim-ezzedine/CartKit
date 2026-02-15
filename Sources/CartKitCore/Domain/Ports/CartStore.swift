/// Describes filtering and sorting criteria for cart discovery queries.
///
/// Query semantics:
/// - `storeID == nil` matches carts from any store.
/// - `profile` controls guest/profile scope:
///   - `.any` matches all carts, including guest and logged-in.
///   - `.guestOnly` matches guest carts (`Cart.profileID == nil`).
///   - `.profile(id)` matches carts owned by that profile.
/// - `session` controls session scope.
/// - `statuses == nil` (or empty) means no status filter.
/// - `sort` controls ordering of returned carts.
public struct CartQuery: Hashable, Codable, Sendable {

    /// Describes which profile ownership scope to include in query results.
    public enum ProfileFilter: Hashable, Codable, Sendable {
        /// Includes all carts regardless of profile ownership.
        case any

        /// Includes only guest carts (`Cart.profileID == nil`).
        case guestOnly

        /// Includes only carts belonging to the provided profile.
        case profile(UserProfileID)
    }

    /// Describes which session scope to include in query results.
    public enum SessionFilter: Hashable, Codable, Sendable {
        /// Do not filter by session (returns carts for any session, including nil).
        case any
        /// Only sessionless carts (sessionId == nil).
        case sessionless
        /// Only carts in the given session.
        case session(CartSessionID)
    }
    
    public enum Sort: String, Hashable, Codable, Sendable {
        case createdAtAscending
        case createdAtDescending
        case updatedAtAscending
        case updatedAtDescending
    }

    /// Optional store scope.
    ///
    /// - `nil`: Any store.
    /// - Non-`nil`: A single store.
    public let storeID: StoreID?

    /// Profile ownership scope for this query.
    public let profile: ProfileFilter

    /// Session scope for this query.
    public let session: SessionFilter

    /// Optional status scope.
    ///
    /// - `nil`: Any status.
    /// - Empty set: Any status.
    /// - Non-empty set: Only listed statuses.
    public let statuses: Set<CartStatus>?

    /// Sort order for matching carts.
    public let sort: Sort

    /// Creates a cart query with explicit profile scope.
    ///
    /// - Parameters:
    ///   - storeID: Optional store scope. Pass `nil` to match carts across stores.
    ///   - profile: Profile ownership scope.
    ///   - session: Session scope filter.
    ///   - statuses: Optional status filter.
    ///   - sort: Sort order for matching carts.
    public init(
        storeID: StoreID?,
        profile: ProfileFilter,
        session: SessionFilter = .sessionless,
        statuses: Set<CartStatus>? = nil,
        sort: Sort = .updatedAtDescending
    ) {
        self.storeID = storeID
        self.profile = profile
        self.session = session
        self.statuses = statuses
        self.sort = sort
    }

    /// Creates an active-cart query for an explicit profile scope.
    ///
    /// - Parameters:
    ///   - storeID: Store scope.
    ///   - profile: Profile ownership scope.
    ///   - sessionID: Optional session identifier. `nil` maps to `.sessionless`.
    /// - Returns: A query filtered to `.active` carts.
    public static func active(
        storeID: StoreID,
        profile: ProfileFilter,
        sessionID: CartSessionID? = nil
    ) -> CartQuery {
        CartQuery(
            storeID: storeID,
            profile: profile,
            session: sessionID.map(SessionFilter.session) ?? .sessionless,
            statuses: [.active],
            sort: .updatedAtDescending
        )
    }

    /// Creates an active-cart query across stores and sessions for an explicit profile scope.
    ///
    /// - Parameter profile: Profile ownership scope.
    /// - Returns: A query filtered to `.active` carts across all stores and sessions.
    public static func activeAcrossStoresAndSessions(
        profile: ProfileFilter
    ) -> CartQuery {
        CartQuery(
            storeID: nil,
            profile: profile,
            session: .any,
            statuses: [.active],
            sort: .updatedAtDescending
        )
    }

    /// Creates an active-cart query across stores for an explicit profile/session scope.
    ///
    /// - Parameters:
    ///   - profile: Profile ownership scope.
    ///   - sessionID: Optional session identifier. `nil` maps to `.sessionless`.
    /// - Returns: A query filtered to `.active` carts across all stores.
    public static func activeAcrossStores(
        profile: ProfileFilter,
        sessionID: CartSessionID?
    ) -> CartQuery {
        CartQuery(
            storeID: nil,
            profile: profile,
            session: sessionID.map(SessionFilter.session) ?? .sessionless,
            statuses: [.active],
            sort: .updatedAtDescending
        )
    }

}

/// Abstraction over the underlying cart storage.
///
/// Implementations live in separate modules:
/// - CartKitStorageCoreData
/// - CartKitStorageSwiftData
///
/// This protocol is designed as a "port" in a hexagonal / clean architecture:
/// core logic (CartManager, engines) depends on this interface, not on the
/// concrete persistence technology.
public protocol CartStore: Sendable {
    
    /// Loads a single cart by its identifier.
    ///
    /// - Returns: `Cart` if found, otherwise `nil`.
    func loadCart(id: CartID) async throws -> Cart?
    
    /// Persists the given cart (insert or update).
    ///
    /// Implementations should ensure that `updatedAt` is stored as provided by
    /// the caller; the core will be responsible for bumping timestamps.
    func saveCart(_ cart: Cart) async throws
    
    /// Deletes a cart by its identifier.
    ///
    /// Implementations should be idempotent: deleting a missing cart should not throw.
    func deleteCart(id: CartID) async throws
    
    /// Fetches carts matching the given query.
    ///
    /// - Parameters:
    ///   - query: Scope + status filters + ordering.
    ///   - limit: Optional maximum number of carts to return. `nil` = no limit.
    func fetchCarts(
        matching query: CartQuery,
        limit: Int?
    ) async throws -> [Cart]

    /// Fetches all carts across stores/profiles/sessions.
    ///
    /// - Note: Used by infrastructure migrations that need a full snapshot.
    /// - Parameter limit: Optional maximum number of carts to return. `nil` = no limit.
    func fetchAllCarts(limit: Int?) async throws -> [Cart]
}
