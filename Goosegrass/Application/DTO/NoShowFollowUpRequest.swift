import Foundation

struct NoShowFollowUpRequest: Identifiable, Equatable, Sendable {
    var id: UUID { appointmentID }

    let appointmentID: UUID
    let customerID: UUID
    let requestedAt: Date
}

enum NoShowFollowUpError: Error, Equatable, LocalizedError {
    case serviceUnavailable
    case customerRequired

    var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "Follow-up service is unavailable."
        case .customerRequired:
            return "Choose a customer for this follow-up."
        }
    }
}
