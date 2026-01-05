import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

struct InMemoryCartStoreTests {
    
    // MARK: - Factory
    
    private func makeStore(initialCarts: [Cart] = []) -> InMemoryCartStore {
        InMemoryCartStore(initialCarts: initialCarts)
    }
    
    // MARK: - Save / load / delete
    
    @Test
    func saveAndLoad_roundTripsCartByID() async throws {
        let store = makeStore()
        let now = Date()
        
        let cart = CartTestFixtures.guestCart(
            storeID: CartTestFixtures.demoStoreID,
            now: now
        )
        
        try await store.saveCart(cart)
        
        let loaded = try await store.loadCart(id: cart.id)
        
        #expect(loaded?.id == cart.id)
        #expect(loaded?.storeID == cart.storeID)
        #expect(loaded?.profileID == cart.profileID)
    }
    
    @Test
    func deleteCart_removesItFromStore() async throws {
        let now = Date()
        let cart = CartTestFixtures.guestCart(
            storeID: CartTestFixtures.demoStoreID,
            now: now
        )
        
        let store = makeStore(initialCarts: [cart])
        
        let loadedBefore = try await store.loadCart(id: cart.id)
        #expect(loadedBefore != nil)
        
        try await store.deleteCart(id: cart.id)
        
        let loadedAfter = try await store.loadCart(id: cart.id)
        #expect(loadedAfter == nil)
    }
    
    // MARK: - Fetch: storeID + profileID
    
    @Test
    func fetchCarts_filtersByStoreAndGuestVsProfile() async throws {
        let now = Date()
        
        let storeID = CartTestFixtures.demoStoreID
        let otherStoreID = CartTestFixtures.anotherStoreID
        let profileID = CartTestFixtures.demoProfileID
        
        let guestCart = CartTestFixtures.guestCart(
            storeID: storeID,
            now: now
        )
        
        let profileCart = CartTestFixtures.loggedInCart(
            storeID: storeID,
            profileID: profileID,
            now: now
        )
        
        let otherStoreCart = CartTestFixtures.loggedInCart(
            storeID: otherStoreID,
            profileID: profileID,
            now: now
        )
        
        let store = makeStore(initialCarts: [guestCart, profileCart, otherStoreCart])
        
        // Guest query: profileID == nil
        let guestQuery = CartQuery(
            storeID: storeID,
            profileID: nil,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let guestResults = try await store.fetchCarts(matching: guestQuery, limit: nil)
        
        #expect(guestResults.count == 1)
        #expect(guestResults.first?.id == guestCart.id)
        
        // Logged-in query: profileID != nil
        let profileQuery = CartQuery(
            storeID: storeID,
            profileID: profileID,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let profileResults = try await store.fetchCarts(matching: profileQuery, limit: nil)
        
        #expect(profileResults.count == 1)
        #expect(profileResults.first?.id == profileCart.id)
    }
    
    // MARK: - Fetch: statuses, sort, limit
    
    @Test
    func fetchCarts_respectsStatusFilter() async throws {
        let now = Date()
        let storeID = CartTestFixtures.demoStoreID
        
        var activeCart = CartTestFixtures.guestCart(
            storeID: storeID,
            now: now.addingTimeInterval(-200)
        )
        activeCart.status = .active
        
        var checkedOutCart = CartTestFixtures.guestCart(
            storeID: storeID,
            now: now.addingTimeInterval(-100)
        )
        checkedOutCart.status = .checkedOut
        
        let store = makeStore(initialCarts: [activeCart, checkedOutCart])
        
        let query = CartQuery(
            storeID: storeID,
            profileID: nil,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        
        let results = try await store.fetchCarts(matching: query, limit: nil)
        
        #expect(results.count == 1)
        #expect(results.first?.id == activeCart.id)
    }
    
    @Test
    func fetchCarts_appliesSortAndLimit() async throws {
        let now = Date()
        let storeID = CartTestFixtures.demoStoreID
        
        // Older cart
        var olderCart = CartTestFixtures.guestCart(
            storeID: storeID,
            now: now.addingTimeInterval(-300)
        )
        olderCart.status = .active
        
        // Newer cart
        var newerCart = CartTestFixtures.guestCart(
            storeID: storeID,
            now: now.addingTimeInterval(-100)
        )
        newerCart.status = .active
        
        let store = makeStore(initialCarts: [olderCart, newerCart])
        
        let query = CartQuery(
            storeID: storeID,
            profileID: nil,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let results = try await store.fetchCarts(matching: query, limit: 1)
        
        #expect(results.count == 1)
        #expect(results.first?.id == newerCart.id)
    }
}
