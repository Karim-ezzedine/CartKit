import Foundation
import Testing
@testable import CartKitCore
import CartKitTestingSupport

// MARK: - Checkout Totals (Active Cart Group)

extension CartManagerDomainTests {
    
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
    
    @Test
    func validateBeforeCheckoutForActiveCartGroup_filtersEmptyCartsByDefault() async throws {
        let profileID = UserProfileID("profile_group_validate_filter_empty")
        let sessionID = CartSessionID("session_group_validate_filter_empty")

        let storeA = StoreID("store_validate_A")
        let storeB = StoreID("store_validate_B")

        var cartA = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        cartA.status = .active

        var cartB = CartTestFixtures.loggedInCart(storeID: storeB, profileID: profileID, sessionID: sessionID)
        cartB.status = .active
        cartB.items = [] // empty

        let store = InMemoryCartStore(initialCarts: [cartA, cartB])
        let validation = StubValidationEngine(resultsByStore: [:])

        let manager = CartManager(configuration: CartConfiguration(
            cartStore: store,
            validationEngine: validation
        ))

        let result = try await manager.validateBeforeCheckoutForActiveCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            includeEmptyCarts: false
        )

        #expect(Set(result.perStore.keys) == Set([storeA]))
        #expect(result.isValid == true)
    }

    @Test
    func validateBeforeCheckoutForActiveCartGroup_isInvalidWhenAnyStoreCartInvalid() async throws {
        let profileID = UserProfileID("profile_group_validate_any_invalid")
        let sessionID = CartSessionID("session_group_validate_any_invalid")

        let storeA = StoreID("store_validate_ok")
        let storeB = StoreID("store_validate_bad")

        var cartA = CartTestFixtures.loggedInCart(storeID: storeA, profileID: profileID, sessionID: sessionID)
        cartA.status = .active

        var cartB = CartTestFixtures.loggedInCart(storeID: storeB, profileID: profileID, sessionID: sessionID)
        cartB.status = .active

        let store = InMemoryCartStore(initialCarts: [cartA, cartB])

        // Use any real validation error you already have in the module.
        let invalid: CartValidationResult = .invalid(error: .custom(message: "forced"))
        let validation = StubValidationEngine(resultsByStore: [storeB: invalid])

        let manager = CartManager(configuration: CartConfiguration(
            cartStore: store,
            validationEngine: validation
        ))

        let result = try await manager.validateBeforeCheckoutForActiveCartGroup(
            profileID: profileID,
            sessionID: sessionID,
            includeEmptyCarts: true
        )

        #expect(result.perStore[storeA] == .valid)
        #expect(result.perStore[storeB] == invalid)
        #expect(result.isValid == false)
    }

}
