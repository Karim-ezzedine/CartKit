/// Represents a single, independently trackable migration step.
protocol CartStoreMigrator: Sendable {
    /// Stable identifier for this migration step.
    var id: CartMigrationID { get }

    /// Executes the migration.
    ///
    /// - Important: If this throws, the runner must treat the migration as failed
    ///   and must **not** mark it completed.
    func migrate() async throws
}
