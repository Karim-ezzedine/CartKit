/// Orchestrates execution of a set of `CartStoreMigrator`s.
///
/// Responsibilities:
/// - Enforce ordering (provided order).
/// - Enforce idempotency via `CartStoreMigrationStateStore`.
/// - Ensure a migration is only marked completed after successful execution.
/// - Provide explicit policy controls (`none` / `auto` / `force`).
///
/// This is a composition/infrastructure service (not domain):
/// it should be invoked from the same place you choose the storage backend
/// (e.g., your `CartStoreFactory` / configuration composition).
struct CartStoreMigrationRunner: Sendable {
    
    /// Defines how the runner behaves when a migration fails.
    enum FailureMode: Sendable, Equatable {
        /// Stop at the first failure and rethrow the error.
        case stopOnFailure
    }
    
    private let stateStore: any CartStoreMigrationStateStore
    private let policy: CartStoreMigrationPolicy
    private let failureMode: FailureMode
    
    public init(
        stateStore: any CartStoreMigrationStateStore,
        policy: CartStoreMigrationPolicy = .auto,
        failureMode: FailureMode = .stopOnFailure
    ) {
        self.stateStore = stateStore
        self.policy = policy
        self.failureMode = failureMode
    }
    
    /// Runs the provided migrators in order.
    ///
    /// - Parameter migrators: Migration steps to run, in deterministic order.
    ///
    /// Behavior:
    /// - `.none`: does nothing.
    /// - `.auto`: skips migrations already marked completed.
    /// - `.force`: runs even if marked completed.
    ///
    /// Failure semantics:
    /// - On failure, the runner does not mark the migration completed.
    /// - Default is to stop at the first failure.
    public func run(_ migrators: [any CartStoreMigrator]) async throws {
        guard policy != .none else { return }
        
        for migrator in migrators {
            let completed = await stateStore.isCompleted(migrator.id)
            
            if completed, policy != .force {
                continue
            }
            
            do {
                try await migrator.migrate()
                await stateStore.markCompleted(migrator.id)
            } catch {
                switch failureMode {
                case .stopOnFailure:
                    throw error
                }
            }
        }
    }
}
