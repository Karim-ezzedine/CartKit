import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

extension CartManagerDomainTests {
    //MARK: - Reports Conflicts
    
    @Test
    func addItem_reportsCatalogConflicts() async throws {
        let storeID = StoreID(rawValue: "store_conflict_add")
        
        let detector = FakeCatalogConflictDetector { cart in
            guard let item = cart.items.first else { return [] }
            return [
                CartCatalogConflict(
                    itemID: item.id,
                    productID: item.productID,
                    kind: .removedFromCatalog
                )
            ]
        }
        
        let (manager, _) = makeSUT(detector: detector)
        let cart = try await manager.setActiveCart(storeID: storeID)
        
        let item = CartItem(
            id: CartItemID.generate(),
            productID: "burger",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )
        
        let result = try await manager.addItem(to: cart.id, item: item)
        
        #expect(result.conflicts.count == 1)
    }
    
    @Test
    func addItem_reportsAllCatalogConflictKinds() async throws {
        let storeID = StoreID(rawValue: "store_conflict_kinds")
        
        let detector = FakeCatalogConflictDetector { cart in
            guard let item = cart.items.first else { return [] }
            return [
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .removedFromCatalog),
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .priceChanged(old: Money(amount: 10, currencyCode: "USD"), new: Money(amount: 12, currencyCode: "USD"))),
                CartCatalogConflict(itemID: item.id, productID: item.productID, kind: .insufficientStock(requested: 5, available: 0))
            ]
        }
        
        let (manager, _) = makeSUT(detector: detector)
        let cart = try await manager.setActiveCart(storeID: storeID)
        
        let item = CartItem(
            id: CartItemID.generate(),
            productID: "burger",
            quantity: 1,
            unitPrice: Money(amount: 10, currencyCode: "USD"),
            modifiers: [],
            imageURL: nil
        )
        
        let result = try await manager.addItem(to: cart.id, item: item)
        
        #expect(result.conflicts.count == 3)
    }
}
