@testable import CartKit

struct SpyMigrator: CartStoreMigrator {
    let id: CartMigrationID
    let onMigrate: @Sendable () async throws -> Void

    func migrate() async throws { try await onMigrate() }
}
