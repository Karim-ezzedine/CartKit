import Foundation
import CartKitCore
import CartKitStorageCoreData

#if canImport(CartKitStorageSwiftData)
import CartKitStorageSwiftData
#endif

public enum CartStoreFactory {

    public static func makeStore(
        preference: CartStoragePreference,
        coreData: CoreDataCartStoreConfiguration = .init(),
        swiftData: SwiftDataCartStoreConfiguration = .init()
    ) async throws -> any CartStore {

        switch preference {

        case .coreData:
            return try await CoreDataCartStore(configuration: coreData)

        case .swiftData:
            #if canImport(CartKitStorageSwiftData)
            if #available(iOS 17, *) {
                return try SwiftDataCartStore(configuration: swiftData)
            } else {
                throw CartStoreFactoryError.swiftDataUnavailable
            }
            #else
            throw CartStoreFactoryError.swiftDataUnavailable
            #endif

        case .automatic:
            #if canImport(CartKitStorageSwiftData)
            if #available(iOS 17, *) {
                return try SwiftDataCartStore(configuration: swiftData)
            }
            #endif
            return try await CoreDataCartStore(configuration: coreData)
        }
    }
}

enum CartStoreFactoryError: Error {
    case swiftDataUnavailable
}
