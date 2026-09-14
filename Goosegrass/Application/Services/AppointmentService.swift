import Foundation

@MainActor
final class AppointmentService {
    private let repository: any AppointmentRepository

    init(repository: any AppointmentRepository) {
        self.repository = repository
    }

    func create(_ appointment: Appointment) throws {
        try repository.create(appointment)
    }

    func update(_ appointment: Appointment) throws {
        try repository.update(appointment)
    }

    func fetch(id: UUID) throws -> Appointment? {
        try repository.fetch(id: id)
    }

    func fetchAll(customerID: UUID? = nil) throws -> [Appointment] {
        try repository.fetchAll(customerID: customerID)
    }

    func deleteDraft(id: UUID) throws {
        try repository.deleteDraft(id: id)
    }
}
