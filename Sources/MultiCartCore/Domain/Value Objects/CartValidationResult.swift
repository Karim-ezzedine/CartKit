import Foundation

/// Result of validating a cart or an item change.
///
/// We keep it intentionally small for v1; if we later need error codes
/// we can extend this (e.g. with associated data or a separate error type).
public enum CartValidationResult: Hashable, Codable, Sendable {
    case valid
    case invalid(reason: String)
}
