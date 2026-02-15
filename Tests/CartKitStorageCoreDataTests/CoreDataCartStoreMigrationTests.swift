import Foundation
import Testing
import CartKitCore
import CartKitStorageCoreData

/// Lightweight Core Data migration test (fixture-based).
///
/// How to generate the legacy fixture:
/// 1. Checkout the commit/tag *before* the schema change you want to migrate from.
/// 2. Use `CoreDataCartStore` to create carts on disk (not in-memory) with at least one cart.
///    - Set `CoreDataCartStoreConfiguration(storeURL: ...)` to a temp location.
///    - Save at least one cart with items + promotion kinds (if those fields are new).
/// 3. Copy the SQLite files into:
///    `Tests/CartKitStorageCoreDataTests/Fixtures/LegacyCoreData/`
///    - CartStorage_v1.sqlite
///    - CartStorage_v1.sqlite-wal (if present)
///    - CartStorage_v1.sqlite-shm (if present)
///
/// This test will NO-OP if the fixture is missing.
struct CoreDataCartStoreMigrationTests {
    
    private enum Fixture {
        static let directoryName = "LegacyCoreData"
        static let sqliteName = "CartStorage_v1.sqlite"
        static let walName = "CartStorage_v1.sqlite-wal"
        static let shmName = "CartStorage_v1.sqlite-shm"
        
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
    func lightweightMigration_opensLegacyStore_andLoadsCarts() async throws {
        guard Fixture.exists() else {
            // Fixture not present yet; follow the instructions above to enable this test.
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sqliteURL = try copyFixture(to: tempDir)
        
        let config = CoreDataCartStoreConfiguration(
            modelName: "CartStorage",
            inMemory: false,
            storeURL: sqliteURL
        )
        
        let store = try await CoreDataCartStore(configuration: config)
        
        // Fixture-specific query: legacy fixture uses a logged-in profile cart.
        let query = CartQuery(
            storeID: StoreID(rawValue: "store-legacy"),
            profile: .profile(UserProfileID(rawValue: "profile-legacy")),
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
