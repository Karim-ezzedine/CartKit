/// Outcome of a cleanup run.
public struct CartCleanupResult: Sendable, Hashable {
    public let deletedCartIDs: [CartID]
    
    public init(deletedCartIDs: [CartID]) {
        self.deletedCartIDs = deletedCartIDs
    }
}
