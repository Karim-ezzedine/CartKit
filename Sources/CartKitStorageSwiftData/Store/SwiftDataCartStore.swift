import Foundation
import CartKitCore

#if canImport(SwiftData) && os(iOS)
import SwiftData

@available(iOS 17, *)
public actor SwiftDataCartStore: CartStore {
    
    // MARK: - Dependencies (Infrastructure)
    
    private let container: ModelContainer
    
    // MARK: - Init
    
    public init(configuration: SwiftDataCartStoreConfiguration = .init()) throws {
        let modelConfiguration: ModelConfiguration
        
        if configuration.inMemory {
            modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if let url = configuration.storeURL {
            modelConfiguration = ModelConfiguration(url: url)
        } else {
            modelConfiguration = ModelConfiguration()
        }
        
        let schema = Schema(versionedSchema: CartKitSwiftDataSchemaV1.self)
        self.container = try ModelContainer(
            for: schema,
            migrationPlan: CartKitSwiftDataMigrationPlan.self,
            configurations: modelConfiguration
        )
    }
    
    // MARK: - CartStore
    
    public func loadCart(id: CartID) async throws -> Cart? {
        let context = ModelContext(container)
        
        let descriptor = FetchDescriptor<CartModel>(
            predicate: #Predicate { $0.id == id.rawValue }
        )
        let results = try context.fetch(descriptor)
        
        guard let model = results.first else { return nil }
        return try SwiftDataCartMapping.toDomain(model)
    }
    
    public func saveCart(_ cart: Cart) async throws {
        let context = ModelContext(container)
        
        // Upsert by unique id
        let existing = try fetchCartModel(id: cart.id.rawValue, in: context)
        
        if let existing {
            // Update fields + replace owned graph (items/modifiers)
            apply(cart, to: existing, in: context)
        } else {
            let newModel = SwiftDataCartMapping.toModel(cart)
            context.insert(newModel)
        }
        
        try context.save()
    }
    
    public func deleteCart(id: CartID) async throws {
        let context = ModelContext(container)
        
        if let existing = try fetchCartModel(id: id.rawValue, in: context) {
            context.delete(existing)
            try context.save()
        } else {
            // idempotent: no-op
            return
        }
    }
    
    public func fetchCarts(matching query: CartQuery, limit: Int?) async throws -> [Cart] {
        let context = ModelContext(container)

        let descriptor = makeDescriptor(for: query, limit: limit)
        let models = try context.fetch(descriptor)

        return try models.map(SwiftDataCartMapping.toDomain)
    }

    public func fetchAllCarts(limit: Int?) async throws -> [Cart] {
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<CartModel>()
        descriptor.sortBy = sortDescriptors(for: .updatedAtDescending)
        if let limit { descriptor.fetchLimit = max(0, limit) }

        let models = try context.fetch(descriptor)
        return try models.map(SwiftDataCartMapping.toDomain)
    }
    
    // MARK: - Internals
    
    private func fetchCartModel(id: String, in context: ModelContext) throws -> CartModel? {
        let descriptor = FetchDescriptor<CartModel>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    private func apply(_ cart: Cart, to model: CartModel, in context: ModelContext) {
        model.storeId = cart.storeID.rawValue
        model.profileId = cart.profileID?.rawValue
        model.sessionId = cart.sessionID?.rawValue
        model.status = cart.status.rawValue
        model.createdAt = cart.createdAt
        model.updatedAt = cart.updatedAt
        
        model.metadataJSON = (cart.metadata.isEmpty ? nil : try? JSONEncoder().encode(cart.metadata))
        model.promotionKindsJSON = (cart.savedPromotionKinds.isEmpty
                                    ? nil
                                    : try? JSONEncoder().encode(cart.savedPromotionKinds))
        model.displayName = cart.displayName
        model.context = cart.context
        model.storeImageURLString = cart.storeImageURL?.absoluteString
        
        model.minSubtotalAmount = cart.minSubtotal?.amount
        model.minSubtotalCurrencyCode = cart.minSubtotal?.currencyCode
        model.maxItemCount = cart.maxItemCount
        
        // Replace owned child graph (aggregate boundary)
        // Delete old children explicitly to avoid orphaned nodes.
        for oldItem in model.items {
            context.delete(oldItem) // cascades modifiers
        }
        model.items = cart.items.map(SwiftDataCartMapping.toModel)
    }
    
    private func makeDescriptor(for query: CartQuery, limit: Int?) -> FetchDescriptor<CartModel> {
        
        let storeRaw: String? = query.storeID?.rawValue
        let storeRawValue = storeRaw ?? ""

        let shouldFilterProfile: Bool
        let requiresGuestProfile: Bool
        let profileRawValue: String
        switch query.profile {
        case .any:
            shouldFilterProfile = false
            requiresGuestProfile = false
            profileRawValue = ""
        case .guestOnly:
            shouldFilterProfile = true
            requiresGuestProfile = true
            profileRawValue = ""
        case .profile(let profileID):
            shouldFilterProfile = true
            requiresGuestProfile = false
            profileRawValue = profileID.rawValue
        }

        let shouldFilterStatuses: Bool
        let statusRawValues: Set<String>
        if let statuses = query.statuses, !statuses.isEmpty {
            shouldFilterStatuses = true
            statusRawValues = Set(statuses.map(\.rawValue))
        } else {
            shouldFilterStatuses = false
            statusRawValues = []
        }

        // Helpers expressed as inline boolean expressions, not functions.
        // We materialize scope constraints as flags and raw values.
        let shouldFilterStore = (storeRaw != nil)

        let shouldFilterSession: Bool
        let sessionRaw: String?
        switch query.session {
        case .any:
            shouldFilterSession = false
            sessionRaw = nil
        case .sessionless:
            shouldFilterSession = true
            sessionRaw = nil
        case .session(let id):
            shouldFilterSession = true
            sessionRaw = id.rawValue
        }

        let descriptor = FetchDescriptor<CartModel>(
            predicate: #Predicate<CartModel> { cart in
                (!shouldFilterStore || cart.storeId == storeRawValue) &&
                (
                    !shouldFilterProfile ||
                    (requiresGuestProfile && cart.profileId == nil) ||
                    (!requiresGuestProfile && cart.profileId == profileRawValue)
                ) &&
                (!shouldFilterSession || cart.sessionId == sessionRaw) &&
                (!shouldFilterStatuses || statusRawValues.contains(cart.status))
            }
        )
        
        var mutable = descriptor
        mutable.sortBy = sortDescriptors(for: query.sort)
        
        if let limit { mutable.fetchLimit = max(0, limit) }
        
        return mutable
    }
    
    private func sortDescriptors(for sort: CartQuery.Sort) -> [SortDescriptor<CartModel>] {
        switch sort {
        case .createdAtAscending:
            return [SortDescriptor(\.createdAt, order: .forward)]
        case .createdAtDescending:
            return [SortDescriptor(\.createdAt, order: .reverse)]
        case .updatedAtAscending:
            return [SortDescriptor(\.updatedAt, order: .forward)]
        case .updatedAtDescending:
            return [SortDescriptor(\.updatedAt, order: .reverse)]
        }
    }
}
#endif
