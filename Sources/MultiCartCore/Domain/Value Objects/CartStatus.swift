/// High-level state of a cart.
public enum CartStatus: String, Hashable, Codable, Sendable {
    case active
    case checkedOut
    case cancelled
    case expired
}
