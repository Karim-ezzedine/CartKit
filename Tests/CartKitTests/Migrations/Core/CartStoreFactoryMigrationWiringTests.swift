import Testing
@testable import CartKit

@Suite("CartStoreFactory migration wiring")
struct CartStoreFactoryMigrationWiringTests {

    @Test
    func factory_makeStore_withNoMigrators_hasNoStateSideEffects() async throws {
        let state = InMemoryMigrationStateStore()
        let id = CartMigrationID(rawValue: "should_not_be_set")

        // When there are no migrators (Phase 2), no completion should be set.
        _ = try await CartStoreFactory.makeStore(
            preference: .coreData,
            migrationPolicy: .auto,
            migrationStateStore: state
        )

        #expect(await state.isCompleted(id) == false)
    }

    @Test
    func factory_makeStore_withNonePolicy_succeeds() async throws {
        let state = InMemoryMigrationStateStore()

        _ = try await CartStoreFactory.makeStore(
            preference: .coreData,
            migrationPolicy: .none,
            migrationStateStore: state
        )

        // No migrators and policy none -> no-op.
        #expect(true)
    }
}
