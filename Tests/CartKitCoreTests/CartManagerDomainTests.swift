import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

struct CartManagerDomainTests {
    
    // MARK: - Factory

    func makeSUT(
        initialCarts: [Cart] = [],
        detector: CartCatalogConflictDetector = NoOpCartCatalogConflictDetector()
    ) -> (manager: CartManager, support: MultiCartTestingSupport) {
        
        let support = MultiCartTestingSupport(initialCarts: initialCarts)
        
        let config = support.makeConfiguration(
            catalogConflictDetector: detector
        )
        
        let manager = CartManager(configuration: config)
        return (manager, support)
    }

    // MARK: -  Add / Update / Remove

    @Test
    func addItem_appendsItem_andReportsChangedItems() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_add")
        
        let cart = try await manager.setActiveCart(storeID: storeID)

        let newItem = CartItem(
            id: CartItemID.generate(),
            productID: "burger",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        let result = try await manager.addItem(to: cart.id, item: newItem)

        #expect(result.cart.id == cart.id)
        #expect(result.cart.items.count == 1)
        #expect(result.removedItems.isEmpty)
        #expect(result.changedItems.count == 1)
        #expect(result.changedItems.first?.id == newItem.id)
        #expect(result.cart.items.contains { $0.id == newItem.id })
    }

    @Test
    func updateItem_changesExistingItem_andReportsChange() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_update")
        
        var cart = try await manager.setActiveCart(storeID: storeID)

        let originalItem = CartItem(
            id: CartItemID.generate(),
            productID: "pizza",
            quantity: 1,
            unitPrice: Money(amount: 12, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        let addResult = try await manager.addItem(to: cart.id, item: originalItem)
        cart = addResult.cart

        var updatedItem = originalItem
        updatedItem.quantity = 2

        let updateResult = try await manager.updateItem(in: cart.id, item: updatedItem)

        #expect(updateResult.cart.items.count == 1)
        #expect(updateResult.removedItems.isEmpty)
        #expect(updateResult.changedItems.count == 1)
        #expect(updateResult.changedItems.first?.id == originalItem.id)
        #expect(updateResult.cart.items.first?.quantity == 2)
    }

    @Test
    func removeItem_removesLine_andReportsRemovedItems() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_remove")
        
        var cart = try await manager.setActiveCart(storeID: storeID)

        let item = CartItem(
            id: CartItemID.generate(),
            productID: "fries",
            quantity: 1,
            unitPrice: Money(amount: 3, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        let addResult = try await manager.addItem(to: cart.id, item: item)
        cart = addResult.cart

        let removeResult = try await manager.removeItem(from: cart.id, itemID: item.id)

        #expect(removeResult.cart.items.isEmpty)
        #expect(removeResult.removedItems.count == 1)
        #expect(removeResult.removedItems.first?.id == item.id)
        #expect(removeResult.changedItems.isEmpty)
    }

    //MARK: - Get Cart Tests
    
    @Test
    func getCart_returnsCart_whenExists() async throws {
        let cart = CartTestFixtures.guestCart(storeID: StoreID(rawValue: "store_get"))
        let (manager, _) = makeSUT(initialCarts: [cart])

        let loaded = try await manager.getCart(id: cart.id)

        let unwrapped = try #require(loaded)
        #expect(unwrapped.id == cart.id)
    }
    
    @Test
    func getCart_returnsNil_whenMissing() async throws {
        let (manager, _) = makeSUT(initialCarts: [])
        let loaded = try await manager.getCart(id: CartID.generate())
        #expect(loaded == nil)
    }
    
    //MARK: - Reorder Tests
    
    @Test
    func reorder_throws_whenSourceCartMissing() async throws {
        let (manager, _) = makeSUT()
        await #expect(throws: CartError.self) {
            _ = try await manager.reorder(from: CartID.generate())
        }
    }

    @Test
    func reorder_createsNewActiveCart_withNewIDs_andCopiedFields() async throws {
        let storeID = StoreID(rawValue: "store_reorder_core")
        let profileID: UserProfileID? = nil

        var source = CartTestFixtures.guestCart(storeID: storeID)

        source.displayName = "My Cart"
        source.context = "home"
        source.metadata = ["k": "v"]
        source.storeImageURL = URL(string: "https://example.com/s.png")
        source.minSubtotal = Money(amount: 10, currencyCode: "USD")
        source.maxItemCount = 7
        source.savedPromotionKinds = [.freeDelivery]

        let (manager, _) = makeSUT(initialCarts: [source])
        let reordered = try await manager.reorder(from: source.id)

        #expect(reordered.id != source.id)
        #expect(reordered.status == .active)
        #expect(reordered.storeID == storeID)
        #expect(reordered.profileID == profileID)

        #expect(reordered.displayName == source.displayName)
        #expect(reordered.context == source.context)
        #expect(reordered.metadata == source.metadata)
        #expect(reordered.storeImageURL == source.storeImageURL)
        #expect(reordered.minSubtotal == source.minSubtotal)
        #expect(reordered.maxItemCount == source.maxItemCount)
        #expect(reordered.savedPromotionKinds == source.savedPromotionKinds)
    }

    @Test
    func reorder_regeneratesCartItemIDs_butKeepsItemContent() async throws {
        let storeID = StoreID(rawValue: "store_reorder_items")
        var source = CartTestFixtures.guestCart(storeID: storeID)

        // Ensure at least one item exists; if fixture is empty, add one.
        if source.items.isEmpty {
            source.items = [
                CartItem(
                    id: CartItemID.generate(),
                    productID: "p1",
                    quantity: 2,
                    unitPrice: Money(amount: 5, currencyCode: "USD"),
                    modifiers: [CartItemModifier(id: "m1", name: "extra", priceDelta: Money(amount: 1, currencyCode: "USD"))],
                    imageURL: URL(string: "https://example.com/i.png"),
                    availableStock: 10
                )
            ]
        }

        let (manager, _) = makeSUT(initialCarts: [source])
        let reordered = try await manager.reorder(from: source.id)

        #expect(reordered.items.count == source.items.count)

        let sourceByProduct = Dictionary(uniqueKeysWithValues: source.items.map { ($0.productID, $0) })
        for item in reordered.items {
            let original = try #require(sourceByProduct[item.productID])
            #expect(item.id != original.id)              // regenerated
            #expect(item.productID == original.productID)
            #expect(item.quantity == original.quantity)
            #expect(item.unitPrice == original.unitPrice)
            #expect(item.totalPrice == original.totalPrice)
            #expect(item.modifiers == original.modifiers)
            #expect(item.imageURL == original.imageURL)
            #expect(item.availableStock == original.availableStock)
        }
    }

    @Test
    func reorder_expiresExistingActiveCart_inSameScope() async throws {
        let storeID = StoreID(rawValue: "store_reorder_expire")

        // Existing active cart in scope
        var active = CartTestFixtures.guestCart(storeID: storeID)
        active.status = .active

        // Source cart (can also be active or non-active; reorder source is independent)
        var source = CartTestFixtures.guestCart(storeID: storeID)
        source.status = .expired

        let (manager, _) = makeSUT(initialCarts: [active, source])

        let reordered = try await manager.reorder(from: source.id)

        #expect(reordered.status == .active)
        #expect(reordered.storeID == storeID)

        // Old active cart should now be expired
        let oldLoaded = try await manager.getCart(id: active.id)
        let old = try #require(oldLoaded)
        #expect(old.status == .expired)
    }

    @Test
    func reorder_doesNotExpireActiveCart_inDifferentScope() async throws {
        let storeA = StoreID(rawValue: "store_A")
        let storeB = StoreID(rawValue: "store_B")

        var activeA = CartTestFixtures.guestCart(storeID: storeA)
        activeA.status = .active

        let sourceB = CartTestFixtures.guestCart(storeID: storeB)

        let (manager, _) = makeSUT(initialCarts: [activeA, sourceB])

        _ = try await manager.reorder(from: sourceB.id)

        let stillActiveA = try await manager.getCart(id: activeA.id)
        let a = try #require(stillActiveA)
        #expect(a.status == .active)   // untouched
    }
    
    //MARK: - Set Active Cart
    
    @Test
    func setActiveCart_createsNewCart_withPassedValues() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_set_active_payload")
        let sessionID = CartSessionID("session_payload")

        let expectedMin = Money(amount: 10, currencyCode: "USD")
        let expectedPromos: [PromotionKind] = [.freeDelivery]

        let cart = try await manager.setActiveCart(
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            displayName: "My Cart",
            context: "home",
            storeImageURL: URL(string: "https://example.com/s.png"),
            metadata: ["k": "v"],
            minSubtotal: expectedMin,
            maxItemCount: 7,
            savedPromotionKinds: expectedPromos
        )

        #expect(cart.status == .active)
        #expect(cart.storeID == storeID)
        #expect(cart.sessionID == sessionID)
        #expect(cart.displayName == "My Cart")
        #expect(cart.context == "home")
        #expect(cart.storeImageURL == URL(string: "https://example.com/s.png"))
        #expect(cart.metadata == ["k": "v"])
        #expect(cart.minSubtotal == expectedMin)
        #expect(cart.maxItemCount == 7)
        #expect(cart.savedPromotionKinds == expectedPromos)
    }

    @Test
    func setActiveCart_returnsExistingActiveCart_andDoesNotOverrideValues() async throws {
        let storeID = StoreID(rawValue: "store_set_active_existing")

        var existing = CartTestFixtures.guestCart(storeID: storeID)
        existing.status = .active
        existing.displayName = "Original"
        existing.savedPromotionKinds = [.freeDelivery]

        let (manager, _) = makeSUT(initialCarts: [existing])

        let returned = try await manager.setActiveCart(
            storeID: storeID,
            displayName: "New Name Should NOT Apply",
            savedPromotionKinds: [.percentageOffCart(0.10)]
        )

        #expect(returned.id == existing.id)
        #expect(returned.displayName == "Original")
        #expect(returned.savedPromotionKinds == [.freeDelivery])
    }

    //MARK: - Emits Analytics
    
    @Test
    func setActiveCart_emitsAnalytics_activeCartChanged() async throws {
        let (manager, support) = makeSUT()
        let storeID = StoreID(rawValue: "store_analytics_active")
        
        let cart = try await manager.setActiveCart(storeID: storeID)
        
        let changes = support.analytics.activeCartChanges
        #expect(changes.count == 1)
        #expect(changes.first?.1 == storeID)
        #expect(changes.first?.2 == nil)
        #expect(changes.first?.0 == cart.id)
    }
    
    @Test
    func setActiveCart_calledTwiceSameScope_emitsAnalyticsOnce() async throws {
        let (manager, support) = makeSUT()
        let storeID = StoreID(rawValue: "store_analytics_active_once")

        _ = try await manager.setActiveCart(storeID: storeID)
        _ = try await manager.setActiveCart(storeID: storeID) // should return existing

        let changes = support.analytics.activeCartChanges
        #expect(changes.count == 1)
    }

    @Test
    func deleteActiveCart_emitsAnalytics_activeCartChangedNil() async throws {
        let (manager, support) = makeSUT()
        let storeID = StoreID(rawValue: "store_analytics_delete")
        
        let cart = try await manager.setActiveCart(storeID: storeID)
        try await manager.deleteCart(id: cart.id)
        
        let changes = support.analytics.activeCartChanges
        // One for setActiveCart, one for delete -> nil
        #expect(changes.count == 2)
        #expect(changes.last?.1 == storeID)
        #expect(changes.last?.2 == nil)
        #expect(changes.last?.0 == nil)
    }
}
