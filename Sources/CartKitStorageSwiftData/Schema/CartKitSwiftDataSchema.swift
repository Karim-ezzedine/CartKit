import Foundation

#if canImport(SwiftData) && os(iOS)
import SwiftData

/// Versioned SwiftData schema for CartKit storage.
@available(iOS 17, *)
enum CartKitSwiftDataSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    
    static var models: [any PersistentModel.Type] {
        [
            CartModel.self,
            CartItemModel.self,
            CartItemModifierModel.self
        ]
    }
}

/// Migration plan for SwiftData schema evolution.
@available(iOS 17, *)
enum CartKitSwiftDataMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CartKitSwiftDataSchemaV1.self]
    }
    
    static var stages: [MigrationStage] { [] }
}
#endif
