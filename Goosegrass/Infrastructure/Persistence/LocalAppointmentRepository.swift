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

    private func record(id: UUID) throws -> PersistenceSchemaV1.AppointmentRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>()).first { $0.id == id }
    }

    private func customerRecord(id: UUID) throws -> PersistenceSchemaV1.CustomerRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>()).first { $0.id == id }
    }
}
