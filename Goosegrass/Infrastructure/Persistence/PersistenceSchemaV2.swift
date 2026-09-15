import Foundation
import SwiftData

enum PersistenceSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        PersistenceSchemaV1.models + [AppointmentChangeRecord.self]
    }

    @Model
    final class AppointmentChangeRecord {
        @Attribute(.unique) var id: UUID
        var appointmentID: UUID
        var changeTypeRawValue: String
        var oldValueJSON: String
        var newValueJSON: String
        var reason: String
        var changedAt: Date

        init(
            id: UUID = UUID(),
            appointmentID: UUID,
            changeTypeRawValue: String,
            oldValueJSON: String,
            newValueJSON: String,
            reason: String = "",
            changedAt: Date = Date()
        ) {
            self.id = id
            self.appointmentID = appointmentID
            self.changeTypeRawValue = changeTypeRawValue
            self.oldValueJSON = oldValueJSON
            self.newValueJSON = newValueJSON
            self.reason = reason
            self.changedAt = changedAt
        }
    }
}
