import Foundation

@MainActor
protocol ReminderRepository {
    @discardableResult
    func upsert(_ reminder: Reminder) throws -> Reminder
    func fetch(id: UUID) throws -> Reminder?
    func fetchAll(appointmentID: UUID?) throws -> [Reminder]
    @discardableResult
    func updateStatus(id: UUID, status: ReminderStatus, at: Date) throws -> Reminder
    @discardableResult
    func cancelAll(appointmentID: UUID, at: Date) throws -> [Reminder]
}

extension ReminderRepository {
    func fetchAll() throws -> [Reminder] {
        try fetchAll(appointmentID: nil)
    }
}
