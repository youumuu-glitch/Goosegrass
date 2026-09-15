enum AppointmentAction: String, CaseIterable, Equatable, Sendable {
    case submit
    case confirm
    case markUpcoming
    case arrive
    case complete
    case reschedule
    case markNoShow
    case cancel
}

enum AppointmentLifecycleError: Error, Equatable, Sendable {
    case invalidTransition(from: AppointmentStatus, action: AppointmentAction)
}

enum AppointmentLifecycle {
    static func destination(
        from status: AppointmentStatus,
        action: AppointmentAction
    ) throws -> AppointmentStatus {
        switch (status, action) {
        case (.draft, .submit):
            return .pendingConfirmation
        case (.draft, .cancel):
            return .cancelled
        case (.pendingConfirmation, .confirm), (.rescheduled, .confirm):
            return .confirmed
        case (.pendingConfirmation, .reschedule),
             (.confirmed, .reschedule),
             (.upcoming, .reschedule):
            return .rescheduled
        case (.pendingConfirmation, .cancel),
             (.confirmed, .cancel),
             (.upcoming, .cancel),
             (.rescheduled, .cancel):
            return .cancelled
        case (.confirmed, .markUpcoming):
            return .upcoming
        case (.upcoming, .arrive):
            return .arrived
        case (.upcoming, .markNoShow):
            return .noShow
        case (.arrived, .complete):
            return .completed
        default:
            throw AppointmentLifecycleError.invalidTransition(from: status, action: action)
        }
    }

    static func allowedActions(from status: AppointmentStatus) -> [AppointmentAction] {
        AppointmentAction.allCases.filter { action in
            (try? destination(from: status, action: action)) != nil
        }
    }
}
