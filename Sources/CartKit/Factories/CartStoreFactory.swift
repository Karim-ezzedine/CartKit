import Foundation
import CartKitCore
import CartKitStorageCoreData

#if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
import CartKitStorageSwiftData
#endif

public enum CartStoreFactory {

    /// Creates a `CartStore` based on the requested preference and (optionally) runs migrations.
    ///
    /// - Migration is a composition concern (Clean Architecture): performed here, before returning the store.
    /// - By default, migration runs in `.auto` mode using a `UserDefaults`-backed state store.
    public static func makeStore(
        preference: CartStoragePreference,
        migrationPolicy: CartStoreMigrationPolicy = .auto,
        migrationStateStore: any CartStoreMigrationStateStore = UserDefaultsCartMigrationStateStore()
    ) async throws -> any CartStore {

        let store = try await resolveStore(preference: preference)

        // Phase 4 wiring: run cross-backend migration if needed.
        try await runMigrationsIfNeeded(
            policy: migrationPolicy,
            stateStore: migrationStateStore,
            migrators: await migratorsForCrossBackendMigration(
                preference: preference,
                targetStore: store,
                policy: migrationPolicy
            )
        )

        return store
    }
}

// MARK: - Store Resolution

private extension CartStoreFactory {

    static func resolveStore(
        preference: CartStoragePreference
    ) async throws -> any CartStore {

        switch preference {

        case .coreData:
            return try await CoreDataCartStore()

        case .swiftData:
            #if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
            if #available(iOS 17, *) {
                return try SwiftDataCartStore()
            } else {
                throw CartStoreFactoryError.swiftDataUnavailable
            }
            #else
            throw CartStoreFactoryError.swiftDataUnavailable
            #endif

        case .automatic:
            #if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
            if #available(iOS 17, *) {
                return try SwiftDataCartStore()
            }
            #endif

            // Fallback for macOS / iOS < 17
            return try await CoreDataCartStore()
        }
    }
}

// MARK: - Migration Wiring

private extension CartStoreFactory {

    static func runMigrationsIfNeeded(
        policy: CartStoreMigrationPolicy,
        stateStore: any CartStoreMigrationStateStore,
        migrators: [any CartStoreMigrator]
    ) async throws {
        let runner = CartStoreMigrationRunner(
            stateStore: stateStore,
            policy: policy
        )
        try await runner.run(migrators)
    }

    /// Cross-backend migration (iOS 17+ when SwiftData is target).
    static func migratorsForCrossBackendMigration(
        preference: CartStoragePreference,
        targetStore: any CartStore,
        policy: CartStoreMigrationPolicy
    ) async -> [any CartStoreMigrator] {
        #if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
        guard preference != .coreData else { return [] }
        guard #available(iOS 17, *) else { return [] }
        guard targetStore is SwiftDataCartStore else { return [] }

        do {
            let source = try await CoreDataCartStore()
            let allowWhenTargetHasData = (policy == .force)
            return [
                CartStoreCrossBackendMigrator(
                    source: source,
                    target: targetStore,
                    allowWhenTargetHasData: allowWhenTargetHasData
                )
            ]
        } catch {
            // If Core Data cannot be initialized, skip migration and fall back to target store.
            return []
        }
        #else
        return []
        #endif
    }
}

enum CartStoreFactoryError: Error {
    case swiftDataUnavailable
}
