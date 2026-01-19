import Foundation
import CartKitCore

#if canImport(SwiftData) && os(iOS)
import SwiftData

@available(iOS 17, *)
enum SwiftDataCartMapping {
    
    // MARK: - Domain -> SwiftData
    
    static func toModel(_ cart: Cart) -> CartModel {
        let model = CartModel(
            id: cart.id.rawValue,
            storeId: cart.storeID.rawValue,
            profileId: cart.profileID?.rawValue,
            sessionId: cart.sessionID?.rawValue,
            status: cart.status.rawValue,
            createdAt: cart.createdAt,
            updatedAt: cart.updatedAt,
            metadataJSON: encodeMetadata(cart.metadata),
            displayName: cart.displayName,
            context: cart.context,
            storeImageURLString: cart.storeImageURL?.absoluteString,
            minSubtotalAmount: cart.minSubtotal?.amount,
            minSubtotalCurrencyCode: cart.minSubtotal?.currencyCode,
            maxItemCount: cart.maxItemCount,
            items: cart.items.map(toModel)
        )
        return model
    }
    
    static func toModel(_ item: CartItem) -> CartItemModel {
        let model = CartItemModel(
            id: item.id.rawValue,
            productId: item.productID,
            quantity: item.quantity,
            unitPriceAmount: item.unitPrice.amount,
            unitPriceCurrencyCode: item.unitPrice.currencyCode,
            totalPriceAmount: item.totalPrice.amount,
            totalPriceCurrencyCode: item.totalPrice.currencyCode,
            imageURLString: item.imageURL?.absoluteString,
            availableStock: item.availableStock,
            modifiers: item.modifiers.map {
                toModel($0, owningItemID: item.id.rawValue)
            }
        )
        return model
    }
    
    static func toModel(
        _ modifier: CartItemModifier,
        owningItemID: String
    ) -> CartItemModifierModel {

        // Composite persisted identifier to guarantee uniqueness across all items.
        // Domain stays unchanged (modifier.id remains whatever the host provides).
        let persistedId = "\(owningItemID)::\(modifier.id)"

        return CartItemModifierModel(
            id: persistedId,
            name: modifier.name,
            priceDeltaAmount: modifier.priceDelta.amount,
            priceDeltaCurrencyCode: modifier.priceDelta.currencyCode
        )
    }
    
    // MARK: - SwiftData -> Domain
    
    static func toDomain(_ model: CartModel) throws -> Cart {
        Cart(
            id: CartID(rawValue: model.id),
            storeID: StoreID(rawValue: model.storeId),
            profileID: model.profileId.map(UserProfileID.init(rawValue:)),
            sessionID: model.sessionId.map(CartSessionID.init(rawValue:)),
            items: try model.items.map(toDomain),
            status: CartStatus(rawValue: model.status) ?? .active,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            metadata: decodeMetadata(model.metadataJSON),
            displayName: model.displayName,
            context: model.context,
            storeImageURL: model.storeImageURLString.flatMap(URL.init(string:)),
            minSubtotal: decodeMoney(amount: model.minSubtotalAmount,
                                     currencyCode: model.minSubtotalCurrencyCode),
            maxItemCount: model.maxItemCount
        )
    }
    
    static func toDomain(_ model: CartItemModel) throws -> CartItem {
        CartItem(
            id: CartItemID(rawValue: model.id),
            productID: model.productId,
            quantity: model.quantity,
            unitPrice: Money(amount: model.unitPriceAmount,
                             currencyCode: model.unitPriceCurrencyCode),
            totalPrice: Money(amount: model.totalPriceAmount,
                              currencyCode: model.totalPriceCurrencyCode),
            modifiers: model.modifiers.map(toDomain),
            imageURL: model.imageURLString.flatMap(URL.init(string:)),
            availableStock: model.availableStock
        )
    }
    
    static func toDomain(_ model: CartItemModifierModel) -> CartItemModifier {
        let rawId: String
        if let idx = model.id.range(of: "::") {
            rawId = String(model.id[idx.upperBound...])
        } else {
            rawId = model.id
        }

        return CartItemModifier(
            id: rawId,
            name: model.name,
            priceDelta: Money(amount: model.priceDeltaAmount, currencyCode: model.priceDeltaCurrencyCode)
        )
    }
    
    // MARK: - Helpers
    
    private static func encodeMetadata(_ metadata: [String: String]) -> Data? {
        guard !metadata.isEmpty else { return nil }
        return try? JSONEncoder().encode(metadata)
    }
    
    private static func decodeMetadata(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
    
    private static func decodeMoney(amount: Decimal?, currencyCode: String?) -> Money? {
        guard let amount, let currencyCode else { return nil }
        return Money(amount: amount, currencyCode: currencyCode)
    }
}
#endif

