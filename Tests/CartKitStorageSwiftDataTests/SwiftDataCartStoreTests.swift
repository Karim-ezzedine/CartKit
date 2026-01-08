import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

#if canImport(SwiftData) && os(iOS)
@testable import CartKitStorageSwiftData
import SwiftData

struct SwiftDataCartStoreTests {

    // Swift Testing has no XCTestCase.setUp().
    // Keep tests isolated by creating a fresh in-memory store per test.
    @available(iOS 17, *)
    private func makeStore() throws -> SwiftDataCartStore {
        try SwiftDataCartStore(configuration: .init(inMemory: true))
    }

    // MARK: - CRUD

    @Test("save then load returns cart")
    @available(iOS 17, *)
    func save_then_load_returns_cart() async throws {
        let store = try makeStore()

        let now = Date()
        let cart = CartTestFixtures.guestCart(
            storeID: CartTestFixtures.demoStoreID,
            now: now
        )

        try await store.saveCart(cart)

        let loaded = try await store.loadCart(id: cart.id)

        let unwrapped = try #require(loaded)
        #expect(unwrapped.id == cart.id)
        #expect(unwrapped.storeID == cart.storeID)
        #expect(unwrapped.profileID == nil) // guest
        #expect(unwrapped.status == cart.status)
        #expect(unwrapped.items.count == cart.items.count)
    }

    @Test("save twice updates existing cart")
    @available(iOS 17, *)
    func save_twice_updates_existing_cart() async throws {
        let store = try makeStore()

        let now = Date()
        var cart = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            now: now
        )

        try await store.saveCart(cart)

        cart = Cart(
            id: cart.id,
            storeID: cart.storeID,
            profileID: cart.profileID,
            items: cart.items,
            status: .active,
            createdAt: cart.createdAt,
            updatedAt: now.addingTimeInterval(60),
            metadata: cart.metadata,
            displayName: cart.displayName,
            context: cart.context,
            storeImageURL: cart.storeImageURL,
            minSubtotal: cart.minSubtotal,
            maxItemCount: cart.maxItemCount
        )

        try await store.saveCart(cart)

        let loaded = try await store.loadCart(id: cart.id)
        let unwrapped = try #require(loaded)
        #expect(unwrapped.updatedAt == cart.updatedAt)
    }

    @Test("delete is idempotent and removes cart")
    @available(iOS 17, *)
    func delete_is_idempotent_and_removes_cart() async throws {
        let store = try makeStore()

        let cart = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID)
        try await store.saveCart(cart)

        try await store.deleteCart(id: cart.id)
        try await store.deleteCart(id: cart.id) // idempotent: should not throw

        let loaded = try await store.loadCart(id: cart.id)
        #expect(loaded == nil)
    }

    // MARK: - Query semantics

    @Test("fetch filters by store and guest scope")
    @available(iOS 17, *)
    func fetch_filters_by_store_and_guest_scope() async throws {
        let store = try makeStore()

        let now = Date()
        let guestS1 = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID, now: now)
        let loggedS1 = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            now: now
        )
        let guestS2 = CartTestFixtures.guestCart(storeID: CartTestFixtures.anotherStoreID, now: now)

        try await store.saveCart(guestS1)
        try await store.saveCart(loggedS1)
        try await store.saveCart(guestS2)

        let query = CartQuery(
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil,              // guest scope
            statuses: nil,
            sort: .updatedAtDescending
        )

        let result = try await store.fetchCarts(matching: query, limit: nil)

        #expect(result.count == 1)
        #expect(result.first?.id == guestS1.id)
        #expect(result.first?.profileID == nil)
    }

    @Test("fetch filters by profile scope")
    @available(iOS 17, *)
    func fetch_filters_by_profile_scope() async throws {
        let store = try makeStore()

        let now = Date()
        let loggedA = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            now: now
        )
        let loggedB = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: UserProfileID(rawValue: "user_other"),
            now: now
        )

        try await store.saveCart(loggedA)
        try await store.saveCart(loggedB)

        let query = CartQuery(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            statuses: nil,
            sort: .createdAtAscending
        )

        let result = try await store.fetchCarts(matching: query, limit: nil)

        #expect(result.count == 1)
        #expect(result.first?.profileID == CartTestFixtures.demoProfileID)
    }

    @Test("fetch filters by statuses")
    @available(iOS 17, *)
    func fetch_filters_by_statuses() async throws {
        let store = try makeStore()

        let now = Date()
        let guest = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID, now: now)
        var logged = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            now: now
        )

        let guestSaved = Cart(
            id: CartID.generate(),
            storeID: guest.storeID,
            profileID: nil,
            items: [
                CartItem(
                    id: CartItemID.generate(),
                    productID: "demo_expired_item",
                    quantity: 1,
                    unitPrice: Money(amount: 1.00, currencyCode: "USD"),
                    modifiers: [],
                    imageURL: nil
                )
            ],
            status: .expired,
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-50),
            metadata: guest.metadata,
            displayName: guest.displayName,
            context: guest.context,
            storeImageURL: guest.storeImageURL,
            minSubtotal: guest.minSubtotal,
            maxItemCount: guest.maxItemCount
        )

        logged = Cart(
            id: logged.id,
            storeID: logged.storeID,
            profileID: logged.profileID,
            items: logged.items,
            status: .checkedOut,
            createdAt: logged.createdAt,
            updatedAt: logged.updatedAt,
            metadata: logged.metadata,
            displayName: logged.displayName,
            context: logged.context,
            storeImageURL: logged.storeImageURL,
            minSubtotal: logged.minSubtotal,
            maxItemCount: logged.maxItemCount
        )

        try await store.saveCart(guest)
        try await store.saveCart(guestSaved)
        try await store.saveCart(logged)

        let query = CartQuery(
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil, // guest carts only
            statuses: [.active, .expired],
            sort: .createdAtAscending
        )

        let result = try await store.fetchCarts(matching: query, limit: nil)

        #expect(Set(result.map(\.status)) == Set([.active, .expired]))
        #expect(result.allSatisfy { $0.profileID == nil })
    }

    @Test("fetch applies sort and limit")
    @available(iOS 17, *)
    func fetch_applies_sort_and_limit() async throws {
        let store = try makeStore()

        let now = Date()
        let c1 = Cart(
            id: CartID.generate(),
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil,
            items: [],
            status: .active,
            createdAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-300),
            metadata: [:],
            displayName: nil,
            context: nil,
            storeImageURL: nil,
            minSubtotal: nil,
            maxItemCount: nil
        )

        let c2 = Cart(
            id: CartID.generate(),
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil,
            items: [],
            status: .active,
            createdAt: now.addingTimeInterval(-200),
            updatedAt: now.addingTimeInterval(-200),
            metadata: [:],
            displayName: nil,
            context: nil,
            storeImageURL: nil,
            minSubtotal: nil,
            maxItemCount: nil
        )

        let c3 = Cart(
            id: CartID.generate(),
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil,
            items: [],
            status: .active,
            createdAt: now.addingTimeInterval(-100),
            updatedAt: now.addingTimeInterval(-100),
            metadata: [:],
            displayName: nil,
            context: nil,
            storeImageURL: nil,
            minSubtotal: nil,
            maxItemCount: nil
        )

        try await store.saveCart(c1)
        try await store.saveCart(c2)
        try await store.saveCart(c3)

        let query = CartQuery(
            storeID: CartTestFixtures.demoStoreID,
            profileID: nil,
            statuses: nil,
            sort: .createdAtDescending
        )

        let result = try await store.fetchCarts(matching: query, limit: 2)

        #expect(result.count == 2)
        #expect(result.map(\.id) == [c3.id, c2.id])
    }
}

#endif
