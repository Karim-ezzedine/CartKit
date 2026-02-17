import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

struct DomainPolicyTests {

    @Test
    func cartStatus_canTransition_whenActiveToArchived() {
        #expect(CartStatus.active.canTransition(to: .checkedOut))
        #expect(CartStatus.active.canTransition(to: .cancelled))
        #expect(CartStatus.active.canTransition(to: .expired))
    }

    @Test
    func cartStatus_cannotTransition_whenArchivedToDifferentStatus() {
        #expect(!CartStatus.checkedOut.canTransition(to: .active))
        #expect(!CartStatus.cancelled.canTransition(to: .expired))
        #expect(!CartStatus.expired.canTransition(to: .cancelled))
    }

    @Test
    func cartStatus_selfTransition_isAllowed() {
        #expect(CartStatus.active.canTransition(to: .active))
        #expect(CartStatus.checkedOut.canTransition(to: .checkedOut))
    }

    @Test
    func activeCartGroupPolicy_eligibleCarts_excludesEmptyByDefault() {
        let policy = ActiveCartGroupPolicy()
        let storeID = StoreID("store_policy_empty")

        var nonEmpty = CartTestFixtures.guestCart(storeID: storeID)
        nonEmpty.status = .active

        var empty = CartTestFixtures.guestCart(storeID: StoreID("store_policy_empty_2"))
        empty.status = .active
        empty.items = []

        let eligible = policy.eligibleCarts(
            from: [nonEmpty, empty],
            includeEmptyCarts: false
        )

        #expect(eligible.count == 1)
        #expect(eligible.first?.storeID == storeID)
    }

    @Test
    func activeCartGroupPolicy_duplicateStoreIDs_detectsRepeatedStores() {
        let policy = ActiveCartGroupPolicy()
        let repeatedStore = StoreID("store_policy_duplicate")
        let profileID = UserProfileID("profile_policy_duplicate")
        let sessionID = CartSessionID("session_policy_duplicate")

        var first = CartTestFixtures.loggedInCart(
            storeID: repeatedStore,
            profileID: profileID,
            sessionID: sessionID
        )
        first.status = .active

        var second = CartTestFixtures.loggedInCart(
            storeID: repeatedStore,
            profileID: profileID,
            sessionID: sessionID
        )
        second.status = .active

        let duplicates = policy.duplicateStoreIDs(in: [first, second])
        #expect(duplicates == Set([repeatedStore]))
    }

    @Test
    func cartStatusTransitionPolicy_rejectsGuestCheckout() throws {
        let policy = CartStatusTransitionPolicy()

        var guest = CartTestFixtures.guestCart(storeID: StoreID("store_policy_checkout_guest"))
        guest.status = .active

        #expect(throws: CartError.self) {
            try policy.validateTransition(for: guest, to: .checkedOut)
        }
    }

    @Test
    func cartStatusTransitionPolicy_allowsProfileCheckout() throws {
        let policy = CartStatusTransitionPolicy()

        var profileCart = CartTestFixtures.loggedInCart(
            storeID: StoreID("store_policy_checkout_profile"),
            profileID: UserProfileID("profile_policy_checkout_profile")
        )
        profileCart.status = .active

        try policy.validateTransition(for: profileCart, to: .checkedOut)
    }

    @Test
    func cartStatusTransitionPolicy_shouldClearActiveCart_onlyForActiveToArchived() {
        let policy = CartStatusTransitionPolicy()

        #expect(policy.shouldClearActiveCart(from: .active, to: .checkedOut))
        #expect(policy.shouldClearActiveCart(from: .active, to: .expired))
        #expect(!policy.shouldClearActiveCart(from: .active, to: .active))
        #expect(!policy.shouldClearActiveCart(from: .checkedOut, to: .checkedOut))
    }

    @Test
    func cartStatusTransitionPolicy_requiresFullValidation_onlyForActiveToCheckedOut() {
        let policy = CartStatusTransitionPolicy()

        #expect(policy.requiresFullValidation(from: .active, to: .checkedOut))
        #expect(!policy.requiresFullValidation(from: .active, to: .expired))
        #expect(!policy.requiresFullValidation(from: .checkedOut, to: .checkedOut))
    }

    @Test
    func guestCartMigrationPolicy_requiresGuestActiveCart() throws {
        let policy = GuestCartMigrationPolicy()

        #expect(throws: CartError.self) {
            _ = try policy.requireGuestActiveCart(
                nil,
                storeID: StoreID("store_guest_migration_missing")
            )
        }
    }

    @Test
    func guestCartMigrationPolicy_rejectsOccupiedTargetScope() throws {
        let policy = GuestCartMigrationPolicy()

        let activeProfileCart = CartTestFixtures.loggedInCart(
            storeID: StoreID("store_guest_migration_target"),
            profileID: UserProfileID("profile_guest_migration_target")
        )

        #expect(throws: CartError.self) {
            try policy.validateTargetScopeIsEmpty(
                activeProfileCart: activeProfileCart,
                storeID: StoreID("store_guest_migration_target"),
                profileID: UserProfileID("profile_guest_migration_target")
            )
        }
    }

    @Test
    func guestCartMigrationPolicy_makeMovedCart_preservesIdentityAndMarksActive() {
        let policy = GuestCartMigrationPolicy()
        let targetProfileID = UserProfileID("profile_guest_migration_move")
        let now = Date(timeIntervalSince1970: 77_777)

        var guest = CartTestFixtures.guestCart(
            storeID: StoreID("store_guest_migration_move"),
            sessionID: CartSessionID("session_guest_migration_move")
        )
        guest.status = .active

        let moved = policy.makeMovedCart(
            from: guest,
            to: targetProfileID,
            now: now
        )

        #expect(moved.id == guest.id)
        #expect(moved.storeID == guest.storeID)
        #expect(moved.profileID == targetProfileID)
        #expect(moved.status == CartStatus.active)
        #expect(moved.updatedAt == now)
    }
}
