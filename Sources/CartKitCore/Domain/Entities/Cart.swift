import Foundation

/// Represents a cart for a given store, optionally scoped to a user profile.
///
/// Guest carts are represented by `profileID == nil`.
public struct Cart: Hashable, Codable, Sendable {
    
    // MARK: - Core identifiers
    
    public let id: CartID
    public let storeID: StoreID
    
    /// Optional user profile. `nil` means guest cart.
    public let profileID: UserProfileID?
    
    /// Optional checkout session identifier.
    /// - `nil` =  single-store flow.
    /// - non-nil = cart belongs to a multi-store unified checkout session.
    public let sessionID: CartSessionID?
    
    // MARK: - Contents
    
    public var items: [CartItem]
    
    // MARK: - State & metadata
    
    public var status: CartStatus
    public var createdAt: Date
    public var updatedAt: Date
    
    /// Arbitrary key–value metadata (host app can use this for tagging, A/B, etc.).
    public var metadata: [String: String]
    
    /// Optional name shown to the user (e.g., "Weekly groceries").
    public var displayName: String?
    
    /// Optional context string (e.g., "web", "mobile", "campaign-xyz").
    public var context: String?
    
    /// Optional store image URL associated with the cart (for UI).
    public var storeImageURL: URL?
    
    /// Optional per-cart minimum subtotal requirement (snapshot of store rules).
    public var minSubtotal: Money?
    
    /// Optional per-cart maximum number of items allowed.
    public var maxItemCount: Int?
    
    // MARK: - Init
    
    public init(
        id: CartID,
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        sessionID: CartSessionID? = nil,
        items: [CartItem] = [],
        status: CartStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: String] = [:],
        displayName: String? = nil,
        context: String? = nil,
        storeImageURL: URL? = nil,
        minSubtotal: Money? = nil,
        maxItemCount: Int? = nil
    ) {
        self.id = id
        self.storeID = storeID
        self.profileID = profileID
        self.sessionID = sessionID
        self.items = items
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.displayName = displayName
        self.context = context
        self.storeImageURL = storeImageURL
        self.minSubtotal = minSubtotal
        self.maxItemCount = maxItemCount
    }
    
    // MARK: - Convenience
    
    /// `true` when this cart is not bound to any logged-in profile.
    public var isGuestCart: Bool {
        profileID == nil
    }
}
