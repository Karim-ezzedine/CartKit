/// Defines how CartKit should run persistence migrations.
///
/// This is a composition-level concern:
/// the policy is selected by the app/SDK composition layer and should not
/// leak into domain (`CartManager`) or entities.
///
/// Typical usage:
/// - `.auto` (default): run migrations only when needed (idempotent).
/// - `.none`: opt out (useful for tests or controlled rollout).
/// - `.force`: run regardless of state (debug/tools, or recovery paths).
public enum CartStoreMigrationPolicy: Sendable, Equatable {
    /// Never run migrations automatically.
    case none

    /// Run migrations only when needed. Completed migrations are skipped.
    case auto

    /// Run migrations even if previously marked as completed.
    case force
}
