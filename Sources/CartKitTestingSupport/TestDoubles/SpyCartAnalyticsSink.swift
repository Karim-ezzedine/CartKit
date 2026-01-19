import Foundation
import CartKitCore

/// Captures analytics calls for assertions in tests.
public final class SpyCartAnalyticsSink: CartAnalyticsSink, @unchecked Sendable {

    public private(set) var createdCarts: [Cart] = []
    public private(set) var updatedCarts: [Cart] = []
    public private(set) var deletedCartIDs: [CartID] = []

    // Added sessionId to the tuple to match the updated analytics API.
    public private(set) var activeCartChanges: [(CartID?, StoreID, UserProfileID?, CartSessionID?)] = []

    public private(set) var addedItems: [(CartItem, Cart)] = []
    public private(set) var updatedItems: [(CartItem, Cart)] = []
    public private(set) var removedItems: [(CartItemID, Cart)] = []

    public init() {}

    public func cartCreated(_ cart: Cart) {
        createdCarts.append(cart)
    }

    public func cartUpdated(_ cart: Cart) {
        updatedCarts.append(cart)
    }

    public func cartDeleted(id: CartID) {
        deletedCartIDs.append(id)
    }

    public func activeCartChanged(
        newActiveCartId: CartID?,
        storeId: StoreID,
        profileId: UserProfileID?,
        sessionId: CartSessionID?
    ) {
        activeCartChanges.append((newActiveCartId, storeId, profileId, sessionId))
    }

    public func itemAdded(_ item: CartItem, in cart: Cart) {
        addedItems.append((item, cart))
    }

    public func itemUpdated(_ item: CartItem, in cart: Cart) {
        updatedItems.append((item, cart))
    }

    public func itemRemoved(
        itemId: CartItemID,
        from cart: Cart
    ) {
        removedItems.append((itemId, cart))
    }
}
