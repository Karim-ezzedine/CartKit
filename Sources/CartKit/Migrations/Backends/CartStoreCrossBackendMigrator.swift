import CartKitCore

/// Migrates carts across persistence backends via migration-specific ports.
///
/// - note: This is a composition/infrastructure concern (not domain).
/// It uses `CartStoreSnapshotReadable` for snapshots and `CartStore`
/// for upsert behavior on the target side.
struct CartStoreCrossBackendMigrator: CartStoreMigrator {

    let id: CartMigrationID = CartMigrationID(rawValue: "cart_store_cross_backend_migrator")

    private let source: any CartStoreSnapshotReadable
    private let target: any CartStore & CartStoreSnapshotReadable
    private let allowWhenTargetHasData: Bool

    init(
        source: any CartStoreSnapshotReadable,
        target: any CartStore & CartStoreSnapshotReadable,
        allowWhenTargetHasData: Bool = false
    ) {
        self.source = source
        self.target = target
        self.allowWhenTargetHasData = allowWhenTargetHasData
    }

    @discardableResult
    func migrate() async throws -> CartStoreMigrator.Result {
        let sourceCarts = try await source.fetchAllCarts(limit: nil)
        guard !sourceCarts.isEmpty else { return .skipped(shouldMarkCompleted: true) }

        if !allowWhenTargetHasData {
            // Stricter detection: verify all source carts are already in target (handles partial migrations).
            let targetCarts = try await target.fetchAllCarts(limit: nil)
            let sourceCartIDs = Set(sourceCarts.map(\.id))
            let targetCartIDs = Set(targetCarts.map(\.id))
            let sourceCartsInTarget = sourceCartIDs.intersection(targetCartIDs)
            
            // If target has all source carts, migration is complete (safe to skip).
            if sourceCartIDs.isSubset(of: targetCartIDs) {
                return .skipped(shouldMarkCompleted: true)
            }
            
            // If target has carts but NONE are from source (unrelated data), skip.
            if !targetCartIDs.isEmpty && sourceCartsInTarget.isEmpty {
                return .skipped(shouldMarkCompleted: false)
            }
        }

        // Migrate all source carts (upsert semantics ensure idempotency).
        var migratedCount = 0
        for cart in sourceCarts {
            try await target.saveCart(cart)
            migratedCount += 1
        }

        return .migrated(carts: migratedCount)
    }
}
