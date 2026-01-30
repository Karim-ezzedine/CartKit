import CartKitCore

/// Simple in-memory implementation of `CartStore`.
///
/// This is primarily intended for:
/// - unit tests / previews,
/// - local demo environments.
///
/// Thread-safety is handled by making the store an `actor`, so all access
/// to the internal storage is serialized.
public actor InMemoryCartStore: CartStore {
    
    // MARK: - Storage
    
    private var cartsByID: [CartID: Cart] = [:]
    
    // MARK: - Init
    
    /// Creates a new in-memory store, optionally seeded with carts.
    public init(initialCarts: [Cart] = []) {
        for cart in initialCarts {
            cartsByID[cart.id] = cart
        }
    }
    
    // MARK: - CartStore
    
    public func loadCart(id: CartID) async throws -> Cart? {
        return cartsByID[id]
    }
    
    public func saveCart(_ cart: Cart) async throws {
        cartsByID[cart.id] = cart
    }
    
    public func deleteCart(id: CartID) async throws {
        cartsByID[id] = nil
    }
    
    public func fetchCarts(
        matching query: CartQuery,
        limit: Int?
    ) async throws -> [Cart] {
        // Start from all carts as an Array
        var result = Array(cartsByID.values)
        
        // Filter by store (optional: nil means any store)
        if let storeID = query.storeID {
            result = result.filter { $0.storeID == storeID }
        }

        // Filter by profile (guest vs logged-in)
        if let profileID = query.profileID {
            result = result.filter { $0.profileID == profileID }
        } else {
            result = result.filter { $0.profileID == nil }
        }

        // Filter by session (3-state)
        switch query.session {
        case .any:
            break
        case .sessionless:
            result = result.filter { $0.sessionID == nil }
        case .session(let sessionID):
            result = result.filter { $0.sessionID == sessionID }
        }

        // Filter by status set, if provided (treat empty as no filter, consistent with adapters)
        if let statuses = query.statuses, !statuses.isEmpty {
            result = result.filter { statuses.contains($0.status) }
        }
        
        // Sort
        let sorted: [Cart] = result.sorted { lhs, rhs in
            switch query.sort {
            case .createdAtAscending:
                return lhs.createdAt < rhs.createdAt
            case .createdAtDescending:
                return lhs.createdAt > rhs.createdAt
            case .updatedAtAscending:
                return lhs.updatedAt < rhs.updatedAt
            case .updatedAtDescending:
                return lhs.updatedAt > rhs.updatedAt
            }
        }
        
        // Apply limit.
        if let limit, limit >= 0 {
            return Array(sorted.prefix(limit))
        } else {
            return sorted
        }
    }

    public func fetchAllCarts(limit: Int?) async throws -> [Cart] {
        let sorted = cartsByID.values.sorted { $0.updatedAt > $1.updatedAt }

        if let limit, limit >= 0 {
            return Array(sorted.prefix(limit))
        } else {
            return sorted
        }
    }
}
