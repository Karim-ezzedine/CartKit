/// Structured reasons why a cart is considered invalid for a given operation.
public enum CartValidationError: Hashable, Codable, Sendable {
    /// Cart subtotal is below the configured minimum.
    case minSubtotalNotMet(required: Money, actual: Money)
    
    /// Cart contains more items than allowed.
    case maxItemsExceeded(max: Int, actual: Int)
    
    /// Quantity for this item exceeds its available stock.
    case quantityExceedsAvailableStock(productID: String, available: Int, requested: Int)
    
    /// Catch-all for simple store constraints or app-specific reasons.
    case custom(message: String)
    
    /// Human-readable description, suitable for logs or simple UI.
    public var message: String {
        switch self {
        case let .minSubtotalNotMet(required, actual):
            return "Minimum order is \(required.amount) \(required.currencyCode), " +
            "current subtotal is \(actual.amount) \(actual.currencyCode)."
            
        case let .maxItemsExceeded(max, actual):
            return "Maximum allowed items is \(max), current count is \(actual)."
            
        case let .quantityExceedsAvailableStock(productID, available, requested):
            return "Requested quantity (\(requested)) for product '\(productID)' " +
            "exceeds available stock (\(available))."
            
        case let .custom(message):
            return message
        }
    }
}
