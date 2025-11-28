import Foundation

/// A single line item inside a cart.
///
/// Keeps product reference, quantity, pricing, optional modifiers and image.
public struct CartItem: Hashable, Codable, Sendable {

    public let id: CartItemID

    /// Host app–defined product identifier.
    public let productID: String

    /// Quantity of this product in the cart.
    public var quantity: Int

    /// Price for a single unit of the product.
    public var unitPrice: Money

    /// Total line amount (usually `unitPrice * quantity`, but kept explicit
    /// so pricing engines can override / apply discounts).
    public var totalPrice: Money

    /// Optional modifiers affecting this item (options, add-ons, etc.).
    public var modifiers: [CartItemModifier]

    /// Optional image URL representing the item.
    public var imageURL: URL?

    // MARK: - Init

    public init(
        id: CartItemID,
        productID: String,
        quantity: Int,
        unitPrice: Money,
        totalPrice: Money? = nil,
        modifiers: [CartItemModifier] = [],
        imageURL: URL? = nil
    ) {
        self.id = id
        self.productID = productID
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.modifiers = modifiers
        self.imageURL = imageURL

        if let totalPrice {
            self.totalPrice = totalPrice
        } else {
            // Basic default: unitPrice * quantity.
            let amount = unitPrice.amount * Decimal(quantity)
            self.totalPrice = Money(amount: amount, currencyCode: unitPrice.currencyCode)
        }
    }
}

/// Lightweight representation of an item modifier (e.g., size, extras).
///
/// These are intentionally generic; the host app can encode any semantics
/// it needs via `id` and `name`, while `priceDelta` captures the pricing effect.
public struct CartItemModifier: Hashable, Codable, Sendable {

    public var id: String
    public var name: String
    public var priceDelta: Money

    public init(
        id: String,
        name: String,
        priceDelta: Money
    ) {
        self.id = id
        self.name = name
        self.priceDelta = priceDelta
    }
}
