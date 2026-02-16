import Testing
import CartKitCore
import CartKitStorageCoreData
import CartKitTestingSupport

struct CoreDataCartStoreTests {

    /// Creates a fresh in-memory Core Data store for contract checks.
    private func makeStore() async throws -> CartStore {
        let config = CoreDataCartStoreConfiguration(
            modelName: "CartStorage",
            inMemory: true
        )
        return try await CoreDataCartStore(configuration: config)
    }

    /// Returns the shared contract suite bound to the Core Data adapter.
    private func makeContractSuite() -> CartStoreContractSuite {
        CartStoreContractSuite {
            try await makeStore()
        }
    }

    @Test
    func saveCart_thenLoadCart_returnsSameCart() async throws {
        try await makeContractSuite().assertSaveAndLoadRoundTrip()
    }

    @Test
    func saveCart_whenSavingSameId_updatesExistingRecord() async throws {
        try await makeContractSuite().assertSaveTwiceUpdatesExistingRecord()
    }

    @Test
    func deleteCart_removesCart_andIsIdempotent() async throws {
        try await makeContractSuite().assertDeleteRemovesAndIsIdempotent()
    }

    @Test
    func fetchCarts_filtersGuestVsLoggedInScopes() async throws {
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
    func fetchCarts_filtersByStatusesWithinScope() async throws {
        try await makeContractSuite().assertFetchFiltersByStatusesWithinScope()
    }

    @Test
    func fetchCarts_respectsLimit() async throws {
        try await makeContractSuite().assertFetchAppliesSortAndLimit()
    }

    @Test
    func fetchCarts_sessionFilter_semantics_areCorrect() async throws {
        try await makeContractSuite().assertFetchSessionFilterSemantics()
    }

    @Test
    func fetchCarts_storeID_nil_meansAnyStore() async throws {
        try await makeContractSuite().assertFetchStoreIDNilMeansAnyStore()
    }

    @Test
    func fetchCarts_statusesNil_equalsEmptySet_noFilter() async throws {
        try await makeContractSuite().assertFetchStatusesNilEqualsEmptySet()
    }
}
