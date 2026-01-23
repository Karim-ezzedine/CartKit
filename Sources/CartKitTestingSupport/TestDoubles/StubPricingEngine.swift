//
//  StubPricingEngine.swift
//  CartKit
//
//  Created by Karim Ezzeddine on 23/01/2026.
//


private actor StubPricingEngine: CartPricingEngine {
        enum Mode {
            /// Subtotal is derived from the cart's items sum (unitPrice * quantity).
            /// Currency follows the first item (or USD if empty).
            case deriveFromItems

            /// Forces a fixed subtotal per store (currency must be provided).
            case fixedPerStore([StoreID: Money])
        }

        private let mode: Mode

        init(mode: Mode) {
            self.mode = mode
        }

        func computeTotals(for cart: Cart, context: CartPricingContext) async throws -> CartTotals {
            switch mode {
            case .deriveFromItems:
                let currency = cart.items.first?.unitPrice.currencyCode ?? "USD"
                let subtotalAmount: Decimal = cart.items.reduce(.zero) { partial, item in
                    partial + (item.unitPrice.amount * Decimal(item.quantity))
                }
                return CartTotals(subtotal: Money(amount: subtotalAmount, currencyCode: currency))

            case .fixedPerStore(let map):
                let money = map[cart.storeID] ?? Money(amount: .zero, currencyCode: "USD")
                return CartTotals(subtotal: money)
            }
        }
    }