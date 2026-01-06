import XCTest
@testable import CartKitCore
import CartKitTestingSupport

#if canImport(SwiftData) && os(iOS)
@testable import CartKitStorageSwiftData
import SwiftData

@available(iOS 17, *)
final class SwiftDataCartStoreTests: XCTestCase {

    private var store: SwiftDataCartStore!

    override func setUp() async throws {
        store = try SwiftDataCartStore(configuration: .init(inMemory: true))
    }

    // MARK: - CRUD

    func test_save_then_load_returns_cart() async throws {
        let now = Date()
        let cart = CartTestFixtures.guestCart(
            storeID: CartTestFixtures.demoStoreID,
            now: now
        )

        try await store.saveCart(cart)

        let loaded = try await store.loadCart(id: cart.id)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, cart.id)
        XCTAssertEqual(loaded?.storeID, cart.storeID)
        XCTAssertEqual(loaded?.profileID, nil) // guest
        XCTAssertEqual(loaded?.status, cart.status)
        XCTAssertEqual(loaded?.items.count, cart.items.count)
    }

    func test_save_twice_updates_existing_cart() async throws {
        let now = Date()
        var cart = CartTestFixtures.loggedInCart(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            now: now
        )

        try await store.saveCart(cart)

        // Simulate core bumping timestamps + changing content
        cart = Cart(
            id: cart.id,
            storeID: cart.storeID,
            profileID: cart.profileID,
            items: cart.items, // keep items for now
            status: .active,
            createdAt: cart.createdAt,
            updatedAt: now.addingTimeInterval(60),
            metadata: cart.metadata,
            displayName: cart.displayName,
            context: cart.context,
            storeImageURL: cart.storeImageURL
        )

        try await store.saveCart(cart)

        let loaded = try await store.loadCart(id: cart.id)
        XCTAssertEqual(loaded?.updatedAt, cart.updatedAt)
    }

    func test_delete_is_idempotent_and_removes_cart() async throws {
        let cart = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID)
        try await store.saveCart(cart)

        try await store.deleteCart(id: cart.id)
        try await store.deleteCart(id: cart.id) // idempotent: should not throw

        let loaded = try await store.loadCart(id: cart.id)
        XCTAssertNil(loaded)
    }

    // MARK: - Query semantics

    func test_fetch_filters_by_store_and_guest_scope() async throws {
        let now = Date()

        let guestS1 = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID, now: now)
        let loggedS1 = CartTestFixtures.loggedInCart(storeID: CartTestFixtures.demoStoreID, profileID: CartTestFixtures.demoProfileID, now: now)
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

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, guestS1.id)
        XCTAssertNil(result.first?.profileID)
    }

    func test_fetch_filters_by_profile_scope() async throws {
        let now = Date()

        let loggedA = CartTestFixtures.loggedInCart(storeID: CartTestFixtures.demoStoreID, profileID: CartTestFixtures.demoProfileID, now: now)
        let loggedB = CartTestFixtures.loggedInCart(storeID: CartTestFixtures.demoStoreID, profileID: UserProfileID(rawValue: "user_other"), now: now)

        try await store.saveCart(loggedA)
        try await store.saveCart(loggedB)

        let query = CartQuery(
            storeID: CartTestFixtures.demoStoreID,
            profileID: CartTestFixtures.demoProfileID,
            statuses: nil,
            sort: .createdAtAscending
        )

        let result = try await store.fetchCarts(matching: query, limit: nil)

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.profileID, CartTestFixtures.demoProfileID)
    }

    func test_fetch_filters_by_statuses() async throws {
        let now = Date()

        let guest = CartTestFixtures.guestCart(storeID: CartTestFixtures.demoStoreID, now: now)
        var logged = CartTestFixtures.loggedInCart(storeID: CartTestFixtures.demoStoreID, profileID: CartTestFixtures.demoProfileID, now: now)

        // Create additional carts by copying with different status
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
            storeImageURL: guest.storeImageURL
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
            storeImageURL: logged.storeImageURL
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

        XCTAssertEqual(Set(result.map(\.status)), Set([.active, .expired]))
        XCTAssertTrue(result.allSatisfy { $0.profileID == nil })
    }

    func test_fetch_applies_sort_and_limit() async throws {
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
            storeImageURL: nil
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
            storeImageURL: nil
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
            storeImageURL: nil
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

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.id), [c3.id, c2.id])
    }
}

#endif
