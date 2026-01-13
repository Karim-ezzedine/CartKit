import CartKitCore

public struct FakeCatalogConflictDetector: CartCatalogConflictDetector, Sendable {
    let handler: @Sendable (Cart) -> [CartCatalogConflict]
    
    public init(_ handler: @escaping @Sendable (Cart) -> [CartCatalogConflict]) {
        self.handler = handler
    }
    
    public func detectConflicts(for cart: Cart) async -> [CartCatalogConflict] {
        handler(cart)
    }
}
