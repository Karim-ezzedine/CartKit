import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

//MARK: - Migrate from guest to logged in

extension CartManagerDomainTests {
    
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
    
    @Test
    func migrateGuestActiveCart_move_preservesSavedPromotionKinds() async throws {
        let storeID = StoreID(rawValue: "store_migrate_move_promos")
        let profileID = UserProfileID("profile_migrate_move")
        let sessionID = CartSessionID("session_migrate_move")

        var guest = CartTestFixtures.guestCart(storeID: storeID, sessionID: sessionID)
        guest.status = .active
        guest.savedPromotionKinds = [.freeDelivery]

        let (manager, _) = makeSUT(initialCarts: [guest])

        let migrated = try await manager.migrateGuestActiveCart(
            storeID: storeID,
            to: profileID,
            strategy: .move,
            sessionID: sessionID
        )

        #expect(migrated.profileID == profileID)
        #expect(migrated.savedPromotionKinds == [.freeDelivery])
    }
}
