/// Represents a single, independently trackable migration step.
protocol CartStoreMigrator: Sendable {
    /// Stable identifier for this migration step.
    var id: CartMigrationID { get }

    /// Minimal outcome of a migration attempt.
    ///
    /// Used for observability and correct completion semantics.
    typealias Result = CartStoreMigrationResult

    /// Executes the migration.
    ///
    /// - Important: If this throws, the runner must treat the migration as failed
    ///   and must **not** mark it completed.
    func migrate() async throws -> Result
}
