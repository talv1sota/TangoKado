import Foundation
import SwiftData

enum TangoKadoSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Deck.self, Flashcard.self]
    }
}

enum TangoKadoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TangoKadoSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — this is the initial version.
        // When adding V2 in a future update:
        // 1. Create TangoKadoSchemaV2 with the updated models
        // 2. Add a migration stage here (lightweight or custom)
        // Example:
        // .lightweight(fromVersion: TangoKadoSchemaV1.self, toVersion: TangoKadoSchemaV2.self)
        []
    }
}
