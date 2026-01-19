import Foundation

#if canImport(SwiftData) && os(iOS)
import SwiftData

/// SwiftData persistence model for `Cart` (Infrastructure DTO).
@available(iOS 17, *)
@Model
public final class CartModel {

    // MARK: - Identifiers / scope

    /// Domain: CartID.rawValue
    @Attribute(.unique)
    public var id: String

    /// Domain: StoreID.rawValue
    public var storeId: String

    /// Domain: UserProfileID?.rawValue (nil = guest)
    public var profileId: String?
    
    /// Domain: CartSessionID?.rawValue (nil = one cart per session)
    public var sessionId: String?

    // MARK: - State

    /// Domain: CartStatus.rawValue
    public var status: String

    // MARK: - Timestamps

    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Metadata / optional display fields (mirrors domain)

    /// Domain: [String: String] stored as JSON bytes.
    /// (SwiftData does not reliably persist dictionary types across all configurations.)
    public var metadataJSON: Data?

    public var displayName: String?
    public var context: String?
    public var storeImageURLString: String?

    // MARK: - Snapshot rules (mirrors domain)

    public var minSubtotalAmount: Decimal?
    public var minSubtotalCurrencyCode: String?

    public var maxItemCount: Int?

    // MARK: - Relationship

    /// Items belong to a cart. Cascade delete ensures cart deletion cleans up items.
    @Relationship(deleteRule: .cascade)
    public var items: [CartItemModel] = []

    // MARK: - Init

    public init(
        id: String,
        storeId: String,
        profileId: String? = nil,
        sessionId: String? = nil,
        status: String,
        createdAt: Date,
        updatedAt: Date,
        metadataJSON: Data? = nil,
        displayName: String? = nil,
        context: String? = nil,
        storeImageURLString: String? = nil,
        minSubtotalAmount: Decimal? = nil,
        minSubtotalCurrencyCode: String? = nil,
        maxItemCount: Int? = nil,
        items: [CartItemModel] = []
    ) {
        self.id = id
        self.storeId = storeId
        self.profileId = profileId
        self.sessionId = sessionId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataJSON = metadataJSON
        self.displayName = displayName
        self.context = context
        self.storeImageURLString = storeImageURLString
        self.minSubtotalAmount = minSubtotalAmount
        self.minSubtotalCurrencyCode = minSubtotalCurrencyCode
        self.maxItemCount = maxItemCount
        self.items = items
    }
}
#endif
