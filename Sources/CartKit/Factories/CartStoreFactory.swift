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

        // Phase 2 wiring: run migration orchestration (migrators list is empty for now).
        // Phase 4 will add real migrators (e.g., CoreData -> SwiftData copy).
        try await runMigrationsIfNeeded(
            policy: migrationPolicy,
            stateStore: migrationStateStore,
            migrators: migratorsForPhase2()
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

    /// Phase 2: no actual migrations yet. Keep the hook in place.
    static func migratorsForPhase2() -> [any CartStoreMigrator] {
        []
    }
}

enum CartStoreFactoryError: Error {
    case swiftDataUnavailable
}
