import Foundation
import CartKitCore

/// Provides shared contract checks for any `CartStore` implementation.
///
/// Use this suite from adapter-specific test targets to ensure all stores
/// behave consistently for CRUD and query semantics.
public struct CartStoreContractSuite {

    /// Factory used to create a fresh store instance per contract check.
    public typealias MakeStore = @Sendable () async throws -> CartStore

    /// Store factory for this contract suite.
    private let makeStore: MakeStore

    /// Creates a contract suite bound to a store factory.
    ///
    /// - Parameter makeStore: Async factory that returns a clean `CartStore`.
    public init(makeStore: @escaping MakeStore) {
        self.makeStore = makeStore
    }

    /// Verifies save + load round-trip behavior including items and promotions.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertSaveAndLoadRoundTrip() async throws {
        let store = try await makeStore()

        let cart = makeCart(
            storeID: StoreID("contract_store_save_load"),
            profileID: UserProfileID("contract_profile_save_load"),
            status: .active,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            items: [makeItem(productID: "contract_item", quantity: 3)],
            savedPromotionKinds: [
                .freeDelivery,
                .fixedAmountOffCart(Money(amount: 2, currencyCode: "USD"))
            ]
        )

        try await store.saveCart(cart)
        let loaded = try await store.loadCart(id: cart.id)

        try require(loaded != nil, "Expected saved cart to be loadable.")
        try require(loaded?.id == cart.id, "Expected loaded cart ID to match.")
        try require(loaded?.storeID == cart.storeID, "Expected loaded store to match.")
        try require(loaded?.profileID == cart.profileID, "Expected loaded profile to match.")
        try require(loaded?.status == cart.status, "Expected loaded status to match.")
        try require(loaded?.items.count == 1, "Expected one loaded item.")
        try require(loaded?.items.first?.quantity == 3, "Expected loaded item quantity to match.")
        try require(loaded?.savedPromotionKinds == cart.savedPromotionKinds, "Expected loaded promotions to match.")
    }

    /// Verifies saving the same cart ID twice updates the existing record.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertSaveTwiceUpdatesExistingRecord() async throws {
        let store = try await makeStore()

        let id = CartID.generate()
        let storeID = StoreID("contract_store_save_update")
        let profileID = UserProfileID("contract_profile_save_update")

        let first = makeCart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 200),
            items: [makeItem(productID: "before", quantity: 1)],
            savedPromotionKinds: [.freeDelivery]
        )
        try await store.saveCart(first)

        let second = makeCart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            status: .checkedOut,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 300),
            items: [makeItem(productID: "after", quantity: 4)],
            savedPromotionKinds: [.percentageOffCart(0.10)]
        )
        try await store.saveCart(second)

        let loaded = try await store.loadCart(id: id)
        try require(loaded != nil, "Expected cart to exist after update.")
        try require(loaded?.status == .checkedOut, "Expected updated status.")
        try require(loaded?.updatedAt == second.updatedAt, "Expected updated timestamp.")
        try require(loaded?.items.first?.productID == "after", "Expected updated item.")
        try require(loaded?.savedPromotionKinds == second.savedPromotionKinds, "Expected updated promotions.")
    }

    /// Verifies deleting a cart removes it and is idempotent.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertDeleteRemovesAndIsIdempotent() async throws {
        let store = try await makeStore()

        let cart = makeCart(
            storeID: StoreID("contract_store_delete"),
            profileID: nil,
            status: .active
        )

        try await store.saveCart(cart)
        let beforeDelete = try await store.loadCart(id: cart.id)
        try require(beforeDelete != nil, "Expected cart before delete.")

        try await store.deleteCart(id: cart.id)
        try await store.deleteCart(id: cart.id)

        let afterDelete = try await store.loadCart(id: cart.id)
        try require(afterDelete == nil, "Expected cart to be deleted.")
    }

    /// Verifies guest/profile scope filtering by store.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchFiltersGuestVsLoggedInScopes() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_scope")
        let otherStoreID = StoreID("contract_store_scope_other")
        let profileID = UserProfileID("contract_profile_scope")

        let guest = makeCart(storeID: storeID, profileID: nil, status: .active)
        let logged = makeCart(storeID: storeID, profileID: profileID, status: .active)
        let otherStoreGuest = makeCart(storeID: otherStoreID, profileID: nil, status: .active)

        try await store.saveCart(guest)
        try await store.saveCart(logged)
        try await store.saveCart(otherStoreGuest)

        let guestQuery = CartQuery(
            storeID: storeID,
            profile: .guestOnly,
            statuses: nil,
            sort: .updatedAtDescending
        )
        let guestResults = try await store.fetchCarts(matching: guestQuery, limit: nil)

        try require(guestResults.count == 1, "Expected one guest cart in scope.")
        try require(guestResults.first?.id == guest.id, "Expected guest cart in guest scope.")

        let profileQuery = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            statuses: nil,
            sort: .updatedAtDescending
        )
        let profileResults = try await store.fetchCarts(matching: profileQuery, limit: nil)

        try require(profileResults.count == 1, "Expected one profile cart in scope.")
        try require(profileResults.first?.id == logged.id, "Expected logged-in cart in profile scope.")
    }

    /// Verifies profile-scope filtering returns only carts for the requested profile.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchFiltersBySpecificProfileScope() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_profile_filter")
        let targetProfile = UserProfileID("contract_profile_target")
        let otherProfile = UserProfileID("contract_profile_other")

        let targetCart = makeCart(storeID: storeID, profileID: targetProfile, status: .active)
        let otherCart = makeCart(storeID: storeID, profileID: otherProfile, status: .active)

        try await store.saveCart(targetCart)
        try await store.saveCart(otherCart)

        let query = CartQuery(
            storeID: storeID,
            profile: .profile(targetProfile),
            statuses: nil,
            sort: .updatedAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: nil)

        try require(results.count == 1, "Expected one cart for target profile.")
        try require(results.first?.id == targetCart.id, "Expected only target profile cart.")
    }

    /// Verifies `.any` profile filtering includes both guest and logged-in carts.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchProfileAnyIncludesGuestAndLoggedIn() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_profile_any")
        let otherStoreID = StoreID("contract_store_profile_any_other")
        let profileID = UserProfileID("contract_profile_any")

        let guest = makeCart(storeID: storeID, profileID: nil, status: .active)
        let logged = makeCart(storeID: storeID, profileID: profileID, status: .active)
        let otherStoreGuest = makeCart(storeID: otherStoreID, profileID: nil, status: .active)

        try await store.saveCart(guest)
        try await store.saveCart(logged)
        try await store.saveCart(otherStoreGuest)

        let query = CartQuery(
            storeID: storeID,
            profile: .any,
            session: .sessionless,
            statuses: nil,
            sort: .updatedAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: nil)

        try require(results.count == 2, "Expected guest + logged-in carts for `.any` profile.")
        try require(Set(results.map(\.id)) == Set([guest.id, logged.id]), "Expected matching IDs for `.any` profile.")
    }

    /// Verifies status filtering within one scope.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchFiltersByStatusesWithinScope() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_statuses")
        let profileID = UserProfileID("contract_profile_statuses")
        let sessionID = CartSessionID("contract_session_statuses")

        let active = makeCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            status: .active
        )
        let checkedOut = makeCart(
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            status: .checkedOut
        )

        try await store.saveCart(active)
        try await store.saveCart(checkedOut)

        let query = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .session(sessionID),
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: nil)

        try require(results.count == 1, "Expected one active cart after status filtering.")
        try require(results.first?.id == active.id, "Expected active cart after status filtering.")
    }

    /// Verifies sorting + limit semantics.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchAppliesSortAndLimit() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_sort_limit")
        let base = Date(timeIntervalSince1970: 1_000)

        let oldest = makeCart(
            storeID: storeID,
            profileID: nil,
            status: .active,
            createdAt: base.addingTimeInterval(-300),
            updatedAt: base.addingTimeInterval(-300)
        )
        let middle = makeCart(
            storeID: storeID,
            profileID: nil,
            status: .active,
            createdAt: base.addingTimeInterval(-200),
            updatedAt: base.addingTimeInterval(-200)
        )
        let newest = makeCart(
            storeID: storeID,
            profileID: nil,
            status: .active,
            createdAt: base.addingTimeInterval(-100),
            updatedAt: base.addingTimeInterval(-100)
        )

        try await store.saveCart(oldest)
        try await store.saveCart(middle)
        try await store.saveCart(newest)

        let query = CartQuery(
            storeID: storeID,
            profile: .guestOnly,
            statuses: nil,
            sort: .createdAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: 2)

        try require(results.count == 2, "Expected limited result count.")
        try require(results.map(\.id) == [newest.id, middle.id], "Expected descending createdAt ordering.")
    }

    /// Verifies session filter semantics (`sessionless`, specific session, `any`).
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchSessionFilterSemantics() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_session")
        let profileID = UserProfileID("contract_profile_session")
        let sessionA = CartSessionID("contract_session_A")
        let sessionB = CartSessionID("contract_session_B")

        let sessionless = makeCart(storeID: storeID, profileID: profileID, sessionID: nil, status: .active)
        let a = makeCart(storeID: storeID, profileID: profileID, sessionID: sessionA, status: .active)
        let b = makeCart(storeID: storeID, profileID: profileID, sessionID: sessionB, status: .active)

        try await store.saveCart(sessionless)
        try await store.saveCart(a)
        try await store.saveCart(b)

        let querySessionless = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .sessionless,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let resultSessionless = try await store.fetchCarts(matching: querySessionless, limit: nil)
        try require(resultSessionless.count == 1, "Expected one sessionless cart.")
        try require(resultSessionless.first?.sessionID == nil, "Expected nil session.")

        let queryA = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .session(sessionA),
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let resultA = try await store.fetchCarts(matching: queryA, limit: nil)
        try require(resultA.count == 1, "Expected one cart for session A.")
        try require(resultA.first?.sessionID == sessionA, "Expected session A cart.")

        let queryAny = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .any,
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let resultAny = try await store.fetchCarts(matching: queryAny, limit: nil)
        try require(resultAny.count == 3, "Expected sessionless + session A + session B carts.")
    }

    /// Verifies `storeID == nil` means any store.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchStoreIDNilMeansAnyStore() async throws {
        let store = try await makeStore()

        let profileID = UserProfileID("contract_profile_any_store")
        let sessionID = CartSessionID("contract_session_any_store")
        let storeA = StoreID("contract_store_any_A")
        let storeB = StoreID("contract_store_any_B")

        let a = makeCart(storeID: storeA, profileID: profileID, sessionID: sessionID, status: .active)
        let b = makeCart(storeID: storeB, profileID: profileID, sessionID: sessionID, status: .active)

        try await store.saveCart(a)
        try await store.saveCart(b)

        let query = CartQuery(
            storeID: nil,
            profile: .profile(profileID),
            session: .session(sessionID),
            statuses: [.active],
            sort: .updatedAtDescending
        )
        let results = try await store.fetchCarts(matching: query, limit: nil)

        try require(Set(results.map(\.storeID)) == Set([storeA, storeB]), "Expected carts from all stores.")
    }

    /// Verifies `statuses == nil` and `statuses == []` both mean no status filter.
    ///
    /// - Throws: `CartStoreContractError` when behavior does not match contract.
    public func assertFetchStatusesNilEqualsEmptySet() async throws {
        let store = try await makeStore()

        let storeID = StoreID("contract_store_status_empty")
        let profileID = UserProfileID("contract_profile_status_empty")
        let sessionID = CartSessionID("contract_session_status_empty")

        let active = makeCart(storeID: storeID, profileID: profileID, sessionID: sessionID, status: .active)
        let checkedOut = makeCart(storeID: storeID, profileID: profileID, sessionID: sessionID, status: .checkedOut)

        try await store.saveCart(active)
        try await store.saveCart(checkedOut)

        let queryNil = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .session(sessionID),
            statuses: nil,
            sort: .updatedAtDescending
        )
        let queryEmpty = CartQuery(
            storeID: storeID,
            profile: .profile(profileID),
            session: .session(sessionID),
            statuses: [],
            sort: .updatedAtDescending
        )

        let resultsNil = try await store.fetchCarts(matching: queryNil, limit: nil)
        let resultsEmpty = try await store.fetchCarts(matching: queryEmpty, limit: nil)

        try require(Set(resultsNil.map(\.id)) == Set(resultsEmpty.map(\.id)), "Expected nil and empty statuses to be equivalent.")
        try require(resultsNil.count == 2, "Expected both carts with no status filter.")
    }

    /// Simple assertion error used by contract checks.
    private enum CartStoreContractError: Error {
        case assertionFailed(String)
    }

    /// Throws a contract error when a condition is false.
    ///
    /// - Parameters:
    ///   - condition: Condition to verify.
    ///   - message: Failure message.
    /// - Throws: `CartStoreContractError.assertionFailed` when `condition` is false.
    private func require(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) throws {
        if !condition() {
            throw CartStoreContractError.assertionFailed(message)
        }
    }

    /// Creates a cart with explicit timestamps and status.
    ///
    /// - Parameters:
    ///   - id: Cart ID.
    ///   - storeID: Store ID.
    ///   - profileID: Optional profile ID.
    ///   - sessionID: Optional session ID.
    ///   - status: Cart status.
    ///   - createdAt: Creation timestamp.
    ///   - updatedAt: Last update timestamp.
    ///   - items: Cart items.
    ///   - savedPromotionKinds: Persisted promotion kinds.
    /// - Returns: A cart fixture suitable for contract checks.
    private func makeCart(
        id: CartID = .generate(),
        storeID: StoreID,
        profileID: UserProfileID?,
        sessionID: CartSessionID? = nil,
        status: CartStatus,
        createdAt: Date = Date(timeIntervalSince1970: 1),
        updatedAt: Date = Date(timeIntervalSince1970: 2),
        items: [CartItem] = [],
        savedPromotionKinds: [PromotionKind] = []
    ) -> Cart {
        Cart(
            id: id,
            storeID: storeID,
            profileID: profileID,
            sessionID: sessionID,
            items: items,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: ["contract": "true"],
            displayName: "Contract Cart",
            context: "contract-tests",
            storeImageURL: URL(string: "https://example.com/contract.png"),
            minSubtotal: nil,
            maxItemCount: nil,
            savedPromotionKinds: savedPromotionKinds
        )
    }

    /// Creates a cart item for contract checks.
    ///
    /// - Parameters:
    ///   - productID: Product identifier.
    ///   - quantity: Quantity.
    /// - Returns: A cart item fixture.
    private func makeItem(
        productID: String,
        quantity: Int
    ) -> CartItem {
        CartItem(
            id: CartItemID.generate(),
            productID: productID,
            quantity: quantity,
            unitPrice: Money(amount: 5, currencyCode: "USD"),
            totalPrice: Money(amount: Decimal(quantity) * 5, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil,
            availableStock: nil
        )
    }
}
