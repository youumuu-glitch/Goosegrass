import SwiftData

enum GoosegrassMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PersistenceSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
