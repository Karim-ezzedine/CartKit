import Testing
import CartKitTestingSupport

struct InMemoryCartStoreTests {

    /// Returns the shared contract suite bound to the in-memory adapter.
    private func makeContractSuite() -> CartStoreContractSuite {
        CartStoreContractSuite {
            InMemoryCartStore()
        }
    }

    @Test
    func saveAndLoad_roundTripsCartByID() async throws {
        try await makeContractSuite().assertSaveAndLoadRoundTrip()
    }

    @Test
    func saveCart_whenSavingSameId_updatesExistingRecord() async throws {
        try await makeContractSuite().assertSaveTwiceUpdatesExistingRecord()
    }

    @Test
    func deleteCart_removesItFromStore() async throws {
        try await makeContractSuite().assertDeleteRemovesAndIsIdempotent()
    }

    @Test
    func fetchCarts_filtersByStoreAndGuestVsProfile() async throws {
        try await makeContractSuite().assertFetchFiltersGuestVsLoggedInScopes()
    }

    @Test
    func fetchCarts_filtersBySpecificProfileScope() async throws {
        try await makeContractSuite().assertFetchFiltersBySpecificProfileScope()
    }

    @Test
    func fetchCarts_profileAny_includesGuestAndLoggedIn() async throws {
        try await makeContractSuite().assertFetchProfileAnyIncludesGuestAndLoggedIn()
    }

    @Test
    func fetchCarts_respectsStatusFilter() async throws {
        try await makeContractSuite().assertFetchFiltersByStatusesWithinScope()
    }

    @Test
    func fetchCarts_appliesSortAndLimit() async throws {
        try await makeContractSuite().assertFetchAppliesSortAndLimit()
    }

    @Test
    func fetch_sessionFilter_semantics_areCorrect() async throws {
        try await makeContractSuite().assertFetchSessionFilterSemantics()
    }

    @Test
    func fetch_storeID_nil_meansAnyStore() async throws {
        try await makeContractSuite().assertFetchStoreIDNilMeansAnyStore()
    }

    @Test
    func fetch_statusesNil_equalsEmptySet_noFilter() async throws {
        try await makeContractSuite().assertFetchStatusesNilEqualsEmptySet()
    }

    @Test
    func fetch_scale_behavior_with_filters_sort_and_limit() async throws {
        try await makeContractSuite().assertFetchScaleBehaviorWithFiltersSortAndLimit()
    }
}
