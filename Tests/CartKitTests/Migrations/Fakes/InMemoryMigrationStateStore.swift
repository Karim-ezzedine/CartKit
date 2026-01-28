@testable import CartKit

actor InMemoryMigrationStateStore: CartStoreMigrationStateStore {
    private var completed: Set<CartMigrationID> = []

    func isCompleted(_ id: CartMigrationID) async -> Bool { completed.contains(id) }
    func markCompleted(_ id: CartMigrationID) async { completed.insert(id) }
    func reset(_ id: CartMigrationID) async { completed.remove(id) }
}
