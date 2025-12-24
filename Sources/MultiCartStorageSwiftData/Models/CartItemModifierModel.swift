import Foundation

#if canImport(SwiftData) && os(iOS)
import SwiftData

/// SwiftData persistence model for `CartItemModifier` (Infrastructure DTO).
@available(iOS 17, *)
@Model
public final class CartItemModifierModel {

    // MARK: - Identifier (persistence)

    /// A stable identifier for this modifier row.
    /// If your domain modifier `id` is stable per modifier, you can use it directly.
    /// If not, consider making this a composite ID at mapping time (see notes below).
    @Attribute(.unique)
    public var id: String

    // MARK: - Domain fields

    public var name: String

    // Money (mirrors domain Money)
    public var priceDeltaAmount: Decimal
    public var priceDeltaCurrencyCode: String

    // MARK: - Init

    public init(
        id: String,
        name: String,
        priceDeltaAmount: Decimal,
        priceDeltaCurrencyCode: String,
    ) {
        self.id = id
        self.name = name
        self.priceDeltaAmount = priceDeltaAmount
        self.priceDeltaCurrencyCode = priceDeltaCurrencyCode
    }
}
#endif
