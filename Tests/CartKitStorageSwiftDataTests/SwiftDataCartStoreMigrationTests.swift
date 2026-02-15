import Foundation
import Testing
import CartKitCore
import CartKitStorageSwiftData

#if canImport(SwiftData) && os(iOS)
import SwiftData

/// SwiftData migration test (fixture-based).
///
/// How to generate the legacy fixture:
/// 1. Checkout the commit/tag *before* the schema change you want to migrate from.
/// 2. Create a disk-backed `SwiftDataCartStore` with a fixed URL:
///    - `SwiftDataCartStoreConfiguration(storeURL: ...)`
/// 3. Save at least one cart (items + promotion kinds if those fields are new).
/// 4. Copy the SwiftData store files into:
///    `Tests/CartKitStorageSwiftDataTests/LegacySwiftData/`
///    - CartKitSwiftData_v1.sqlite
///    - CartKitSwiftData_v1.sqlite-wal (if present)
///    - CartKitSwiftData_v1.sqlite-shm (if present)
///
/// This test will NO-OP if the fixture is missing.
struct SwiftDataCartStoreMigrationTests {
    
    private enum Fixture {
        static let directoryName = "LegacySwiftData"
        static let sqliteName = "CartKitSwiftData_v1.sqlite"
        static let walName = "CartKitSwiftData_v1.sqlite-wal"
        static let shmName = "CartKitSwiftData_v1.sqlite-shm"
        
        static var directoryURL: URL {
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent(directoryName, isDirectory: true)
        }
        
        static var sqliteURL: URL {
            directoryURL.appendingPathComponent(sqliteName)
        }
        
        static var walURL: URL {
            directoryURL.appendingPathComponent(walName)
        }
        
        static var shmURL: URL {
            directoryURL.appendingPathComponent(shmName)
        }
        
        static func exists() -> Bool {
            FileManager.default.fileExists(atPath: sqliteURL.path)
        }
    }
    
    @Test
    func migration_opensLegacyStore_andLoadsCarts() async throws {
        guard #available(iOS 17, *) else { return }
        
        guard Fixture.exists() else {
            // Fixture not present yet; follow the instructions above to enable this test.
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sqliteURL = try copyFixture(to: tempDir)
        
        let config = SwiftDataCartStoreConfiguration(
            inMemory: false,
            storeURL: sqliteURL
        )
        
        let store = try SwiftDataCartStore(configuration: config)
        
        let query = CartQuery(
            storeID: nil,
            profile: .guestOnly,
            session: .any,
            statuses: nil,
            sort: .updatedAtDescending
        )
        
        let carts = try await store.fetchCarts(matching: query, limit: nil)
        #expect(!carts.isEmpty)
    }
    
    private func copyFixture(to directory: URL) throws -> URL {
        let fileManager = FileManager.default
        
        let sqliteDestination = directory.appendingPathComponent(Fixture.sqliteName)
        try copyIfExists(from: Fixture.sqliteURL, to: sqliteDestination, fileManager: fileManager)
        
        let walDestination = directory.appendingPathComponent(Fixture.walName)
        try copyIfExists(from: Fixture.walURL, to: walDestination, fileManager: fileManager)
        
        let shmDestination = directory.appendingPathComponent(Fixture.shmName)
        try copyIfExists(from: Fixture.shmURL, to: shmDestination, fileManager: fileManager)
        
        return sqliteDestination
    }
    
    private func copyIfExists(
        from source: URL,
        to destination: URL,
        fileManager: FileManager
    ) throws {
        guard fileManager.fileExists(atPath: source.path) else { return }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }
}
#endif
