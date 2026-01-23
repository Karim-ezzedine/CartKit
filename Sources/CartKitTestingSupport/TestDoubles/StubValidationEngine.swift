//
//  StubValidationEngine.swift
//  CartKit
//
//  Created by Karim Ezzeddine on 23/01/2026.
//


private actor StubValidationEngine: CartValidationEngine {
    private let resultsByStore: [StoreID: CartValidationResult]

    init(resultsByStore: [StoreID: CartValidationResult]) {
        self.resultsByStore = resultsByStore
    }

    func validate(cart: Cart) async -> CartValidationResult {
        resultsByStore[cart.storeID] ?? .valid
    }

    func validateItemChange(in cart: Cart, proposedItem: CartItem) async -> CartValidationResult {
        .valid
    }
}
