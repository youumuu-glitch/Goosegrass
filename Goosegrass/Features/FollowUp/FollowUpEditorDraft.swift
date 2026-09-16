import Foundation

enum FollowUpEditorError: Error, Equatable, LocalizedError {
    case customerRequired

    var errorDescription: String? {
        "Choose a customer for this follow-up."
    }
}

struct FollowUpEditorDraft: Equatable, Sendable {
    var customerID: UUID?
    var appointmentID: UUID?
    var dueAt: Date
    var reason: String
    var note: String
    var priority: FollowUpPriority

    init(
        customerID: UUID? = nil,
        appointmentID: UUID? = nil,
        dueAt: Date = Date(),
        reason: String = "",
        note: String = "",
        priority: FollowUpPriority = .normal
    ) {
        self.customerID = customerID
        self.appointmentID = appointmentID
        self.dueAt = dueAt
        self.reason = reason
        self.note = note
        self.priority = priority
    }
}
