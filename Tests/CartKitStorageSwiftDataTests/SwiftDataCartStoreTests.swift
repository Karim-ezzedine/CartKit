import Testing
import CartKitCore
import CartKitTestingSupport

#if canImport(SwiftData) && os(iOS)
import CartKitStorageSwiftData

struct SwiftDataCartStoreTests {

    /// Creates a fresh in-memory SwiftData store for contract checks.
    @available(iOS 17, *)
    private func makeStore() throws -> CartStore {
        try SwiftDataCartStore(configuration: .init(inMemory: true))
    }

    /// Returns the shared contract suite bound to the SwiftData adapter.
    @available(iOS 17, *)
    private func makeContractSuite() -> CartStoreContractSuite {
        CartStoreContractSuite {
            try makeStore()
        }
    }

    @Test
    @available(iOS 17, *)
    func save_then_load_returns_cart() async throws {
        try await makeContractSuite().assertSaveAndLoadRoundTrip()
    }

    @Test
    @available(iOS 17, *)
    func save_twice_updates_existing_cart() async throws {
        try await makeContractSuite().assertSaveTwiceUpdatesExistingRecord()
    }

    @Test
    @available(iOS 17, *)
    func delete_is_idempotent_and_removes_cart() async throws {
        try await makeContractSuite().assertDeleteRemovesAndIsIdempotent()
    }

    @Test
    @available(iOS 17, *)
    func fetch_filters_by_store_and_guest_scope() async throws {
        try await makeContractSuite().assertFetchFiltersGuestVsLoggedInScopes()
    }

    @Test
    @available(iOS 17, *)
    func fetch_filters_by_profile_scope() async throws {
        try await makeContractSuite().assertFetchFiltersBySpecificProfileScope()
    }

    @Test
    @available(iOS 17, *)
    func fetch_profile_any_includes_guest_and_loggedIn() async throws {
        try await makeContractSuite().assertFetchProfileAnyIncludesGuestAndLoggedIn()
    }

    @Test
    @available(iOS 17, *)
    func fetch_filters_by_statuses() async throws {
        try await makeContractSuite().assertFetchFiltersByStatusesWithinScope()
    }

    @Test
    @available(iOS 17, *)
    func fetch_applies_sort_and_limit() async throws {
        try await makeContractSuite().assertFetchAppliesSortAndLimit()
    }

    @Test
    @available(iOS 17, *)
    func fetch_sessionFilter_semantics_areCorrect() async throws {
        try await makeContractSuite().assertFetchSessionFilterSemantics()
    }

    @Test
    @available(iOS 17, *)
    func fetch_storeID_nil_meansAnyStore() async throws {
        try await makeContractSuite().assertFetchStoreIDNilMeansAnyStore()
    }

    @Test
    @available(iOS 17, *)
    func fetch_statusesNil_equalsEmptySet_noFilter() async throws {
        try await makeContractSuite().assertFetchStatusesNilEqualsEmptySet()
    }

    @Test
    @available(iOS 17, *)
    func fetch_scale_behavior_with_filters_sort_and_limit() async throws {
        try await makeContractSuite().assertFetchScaleBehaviorWithFiltersSortAndLimit()
    }
}

#endif
