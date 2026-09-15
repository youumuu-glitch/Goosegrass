import SwiftData

enum GoosegrassMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PersistenceSchemaV1.self, PersistenceSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: PersistenceSchemaV1.self,
                toVersion: PersistenceSchemaV2.self
            ),
        ]
    }
}
