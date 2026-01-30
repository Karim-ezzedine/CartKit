import Foundation
import Testing
import CartKitCore
import CartKitStorageCoreData
@testable import CartKit

#if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
import CartKitStorageSwiftData

struct CartStoreCrossBackendMigratorTests {

    @Test
    func migrate_copiesCartsAndPreservesFields() async throws {
        guard #available(iOS 17, *) else { return }

        let source = try await makeCoreDataStore()
        let target = try makeSwiftDataStore()

        let cart = makeCart(id: "cart-1", storeID: "store-1", profileID: "profile-1")
        try await source.saveCart(cart)

        let migrator = CartStoreCrossBackendMigrator(source: source, target: target)
        try await migrator.migrate()

        let migrated = try await target.fetchAllCarts(limit: nil)
        #expect(migrated.count == 1)
        #expect(migrated.first?.id == cart.id)
        #expect(migrated.first?.storeID == cart.storeID)
        #expect(migrated.first?.profileID == cart.profileID)
        #expect(migrated.first?.items.count == cart.items.count)
        #expect(migrated.first?.savedPromotionKinds == cart.savedPromotionKinds)
    }

    @Test
    func migrate_isIdempotent_whenRunTwice() async throws {
        guard #available(iOS 17, *) else { return }

        let source = try await makeCoreDataStore()
        let target = try makeSwiftDataStore()

        let cart = makeCart(id: "cart-2", storeID: "store-2", profileID: nil)
        try await source.saveCart(cart)

        let migrator = CartStoreCrossBackendMigrator(source: source, target: target)
        try await migrator.migrate()
        try await migrator.migrate()

        let migrated = try await target.fetchAllCarts(limit: nil)
        #expect(migrated.count == 1)
        #expect(migrated.first?.id == cart.id)
    }

    @Test
    func migrate_skipsWhenTargetHasData_byDefault() async throws {
        guard #available(iOS 17, *) else { return }

        let source = try await makeCoreDataStore()
        let target = try makeSwiftDataStore()

        let sourceCart = makeCart(id: "cart-source", storeID: "store-src", profileID: nil)
        let targetCart = makeCart(id: "cart-target", storeID: "store-tgt", profileID: nil)

        try await source.saveCart(sourceCart)
        try await target.saveCart(targetCart)

        let migrator = CartStoreCrossBackendMigrator(source: source, target: target)
        try await migrator.migrate()

        let migrated = try await target.fetchAllCarts(limit: nil)
        #expect(migrated.count == 1)
        #expect(migrated.first?.id == targetCart.id)
    }

    @Test
    func migrate_allowsWhenTargetHasData_ifForced() async throws {
        guard #available(iOS 17, *) else { return }

        let source = try await makeCoreDataStore()
        let target = try makeSwiftDataStore()

        let sourceCart = makeCart(id: "cart-source-force", storeID: "store-src", profileID: nil)
        let targetCart = makeCart(id: "cart-target-force", storeID: "store-tgt", profileID: nil)

        try await source.saveCart(sourceCart)
        try await target.saveCart(targetCart)

        let migrator = CartStoreCrossBackendMigrator(
            source: source,
            target: target,
            allowWhenTargetHasData: true
        )
        try await migrator.migrate()

        let migrated = try await target.fetchAllCarts(limit: nil)
        let ids = Set(migrated.map(\.id))
        #expect(ids.contains(sourceCart.id))
        #expect(ids.contains(targetCart.id))
    }
}

// MARK: - Helpers

@available(iOS 17, *)
private func makeCoreDataStore() async throws -> CartStore {
    let dir = try makeTempDirectory()
    let url = dir.appendingPathComponent("CoreDataCartStore.sqlite")
    let config = CoreDataCartStoreConfiguration(modelName: "CartStorage", inMemory: false, storeURL: url)
    return try await CoreDataCartStore(configuration: config)
}

@available(iOS 17, *)
private func makeSwiftDataStore() throws -> CartStore {
    let dir = try makeTempDirectory()
    let url = dir.appendingPathComponent("SwiftDataCartStore.sqlite")
    let config = SwiftDataCartStoreConfiguration(inMemory: false, storeURL: url)
    return try SwiftDataCartStore(configuration: config)
}

private func makeTempDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("CartKitMigrationTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func makeCart(id: String, storeID: String, profileID: String?) -> Cart {
    let item = CartItem(
        id: CartItemID(rawValue: "item-\(id)"),
        productID: "product-\(id)",
        quantity: 2,
        unitPrice: Money(amount: 5, currencyCode: "USD"),
        totalPrice: Money(amount: 10, currencyCode: "USD"),
        modifiers: [
            CartItemModifier(id: "mod-\(id)", name: "Extra", priceDelta: Money(amount: 1, currencyCode: "USD"))
        ],
        imageURL: URL(string: "https://picsum.photos/100"),
        availableStock: 10
    )

    return Cart(
        id: CartID(rawValue: id),
        storeID: StoreID(rawValue: storeID),
        profileID: profileID.map(UserProfileID.init(rawValue:)),
        sessionID: CartSessionID("session-\(id)"),
        items: [item],
        status: .active,
        createdAt: Date(timeIntervalSince1970: 1),
        updatedAt: Date(timeIntervalSince1970: 2),
        metadata: ["source": "migration-test"],
        displayName: "Test Cart",
        context: "tests",
        storeImageURL: URL(string: "https://picsum.photos/100"),
        minSubtotal: Money(amount: 10, currencyCode: "USD"),
        maxItemCount: 5,
        savedPromotionKinds: [.freeDelivery]
    )
}
#endif
