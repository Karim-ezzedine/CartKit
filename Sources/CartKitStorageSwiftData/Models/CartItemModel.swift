import Foundation

#if canImport(SwiftData) && os(iOS)
import SwiftData

/// SwiftData persistence model for `CartItem` (Infrastructure DTO).
@available(iOS 17, *)
@Model
public final class CartItemModel {

    // MARK: - Identifiers

    /// Domain: CartItemID.rawValue
    @Attribute(.unique)
    public var id: String

    /// Domain: CartItem.productID
    public var productId: String

    // MARK: - Quantity / constraints

    public var quantity: Int
    public var availableStock: Int?

    // MARK: - Money (mirrors domain Money)

    public var unitPriceAmount: Decimal
    public var unitPriceCurrencyCode: String

    public var totalPriceAmount: Decimal
    public var totalPriceCurrencyCode: String

    // MARK: - Modifiers

    /// Modifiers for this item.
    /// Cascade delete ensures removing the item removes its modifiers.
    @Relationship(deleteRule: .cascade)
    public var modifiers: [CartItemModifierModel] = []

    // MARK: - Optional display fields

    public var imageURLString: String?

    // MARK: - Init

    public init(
        id: String,
        productId: String,
        quantity: Int,
        unitPriceAmount: Decimal,
        unitPriceCurrencyCode: String,
        totalPriceAmount: Decimal,
        totalPriceCurrencyCode: String,
        imageURLString: String? = nil,
        availableStock: Int? = nil,
        modifiers: [CartItemModifierModel] = []
    ) {
        self.id = id
        self.productId = productId
        self.quantity = quantity
        self.unitPriceAmount = unitPriceAmount
        self.unitPriceCurrencyCode = unitPriceCurrencyCode
        self.totalPriceAmount = totalPriceAmount
        self.totalPriceCurrencyCode = totalPriceCurrencyCode
        self.imageURLString = imageURLString
        self.availableStock = availableStock
        self.modifiers = modifiers
    }
}
#endif
