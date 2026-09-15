import Foundation
import SwiftData

@MainActor
final class LocalReminderRepository: ReminderRepository {
    private let context: ModelContext

    var container: ModelContainer { context.container }

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func upsert(_ reminder: Reminder) throws -> Reminder {
        guard let appointment = try appointmentRecord(id: reminder.appointmentID) else {
            throw PersistenceError.recordNotFound(reminder.appointmentID)
        }
        if let existing = try matchingRecord(for: reminder) {
            PersistenceMapper.update(existing, from: reminder, appointment: appointment)
            try context.save()
            return try PersistenceMapper.makeReminder(from: existing)
        }
        guard try record(id: reminder.id) == nil else {
            throw PersistenceError.duplicateIdentifier(reminder.id)
        }
        let record = PersistenceMapper.makeReminderRecord(from: reminder, appointment: appointment)
        context.insert(record)
        try context.save()
        return try PersistenceMapper.makeReminder(from: record)
    }

    func fetch(id: UUID) throws -> Reminder? {
        try record(id: id).map(PersistenceMapper.makeReminder)
    }

    func fetchAll(appointmentID: UUID?) throws -> [Reminder] {
        try allRecords()
            .filter { appointmentID == nil || $0.appointmentID == appointmentID }
            .map(PersistenceMapper.makeReminder)
            .sorted(by: Self.sort)
    }

    @discardableResult
    func updateStatus(id: UUID, status: ReminderStatus, at: Date) throws -> Reminder {
        guard let record = try record(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        record.statusRawValue = status.rawValue
        record.updatedAt = at
        try context.save()
        return try PersistenceMapper.makeReminder(from: record)
    }

    @discardableResult
    func cancelAll(appointmentID: UUID, at: Date) throws -> [Reminder] {
        let records = try allRecords().filter { $0.appointmentID == appointmentID }
        for record in records {
            record.statusRawValue = ReminderStatus.cancelled.rawValue
            record.updatedAt = at
        }
        if !records.isEmpty { try context.save() }
        return try records.map(PersistenceMapper.makeReminder).sorted(by: Self.sort)
    }

    private func matchingRecord(for reminder: Reminder) throws -> PersistenceSchemaV1.ReminderRecord? {
        if reminder.type == .custom {
            return try record(id: reminder.id)
        }
        return try allRecords().first {
            $0.appointmentID == reminder.appointmentID
                && $0.typeRawValue == reminder.type.rawValue
        }
    }

    private func record(id: UUID) throws -> PersistenceSchemaV1.ReminderRecord? {
        try allRecords().first { $0.id == id }
    }

    private func appointmentRecord(id: UUID) throws -> PersistenceSchemaV1.AppointmentRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>())
            .first { $0.id == id }
    }

    private func allRecords() throws -> [PersistenceSchemaV1.ReminderRecord] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.ReminderRecord>())
    }

    private static func sort(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if lhs.fireAt != rhs.fireAt { return lhs.fireAt < rhs.fireAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
