import Foundation
import SwiftData

@MainActor
final class LocalAppointmentRepository: AppointmentRepository {
    private let context: ModelContext

    var container: ModelContainer { context.container }

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ appointment: Appointment) throws {
        guard try record(id: appointment.id) == nil else {
            throw PersistenceError.duplicateIdentifier(appointment.id)
        }
        guard let customer = try customerRecord(id: appointment.customerID) else {
            throw PersistenceError.customerNotFound(appointment.customerID)
        }
        context.insert(PersistenceMapper.makeAppointmentRecord(from: appointment, customer: customer))
        try context.save()
    }

    func update(_ appointment: Appointment) throws {
        guard let record = try record(id: appointment.id) else {
            throw PersistenceError.recordNotFound(appointment.id)
        }
        guard let customer = try customerRecord(id: appointment.customerID) else {
            throw PersistenceError.customerNotFound(appointment.customerID)
        }
        PersistenceMapper.update(record, from: appointment, customer: customer)
        try context.save()
    }

    func fetch(id: UUID) throws -> Appointment? {
        try record(id: id).map(PersistenceMapper.makeAppointment)
    }

    func fetchAll(customerID: UUID?) throws -> [Appointment] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>())
            .filter { customerID == nil || $0.customerID == customerID }
            .sorted { $0.startAt < $1.startAt }
            .map(PersistenceMapper.makeAppointment)
    }

    func deleteDraft(id: UUID) throws {
        guard let record = try record(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        guard record.statusRawValue == AppointmentStatus.draft.rawValue else {
            throw PersistenceError.invalidStoredValue(field: "Appointment.deleteDraft.status", value: record.statusRawValue)
        }
        context.delete(record)
        try context.save()
    }

    func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem] {
        let records = try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>())
        return try records.compactMap { record in
            guard let customer = record.customer, !customer.isArchived else { return nil }
            guard filter.customerID == nil || record.customerID == filter.customerID else { return nil }
            guard filter.dateInterval?.contains(record.startAt) ?? true else { return nil }
            if !filter.statuses.isEmpty {
                guard filter.statuses.contains(try appointmentStatus(record)) else { return nil }
            }
            guard filter.sourceID == nil || record.sourceID == filter.sourceID else { return nil }
            guard filter.tagID == nil || customer.tags.contains(where: { $0.id == filter.tagID }) else { return nil }
            return try makeListItem(from: record, customer: customer)
        }
        .sorted { $0.appointment.startAt < $1.appointment.startAt }
    }

    func fetchDetail(id: UUID) throws -> AppointmentDetail? {
        guard let record = try record(id: id),
              let customer = record.customer,
              !customer.isArchived else {
            return nil
        }
        return AppointmentDetail(
            listItem: try makeListItem(from: record, customer: customer),
            changes: try fetchChanges(appointmentID: id),
            activities: try record.activities
                .map(PersistenceMapper.makeActivity)
                .sorted { $0.createdAt > $1.createdAt }
        )
    }

    func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV2.AppointmentChangeRecord>())
            .filter { $0.appointmentID == appointmentID }
            .map(PersistenceMapper.makeAppointmentChange)
            .sorted { $0.changedAt > $1.changedAt }
    }

    func commit(_ mutation: AppointmentMutation) throws {
        let appointment = mutation.appointment
        guard let customer = try customerRecord(id: appointment.customerID), !customer.isArchived else {
            throw PersistenceError.customerNotFound(appointment.customerID)
        }
        if let sourceID = appointment.sourceID {
            let sources = try context.fetch(FetchDescriptor<PersistenceSchemaV1.LeadSourceRecord>())
            guard sources.contains(where: { $0.id == sourceID }) else {
                throw PersistenceError.recordNotFound(sourceID)
            }
        }
        guard mutation.changes.allSatisfy({ $0.appointmentID == appointment.id }) else {
            throw PersistenceError.recordNotFound(appointment.id)
        }
        guard mutation.activities.allSatisfy({
            $0.customerID == appointment.customerID && $0.appointmentID == appointment.id
        }) else {
            throw PersistenceError.recordNotFound(appointment.id)
        }

        let existingAppointment = try record(id: appointment.id)
        if mutation.isNew {
            guard existingAppointment == nil else {
                throw PersistenceError.duplicateIdentifier(appointment.id)
            }
        } else if existingAppointment == nil {
            throw PersistenceError.recordNotFound(appointment.id)
        }

        let existingChangeIDs = Set(
            try context.fetch(FetchDescriptor<PersistenceSchemaV2.AppointmentChangeRecord>()).map(\.id)
        )
        if let duplicate = mutation.changes.first(where: { existingChangeIDs.contains($0.id) }) {
            throw PersistenceError.duplicateIdentifier(duplicate.id)
        }
        let existingActivityIDs = Set(
            try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActivityRecord>()).map(\.id)
        )
        if let duplicate = mutation.activities.first(where: { existingActivityIDs.contains($0.id) }) {
            throw PersistenceError.duplicateIdentifier(duplicate.id)
        }

        let appointmentRecord: PersistenceSchemaV1.AppointmentRecord
        if let existingAppointment {
            PersistenceMapper.update(existingAppointment, from: appointment, customer: customer)
            appointmentRecord = existingAppointment
        } else {
            let newRecord = PersistenceMapper.makeAppointmentRecord(from: appointment, customer: customer)
            context.insert(newRecord)
            appointmentRecord = newRecord
        }
        mutation.changes.forEach {
            context.insert(PersistenceMapper.makeAppointmentChangeRecord(from: $0))
        }
        mutation.activities.forEach {
            context.insert(PersistenceMapper.makeActivityRecord(
                from: $0,
                customer: customer,
                appointment: appointmentRecord
            ))
        }
        try context.save()
    }

    private func record(id: UUID) throws -> PersistenceSchemaV1.AppointmentRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>()).first { $0.id == id }
    }

    private func customerRecord(id: UUID) throws -> PersistenceSchemaV1.CustomerRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>()).first { $0.id == id }
    }

    private func appointmentStatus(
        _ record: PersistenceSchemaV1.AppointmentRecord
    ) throws -> AppointmentStatus {
        guard let status = AppointmentStatus(rawValue: record.statusRawValue) else {
            throw PersistenceError.invalidStoredValue(
                field: "Appointment.status",
                value: record.statusRawValue
            )
        }
        return status
    }

    private func makeListItem(
        from record: PersistenceSchemaV1.AppointmentRecord,
        customer: PersistenceSchemaV1.CustomerRecord
    ) throws -> AppointmentListItem {
        let sourceName: String?
        if let sourceID = record.sourceID {
            sourceName = try context.fetch(FetchDescriptor<PersistenceSchemaV1.LeadSourceRecord>())
                .first { $0.id == sourceID }?.name
        } else {
            sourceName = nil
        }
        let reminderStatuses = try record.reminders
            .sorted { $0.fireAt < $1.fireAt }
            .map { reminder in
                guard let status = ReminderStatus(rawValue: reminder.statusRawValue) else {
                    throw PersistenceError.invalidStoredValue(
                        field: "Reminder.status",
                        value: reminder.statusRawValue
                    )
                }
                return status
            }
        return AppointmentListItem(
            appointment: try PersistenceMapper.makeAppointment(from: record),
            customerName: customer.displayName,
            customerPhone: customer.phone,
            sourceName: sourceName,
            tagNames: customer.tags.map(\.name)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            reminderStatuses: reminderStatuses
        )
    }
}
