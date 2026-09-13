import Foundation

@MainActor
protocol AppointmentRepository {
    func create(_ appointment: Appointment) throws
    func update(_ appointment: Appointment) throws
    func fetch(id: UUID) throws -> Appointment?
    func fetchAll(customerID: UUID?) throws -> [Appointment]
    func deleteDraft(id: UUID) throws
}

extension AppointmentRepository {
    func fetchAll() throws -> [Appointment] {
        try fetchAll(customerID: nil)
    }
}
