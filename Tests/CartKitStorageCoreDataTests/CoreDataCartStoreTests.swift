import Foundation
import Testing
import CartKitCore
import CartKitStorageCoreData

struct CoreDataCartStoreTests {
    
    // MARK: - Helpers
    
    private func makeSUT() async throws -> CartStore {
        // In-memory store for deterministic unit tests (no disk IO).
        let config = CoreDataCartStoreConfiguration(
            modelName: "CartStorage",
            inMemory: true
        )
        return try await CoreDataCartStore(configuration: config)
    }
    
    private func makeCart(
        id: CartID = .generate(),
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID? = nil,
        status: CartStatus = .active,
        createdAt: Date = Date(timeIntervalSince1970: 1),
        updatedAt: Date = Date(timeIntervalSince1970: 2),
        metadata: [String: String] = ["source": "test"],
        savedPromotionKinds: [PromotionKind] = []
    ) -> Cart {
        Cart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            items: [],
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: metadata,
            displayName: "Test Cart",
            context: "unit-tests",
            storeImageURL: URL(string: "https://example.com/store.png"),
            minSubtotal: nil,
            maxItemCount: nil,
            savedPromotionKinds: savedPromotionKinds
        )
    }
    
    private func makeItem(
        id: CartItemID = CartItemID(rawValue: UUID().uuidString),
        productID: String = "p1",
        quantity: Int = 2,
        currency: String = "USD",
        unit: Decimal = 5
    ) -> CartItem {
        CartItem(
            id: id,
            productID: productID,
            quantity: quantity,
            unitPrice: Money(amount: unit, currencyCode: currency),
            totalPrice: Money(amount: unit * Decimal(quantity), currencyCode: currency),
            modifiers: [],
            imageURL: nil,
            availableStock: nil
        )
    }
    
    // MARK: - CRUD
    
    @Test
    func saveCart_thenLoadCart_returnsSameCart() async throws {
        let sut = try await makeSUT()
        
        let storeID = StoreID(rawValue: "store-1")
        let profileID = UserProfileID(rawValue: "profile-1")
        
        var cart = makeCart(storeID: storeID, profileID: profileID)
        
        cart.savedPromotionKinds = [
            .freeDelivery,
            .fixedAmountOffCart(Money(amount: 2, currencyCode: "USD"))
        ]
        
        cart.items = [makeItem(productID: "burger", quantity: 3)]
        
        try await sut.saveCart(cart)
        let loaded = try await sut.loadCart(id: cart.id)
        
        #expect(loaded != nil)
        #expect(loaded?.id == cart.id)
        #expect(loaded?.storeID == cart.storeID)
        #expect(loaded?.profileID == cart.profileID)
        #expect(loaded?.status == cart.status)
        #expect(loaded?.metadata == cart.metadata)
        #expect(loaded?.items.count == 1)
        #expect(loaded?.items.first?.productID == "burger")
        #expect(loaded?.items.first?.quantity == 3)
        #expect(loaded?.savedPromotionKinds == cart.savedPromotionKinds)
    }
    
    @Test
    func saveCart_whenSavingSameId_updatesExistingRecord() async throws {
        let sut = try await makeSUT()
        
        let storeID = StoreID(rawValue: "store-1")
        let profileID = UserProfileID(rawValue: "profile-1")
        
        let id = CartID.generate()
        
        var v1 = makeCart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            status: .active,
            metadata: ["v": "1"]
        )
        v1.savedPromotionKinds = [.freeDelivery]
        v1.items = [makeItem(productID: "a", quantity: 1)]
        try await sut.saveCart(v1)
        
        var v2 = makeCart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            status: .checkedOut,
            metadata: ["v": "2"]
        )
        v2.savedPromotionKinds = [.percentageOffCart(0.10)]
        v2.items = [makeItem(productID: "b", quantity: 4)]
        try await sut.saveCart(v2)
        
        let loaded = try await sut.loadCart(id: id)
        #expect(loaded?.metadata["v"] == "2")
        #expect(loaded?.status == .checkedOut)
        #expect(loaded?.items.count == 1)
        #expect(loaded?.items.first?.productID == "b")
        #expect(loaded?.items.first?.quantity == 4)
        #expect(loaded?.savedPromotionKinds == [.percentageOffCart(0.10)])
    }
    
    @Test
    func deleteCart_removesCart_andIsIdempotent() async throws {
        let sut = try await makeSUT()
        
        let storeID = StoreID(rawValue: "store-1")
        let cart = makeCart(storeID: storeID, profileID: nil)
        
        try await sut.saveCart(cart)
        #expect(try await sut.loadCart(id: cart.id) != nil)
        
        try await sut.deleteCart(id: cart.id)
        #expect(try await sut.loadCart(id: cart.id) == nil)
        
        // Idempotency: deleting again should not throw.
        try await sut.deleteCart(id: cart.id)
        #expect(try await sut.loadCart(id: cart.id) == nil)
    }
    
    // MARK: - Query semantics (guest vs logged-in)
    
    @Test
    func fetchCarts_filtersGuestVsLoggedInScopes() async throws {
        let sut = try await makeSUT()
        
        let storeA = StoreID(rawValue: "store-A")
        let storeB = StoreID(rawValue: "store-B")
        let profile1 = UserProfileID(rawValue: "profile-1")
        
        let guestA = makeCart(
            storeID: storeA,
            profileID: nil,
            status: .active,
            metadata: ["k": "guestA"]
        )
        
        let userA  = makeCart(
            storeID: storeA,
            profileID: profile1,
            status: .active,
            metadata: ["k": "userA"]
        )
        
        let guestB = makeCart(
            storeID: storeB,
            profileID: nil,
            status: .active,
            metadata: ["k": "guestB"]
        )
        
        try await sut.saveCart(guestA)
        try await sut.saveCart(userA)
        try await sut.saveCart(guestB)
        
        // Guest scope: storeA + profileID == nil
        let guestQuery = CartQuery(
            storeID: storeA,
            profileID: nil,
            statuses: nil,
            sort: .updatedAtDescending
        )
        let guestResults = try await sut.fetchCarts(matching: guestQuery, limit: nil)
        
        #expect(guestResults.count == 1)
        #expect(guestResults.first?.profileID == nil)
        #expect(guestResults.first?.storeID == storeA)
        #expect(guestResults.first?.metadata["k"] == "guestA")
        
        // Logged-in scope: storeA + profile1
        let userQuery = CartQuery(
            storeID: storeA,
            profileID: profile1,
            statuses: nil,
            sort: .updatedAtDescending
        )
        let userResults = try await sut.fetchCarts(matching: userQuery, limit: nil)
        
        #expect(userResults.count == 1)
        #expect(userResults.first?.profileID == profile1)
        #expect(userResults.first?.storeID == storeA)
        #expect(userResults.first?.metadata["k"] == "userA")
    }
    
    @Test
    func fetchCarts_filtersByStatusesWithinScope() async throws {
        let sut = try await makeSUT()
        
        let storeID = StoreID(rawValue: "store-A")
        let profileID = UserProfileID(rawValue: "profile-1")
        
        let active = makeCart(
            storeID: storeID,
            profileID: profileID,
            status: .active,
            metadata: ["s": "active"]
        )
        
        let checkedOut = makeCart(
            storeID: storeID,
            profileID: profileID,
            status: .checkedOut,
            metadata: ["s": "checkedOut"]
        )
        
        try await sut.saveCart(active)
        try await sut.saveCart(checkedOut)
        
        let q = CartQuery(
            storeID: storeID,
            profileID: profileID,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        
        let results = try await sut.fetchCarts(matching: q, limit: nil)
        #expect(results.count == 1)
        #expect(results.first?.status == .active)
        #expect(results.first?.metadata["s"] == "active")
    }
    
    @Test
    func fetchCarts_respectsLimit() async throws {
        let sut = try await makeSUT()
        
        let storeID = StoreID(rawValue: "store-A")
        
        // Guest carts in same scope; limit should cap results.
        // (We vary IDs; updatedAt is fixed in helper, so count/limit is the main assertion.)
        try await sut.saveCart(
            makeCart(
                storeID: storeID,
                profileID: nil,
                metadata: ["i": "1"]
            )
        )
        
        try await sut.saveCart(
            makeCart(
                storeID: storeID,
                profileID: nil,
                metadata: ["i": "2"]
            )
        )
        
        try await sut.saveCart(
            makeCart(
                storeID: storeID,
                profileID: nil,
                metadata: ["i": "3"]
            )
        )
        
        let q = CartQuery(storeID: storeID, profileID: nil, statuses: nil, sort: .updatedAtDescending)
        let results = try await sut.fetchCarts(matching: q, limit: 2)
        
        #expect(results.count == 2)
    }
    
    @Test
    func fetchCarts_sessionFilter_semantics_areCorrect() async throws {
        let sut = try await makeSUT()

        let storeID = StoreID(rawValue: "store_session_coredata")
        let profileID = UserProfileID(rawValue: "profile_session_coredata")

        let sA = CartSessionID("session_A")
        let sB = CartSessionID("session_B")

        let sessionless = makeCart(storeID: storeID, profileID: profileID, sessionID: nil, status: .active, metadata: ["k": "nil"])
        let a = makeCart(storeID: storeID, profileID: profileID, sessionID: sA, status: .active, metadata: ["k": "A"])
        let b = makeCart(storeID: storeID, profileID: profileID, sessionID: sB, status: .active, metadata: ["k": "B"])

        try await sut.saveCart(sessionless)
        try await sut.saveCart(a)
        try await sut.saveCart(b)

        // sessionless only
        let qNil = CartQuery(
            storeID: storeID,
            profileID: profileID,
            session: .sessionless,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let rNil = try await sut.fetchCarts(matching: qNil, limit: nil)
        #expect(rNil.count == 1)
        #expect(rNil.first?.sessionID == nil)

        // session A only
        let qA = CartQuery(
            storeID: storeID,
            profileID: profileID,
            session: .session(sA),
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let rA = try await sut.fetchCarts(matching: qA, limit: nil)
        #expect(rA.count == 1)
        #expect(rA.first?.sessionID == sA)

        // any session (nil + A + B)
        let qAny = CartQuery(
            storeID: storeID,
            profileID: profileID,
            session: .any,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let rAny = try await sut.fetchCarts(matching: qAny, limit: nil)
        #expect(rAny.count == 3)
    }

    @Test
    func fetchCarts_storeID_nil_meansAnyStore() async throws {
        let sut = try await makeSUT()

        let profileID = UserProfileID(rawValue: "profile_any_store_coredata")
        let sA = CartSessionID("session_any_store")

        let store1 = StoreID(rawValue: "store_any_1")
        let store2 = StoreID(rawValue: "store_any_2")

        let c1 = makeCart(storeID: store1, profileID: profileID, sessionID: sA, status: .active, metadata: ["s": "1"])
        let c2 = makeCart(storeID: store2, profileID: profileID, sessionID: sA, status: .active, metadata: ["s": "2"])

        try await sut.saveCart(c1)
        try await sut.saveCart(c2)

        let q = CartQuery(
            storeID: nil,                      // IMPORTANT
            profileID: profileID,
            session: .session(sA),
            statuses: [.active],
            sort: .updatedAtDescending
        )

        let r = try await sut.fetchCarts(matching: q, limit: nil)
        #expect(Set(r.map(\.storeID)) == Set([store1, store2]))
    }

    @Test
    func fetchCarts_statusesNil_equalsEmptySet_noFilter() async throws {
        let sut = try await makeSUT()

        let storeID = StoreID(rawValue: "store_status_empty_coredata")
        let profileID = UserProfileID(rawValue: "profile_status_empty_coredata")
        let sA = CartSessionID("session_status_empty")

        let active = makeCart(storeID: storeID, profileID: profileID, sessionID: sA, status: .active, metadata: ["st": "active"])
        let checkedOut = makeCart(storeID: storeID, profileID: profileID, sessionID: sA, status: .checkedOut, metadata: ["st": "checkedOut"])

        try await sut.saveCart(active)
        try await sut.saveCart(checkedOut)

        let qNil = CartQuery(storeID: storeID, profileID: profileID, session: .session(sA), statuses: nil, sort: .updatedAtDescending)
        let qEmpty = CartQuery(storeID: storeID, profileID: profileID, session: .session(sA), statuses: [], sort: .updatedAtDescending)

        let rNil = try await sut.fetchCarts(matching: qNil, limit: nil)
        let rEmpty = try await sut.fetchCarts(matching: qEmpty, limit: nil)

        #expect(Set(rNil.map(\.id)) == Set(rEmpty.map(\.id)))
        #expect(rNil.count == 2)
    }
}
