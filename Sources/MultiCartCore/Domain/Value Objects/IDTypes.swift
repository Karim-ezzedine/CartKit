import Foundation

/// Strongly-typed identifier for a cart.
public struct CartID: Hashable, Codable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Convenience initializer so you can write `CartID("cart-123")`.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Strongly-typed identifier for a store.
public struct StoreID: Hashable, Codable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Strongly-typed identifier for a user profile.
public struct UserProfileID: Hashable, Codable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Strongly-typed identifier for a cart item.
public struct CartItemID: Hashable, Codable, Sendable {
    public let rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}


// MARK: - ID helpers

public extension CartID {
    /// Generate a new cart ID using a UUID.
    static func generate() -> CartID {
        CartID(UUID().uuidString)
    }
}

public extension CartItemID {
    /// Generate a new cart item ID using a UUID.
    static func generate() -> CartItemID {
        CartItemID(UUID().uuidString)
    }
}

