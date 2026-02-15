import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

extension CartManagerDomainTests {
    
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

    @Test
    func queryCarts_filtersByProfileScopeAndStatuses() async throws {
        let storeID = StoreID("store_query")
        let otherStoreID = StoreID("store_other_query")
        let profileA = UserProfileID("profile_query_A")
        let profileB = UserProfileID("profile_query_B")

        var guest = CartTestFixtures.guestCart(storeID: storeID)
        guest.status = .active

        var profileActive = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileA)
        profileActive.status = .active

        var profileCheckedOut = CartTestFixtures.loggedInCart(storeID: storeID, profileID: profileB)
        profileCheckedOut.status = .checkedOut

        var otherStoreGuest = CartTestFixtures.guestCart(storeID: otherStoreID)
        otherStoreGuest.status = .active

        let (manager, _) = makeSUT(initialCarts: [guest, profileActive, profileCheckedOut, otherStoreGuest])

        let anyProfileResults = try await manager.queryCarts(
            matching: CartQuery(
                storeID: storeID,
                profile: .any,
                session: .sessionless,
                statuses: nil,
                sort: .updatedAtDescending
            )
        )
        #expect(anyProfileResults.count == 3)
        #expect(Set(anyProfileResults.map(\.id)) == Set([guest.id, profileActive.id, profileCheckedOut.id]))

        let guestOnlyResults = try await manager.queryCarts(
            matching: CartQuery(
                storeID: storeID,
                profile: .guestOnly,
                session: .sessionless,
                statuses: nil,
                sort: .updatedAtDescending
            )
        )
        #expect(guestOnlyResults.count == 1)
        #expect(guestOnlyResults.first?.id == guest.id)

        let specificProfileResults = try await manager.queryCarts(
            matching: CartQuery(
                storeID: storeID,
                profile: .profile(profileA),
                session: .sessionless,
                statuses: nil,
                sort: .updatedAtDescending
            )
        )
        #expect(specificProfileResults.count == 1)
        #expect(specificProfileResults.first?.id == profileActive.id)

        let statusResults = try await manager.queryCarts(
            matching: CartQuery(
                storeID: storeID,
                profile: .any,
                session: .sessionless,
                statuses: [.checkedOut],
                sort: .updatedAtDescending
            )
        )
        #expect(statusResults.count == 1)
        #expect(statusResults.first?.id == profileCheckedOut.id)
    }
}
