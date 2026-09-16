import Foundation

@MainActor
final class FollowUpService {
    private let repository: any FollowUpRepository
    private let calendar: Calendar
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        repository: any FollowUpRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        self.makeID = makeID
    }

    func list(filter: FollowUpListFilter = FollowUpListFilter()) throws -> [FollowUpListItem] {
        try repository.fetchList(filter: filter)
    }

    func detail(id: UUID) throws -> FollowUpDetail? {
        try repository.fetchDetail(id: id)
    }

    func create(
        customerID: UUID,
        appointmentID: UUID? = nil,
        dueAt: Date,
        reason: String,
        note: String = "",
        priority: FollowUpPriority = .normal,
        at operationTime: Date? = nil
    ) throws -> FollowUp {
        let timestamp = operationTime ?? now()
        let validReason = try FollowUpLifecycle.validatedReason(reason)
        try FollowUpLifecycle.validateDueAt(dueAt, after: timestamp)
        let followUp = FollowUp(
            id: makeID(),
            customerID: customerID,
            appointmentID: appointmentID,
            dueAt: dueAt,
            reason: validReason,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            status: .pending,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let activity = Activity(
            id: makeID(),
            customerID: customerID,
            appointmentID: appointmentID,
            type: .followUpCreated,
            title: "Follow-up created",
            detail: validReason,
            createdAt: timestamp
        )
        try repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [activity],
            isNew: true
        ))
        return try authoritativeFollowUp(id: followUp.id)
    }

    func createNoShowFollowUp(
        customerID: UUID,
        appointmentID: UUID,
        at operationTime: Date? = nil
    ) throws -> FollowUp {
        let timestamp = operationTime ?? now()
        return try create(
            customerID: customerID,
            appointmentID: appointmentID,
            dueAt: FollowUpSchedule.tomorrowAtEleven(from: timestamp, calendar: calendar),
            reason: "No-show follow-up",
            priority: .normal,
            at: timestamp
        )
    }

    func complete(id: UUID, at operationTime: Date? = nil) throws -> FollowUp {
        let timestamp = operationTime ?? now()
        var followUp = try requiredFollowUp(id: id)
        followUp.status = try FollowUpLifecycle.destination(from: followUp.status, action: .complete)
        followUp.completedAt = timestamp
        followUp.updatedAt = timestamp
        let activity = Activity(
            id: makeID(),
            customerID: followUp.customerID,
            appointmentID: followUp.appointmentID,
            type: .followUpCompleted,
            title: "Follow-up completed",
            detail: followUp.reason,
            createdAt: timestamp
        )
        try repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [activity],
            isNew: false
        ))
        return try authoritativeFollowUp(id: id)
    }

    func snooze(
        id: UUID,
        until dueAt: Date,
        at operationTime: Date? = nil
    ) throws -> FollowUp {
        let timestamp = operationTime ?? now()
        var followUp = try requiredFollowUp(id: id)
        let destination = try FollowUpLifecycle.destination(from: followUp.status, action: .snooze)
        try FollowUpLifecycle.validateDueAt(dueAt, after: timestamp)
        followUp.status = destination
        followUp.dueAt = dueAt
        followUp.completedAt = nil
        followUp.updatedAt = timestamp
        try repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [],
            isNew: false
        ))
        return try authoritativeFollowUp(id: id)
    }

    func cancel(id: UUID, at operationTime: Date? = nil) throws -> FollowUp {
        let timestamp = operationTime ?? now()
        var followUp = try requiredFollowUp(id: id)
        followUp.status = try FollowUpLifecycle.destination(from: followUp.status, action: .cancel)
        followUp.completedAt = nil
        followUp.updatedAt = timestamp
        try repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [],
            isNew: false
        ))
        return try authoritativeFollowUp(id: id)
    }

    private func requiredFollowUp(id: UUID) throws -> FollowUp {
        guard let followUp = try repository.fetch(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        return followUp
    }

    private func authoritativeFollowUp(id: UUID) throws -> FollowUp {
        try requiredFollowUp(id: id)
    }
}
