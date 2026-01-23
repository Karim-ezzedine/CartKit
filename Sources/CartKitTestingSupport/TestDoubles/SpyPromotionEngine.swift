import Foundation
import CartKitCore

public actor SpyPromotionEngine: PromotionEngine {
    
    public init() {}
    
    private(set) var calls: [(storeID: StoreID, promotions: [PromotionKind])] = []
    
    public func applyPromotions(_ promotions: [PromotionKind], to cartTotals: CartTotals) async throws -> CartTotals {
        // In these tests, we apply a simple rule:
        // - fixedAmountOffCart subtracts from grandTotal
        // - freeDelivery sets deliveryFee to zero (already default zero in totals, but kept for completeness)
        // - other kinds no-op
        var result = cartTotals
        
        for promo in promotions {
            switch promo {
            case .fixedAmountOffCart(let money):
                // Assume same currency in tests
                result.grandTotal = Money(
                    amount: result.grandTotal.amount - money.amount,
                    currencyCode: result.grandTotal.currencyCode
                )
                
            case .freeDelivery:
                result.deliveryFee = .zero(currencyCode: result.subtotal.currencyCode)
                // grandTotal already includes deliveryFee; keep consistent:
                result.grandTotal = Money(
                    amount: result.subtotal.amount + result.serviceFee.amount + result.tax.amount + result.deliveryFee.amount,
                    currencyCode: result.subtotal.currencyCode
                )
                
            case .percentageOffCart, .custom:
                break
            }
        }
        
        return result
    }
    
    func record(storeID: StoreID, promotions: [PromotionKind]) async {
        calls.append((storeID: storeID, promotions: promotions))
    }
}
