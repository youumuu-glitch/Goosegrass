import Foundation

enum FollowUpAction: String, CaseIterable, Sendable {
    case complete
    case snooze
    case cancel
}

enum FollowUpValidationError: Error, Equatable, LocalizedError {
    case emptyReason
    case dueDateMustBeFuture
    case invalidSchedule
    case invalidTransition(from: FollowUpStatus, action: FollowUpAction)

    var errorDescription: String? {
        switch self {
        case .emptyReason:
            "Follow-up reason is required."
        case .dueDateMustBeFuture:
            "Follow-up time must be in the future."
        case .invalidSchedule:
            "The follow-up time could not be calculated."
        case let .invalidTransition(status, action):
            "Cannot \(action.rawValue) a \(status.rawValue) follow-up."
        }
    }
}

enum FollowUpLifecycle {
    static func destination(
        from status: FollowUpStatus,
        action: FollowUpAction
    ) throws -> FollowUpStatus {
        guard status == .pending || status == .snoozed else {
            throw FollowUpValidationError.invalidTransition(from: status, action: action)
        }
        switch action {
        case .complete:
            return .completed
        case .snooze:
            return .snoozed
        case .cancel:
            return .cancelled
        }
    }

    static func validatedReason(_ reason: String) throws -> String {
        let value = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw FollowUpValidationError.emptyReason
        }
        return value
    }

    static func validateDueAt(_ dueAt: Date, after operationTime: Date) throws {
        guard dueAt > operationTime else {
            throw FollowUpValidationError.dueDateMustBeFuture
        }
    }
}
