import CartKitCore

/// Testing facade that wires a `CartManager` with in-memory storage and safe defaults.
///
/// Intended for:
/// - unit tests
/// - previews / demos
///
/// DDD/Clean Architecture note:
/// - This lives in TestingSupport (outside the domain) and composes the app service
///   (`CartManager`) with infrastructure fakes (in-memory store, spy sinks).
public struct MultiCartTestingSupport: Sendable {
    
    public let store: InMemoryCartStore
    public let analytics: SpyCartAnalyticsSink
    
    public init(initialCarts: [Cart] = []) {
        self.store = InMemoryCartStore(initialCarts: initialCarts)
        self.analytics = SpyCartAnalyticsSink()
    }
    
    public func makeConfiguration(
        pricingEngine: CartPricingEngine = NoOpPricingEngine(),
        promotionEngine: PromotionEngine = NoOpPromotionEngine(),
        validationEngine: CartValidationEngine = AllowAllValidationEngine(),
        conflictResolver: CartConflictResolver? = NoOpConflictResolver(),
        catalogConflictDetector: CartCatalogConflictDetector = NoOpCartCatalogConflictDetector(),
        analyticsSink: CartAnalyticsSink? = nil
    ) -> CartConfiguration {
        CartConfiguration(
            cartStore: store,
            pricingEngine: pricingEngine,
            promotionEngine: promotionEngine,
            validationEngine: validationEngine,
            conflictResolver: conflictResolver,
            catalogConflictDetector: catalogConflictDetector,
            analyticsSink: analyticsSink ?? analytics
        )
    }
    
    public func makeCartManager(
        pricingEngine: CartPricingEngine = NoOpPricingEngine(),
        promotionEngine: PromotionEngine = NoOpPromotionEngine(),
        validationEngine: CartValidationEngine = AllowAllValidationEngine(),
        conflictResolver: CartConflictResolver? = NoOpConflictResolver(),
        analyticsSink: CartAnalyticsSink? = nil
    ) -> CartManager {
        CartManager(configuration: makeConfiguration(
            pricingEngine: pricingEngine,
            promotionEngine: promotionEngine,
            validationEngine: validationEngine,
            conflictResolver: conflictResolver,
            analyticsSink: analyticsSink
        ))
    }
}
