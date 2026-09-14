import Foundation
import SwiftData

enum PersistenceSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            CustomerRecord.self,
            AppointmentRecord.self,
            ActivityRecord.self,
            FollowUpRecord.self,
            LeadSourceRecord.self,
            TagRecord.self,
            ReminderRecord.self,
        ]
    }

    @Model
    final class CustomerRecord {
        @Attribute(.unique) var id: UUID
        var displayName: String
        var legalName: String?
        var phone: String
        var normalizedPhone: String
        var email: String?
        var sourceID: UUID?
        var statusRawValue: String
        var notes: String
        var isArchived: Bool
        var createdAt: Date
        var updatedAt: Date
        var lastContactedAt: Date?
        var serverID: String?
        var syncStatus: String?
        var lastSyncedAt: Date?
        var source: LeadSourceRecord?
        @Relationship(deleteRule: .nullify, inverse: \AppointmentRecord.customer)
        var appointments: [AppointmentRecord]
        @Relationship(deleteRule: .nullify, inverse: \ActivityRecord.customer)
        var activities: [ActivityRecord]
        @Relationship(deleteRule: .nullify, inverse: \FollowUpRecord.customer)
        var followUps: [FollowUpRecord]
        @Relationship(deleteRule: .nullify, inverse: \TagRecord.customers)
        var tags: [TagRecord]

        init(
            id: UUID = UUID(),
            displayName: String,
            legalName: String? = nil,
            phone: String,
            normalizedPhone: String,
            email: String? = nil,
            sourceID: UUID? = nil,
            statusRawValue: String = CustomerStatus.new.rawValue,
            notes: String = "",
            isArchived: Bool = false,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            lastContactedAt: Date? = nil,
            serverID: String? = nil,
            syncStatus: String? = nil,
            lastSyncedAt: Date? = nil,
            source: LeadSourceRecord? = nil,
            appointments: [AppointmentRecord] = [],
            activities: [ActivityRecord] = [],
            followUps: [FollowUpRecord] = [],
            tags: [TagRecord] = []
        ) {
            self.id = id
            self.displayName = displayName
            self.legalName = legalName
            self.phone = phone
            self.normalizedPhone = normalizedPhone
            self.email = email
            self.sourceID = sourceID
            self.statusRawValue = statusRawValue
            self.notes = notes
            self.isArchived = isArchived
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.lastContactedAt = lastContactedAt
            self.serverID = serverID
            self.syncStatus = syncStatus
            self.lastSyncedAt = lastSyncedAt
            self.source = source
            self.appointments = appointments
            self.activities = activities
            self.followUps = followUps
            self.tags = tags
        }
    }

    @Model
    final class AppointmentRecord {
        @Attribute(.unique) var id: UUID
        var customerID: UUID
        var startAt: Date
        var endAt: Date?
        var partySize: Int
        var statusRawValue: String
        var customerRequest: String
        var internalNote: String
        var sourceID: UUID?
        var confirmedAt: Date?
        var arrivedAt: Date?
        var completedAt: Date?
        var cancelledAt: Date?
        var noShowAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var serverID: String?
        var syncStatus: String?
        var lastSyncedAt: Date?
        var customer: CustomerRecord?
        @Relationship(deleteRule: .nullify, inverse: \ActivityRecord.appointment)
        var activities: [ActivityRecord]
        @Relationship(deleteRule: .nullify, inverse: \FollowUpRecord.appointment)
        var followUps: [FollowUpRecord]
        @Relationship(deleteRule: .nullify, inverse: \ReminderRecord.appointment)
        var reminders: [ReminderRecord]

        init(
            id: UUID = UUID(),
            customerID: UUID,
            startAt: Date,
            endAt: Date? = nil,
            partySize: Int,
            statusRawValue: String = AppointmentStatus.draft.rawValue,
            customerRequest: String = "",
            internalNote: String = "",
            sourceID: UUID? = nil,
            confirmedAt: Date? = nil,
            arrivedAt: Date? = nil,
            completedAt: Date? = nil,
            cancelledAt: Date? = nil,
            noShowAt: Date? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            serverID: String? = nil,
            syncStatus: String? = nil,
            lastSyncedAt: Date? = nil,
            customer: CustomerRecord? = nil,
            activities: [ActivityRecord] = [],
            followUps: [FollowUpRecord] = [],
            reminders: [ReminderRecord] = []
        ) {
            self.id = id
            self.customerID = customerID
            self.startAt = startAt
            self.endAt = endAt
            self.partySize = partySize
            self.statusRawValue = statusRawValue
            self.customerRequest = customerRequest
            self.internalNote = internalNote
            self.sourceID = sourceID
            self.confirmedAt = confirmedAt
            self.arrivedAt = arrivedAt
            self.completedAt = completedAt
            self.cancelledAt = cancelledAt
            self.noShowAt = noShowAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.serverID = serverID
            self.syncStatus = syncStatus
            self.lastSyncedAt = lastSyncedAt
            self.customer = customer
            self.activities = activities
            self.followUps = followUps
            self.reminders = reminders
        }
    }

    @Model
    final class ActivityRecord {
        @Attribute(.unique) var id: UUID
        var customerID: UUID
        var appointmentID: UUID?
        var typeRawValue: String
        var title: String
        var detail: String
        var createdAt: Date
        var customer: CustomerRecord?
        var appointment: AppointmentRecord?

        init(id: UUID = UUID(), customerID: UUID, appointmentID: UUID? = nil, typeRawValue: String, title: String, detail: String = "", createdAt: Date = Date(), customer: CustomerRecord? = nil, appointment: AppointmentRecord? = nil) {
            self.id = id
            self.customerID = customerID
            self.appointmentID = appointmentID
            self.typeRawValue = typeRawValue
            self.title = title
            self.detail = detail
            self.createdAt = createdAt
            self.customer = customer
            self.appointment = appointment
        }
    }

    @Model
    final class FollowUpRecord {
        @Attribute(.unique) var id: UUID
        var customerID: UUID
        var appointmentID: UUID?
        var dueAt: Date
        var reason: String
        var note: String
        var priorityRawValue: String
        var statusRawValue: String
        var completedAt: Date?
        var createdAt: Date
        var updatedAt: Date
        var customer: CustomerRecord?
        var appointment: AppointmentRecord?

        init(id: UUID = UUID(), customerID: UUID, appointmentID: UUID? = nil, dueAt: Date, reason: String, note: String = "", priorityRawValue: String = FollowUpPriority.normal.rawValue, statusRawValue: String = FollowUpStatus.pending.rawValue, completedAt: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), customer: CustomerRecord? = nil, appointment: AppointmentRecord? = nil) {
            self.id = id
            self.customerID = customerID
            self.appointmentID = appointmentID
            self.dueAt = dueAt
            self.reason = reason
            self.note = note
            self.priorityRawValue = priorityRawValue
            self.statusRawValue = statusRawValue
            self.completedAt = completedAt
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.customer = customer
            self.appointment = appointment
        }
    }

    @Model
    final class LeadSourceRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var iconName: String?
        var isActive: Bool
        var createdAt: Date
        @Relationship(deleteRule: .nullify, inverse: \CustomerRecord.source)
        var customers: [CustomerRecord]

        init(id: UUID = UUID(), name: String, iconName: String? = nil, isActive: Bool = true, createdAt: Date = Date(), customers: [CustomerRecord] = []) {
            self.id = id
            self.name = name
            self.iconName = iconName
            self.isActive = isActive
            self.createdAt = createdAt
            self.customers = customers
        }
    }

    @Model
    final class TagRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        var customers: [CustomerRecord]

        init(id: UUID = UUID(), name: String, createdAt: Date = Date(), customers: [CustomerRecord] = []) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.customers = customers
        }
    }

    @Model
    final class ReminderRecord {
        @Attribute(.unique) var id: UUID
        var appointmentID: UUID
        var typeRawValue: String
        var fireAt: Date
        var systemNotificationID: String?
        var statusRawValue: String
        var createdAt: Date
        var updatedAt: Date
        var appointment: AppointmentRecord?

        init(id: UUID = UUID(), appointmentID: UUID, typeRawValue: String, fireAt: Date, systemNotificationID: String? = nil, statusRawValue: String = ReminderStatus.scheduled.rawValue, createdAt: Date = Date(), updatedAt: Date = Date(), appointment: AppointmentRecord? = nil) {
            self.id = id
            self.appointmentID = appointmentID
            self.typeRawValue = typeRawValue
            self.fireAt = fireAt
            self.systemNotificationID = systemNotificationID
            self.statusRawValue = statusRawValue
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.appointment = appointment
        }
    }
}
