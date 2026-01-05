import Foundation
import CartKitCore

import CartKitStorageCoreData

#if canImport(CartKitStorageSwiftData)
import CartKitStorageSwiftData
#endif

public extension CartConfiguration {

    static func configured(
        storage: CartStoragePreference = .automatic,
        coreData: CoreDataCartStoreConfiguration = .init(),
        swiftData: SwiftDataCartStoreConfiguration = .init(),
        pricingEngine: CartPricingEngine = DefaultCartPricingEngine(),
        promotionEngine: PromotionEngine = DefaultPromotionEngine(),
        validationEngine: CartValidationEngine = DefaultCartValidationEngine(),
        analytics: CartAnalyticsSink = NoOpCartAnalyticsSink()
    ) async throws -> CartConfiguration {

        let store = try await CartStoreFactory.makeStore(
            preference: storage,
            coreData: coreData,
            swiftData: swiftData
        )

        return CartConfiguration(
            cartStore: store,
            pricingEngine: pricingEngine,
            promotionEngine: promotionEngine,
            validationEngine: validationEngine,
            analyticsSink: analytics
        )
    }
}
