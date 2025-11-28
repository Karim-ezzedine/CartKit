import Foundation

/// High-level state of a cart.
public enum CartStatus: String, Hashable, Codable, Sendable {
    case active
    case checkedOut
    case cancelled
    case expired
}

/// Represents a cart for a given store, optionally scoped to a user profile.
///
/// Guest carts are represented by `profileID == nil`.
public struct Cart: Hashable, Codable, Sendable {

    // MARK: - Core identifiers

    public let id: CartID
    public let storeID: StoreID

    /// Optional user profile. `nil` means guest cart.
    public let profileID: UserProfileID?

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

    // MARK: - Init

    public init(
        id: CartID,
        storeID: StoreID,
        profileID: UserProfileID? = nil,
        items: [CartItem] = [],
        status: CartStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: String] = [:],
        displayName: String? = nil,
        context: String? = nil,
        storeImageURL: URL? = nil
    ) {
        self.id = id
        self.storeID = storeID
        self.profileID = profileID
        self.items = items
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.displayName = displayName
        self.context = context
        self.storeImageURL = storeImageURL
    }

    // MARK: - Convenience

    /// `true` when this cart is not bound to any logged-in profile.
    public var isGuestCart: Bool {
        profileID == nil
    }
}
