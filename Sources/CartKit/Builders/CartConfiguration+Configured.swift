import CartKitCore

public extension CartConfiguration {

    static func configured(
        storage: CartStoragePreference = .automatic,
        migrationPolicy: CartStoreMigrationPolicy = .auto,
        migrationStateStore: CartStoreMigrationStateStore = UserDefaultsCartMigrationStateStore(),
        migrationFailureStrategy: CartStoreFactory.MigrationFailureStrategy = .throwError,
        pricingEngine: CartPricingEngine = DefaultCartPricingEngine(),
        promotionEngine: PromotionEngine = DefaultPromotionEngine(),
        validationEngine: CartValidationEngine = DefaultCartValidationEngine(),
        conflictResolver: CartConflictResolver? = nil,
        catalogConflictDetector: CartCatalogConflictDetector = NoOpCartCatalogConflictDetector(),
        analytics: CartAnalyticsSink = NoOpCartAnalyticsSink(),
        logger: CartLogger = DefaultCartLogger()
    ) async throws -> CartConfiguration {

        let store = try await CartStoreFactory.makeStore(
            preference: storage,
            migrationPolicy: migrationPolicy,
            migrationStateStore: migrationStateStore,
            migrationFailureStrategy: migrationFailureStrategy,
            migrationLogger: logger
        )

        return CartConfiguration(
            cartStore: store,
            pricingEngine: pricingEngine,
            promotionEngine: promotionEngine,
            validationEngine: validationEngine,
            conflictResolver: conflictResolver,
            catalogConflictDetector: catalogConflictDetector,
            analyticsSink: analytics,
            logger: logger
        )
    }
}
