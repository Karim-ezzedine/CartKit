import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

extension CartManagerDomainTests {
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
}
