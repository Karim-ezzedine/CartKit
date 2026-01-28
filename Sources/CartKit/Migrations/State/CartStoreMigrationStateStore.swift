/// Persistence-agnostic store for migration completion state.
///
/// This is a **port**: it enables the migration runner
/// to track progress without coupling to any specific persistence backend.
///
/// Requirements:
/// - Must be safe under concurrency.
/// - Must support idempotency checks (`isCompleted`) and marking completion.
/// - Must not mark completion when a migration fails.
///
/// Default implementation can be backed by `UserDefaults`, but tests should
/// prefer an in-memory implementation.
public protocol CartStoreMigrationStateStore: Sendable {
    /// Returns whether the given migration has been completed.
    func isCompleted(_ id: CartMigrationID) async -> Bool

    /// Marks the given migration as completed.
    func markCompleted(_ id: CartMigrationID) async

    /// Clears completion state for a migration (primarily for tests or tools).
    func reset(_ id: CartMigrationID) async
}
