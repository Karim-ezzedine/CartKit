/// Result of validating a cart or an item change.
///
/// We keep it intentionally small for v1: either `valid` or `invalid`
/// with a structured `CartValidationError`.
public enum CartValidationResult: Hashable, Codable, Sendable {
    case valid
    case invalid(error: CartValidationError)
}
