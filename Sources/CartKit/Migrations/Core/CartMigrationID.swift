/// Stable identifier for a migration step.
///
/// Migrations must be **append-only** across releases:
/// - Never reuse an identifier for a different behavior.
/// - Prefer versioned IDs, e.g. `car_store_cross_backend_migrator`.
///
/// Using a dedicated type (instead of raw `String`) improves readability and
/// prevents accidental mixing with other keys in the codebase.
public struct CartMigrationID: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
