/// Parameters used to fetch carts from a CartStore.
///
/// Semantics:
/// - `storeID` is always required.
/// - `profileID == nil` means "guest carts for this store".
/// - `profileID != nil` means "carts for that profile in this store".
/// - `sessionID == nil` means "do not filter by session".
/// - `sessionID != nil` filters carts belonging to that session.
/// - `statuses == nil` means "any status".
/// - `statuses != nil` filters by the given statuses.
/// - `sort` controls ordering of the returned array.
public struct CartQuery: Hashable, Codable, Sendable {
    
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
    
    /// Optional store scope:
    /// - nil => any store
    /// - non-nil => only that store
    public let storeID: StoreID?
    public let profileID: UserProfileID?
    public let session: SessionFilter
    public let statuses: Set<CartStatus>?
    public let sort: Sort
    
    public init(
        storeID: StoreID?,
        profileID: UserProfileID? = nil,
        session: SessionFilter = .sessionless,
        statuses: Set<CartStatus>? = nil,
        sort: Sort = .updatedAtDescending
    ) {
        self.storeID = storeID
        self.profileID = profileID
        self.session = session
        self.statuses = statuses
        self.sort = sort
    }
    
    /// Convenience for querying active carts only.
    public static func active(
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID? = nil
    ) -> CartQuery {
        CartQuery(
            storeID: storeID,
            profileID: profileID,
            session: sessionID.map(SessionFilter.session) ?? .sessionless,
            statuses: [.active],
            sort: .updatedAtDescending
        )
    }
    
    /// discover all active carts for a profile across stores & sessions.
    public static func activeAcrossStoresAndSessions(
        profileID: UserProfileID?
    ) -> CartQuery {
        CartQuery(
            storeID: nil,
            profileID: profileID,
            session: .any,
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
}
