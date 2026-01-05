import Foundation

public struct SwiftDataCartStoreConfiguration: Sendable {
    
    /// If true, uses an in-memory store (tests / previews).
    public let inMemory: Bool
    
    /// Optional store URL (host-controlled). If nil and `inMemory == false`,
    /// SwiftData uses a default location.
    public let storeURL: URL?
    
    public init(
        inMemory: Bool = false,
        storeURL: URL? = nil
    ) {
        self.inMemory = inMemory
        self.storeURL = storeURL
    }
}

