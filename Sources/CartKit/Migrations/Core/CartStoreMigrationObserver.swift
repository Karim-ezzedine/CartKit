import CartKitCore

/// Observability hook for persistence migrations.
///
/// This is infrastructure-only and is intended for logging / analytics.
public protocol CartStoreMigrationObserver: Sendable {
    func migrationStarted(id: CartMigrationID) async
    func migrationSucceeded(id: CartMigrationID, result: CartStoreMigrationResult) async
    func migrationFailed(id: CartMigrationID, error: Error) async
}

/// Default observer that logs migration lifecycle using `CartLogger`.
public struct CartLoggerMigrationObserver: CartStoreMigrationObserver {
    private let logger: CartLogger

    public init(logger: CartLogger = DefaultCartLogger()) {
        self.logger = logger
    }

    public func migrationStarted(id: CartMigrationID) async {
        logger.log("[Migration] started: \(id.rawValue)")
    }

    public func migrationSucceeded(id: CartMigrationID, result: CartStoreMigrationResult) async {
        logger.log("[Migration] succeeded: \(id.rawValue) status=\(result.status) carts=\(result.cartsMigrated)")
    }

    public func migrationFailed(id: CartMigrationID, error: Error) async {
        logger.log("[Migration] failed: \(id.rawValue) error=\(error)")
    }
}

