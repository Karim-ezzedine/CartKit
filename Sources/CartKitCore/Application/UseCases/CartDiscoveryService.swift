import Foundation

/// Provides query and discovery operations for carts.
///
/// This service centralizes cart query construction and fetch behavior so
/// facade-level APIs can remain focused on orchestration.
struct CartDiscoveryService {

    /// Backing store used for all discovery reads.
    let cartStore: CartStore

    /// Creates a new discovery service.
    ///
    /// - Parameter cartStore: Cart storage adapter used to fetch carts.
    init(cartStore: CartStore) {
        self.cartStore = cartStore
    }

    /// Returns the active cart for a specific store/profile/session scope.
    ///
    /// - Parameters:
    ///   - storeID: Store scope.
    ///   - profileID: Optional profile scope; `nil` means guest scope.
    ///   - sessionID: Optional session scope.
    /// - Returns: The active cart if one exists.
    func activeCart(
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID?
    ) async throws -> Cart? {
        let query = CartQuery.active(
            storeID: storeID,
            profile: profileFilter(for: profileID),
            sessionID: sessionID
        )
        let carts = try await cartStore.fetchCarts(matching: query, limit: 1)
        return carts.first
    }

    /// Returns active carts across stores for a profile/session group.
    ///
    /// - Parameters:
    ///   - profileID: Optional profile scope; `nil` means guest scope.
    ///   - sessionID: Optional session scope.
    /// - Returns: Active carts across all stores for the provided group.
    func activeCartsAcrossStores(
        profileID: UserProfileID?,
        sessionID: CartSessionID?
    ) async throws -> [Cart] {
        let query = CartQuery.activeAcrossStores(
            profile: profileFilter(for: profileID),
            sessionID: sessionID
        )
        return try await cartStore.fetchCarts(matching: query, limit: nil)
    }

    /// Returns active carts grouped by session for a profile scope.
    ///
    /// - Parameter profileID: Optional profile scope; `nil` means guest scope.
    /// - Returns: Active cart groups ordered by most-recent update.
    func activeCartGroups(
        profileID: UserProfileID?
    ) async throws -> [ActiveCartGroup] {
        let query = CartQuery.activeAcrossStoresAndSessions(
            profile: profileFilter(for: profileID)
        )
        let carts = try await cartStore.fetchCarts(matching: query, limit: nil)
        return groupedBySession(carts)
    }

    /// Returns carts for an arbitrary scope.
    ///
    /// - Parameters:
    ///   - storeID: Optional store scope. `nil` means any store.
    ///   - profileID: Optional profile scope. `nil` means guest scope.
    ///   - session: Session scope.
    ///   - statuses: Optional status filter.
    ///   - sort: Sort order.
    ///   - limit: Optional result limit.
    /// - Returns: Carts matching the provided filters.
    func carts(
        storeID: StoreID?,
        profileID: UserProfileID?,
        session: CartQuery.SessionFilter,
        statuses: Set<CartStatus>?,
        sort: CartQuery.Sort,
        limit: Int?
    ) async throws -> [Cart] {
        let query = CartQuery(
            storeID: storeID,
            profile: profileFilter(for: profileID),
            session: session,
            statuses: statuses,
            sort: sort
        )
        return try await cartStore.fetchCarts(matching: query, limit: limit)
    }

    /// Converts an optional profile identifier into a query profile filter.
    ///
    /// - Parameter profileID: Optional profile identifier.
    /// - Returns: `.profile(profileID)` for logged-in scope or `.guestOnly` for guest scope.
    private func profileFilter(for profileID: UserProfileID?) -> CartQuery.ProfileFilter {
        profileID.map(CartQuery.ProfileFilter.profile) ?? .guestOnly
    }

    /// Groups carts by session and sorts both carts and groups by `updatedAt` descending.
    ///
    /// - Parameter carts: Source carts.
    /// - Returns: Session groups ordered by latest update.
    private func groupedBySession(_ carts: [Cart]) -> [ActiveCartGroup] {
        let grouped = Dictionary(grouping: carts, by: \.sessionID)
        return grouped
            .map { sessionID, sessionCarts in
                ActiveCartGroup(
                    sessionID: sessionID,
                    carts: sessionCarts.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted {
                ($0.carts.first?.updatedAt ?? .distantPast) > ($1.carts.first?.updatedAt ?? .distantPast)
            }
    }
}
