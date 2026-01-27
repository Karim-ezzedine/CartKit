import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

extension CartManagerDomainTests {
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
}
