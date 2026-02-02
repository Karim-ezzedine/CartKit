/// Result of a migration attempt.
///
/// Used by the runner for:
/// - observability (counts / status)
/// - completion semantics (only mark completed when appropriate)
public struct CartStoreMigrationResult: Sendable, Equatable {
    enum Status: Sendable, Equatable {
        /// Migration executed and performed work.
        case migrated
        /// Migration decided there was nothing to do (safe no-op).
        case skipped
    }

    let status: Status
    let cartsMigrated: Int
    let shouldMarkCompleted: Bool

    static func migrated(carts: Int) -> Self {
        .init(status: .migrated, cartsMigrated: carts, shouldMarkCompleted: true)
    }

    static func skipped(shouldMarkCompleted: Bool = false) -> Self {
        .init(status: .skipped, cartsMigrated: 0, shouldMarkCompleted: shouldMarkCompleted)
    }
}

