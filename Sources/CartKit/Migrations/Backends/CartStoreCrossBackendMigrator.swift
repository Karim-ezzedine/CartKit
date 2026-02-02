import CartKitCore

/// Migrates carts across persistence backends via the `CartStore` port.
///
/// - note: This is a composition/infrastructure concern (not domain).
/// It operates on the `CartStore` port to avoid coupling to persistence details.
struct CartStoreCrossBackendMigrator: CartStoreMigrator {

    let id: CartMigrationID = CartMigrationID(rawValue: "car_store_cross_backend_migrator")

    private let source: any CartStore
    private let target: any CartStore
    private let allowWhenTargetHasData: Bool

    init(
        source: any CartStore,
        target: any CartStore,
        allowWhenTargetHasData: Bool = false
    ) {
        self.source = source
        self.target = target
        self.allowWhenTargetHasData = allowWhenTargetHasData
    }

    func migrate() async throws -> CartStoreMigrator.Result {
        let sourceCarts = try await source.fetchAllCarts(limit: nil)
        guard !sourceCarts.isEmpty else { return .skipped(shouldMarkCompleted: true) }

        if !allowWhenTargetHasData {
            let targetPreview = try await target.fetchAllCarts(limit: 1)
            guard targetPreview.isEmpty else { return .skipped(shouldMarkCompleted: false) }
        }

        for cart in sourceCarts {
            try await target.saveCart(cart)
        }

        return .migrated(carts: sourceCarts.count)
    }
}
