import Testing
@testable import CartKit

@Suite("CartStoreMigrationRunner")
struct CartStoreMigrationRunnerTests {
    
    // Concurrency-safe counters/recorders used by tests.
    actor Counter {
        private(set) var value: Int = 0
        func increment() { value += 1 }
    }
    
    actor Recorder {
        private(set) var values: [String] = []
        func append(_ value: String) { values.append(value) }
    }
    
    @Test
    func skipsCompletedMigrations_inAutoPolicy() async throws {
        let store = InMemoryMigrationStateStore()
        let id = CartMigrationID(rawValue: "m1")
        await store.markCompleted(id)
        
        let counter = Counter()
        let migrator = SpyMigrator(id: id) {
            await counter.increment()
            return .migrated(carts: 0)
        }
        
        let runner = CartStoreMigrationRunner(stateStore: store, policy: .auto)
        try await runner.run([migrator])
        
        let called = await counter.value
        #expect(called == 0)
    }
    
    @Test
    func runsCompletedMigrations_inForcePolicy() async throws {
        let store = InMemoryMigrationStateStore()
        let id = CartMigrationID(rawValue: "m1")
        await store.markCompleted(id)
        
        let counter = Counter()
        let migrator = SpyMigrator(id: id) {
            await counter.increment()
            return .migrated(carts: 0)
        }
        
        let runner = CartStoreMigrationRunner(stateStore: store, policy: .force)
        try await runner.run([migrator])
        
        let called = await counter.value
        #expect(called == 1)
    }
    
    @Test
    func stopsOnFailure_andDoesNotMarkCompleted() async {
        enum TestError: Error { case boom }
        
        let store = InMemoryMigrationStateStore()
        let id1 = CartMigrationID(rawValue: "m1")
        let id2 = CartMigrationID(rawValue: "m2")
        
        let recorder = Recorder()
        
        let m1 = SpyMigrator(id: id1) {
            await recorder.append("m1")
            throw TestError.boom
        }
        
        let m2 = SpyMigrator(id: id2) {
            await recorder.append("m2")
            return .migrated(carts: 0)
        }
        
        let runner = CartStoreMigrationRunner(stateStore: store, policy: .auto)
        
        await #expect(throws: TestError.self) {
            try await runner.run([m1, m2])
        }
        
        let order = await recorder.values
        #expect(order == ["m1"])
        
        #expect(await store.isCompleted(id1) == false)
        #expect(await store.isCompleted(id2) == false)
    }
    
    @Test
    func nonePolicy_isNoOp() async throws {
        let store = InMemoryMigrationStateStore()
        let id = CartMigrationID(rawValue: "m_none")

        let counter = Counter()
        let migrator = SpyMigrator(id: id) {
            await counter.increment()
            return .migrated(carts: 0)
        }

        let runner = CartStoreMigrationRunner(stateStore: store, policy: .none)
        try await runner.run([migrator])

        let called = await counter.value
        #expect(called == 0)
        #expect(await store.isCompleted(id) == false)
    }
}
