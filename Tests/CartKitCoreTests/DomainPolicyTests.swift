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
}
