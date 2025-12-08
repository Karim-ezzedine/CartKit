/// A promotion that has been applied to a specific cart.
///
/// This is a value object owned by the `Cart` aggregate. Two carts
/// can have completely different promotions, even for the same store.
public struct AppliedPromotion: Hashable, Codable, Sendable {

    /// Host-defined promotion identifier (e.g. coupon code, campaign id).
    public let id: String

    /// Short label to show in UI, e.g. "10% OFF", "Free Delivery".
    public let title: String

    /// Optional human-readable description for tooltips or details screens.
    public let description: String?

    /// Extra metadata the host app may need (segment, campaign, etc.).
    public let metadata: [String: String]

    public init(
        id: String,
        title: String,
        description: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.metadata = metadata
    }
}
