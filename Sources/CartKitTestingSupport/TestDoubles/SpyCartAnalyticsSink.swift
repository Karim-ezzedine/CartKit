import Foundation
import CartKitCore

/// Captures analytics calls for assertions in tests.
public final class SpyCartAnalyticsSink: CartAnalyticsSink, @unchecked Sendable {

    private let lock = NSLock()

    public private(set) var created: [CartID] = []
    public private(set) var updated: [CartID] = []
    public private(set) var deleted: [CartID] = []

    public private(set) var activeChanges: [(new: CartID?, store: StoreID, profile: UserProfileID?)] = []

    public private(set) var addedItems: [(item: CartItemID, cart: CartID)] = []
    public private(set) var updatedItems: [(item: CartItemID, cart: CartID)] = []
    public private(set) var removedItems: [(item: CartItemID, cart: CartID)] = []

    public init() {}

    public func cartCreated(_ cart: Cart) {
        withLock { created.append(cart.id) }
    }

    public func cartUpdated(_ cart: Cart) {
        withLock { updated.append(cart.id) }
    }

    public func cartDeleted(id: CartID) {
        withLock { deleted.append(id) }
    }

    public func activeCartChanged(
        newActiveCartId: CartID?,
        storeId: StoreID,
        profileId: UserProfileID?
    ) {
        withLock { activeChanges.append((newActiveCartId, storeId, profileId)) }
    }

    public func itemAdded(_ item: CartItem, in cart: Cart) {
        withLock { addedItems.append((item.id, cart.id)) }
    }

    public func itemUpdated(_ item: CartItem, in cart: Cart) {
        withLock { updatedItems.append((item.id, cart.id)) }
    }

    public func itemRemoved(itemId: CartItemID, from cart: Cart) {
        withLock { removedItems.append((itemId, cart.id)) }
    }

    // MARK: - Helpers

    private func withLock(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body()
    }
}
