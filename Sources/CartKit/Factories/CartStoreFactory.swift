import Foundation
import CartKitCore
import CartKitStorageCoreData

#if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
import CartKitStorageSwiftData
#endif

public enum CartStoreFactory {

    /// Always-available factory (macOS CI-safe).
    /// - Note: SwiftData is not referenced here to keep CartKit buildable on macOS.
    public static func makeStore(
        preference: CartStoragePreference,
        coreData: CoreDataCartStoreConfiguration = .init()
    ) async throws -> any CartStore {

        switch preference {

        case .coreData:
            return try await CoreDataCartStore(configuration: coreData)

        case .swiftData:
            // On platforms where SwiftData isn't available, we fail explicitly.
            throw CartStoreFactoryError.swiftDataUnavailable

        case .automatic:
            // Default to Core Data unless the iOS 17+ overload is used.
            return try await CoreDataCartStore(configuration: coreData)
        }
    }
}

#if os(iOS) && canImport(SwiftData) && canImport(CartKitStorageSwiftData)
extension CartStoreFactory {

    /// iOS 17+ factory that can build SwiftData stores.
    @available(iOS 17, *)
    public static func makeStore(
        preference: CartStoragePreference,
        coreData: CoreDataCartStoreConfiguration = .init(),
        swiftData: SwiftDataCartStoreConfiguration = .init()
    ) async throws -> any CartStore {

        switch preference {

        case .coreData:
            return try await CoreDataCartStore(configuration: coreData)

        case .swiftData:
            return try SwiftDataCartStore(configuration: swiftData)

        case .automatic:
            // Prefer SwiftData when available on this runtime.
            return try SwiftDataCartStore(configuration: swiftData)
        }
    }
}
#endif

enum CartStoreFactoryError: Error {
    case swiftDataUnavailable
}
