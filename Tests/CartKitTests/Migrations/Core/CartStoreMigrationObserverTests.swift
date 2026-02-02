import Testing
@testable import CartKit

@Suite("CartStoreMigrationRunner observability")
struct CartStoreMigrationObserverTests {

    actor RecordingObserver: CartStoreMigrationObserver {
        private(set) var events: [String] = []

        func migrationStarted(id: CartMigrationID) async {
            events.append("start:\(id.rawValue)")
        }

        func migrationSucceeded(id: CartMigrationID, result: CartStoreMigrationResult) async {
            events.append("success:\(id.rawValue):\(result.cartsMigrated)")
        }

        func migrationFailed(id: CartMigrationID, error: Error) async {
            events.append("fail:\(id.rawValue)")
        }
    }

    @Test
    func observerReceivesStartAndSuccess() async throws {
        let store = InMemoryMigrationStateStore()
        let observer = RecordingObserver()

        let id = CartMigrationID(rawValue: "m_observe")
        let migrator = SpyMigrator(id: id) {
            return .migrated(carts: 2)
        }

        let runner = CartStoreMigrationRunner(
            stateStore: store,
            policy: .auto,
            observer: observer
        )

        try await runner.run([migrator])

        let events = await observer.events
        #expect(events == ["start:m_observe", "success:m_observe:2"])
    }
}

