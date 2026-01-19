public struct ActiveCartGroup: Sendable, Hashable {
    public let sessionID: CartSessionID?
    public let carts: [Cart]
}
