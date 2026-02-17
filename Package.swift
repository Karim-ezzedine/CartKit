// swift-tools-version: 6.0
import PackageDescription


let package = Package(
    name: "CartKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "CartKit",
            targets: ["CartKit"]
        ),
        // Core domain, use cases, protocols
        .library(
            name: "CartKitCore",
            targets: ["CartKitCore"]
        ),
        // Core Data-based storage implementation
        .library(
            name: "CartKitStorageCoreData",
            targets: ["CartKitStorageCoreData"]
        ),
        
        // SwiftData-based storage implementation (iOS 17+ APIs inside)
        .library(
            name: "CartKitStorageSwiftData",
            targets: ["CartKitStorageSwiftData"]
        ),
        
        // Testing helpers (fakes, builders, in-memory stores)
        .library(
            name: "CartKitTestingSupport",
            targets: ["CartKitTestingSupport"]
        )
    ],
    dependencies: [
        // No external deps for now
    ],
    targets: [
        
        // MARK: - Factory
        
        .target(
            name: "CartKit",
            dependencies: [
                "CartKitCore",
                "CartKitStorageCoreData",
                "CartKitStorageSwiftData"
            ]
        ),
        
        // MARK: - Core
        
            .target(
                name: "CartKitCore",
                dependencies: []
            ),
        
        // MARK: - Storage
        
            .target(
                name: "CartKitStorageCoreData",
                dependencies: [
                    "CartKitCore"
                ],
                exclude: [
                    "Resources/CartStorage.xcdatamodeld"
                ],
                resources: [
                    .process("Resources/CartStorage.momd")
                ]
            ),
        
            .target(
                name: "CartKitStorageSwiftData",
                dependencies: [
                    "CartKitCore"
                ]
            ),
        
        // MARK: - Testing Support
        
            .target(
                name: "CartKitTestingSupport",
                dependencies: [
                    "CartKitCore"
                ]
            ),
        
        // MARK: - Tests (placeholder for now)
        
            .testTarget(
                name: "CartKitTests",
                dependencies: [
                    "CartKit",           // where Migration Runner & policy will live
                    "CartKitCore",       // if any shared fixtures/types are needed
                    "CartKitTestingSupport"
                ]
            ),
        
            .testTarget(
                name: "CartKitCoreTests",
                dependencies: [
                    "CartKitCore",
                    "CartKitTestingSupport"
                ]
            ),
        
            .testTarget(
                name: "CartKitStorageCoreDataTests",
                dependencies: [
                    "CartKitStorageCoreData",
                    "CartKitCore",
                    "CartKitTestingSupport"
                ],
                exclude: [
                    "LegacyCoreData"
                ]
            ),
        
            .testTarget(
                name: "CartKitStorageSwiftDataTests",
                dependencies: [
                    "CartKitStorageSwiftData",
                    "CartKitCore",
                    "CartKitTestingSupport"
                ],
                exclude: [
                    "LegacySwiftData"
                ]
            )
    ]
)
