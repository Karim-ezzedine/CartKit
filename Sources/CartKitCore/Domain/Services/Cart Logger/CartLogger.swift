public protocol CartLogger: Sendable {
    func log(_ message: String)
}

public struct DefaultCartLogger: CartLogger {
    
    public init() {}
    
    public func log(_ message: String) {
        #if DEBUG
        print("\n🛒 Cartkit Logs:\n\(message)\n")
        #endif
    }
}
