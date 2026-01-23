// MARK: - Checkout Totals (Active Cart Group)

extension CartManagerDomainTests {

    // MARK: Test doubles (ports)

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

    private actor SpyPromotionEngine: PromotionEngine {
        private(set) var calls: [(storeID: StoreID, promotions: [PromotionKind])] = []

        func applyPromotions(_ promotions: [PromotionKind], to cartTotals: CartTotals) async throws -> CartTotals {
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

    // MARK: Helpers

    private func makeManagerForGroupTotals(
        initialCarts: [Cart],
        pricingEngine: CartPricingEngine,
        promotionEngine: PromotionEngine
    ) -> CartManager {
        let store = InMemoryCartStore(initialCarts: initialCarts)
        let config = CartConfiguration(
            cartStore: store,
            pricingEngine: pricingEngine,
            promotionEngine: promotionEngine
        )
        return CartManager(configuration: config)
    }

    // MARK: Tests

    @Test
    func getTotalsForActiveCartGroup_filtersEmptyCartsByDefault_andAggregates() async throws {
        let profileID = UserProfileID("profile_group_totals_filter_empty")
        let sessionID = CartSessionID("session_group_totals_filter_empty")

        let storeA = StoreID("store_A_group_totals")
        let storeB = StoreID("store_B_group_totals")

        var cartA = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        cartA.status = .active // non-empty by fixture

        var cartB = CartTestFixtures.loggedInCart(storeID: storeB, profileID: profileID, sessionID: sessionID)
        cartB.status = .active
        cartB.items = [] // empty cart

        let pricing = StubPricingEngine(mode: .fixedPerStore([
            storeA: Money(amount: 10, currencyCode: "USD"),
            storeB: Money(amount: 99, currencyCode: "USD")
        ]))
        let promos = SpyPromotionEngine()

        let manager = makeManagerForGroupTotals(
            initialCarts: [cartA, cartB],
            pricingEngine: pricing,
            promotionEngine: promos
        )

        let totals = try await manager.getTotalsForActiveCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            promotionsByStore: [:],
            includeEmptyCarts: false
        )

        // storeB excluded (empty)
        #expect(Set(totals.perStore.keys) == Set([storeA]))
        #expect(totals.aggregate.subtotal.amount == 10)
        #expect(totals.aggregate.subtotal.currencyCode == "USD")
    }

    @Test
    func getTotalsForActiveCartGroup_includeEmptyCartsTrue_includesEmptyCarts_inAggregation() async throws {
        let profileID = UserProfileID("profile_group_totals_include_empty")
        let sessionID = CartSessionID("session_group_totals_include_empty")

        let storeA = StoreID("store_A_group_totals_inc")
        let storeB = StoreID("store_B_group_totals_inc")

        var cartA = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        cartA.status = .active

        var cartB = CartTestFixtures.loggedInCart(storeID: storeB, profileID: profileID, sessionID: sessionID)
        cartB.status = .active
        cartB.items = [] // empty but should be included

        let pricing = StubPricingEngine(mode: .fixedPerStore([
            storeA: Money(amount: 10, currencyCode: "USD"),
            storeB: Money(amount: 5, currencyCode: "USD")
        ]))
        let promos = SpyPromotionEngine()

        let manager = makeManagerForGroupTotals(
            initialCarts: [cartA, cartB],
            pricingEngine: pricing,
            promotionEngine: promos
        )

        let totals = try await manager.getTotalsForActiveCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            promotionsByStore: [:],
            includeEmptyCarts: true
        )

        #expect(Set(totals.perStore.keys) == Set([storeA, storeB]))
        #expect(totals.aggregate.subtotal.amount == 15)
        #expect(totals.aggregate.subtotal.currencyCode == "USD")
    }

    @Test
    func getTotalsForActiveCartGroup_appliesPromotionsPerStore_onlyToThatStore() async throws {
        let profileID = UserProfileID("profile_group_totals_promos")
        let sessionID = CartSessionID("session_group_totals_promos")

        let storeA = StoreID("store_A_group_promos")
        let storeB = StoreID("store_B_group_promos")

        var cartA = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        cartA.status = .active

        var cartB = CartTestFixtures.loggedInCart(storeID: storeB, profileID: profileID, sessionID: sessionID)
        cartB.status = .active

        let pricing = StubPricingEngine(mode: .fixedPerStore([
            storeA: Money(amount: 10, currencyCode: "USD"),
            storeB: Money(amount: 20, currencyCode: "USD")
        ]))

        // Use a real “apply” behavior but we also want to verify the map wiring;
        // here we only assert output differences (stronger than call-count assertions).
        let promotionEngine = SpyPromotionEngine()

        let manager = makeManagerForGroupTotals(
            initialCarts: [cartA, cartB],
            pricingEngine: pricing,
            promotionEngine: promotionEngine
        )

        let totals = try await manager.getTotalsForActiveCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            promotionsByStore: [
                storeA: [.fixedAmountOffCart(Money(amount: 2, currencyCode: "USD"))]
            ],
            includeEmptyCarts: true
        )

        let a = try #require(totals.perStore[storeA])
        let b = try #require(totals.perStore[storeB])

        // storeA got -2, storeB unchanged
        #expect(a.grandTotal.amount == 8)
        #expect(b.grandTotal.amount == 20)

        // Aggregate reflects both
        #expect(totals.aggregate.grandTotal.amount == 28)
        #expect(totals.aggregate.grandTotal.currencyCode == "USD")
    }

    @Test
    func getTotalsForActiveCartGroup_throwsConflict_whenDuplicateActiveStoreWithinSameGroup() async throws {
        let profileID = UserProfileID("profile_group_totals_dup_store")
        let sessionID = CartSessionID("session_group_totals_dup_store")
        let storeA = StoreID("store_dup_A")

        var c1 = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        c1.status = .active

        var c2 = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        c2.status = .active

        let pricing = StubPricingEngine(mode: .fixedPerStore([storeA: Money(amount: 10, currencyCode: "USD")]))
        let promos = SpyPromotionEngine()

        let manager = makeManagerForGroupTotals(
            initialCarts: [c1, c2],
            pricingEngine: pricing,
            promotionEngine: promos
        )

        await #expect(throws: CartError.self) {
            _ = try await manager.getTotalsForActiveCartGroup(
                profileID: profileID,
                sessionID: sessionID,
                includeEmptyCarts: true
            )
        }
    }

    @Test
    func getTotalsForActiveCartGroup_throwsValidationFailed_whenCurrenciesMixedAcrossStores() async throws {
        let profileID = UserProfileID("profile_group_totals_mixed_ccy")
        let sessionID = CartSessionID("session_group_totals_mixed_ccy")

        let storeUSD = StoreID("store_usd")
        let storeEUR = StoreID("store_eur")

        // USD cart
        var usdCart = CartTestFixtures.loggedInCart(storeID: storeUSD, profileID: profileID, sessionID: sessionID)
        usdCart.status = .active

        // EUR cart: mutate item currency to EUR
        var eurCart = CartTestFixtures.loggedInCart(storeID: storeEUR, profileID: profileID, sessionID: sessionID)
        eurCart.status = .active
        eurCart.items = eurCart.items.map { item in
            var copy = item
            copy.unitPrice = Money(amount: item.unitPrice.amount, currencyCode: "EUR")
            return copy
        }

        // Pricing derives currency from items, so aggregate should detect mismatch.
        let pricing = StubPricingEngine(mode: .deriveFromItems)
        let promos = SpyPromotionEngine()

        let manager = makeManagerForGroupTotals(
            initialCarts: [usdCart, eurCart],
            pricingEngine: pricing,
            promotionEngine: promos
        )

        await #expect(throws: CartError.self) {
            _ = try await manager.getTotalsForActiveCartGroup(
                profileID: profileID,
                sessionID: sessionID,
                includeEmptyCarts: true
            )
        }
    }
}

