import CartKitCore

public actor StubValidationEngine: CartValidationEngine {
    private let resultsByStore: [StoreID: CartValidationResult]

    public init(resultsByStore: [StoreID: CartValidationResult]) {
        self.resultsByStore = resultsByStore
    }

    public func validate(cart: Cart) async -> CartValidationResult {
        resultsByStore[cart.storeID] ?? .valid
    }

    public func validateItemChange(in cart: Cart, proposedItem: CartItem) async -> CartValidationResult {
        .valid
    }
}
