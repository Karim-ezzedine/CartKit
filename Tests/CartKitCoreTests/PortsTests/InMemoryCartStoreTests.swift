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
            profile: .guestOnly,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let guestResults = try await store.fetchCarts(matching: guestQuery, limit: nil)
        
        #expect(guestResults.count == 1)
        #expect(guestResults.first?.id == guestCart.id)
        
        // Logged-in query: profileID != nil
        let profileQuery = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let profileResults = try await store.fetchCarts(matching: profileQuery, limit: nil)
        
        #expect(profileResults.count == 1)
        #expect(profileResults.first?.id == profileCart.id)
    }

    @Test
    func fetchCarts_profileAny_includesGuestAndLoggedIn() async throws {
        let now = Date()

        let storeID = CartTestFixtures.demoStoreID
        let otherStoreID = CartTestFixtures.anotherStoreID
        let profileID = CartTestFixtures.demoProfileID

        let guestCart = CartTestFixtures.guestCart(storeID: storeID, now: now)
        let profileCart = CartTestFixtures.loggedInCart(
            storeID: storeID,
            profileID: profileID,
            now: now
        )
        let otherStoreCart = CartTestFixtures.guestCart(storeID: otherStoreID, now: now)

        let store = makeStore(initialCarts: [guestCart, profileCart, otherStoreCart])

        let query = CartQuery(
            storeID: storeID,
            profile: .any,
            session: .sessionless,
            statuses: nil,
            sort: .updatedAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: nil)

        #expect(results.count == 2)
        #expect(Set(results.map(\.id)) == Set([guestCart.id, profileCart.id]))
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
            profile: .guestOnly,
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
            profile: .guestOnly,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let results = try await store.fetchCarts(matching: query, limit: 1)
        
        #expect(results.count == 1)
        #expect(results.first?.id == newerCart.id)
    }
    
    @Test
    func fetch_sessionFilter_semantics_areCorrect() async throws {
        let storeID = CartTestFixtures.demoStoreID
        let profileID = CartTestFixtures.demoProfileID
        let sA = CartSessionID("session_A")
        let sB = CartSessionID("session_B")
        let now = Date()

        var nilCart = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileID, sessionID: nil, now: now)
        nilCart.status = .active

        var a = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileID, sessionID: sA, now: now)
        a.status = .active

        var b = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileID, sessionID: sB, now: now)
        b.status = .active

        let store = makeStore(initialCarts: [nilCart, a, b])

        let qNil = CartQuery(storeID: storeID, profile: .profile(profileID), session: .sessionless, statuses: [.active], sort: .updatedAtDescending)
        let rNil = try await store.fetchCarts(matching: qNil, limit: nil)
        #expect(rNil.count == 1)
        #expect(rNil.first?.sessionID == nil)

        let qA = CartQuery(storeID: storeID, profile: .profile(profileID), session: .session(sA), statuses: [.active], sort: .updatedAtDescending)
        let rA = try await store.fetchCarts(matching: qA, limit: nil)
        #expect(rA.count == 1)
        #expect(rA.first?.sessionID == sA)

        let qAny = CartQuery(storeID: storeID, profile: .profile(profileID), session: .any, statuses: [.active], sort: .updatedAtDescending)
        let rAny = try await store.fetchCarts(matching: qAny, limit: nil)
        #expect(rAny.count == 3)
    }

    @Test
    func fetch_storeID_nil_meansAnyStore() async throws {
        let profileID = CartTestFixtures.demoProfileID
        let sA = CartSessionID("session_any_store")
        let now = Date()

        let store1 = CartTestFixtures.demoStoreID
        let store2 = CartTestFixtures.anotherStoreID

        var c1 = CartTestFixtures.loggedInCart(storeID: store1, profileID: profileID, sessionID: sA, now: now)
        c1.status = .active
        var c2 = CartTestFixtures.loggedInCart(storeID: store2, profileID: profileID, sessionID: sA, now: now)
        c2.status = .active

        let store = makeStore(initialCarts: [c1, c2])

        let q = CartQuery(storeID: nil, profile: .profile(profileID), session: .session(sA), statuses: [.active], sort: .updatedAtDescending)
        let r = try await store.fetchCarts(matching: q, limit: nil)

        #expect(Set(r.map(\.storeID)) == Set([store1, store2]))
    }

    @Test
    func fetch_statusesNil_equalsEmptySet_noFilter() async throws {
        let storeID = CartTestFixtures.demoStoreID
        let profileID = CartTestFixtures.demoProfileID
        let sA = CartSessionID("session_status_empty")
        let now = Date()

        var active = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileID, sessionID: sA, now: now)
        active.status = .active

        var checkedOut = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileID, sessionID: sA, now: now)
        checkedOut.status = .checkedOut

        let store = makeStore(initialCarts: [active, checkedOut])

        let qNil = CartQuery(storeID: storeID, profile: .profile(profileID), session: .session(sA), statuses: nil, sort: .updatedAtDescending)
        let qEmpty = CartQuery(storeID: storeID, profile: .profile(profileID), session: .session(sA), statuses: [], sort: .updatedAtDescending)

        let rNil = try await store.fetchCarts(matching: qNil, limit: nil)
        let rEmpty = try await store.fetchCarts(matching: qEmpty, limit: nil)

        #expect(Set(rNil.map(\.id)) == Set(rEmpty.map(\.id)))
        #expect(rNil.count == 2)
    }
}
