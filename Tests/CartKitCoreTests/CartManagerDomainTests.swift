import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

struct CartManagerDomainTests {
    
    // MARK: - Factory

    private func makeSUT(
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
    
    // MARK: - Event helpers

    private func makeEventIterator(
        _ stream: AsyncStream<CartEvent>
    ) -> AsyncStream<CartEvent>.AsyncIterator {
        stream.makeAsyncIterator()
    }

    private func nextEvent(
        _ iterator: inout AsyncStream<CartEvent>.AsyncIterator
    ) async -> CartEvent? {
        await iterator.next()
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

    // MARK: - Status transitions

    @Test
    func updateStatus_allowsActiveToCheckedOut() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_status")
        let profileID = UserProfileID(rawValue: "user_1")

        let cart = try await manager.setActiveCart(storeID: storeID, profileID: profileID)

        let updated = try await manager.updateStatus(
            for: cart.id,
            to: .checkedOut
        )

        #expect(updated.status == .checkedOut)
    }

    @Test
    func updateStatus_disallowsCheckedOutBackToActive() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_status_back")
        let profileID = UserProfileID(rawValue: "user_1")

        let cart = try await manager.setActiveCart(storeID: storeID, profileID: profileID)
        _ = try await manager.updateStatus(for: cart.id, to: .checkedOut)

        await #expect(throws: CartError.self) {
            _ = try await manager.updateStatus(for: cart.id, to: .active)
        }
    }

    // MARK: - Active cart per store/profile

    @Test
    func setActiveCart_reusesExistingActive_forSameScope() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_scope")
        let profileID = UserProfileID(rawValue: "user_1")

        let first = try await manager.setActiveCart(storeID: storeID, profileID: profileID)
        let second = try await manager.setActiveCart(storeID: storeID, profileID: profileID)

        #expect(first.id == second.id)
    }

    @Test
    func activeCarts_areScopedByStoreID() async throws {
        let (manager, _) = makeSUT()
        let profileID = UserProfileID(rawValue: "user_scope")

        let storeA = StoreID(rawValue: "store_A")
        let storeB = StoreID(rawValue: "store_B")

        let cartA = try await manager.setActiveCart(storeID: storeA, profileID: profileID)
        let cartB = try await manager.setActiveCart(storeID: storeB, profileID: profileID)

        let fetchedA = try await manager.getActiveCart(storeID: storeA, profileID: profileID)
        let fetchedB = try await manager.getActiveCart(storeID: storeB, profileID: profileID)

        #expect(cartA.id != cartB.id)
        #expect(fetchedA?.id == cartA.id)
        #expect(fetchedB?.id == cartB.id)
    }

    @Test
    func guestAndProfileCarts_areDistinctScopes() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_guest_profile")
        let profileID = UserProfileID(rawValue: "user_42")

        let guestCart = try await manager.setActiveCart(storeID: storeID)
        let profileCart = try await manager.setActiveCart(storeID: storeID, profileID: profileID)

        let fetchedGuest = try await manager.getActiveCart(storeID: storeID)
        let fetchedProfile = try await manager.getActiveCart(storeID: storeID, profileID: profileID)

        #expect(guestCart.id != profileCart.id)
        #expect(fetchedGuest?.id == guestCart.id)
        #expect(fetchedProfile?.id == profileCart.id)
    }
    
    //MARK: - Active Carts Group
    
    @Test
    func setActiveCart_allowsMultipleActiveCarts_forSameStoreAndProfile_whenSessionDiffers() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID("store_session_scope")
        let profileID = UserProfileID("profile_session_scope")

        let s1 = CartSessionID("session_A")
        let s2 = CartSessionID("session_B")

        let c1 = try await manager.setActiveCart(storeID: storeID, profileID: profileID, sessionID: s1)
        let c2 = try await manager.setActiveCart(storeID: storeID, profileID: profileID, sessionID: s2)

        #expect(c1.id != c2.id)

        let fetched1 = try await manager.getActiveCart(storeID: storeID, profileID: profileID, sessionID: s1)
        let fetched2 = try await manager.getActiveCart(storeID: storeID, profileID: profileID, sessionID: s2)

        #expect(fetched1?.id == c1.id)
        #expect(fetched2?.id == c2.id)
    }
    
    @Test
    func setActiveCart_reusesExistingActive_forSameStoreProfileAndSession() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID("store_session_reuse")
        let profileID = UserProfileID("profile_session_reuse")
        let sessionID = CartSessionID("session_reuse")

        let first = try await manager.setActiveCart(storeID: storeID, profileID: profileID, sessionID: sessionID)
        let second = try await manager.setActiveCart(storeID: storeID, profileID: profileID, sessionID: sessionID)

        #expect(first.id == second.id)
    }
    
    @Test
    func getActiveCartGroups_groupsBySessionID_includingNil() async throws {
        let profileID = UserProfileID("profile_groups")
        let sA = CartSessionID("session_A")
        let sB = CartSessionID("session_B")

        let store1 = StoreID("store_1")
        let store2 = StoreID("store_2")
        let store3 = StoreID("store_3")
        let store4 = StoreID("store_4")

        var a1 = CartTestFixtures.loggedInCart(storeID: store1, profileID: profileID, sessionID: sA)
        a1.status = .active

        var a2 = CartTestFixtures.loggedInCart(storeID: store2, profileID: profileID, sessionID: sA)
        a2.status = .active

        var b1 = CartTestFixtures.loggedInCart(storeID: store3, profileID: profileID, sessionID: sB)
        b1.status = .active

        var nil1 = CartTestFixtures.loggedInCart(storeID: store4, profileID: profileID, sessionID: nil)
        nil1.status = .active

        let (manager, _) = makeSUT(initialCarts: [a1, a2, b1, nil1])

        let groups = try await manager.getActiveCartGroups(profileID: profileID)

        // Expect 3 groups: session_A, session_B, nil
        let sessionIDs = groups.map(\.sessionID)
        #expect(sessionIDs.contains(sA))
        #expect(sessionIDs.contains(sB))
        #expect(sessionIDs.contains(nil))

        // Validate each group only contains active carts of the same session
        for g in groups {
            #expect(g.carts.allSatisfy { $0.status == .active })
            #expect(g.carts.allSatisfy { $0.sessionID == g.sessionID })
        }
    }

    @Test
    func getActiveCartGroups_whenGuest_groupsGuestActiveCarts() async throws {
        let sA = CartSessionID("session_guest_A")
        let store1 = StoreID("store_guest_1")
        let store2 = StoreID("store_guest_2")

        var c1 = CartTestFixtures.guestCart(storeID: store1, sessionID: sA)
        c1.status = .active

        var c2 = CartTestFixtures.guestCart(storeID: store2, sessionID: sA)
        c2.status = .active

        let (manager, _) = makeSUT(initialCarts: [c1, c2])

        let groups = try await manager.getActiveCartGroups(profileID: nil)

        #expect(groups.count == 1)
        #expect(groups.first?.sessionID == sA)
        #expect(groups.first?.carts.count == 2)
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
    
    //MARK: - Migrate from guest to logged in
    
    @Test
    func migrateGuestActiveCart_move_rescopesSameCart() async throws {
        let storeID = StoreID("store_move")
        let profileID = UserProfileID("profile_1")
        let sessionID = CartSessionID("session_1")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest])

        let migrated = try await manager.migrateGuestActiveCart(
            storeID: storeID,
            to: profileID,
            strategy: .move,
            sessionID: sessionID
        )

        #expect(migrated.id == guest.id)
        #expect(migrated.profileID == profileID)
        #expect(migrated.status == .active)

        // Guest scope should now be empty
        let guestActive = try await manager.getActiveCart(storeID: storeID, profileID: nil, sessionID: sessionID)
        #expect(guestActive == nil)
    }

    @Test
    func migrateGuestActiveCart_copyAndDelete_createsNewProfileCart_andDeletesGuest() async throws {
        let storeID = StoreID("store_copy")
        let profileID = UserProfileID("profile_2")
        let sessionID = CartSessionID("session_2")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest])

        let migrated = try await manager.migrateGuestActiveCart(
            storeID: storeID,
            to: profileID,
            strategy: .copyAndDelete,
            sessionID: sessionID
        )

        #expect(migrated.id != guest.id)
        #expect(migrated.profileID == profileID)
        #expect(migrated.status == .active)

        // Guest cart should be deleted
        let deletedGuest = try await manager.getCart(id: guest.id)
        #expect(deletedGuest == nil)

        // Items cloned with new IDs
        let srcByProduct = Dictionary(uniqueKeysWithValues: guest.items.map { ($0.productID, $0) })
        for item in migrated.items {
            let original = try #require(srcByProduct[item.productID])
            #expect(item.id != original.id)
            #expect(item.quantity == original.quantity)
        }
    }

    @Test
    func migrateGuestActiveCart_throwsConflict_whenProfileHasActiveCart() async throws {
        let storeID = StoreID("store_conflict")
        let profileID = UserProfileID("profile_conflict")
        let sessionID = CartSessionID("session_conflict")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active

        var profileCart = CartTestFixtures.loggedInCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID
        )
        profileCart.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest, profileCart])

        await #expect(throws: CartError.self) {
            _ = try await manager.migrateGuestActiveCart(
                storeID: storeID,
                to: profileID,
                strategy: .move,
                sessionID: sessionID
            )
        }

        // Ensure nothing changed
        let stillGuest = try await manager.getCart(id: guest.id)
        #expect(stillGuest?.profileID == nil)

        let stillProfile = try await manager.getCart(id: profileCart.id)
        #expect(stillProfile?.status == .active)
    }
    
    @Test
    func migrateGuestActiveCart_throwsConflict_whenNoActiveGuestCart() async throws {
        let (manager, _) = makeSUT()

        await #expect(throws: CartError.self) {
            _ = try await manager.migrateGuestActiveCart(
                storeID: StoreID("store_none"),
                to: UserProfileID("profile_none"),
                strategy: .move,
                sessionID: CartSessionID("session_none")
            )
        }
    }
    
    @Test
    func migrateGuestActiveCart_move_clearsGuestScope_andSetsProfileScopeActive() async throws {
        let storeID = StoreID("store_move_scopes")
        let profileID = UserProfileID("profile_move_scopes")
        let sessionID = CartSessionID("session_move_scopes")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest])

        let migrated = try await manager.migrateGuestActiveCart(
            storeID: storeID,
            to: profileID,
            strategy: .move,
            sessionID: sessionID
        )

        // Same cart id, now profile-scoped
        #expect(migrated.id == guest.id)
        #expect(migrated.profileID == profileID)
        #expect(migrated.sessionID == sessionID)

        // Guest active cart for that scope is gone
        let guestActive = try await manager.getActiveCart(storeID: storeID, profileID: nil, sessionID: sessionID)
        #expect(guestActive == nil)

        // Profile active cart for that scope exists and is the migrated cart
        let profileActive = try await manager.getActiveCart(storeID: storeID, profileID: profileID, sessionID: sessionID)
        #expect(profileActive?.id == migrated.id)
    }

    //MARK: - Reports Conflicts
    
    @Test
    func addItem_reportsCatalogConflicts() async throws {
        let storeID = StoreID(rawValue: "store_conflict_add")

        let detector = FakeCatalogConflictDetector { cart in
            guard let item = cart.items.first else { return [] }
            return [
                CartCatalogConflict(
                    itemID: item.id,
                    productID: item.productID,
                    kind: .removedFromCatalog
                )
            ]
        }

        let (manager, _) = makeSUT(detector: detector)
        let cart = try await manager.setActiveCart(storeID: storeID)

        let item = CartItem(
            id: CartItemID.generate(),
            productID: "burger",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        let result = try await manager.addItem(to: cart.id, item: item)

        #expect(result.conflicts.count == 1)
    }
    
    @Test
    func addItem_reportsAllCatalogConflictKinds() async throws {
        let storeID = StoreID(rawValue: "store_conflict_kinds")
        
        let detector = FakeCatalogConflictDetector { cart in
            guard let item = cart.items.first else { return [] }
            return [
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .removedFromCatalog),
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .priceChanged(old: Money(amount: 10, currencyCode: "USD"), new: Money(amount: 12, currencyCode: "USD"))),
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .insufficientStock(requested: 5, available: 0))
            ]
        }
        
        let (manager, _) = makeSUT(detector: detector)
        let cart = try await manager.setActiveCart(storeID: storeID)
        
        let item = CartItem(
            id: CartItemID.generate(),
            productID: "burger",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )
        
        let result = try await manager.addItem(to: cart.id, item: item)
        
        #expect(result.conflicts.count == 3)
    }
    
    // MARK: - Observers / change streams

    @Test
    func observeEvents_setActiveCart_emitsCreated_thenActiveCartChanged() async throws {
        let (manager, _) = makeSUT()
        let stream = await manager.observeEvents()
        var it = makeEventIterator(stream)

        let storeID = StoreID(rawValue: "store_events_active")
        let cart = try await manager.setActiveCart(storeID: storeID)

        let e1 = await nextEvent(&it)
        let e2 = await nextEvent(&it)

        #expect(e1 == .cartCreated(cart.id))
        #expect(e2 == .activeCartChanged(storeID: storeID, profileID: nil, sessionID: nil, cartID: cart.id))
    }

    @Test
    func observeEvents_addItem_emitsCartUpdated() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_events_add_item")
        let cart = try await manager.setActiveCart(storeID: storeID)

        let stream = await manager.observeEvents()
        var it = makeEventIterator(stream)

        let item = CartItem(
            id: CartItemID.generate(),
            productID: "p1",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )

        _ = try await manager.addItem(to: cart.id, item: item)

        let event = await nextEvent(&it)
        #expect(event == .cartUpdated(cart.id))
    }

    @Test
    func observeEvents_deleteActiveCart_emitsDeleted_thenActiveCartChangedNil() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_events_delete")
        let cart = try await manager.setActiveCart(storeID: storeID)

        let stream = await manager.observeEvents()
        var it = makeEventIterator(stream)

        try await manager.deleteCart(id: cart.id)

        let e1 = await nextEvent(&it)
        let e2 = await nextEvent(&it)

        #expect(e1 == .cartDeleted(cart.id))
        #expect(e2 == .activeCartChanged(storeID: storeID, profileID: nil, sessionID: nil, cartID: nil))
    }

    @Test
    func observeEvents_updateStatus_activeToCheckedOut_emitsCartUpdated_thenActiveCartChangedNil() async throws {
        let (manager, _) = makeSUT()
        let storeID = StoreID(rawValue: "store_events_checkout")
        let profileID = UserProfileID(rawValue: "profile_events_checkout")
        let sessionID = CartSessionID(rawValue: "session_events_checkout")
        let cart = try await manager.setActiveCart(storeID: storeID, profileID: profileID, sessionID: sessionID)

        let stream = await manager.observeEvents()
        var it = makeEventIterator(stream)

        _ = try await manager.updateStatus(for: cart.id, to: .checkedOut)

        let e1 = await nextEvent(&it)
        let e2 = await nextEvent(&it)

        #expect(e1 == .cartUpdated(cart.id))
        #expect(e2 == .activeCartChanged(storeID: storeID, profileID: profileID, sessionID: sessionID, cartID: nil))
    }

    @Test
    func observeEvents_migrateGuestMove_emitsCartUpdated_thenActiveCartChangedForProfile() async throws {
        let storeID = StoreID("store_events_migrate_move")
        let profileID = UserProfileID("profile_events_migrate_move")
        let sessionID = CartSessionID("session_events_migrate_move")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest])

        let stream = await manager.observeEvents()
        var it = makeEventIterator(stream)

        let migrated = try await manager.migrateGuestActiveCart(
            storeID: storeID,
            to: profileID,
            strategy: .move,
            sessionID: sessionID
        )

        let e1 = await nextEvent(&it)
        let e2 = await nextEvent(&it)
        let e3 = await nextEvent(&it)

        #expect(e1 == .cartUpdated(migrated.id))

        // Guest scope is cleared first (same store + same session).
        #expect(e2 == .activeCartChanged(
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            cartID: nil
        ))

        // Then profile scope becomes active.
        #expect(e3 == .activeCartChanged(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            cartID: migrated.id
        ))
    }

    // MARK: - Lifecycle / Cleanup

    @Test
    func cleanupCarts_neverDeletesActiveCart() async throws {
        let storeID = StoreID("store_cleanup_active")
        
        var active = CartTestFixtures.guestCart(storeID: storeID)
        active.status = .active
        
        let (manager, _) = makeSUT(initialCarts: [active])
        
        let result = try await manager.cleanupCarts(
            storeID: storeID,
            policy: CartLifecyclePolicy(
                maxArchivedCartsPerScope: 0,
                deleteExpiredOlderThanDays: 0,
                deleteCancelledOlderThanDays: 0,
                deleteCheckedOutOlderThanDays: 0
            ),
            now: Date()
        )
        
        #expect(result.deletedCartIDs.isEmpty)
        let stillThere = try await manager.getCart(id: active.id)
        #expect(stillThere != nil)
        #expect(stillThere?.status == .active)
    }

    @Test
    func cleanupCarts_deletesExpiredOlderThanThreshold() async throws {
        let storeID = StoreID("store_cleanup_expired_age")
        let now = Date()
        
        var expiredOld = CartTestFixtures.guestCart(storeID: storeID)
        expiredOld.status = .expired
        expiredOld.updatedAt = now.addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
        
        var expiredNew = CartTestFixtures.guestCart(storeID: storeID)
        expiredNew.status = .expired
        expiredNew.updatedAt = now.addingTimeInterval(-2 * 24 * 60 * 60) // 2 days ago
        
        let (manager, _) = makeSUT(initialCarts: [expiredOld, expiredNew])
        
        let result = try await manager.cleanupCarts(
            storeID: storeID,
            policy: CartLifecyclePolicy(
                maxArchivedCartsPerScope: nil,
                deleteExpiredOlderThanDays: 7,
                deleteCancelledOlderThanDays: nil,
                deleteCheckedOutOlderThanDays: nil
            ),
            now: now
        )
        
        #expect(result.deletedCartIDs.contains(expiredOld.id))
        #expect(!result.deletedCartIDs.contains(expiredNew.id))
        
        #expect(try await manager.getCart(id: expiredOld.id) == nil)
        #expect(try await manager.getCart(id: expiredNew.id) != nil)
    }

    @Test
    func cleanupCarts_appliesMaxArchivedRetention_keepsMostRecent() async throws {
        let storeID = StoreID("store_cleanup_retention")
        let now = Date()
        
        func makeNonActiveCart(daysAgo: Int, status: CartStatus) -> Cart {
            var cart = CartTestFixtures.guestCart(storeID: storeID)
            cart.status = status
            cart.updatedAt = now.addingTimeInterval(TimeInterval(-daysAgo * 24 * 60 * 60))
            return cart
        }
        
        let c1 = makeNonActiveCart(daysAgo: 1, status: .expired)     // newest
        let c2 = makeNonActiveCart(daysAgo: 2, status: .cancelled)
        let c3 = makeNonActiveCart(daysAgo: 3, status: .checkedOut)  // oldest
        
        let (manager, _) = makeSUT(initialCarts: [c1, c2, c3])
        
        let result = try await manager.cleanupCarts(
            storeID: storeID,
            policy: CartLifecyclePolicy(
                maxArchivedCartsPerScope: 2,
                deleteExpiredOlderThanDays: nil,
                deleteCancelledOlderThanDays: nil,
                deleteCheckedOutOlderThanDays: nil
            ),
            now: now
        )
        
        // Should delete only the oldest (c3).
        #expect(result.deletedCartIDs == [c3.id].sorted(by: { $0.rawValue < $1.rawValue }))
        #expect(try await manager.getCart(id: c1.id) != nil)
        #expect(try await manager.getCart(id: c2.id) != nil)
        #expect(try await manager.getCart(id: c3.id) == nil)
    }

    @Test
    func cleanupCarts_isScoped_doesNotCrossStoreOrProfile() async throws {
        let now = Date()
        
        let storeA = StoreID("store_cleanup_A")
        let storeB = StoreID("store_cleanup_B")
        let profile = UserProfileID("profile_cleanup")
        
        var expiredAGuest = CartTestFixtures.guestCart(storeID: storeA)
        expiredAGuest.status = .expired
        expiredAGuest.updatedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        
        var expiredBGuest = CartTestFixtures.guestCart(storeID: storeB)
        expiredBGuest.status = .expired
        expiredBGuest.updatedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        
        var expiredAProfile = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profile)
        expiredAProfile.status = .expired
        expiredAProfile.updatedAt = now.addingTimeInterval(-30 * 24 * 60 * 60)
        
        let (manager, _) = makeSUT(initialCarts: [expiredAGuest, expiredBGuest, expiredAProfile])
        
        _ = try await manager.cleanupCarts(
            storeID: storeA,
            profileID: nil,
            policy: CartLifecyclePolicy(
                maxArchivedCartsPerScope: nil,
                deleteExpiredOlderThanDays: 7,
                deleteCancelledOlderThanDays: nil,
                deleteCheckedOutOlderThanDays: nil
            ),
            now: now
        )
        
        // Only storeA guest expired should be deleted.
        #expect(try await manager.getCart(id: expiredAGuest.id) == nil)
        #expect(try await manager.getCart(id: expiredBGuest.id) != nil) // different store
        #expect(try await manager.getCart(id: expiredAProfile.id) != nil) // different profile scope
    }
    
    // MARK: - Lifecycle / Cleanup

    @Test
    func cleanupCarts_sessionless_onlyAffectsSessionlessScope() async throws {
        let now = Date()

        let storeID = StoreID("store_cleanup_sessionless")
        let sA = CartSessionID("session_A")

        // Sessionless (eligible for cleanup when sessionID=nil)
        let sessionlessOldExpired = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: nil,
            items: [],
            status: .expired,
            createdAt: now.addingTimeInterval(-10_000),
            updatedAt: now.addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
        )

        // Session-based (must NOT be affected when sessionID=nil)
        let sessionAOldExpired = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sA,
            items: [],
            status: .expired,
            createdAt: now.addingTimeInterval(-10_000),
            updatedAt: now.addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
        )

        let (manager, _) = makeSUT(initialCarts: [sessionlessOldExpired, sessionAOldExpired])

        let policy = CartLifecyclePolicy(
            maxArchivedCartsPerScope: nil,
            deleteExpiredOlderThanDays: 1,
            deleteCancelledOlderThanDays: nil,
            deleteCheckedOutOlderThanDays: nil
        )

        let result = try await manager.cleanupCarts(
            storeID: storeID,
            profileID: nil,
            sessionID: nil,     // sessionless only
            policy: policy,
            now: now
        )

        #expect(result.deletedCartIDs.contains(sessionlessOldExpired.id))
        #expect(!result.deletedCartIDs.contains(sessionAOldExpired.id))

        let deleted = try await manager.getCart(id: sessionlessOldExpired.id)
        let untouched = try await manager.getCart(id: sessionAOldExpired.id)

        #expect(deleted == nil)
        #expect(untouched != nil)
    }

    @Test
    func cleanupCarts_neverDeletesActive_deletesExpiredByAge() async throws {
        let now = Date()

        let storeID = StoreID("store_cleanup_active_protection")
        let sessionID = CartSessionID("session_cleanup_active_protection")

        let activeOld = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            items: [],
            status: .active,
            createdAt: now.addingTimeInterval(-20 * 24 * 60 * 60),
            updatedAt: now.addingTimeInterval(-20 * 24 * 60 * 60)
        )

        let expiredOld = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            items: [],
            status: .expired,
            createdAt: now.addingTimeInterval(-20 * 24 * 60 * 60),
            updatedAt: now.addingTimeInterval(-20 * 24 * 60 * 60)
        )

        let (manager, _) = makeSUT(initialCarts: [activeOld, expiredOld])

        let policy = CartLifecyclePolicy(
            maxArchivedCartsPerScope: nil,
            deleteExpiredOlderThanDays: 7,
            deleteCancelledOlderThanDays: nil,
            deleteCheckedOutOlderThanDays: nil
        )

        let result = try await manager.cleanupCarts(
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            policy: policy,
            now: now
        )

        #expect(result.deletedCartIDs.contains(expiredOld.id))
        #expect(!result.deletedCartIDs.contains(activeOld.id))

        let activeStillThere = try await manager.getCart(id: activeOld.id)
        let expiredDeleted = try await manager.getCart(id: expiredOld.id)

        #expect(activeStillThere != nil)
        #expect(expiredDeleted == nil)
    }

    @Test
    func cleanupCarts_retentionWholeInput_keepsMostRecentArchived() async throws {
        let now = Date()

        let storeID = StoreID("store_cleanup_retention_wholeInput")
        let sessionID = CartSessionID("session_cleanup_retention_wholeInput")

        // 3 archived carts with descending recency
        let newest = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            items: [],
            status: .checkedOut,
            createdAt: now.addingTimeInterval(-1_000),
            updatedAt: now.addingTimeInterval(-10) // most recent
        )

        let middle = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            items: [],
            status: .checkedOut,
            createdAt: now.addingTimeInterval(-2_000),
            updatedAt: now.addingTimeInterval(-200)
        )

        let oldest = Cart(
            id: .generate(),
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            items: [],
            status: .checkedOut,
            createdAt: now.addingTimeInterval(-3_000),
            updatedAt: now.addingTimeInterval(-500)
        )

        let (manager, _) = makeSUT(initialCarts: [newest, middle, oldest])

        let policy = CartLifecyclePolicy(
            maxArchivedCartsPerScope: 1,     // keep only 1 archived in this scope
            deleteExpiredOlderThanDays: nil,
            deleteCancelledOlderThanDays: nil,
            deleteCheckedOutOlderThanDays: nil
        )

        let result = try await manager.cleanupCarts(
            storeID: storeID,
            profileID: nil,
            sessionID: sessionID,
            policy: policy,
            now: now
        )

        #expect(result.deletedCartIDs.contains(middle.id))
        #expect(result.deletedCartIDs.contains(oldest.id))
        #expect(!result.deletedCartIDs.contains(newest.id))

        #expect(try await manager.getCart(id: newest.id) != nil)
        #expect(try await manager.getCart(id: middle.id) == nil)
        #expect(try await manager.getCart(id: oldest.id) == nil)
    }

    @Test
    func cleanupCartGroup_retentionPerStore_keepsMostRecentArchivedPerStore() async throws {
        let now = Date()

        let profileID = UserProfileID("profile_cleanup_group")
        let sessionID = CartSessionID("session_cleanup_group")

        let storeA = StoreID("storeA_cleanup_group")
        let storeB = StoreID("storeB_cleanup_group")

        // Store A archived (3)
        let aNewest = Cart(
            id: .generate(), storeID: storeA, profileID: profileID, sessionID: sessionID,
            items: [], status: .cancelled,
            createdAt: now.addingTimeInterval(-1_000),
            updatedAt: now.addingTimeInterval(-10)
        )
        let aMiddle = Cart(
            id: .generate(), storeID: storeA, profileID: profileID, sessionID: sessionID,
            items: [], status: .cancelled,
            createdAt: now.addingTimeInterval(-2_000),
            updatedAt: now.addingTimeInterval(-200)
        )
        let aOldest = Cart(
            id: .generate(), storeID: storeA, profileID: profileID, sessionID: sessionID,
            items: [], status: .cancelled,
            createdAt: now.addingTimeInterval(-3_000),
            updatedAt: now.addingTimeInterval(-500)
        )

        // Store B archived (2)
        let bNewest = Cart(
            id: .generate(), storeID: storeB, profileID: profileID, sessionID: sessionID,
            items: [], status: .checkedOut,
            createdAt: now.addingTimeInterval(-1_500),
            updatedAt: now.addingTimeInterval(-20)
        )
        let bOldest = Cart(
            id: .generate(), storeID: storeB, profileID: profileID, sessionID: sessionID,
            items: [], status: .checkedOut,
            createdAt: now.addingTimeInterval(-2_500),
            updatedAt: now.addingTimeInterval(-400)
        )

        // Active carts (must never be deleted)
        let aActive = Cart(
            id: .generate(), storeID: storeA, profileID: profileID, sessionID: sessionID,
            items: [], status: .active,
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-5)
        )
        let bActive = Cart(
            id: .generate(), storeID: storeB, profileID: profileID, sessionID: sessionID,
            items: [], status: .active,
            createdAt: now.addingTimeInterval(-120),
            updatedAt: now.addingTimeInterval(-6)
        )

        // Another session group cart that must remain untouched
        let otherSession = CartSessionID("session_other")
        let otherGroupCart = Cart(
            id: .generate(), storeID: storeA, profileID: profileID, sessionID: otherSession,
            items: [], status: .cancelled,
            createdAt: now.addingTimeInterval(-10_000),
            updatedAt: now.addingTimeInterval(-10_000)
        )

        let (manager, _) = makeSUT(initialCarts: [
            aNewest, aMiddle, aOldest,
            bNewest, bOldest,
            aActive, bActive,
            otherGroupCart
        ])

        let policy = CartLifecyclePolicy(
            maxArchivedCartsPerScope: 1, // per-store in cleanupCartGroup
            deleteExpiredOlderThanDays: nil,
            deleteCancelledOlderThanDays: nil,
            deleteCheckedOutOlderThanDays: nil
        )

        let result = try await manager.cleanupCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            policy: policy,
            now: now
        )

        // Store A: keep newest archived + active
        #expect(!result.deletedCartIDs.contains(aNewest.id))
        #expect(result.deletedCartIDs.contains(aMiddle.id))
        #expect(result.deletedCartIDs.contains(aOldest.id))
        #expect(!result.deletedCartIDs.contains(aActive.id))

        // Store B: keep newest archived + active
        #expect(!result.deletedCartIDs.contains(bNewest.id))
        #expect(result.deletedCartIDs.contains(bOldest.id))
        #expect(!result.deletedCartIDs.contains(bActive.id))

        // Other session group: untouched
        #expect(!result.deletedCartIDs.contains(otherGroupCart.id))

        #expect(try await manager.getCart(id: aNewest.id) != nil)
        #expect(try await manager.getCart(id: aMiddle.id) == nil)
        #expect(try await manager.getCart(id: aOldest.id) == nil)

        #expect(try await manager.getCart(id: bNewest.id) != nil)
        #expect(try await manager.getCart(id: bOldest.id) == nil)

        #expect(try await manager.getCart(id: aActive.id) != nil)
        #expect(try await manager.getCart(id: bActive.id) != nil)

        #expect(try await manager.getCart(id: otherGroupCart.id) != nil)
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
