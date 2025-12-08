import Foundation

/// Default validation engine:
/// - Supports dynamic min subtotal and max item count.
/// - Rules are resolved as: per-cart override OR global default.
///
/// This is a pure domain service (no storage dependencies).
public struct DefaultCartValidationEngine: CartValidationEngine, Sendable {
    
    private let defaultMinSubtotal: Money?
    private let defaultMaxItems: Int?
    
    public init(
        defaultMinSubtotal: Money? = nil,
        defaultMaxItems: Int? = nil
    ) {
        self.defaultMinSubtotal = defaultMinSubtotal
        self.defaultMaxItems = defaultMaxItems
    }
    
    // MARK: - Full-cart validation (checkout-level)
    
    public func validate(cart: Cart) async -> CartValidationResult {
        // Max items rule
        if let error = validateMaxItems(in: cart, prospectiveItem: nil) {
            return .invalid(error: error)
        }
        
        // Min subtotal rule
        let (minSubtotal, _) = effectiveRules(for: cart)
        if let minSubtotal {
            let subtotal = computeSubtotal(for: cart)
            if subtotal.amount < minSubtotal.amount {
                return .invalid(
                    error: .minSubtotalNotMet(
                        required: minSubtotal,
                        actual: subtotal
                    )
                )
            }
        }
        
        return .valid
    }
    
    // MARK: - Item-level validation (no minSubtotal here)
    
    public func validateItemChange(
        in cart: Cart,
        proposedItem: CartItem
    ) async -> CartValidationResult {
        // Quantity must be positive.
        guard proposedItem.quantity > 0 else {
            return .invalid(
                error: .custom(message: "Quantity must be greater than zero.")
            )
        }
        
        // Respect available stock, if provided.
        if let available = proposedItem.availableStock,
           proposedItem.quantity > available {
            return .invalid(
                error: .quantityExceedsAvailableStock(
                    productID: proposedItem.productID,
                    available: available,
                    requested: proposedItem.quantity
                )
            )
        }
        
        // Max items rule (shared with full-cart validation),
        // but using a *prospective* item to account for add vs update.
        if let error = validateMaxItems(in: cart, prospectiveItem: proposedItem) {
            return .invalid(error: error)
        }
        
        return .valid
    }
    
    // MARK: - Helpers
    
    private func effectiveRules(for cart: Cart) -> (minSubtotal: Money?, maxItems: Int?) {
        let min = cart.minSubtotal ?? defaultMinSubtotal
        let max = cart.maxItemCount ?? defaultMaxItems
        return (min, max)
    }
    
    private func computeSubtotal(for cart: Cart) -> Money {
        let currencyCode = cart.items.first?.unitPrice.currencyCode ?? "USD"
        var total = Decimal(0)
        for item in cart.items {
            total += item.unitPrice.amount * Decimal(item.quantity)
        }
        return Money(amount: total, currencyCode: currencyCode)
    }
    
    /// Shared max-items rule logic, used by both `validate(cart:)` and
    /// `validateItemChange(in:proposedItem:)`.
    ///
    /// - For plain cart validation, `prospectiveItem` is `nil`, so it uses
    ///   the current `cart.items.count`.
    /// - For item changes, we treat `prospectiveItem` as:
    ///   - *new* line if its `id` does not exist in the cart → count + 1
    ///   - *update* to an existing line if `id` matches → same count.
    private func validateMaxItems(
        in cart: Cart,
        prospectiveItem: CartItem?
    ) -> CartValidationError? {
        let (_, maxItems) = effectiveRules(for: cart)
        guard let maxItems else { return nil }
        
        let baseCount = cart.items.count
        
        let prospectiveCount: Int
        if let item = prospectiveItem,
           cart.items.firstIndex(where: { $0.id == item.id }) == nil {
            // New line being added.
            prospectiveCount = baseCount + 1
        } else {
            // Either no item provided, or updating an existing line.
            prospectiveCount = baseCount
        }
        
        guard prospectiveCount <= maxItems else {
            return .maxItemsExceeded(
                max: maxItems,
                actual: prospectiveCount
            )
        }
        
        return nil
    }
}
