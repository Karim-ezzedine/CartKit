import Foundation
/// `UserDefaults`-backed implementation of `CartStoreMigrationStateStore`.
///
/// Stores a boolean flag per migration ID.
/// Implemented as an `actor` to be concurrency-safe.
///
/// This is intended for composition/infrastructure usage (not domain).
public actor UserDefaultsCartMigrationStateStore: CartStoreMigrationStateStore {

    private let defaults: UserDefaults
    private let prefix: String

    public init(
        defaults: UserDefaults = .standard,
        prefix: String = "com.toters.cartkit.migration."
    ) {
        self.defaults = defaults
        self.prefix = prefix
    }

    public func isCompleted(_ id: CartMigrationID) async -> Bool {
        defaults.bool(forKey: prefix + id.rawValue)
    }

    public func markCompleted(_ id: CartMigrationID) async {
        defaults.set(true, forKey: prefix + id.rawValue)
    }

    public func reset(_ id: CartMigrationID) async {
        defaults.removeObject(forKey: prefix + id.rawValue)
    }
}
