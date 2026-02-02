@testable import CartKit

struct SpyMigrator: CartStoreMigrator {
    let id: CartMigrationID
    let onMigrate: @Sendable () async throws -> CartStoreMigrationResult

    func migrate() async throws -> CartStoreMigrator.Result { try await onMigrate() }
}
