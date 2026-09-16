import Foundation

@MainActor
final class AppointmentService {
    private let repository: any AppointmentRepository
    private let customerRepository: any CustomerRepository
    private let reminderScheduler: (any AppointmentReminderScheduling)?

    init(
        repository: any AppointmentRepository,
        customerRepository: any CustomerRepository,
        reminderScheduler: (any AppointmentReminderScheduling)? = nil
    ) {
        self.repository = repository
        self.customerRepository = customerRepository
        self.reminderScheduler = reminderScheduler
    }

    func create(_ appointment: Appointment) throws {
        try repository.create(appointment)
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
    }

    func update(_ appointment: Appointment) throws {
        try repository.update(appointment)
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
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

    func create(draft: AppointmentEditorDraft, at now: Date = Date()) throws -> Appointment {
        let appointment = try draft.makeAppointment(now: now)
        try requireCustomer(appointment.customerID)
        try repository.commit(AppointmentMutation(
            appointment: appointment,
            changes: [],
            activities: [activity(for: .submit, appointment: appointment, at: now)],
            isNew: true
        ))
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
        return appointment
    }

    func edit(
        id: UUID,
        draft: AppointmentEditorDraft,
        at now: Date = Date()
    ) throws -> Appointment {
        guard let existing = try repository.fetch(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        let appointment = try draft.makeAppointment(existing: existing, now: now)
        try requireCustomer(appointment.customerID)
        let changes = editChanges(from: existing, to: appointment, at: now)
        try repository.commit(AppointmentMutation(
            appointment: appointment,
            changes: changes,
            activities: [],
            isNew: false
        ))
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
        return appointment
    }

    func transition(
        id: UUID,
        action: AppointmentAction,
        at now: Date = Date()
    ) throws -> Appointment {
        guard var appointment = try repository.fetch(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        let oldStatus = appointment.status
        let destination = try AppointmentLifecycle.destination(from: oldStatus, action: action)
        try requireCustomer(appointment.customerID)
        appointment.status = destination
        appointment.updatedAt = now
        applyTimestamp(for: action, to: &appointment, at: now)
        let change = AppointmentChange(
            appointmentID: id,
            changeType: .statusChanged,
            oldValueJSON: Self.jsonString(oldStatus.rawValue),
            newValueJSON: Self.jsonString(destination.rawValue),
            changedAt: now
        )
        try repository.commit(AppointmentMutation(
            appointment: appointment,
            changes: [change],
            activities: [activity(for: action, appointment: appointment, at: now)],
            isNew: false
        ))
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
        return appointment
    }

    func reschedule(
        id: UUID,
        startAt: Date,
        endAt: Date?,
        reason: String,
        at now: Date = Date()
    ) throws -> Appointment {
        guard var appointment = try repository.fetch(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        _ = try AppointmentLifecycle.destination(from: appointment.status, action: .reschedule)
        try requireCustomer(appointment.customerID)
        let oldSchedule = ScheduleSnapshot(startAt: appointment.startAt, endAt: appointment.endAt)
        appointment.startAt = startAt
        appointment.endAt = endAt
        appointment.status = .rescheduled
        appointment.updatedAt = now
        let change = AppointmentChange(
            appointmentID: id,
            changeType: .rescheduled,
            oldValueJSON: Self.jsonString(oldSchedule),
            newValueJSON: Self.jsonString(ScheduleSnapshot(startAt: startAt, endAt: endAt)),
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            changedAt: now
        )
        try repository.commit(AppointmentMutation(
            appointment: appointment,
            changes: [change],
            activities: [activity(for: .reschedule, appointment: appointment, at: now)],
            isNew: false
        ))
        reminderScheduler?.synchronizeAfterAppointmentMutation(appointment)
        return appointment
    }

    func list(filter: AppointmentFilter = AppointmentFilter()) throws -> [AppointmentListItem] {
        try repository.fetchList(filter: filter)
    }

    func detail(id: UUID) throws -> AppointmentDetail? {
        try repository.fetchDetail(id: id)
    }

    private func requireCustomer(_ id: UUID) throws {
        guard try customerRepository.fetch(id: id) != nil else {
            throw PersistenceError.customerNotFound(id)
        }
    }

    private func editChanges(
        from old: Appointment,
        to new: Appointment,
        at now: Date
    ) -> [AppointmentChange] {
        var changes: [AppointmentChange] = []
        if old.startAt != new.startAt || old.endAt != new.endAt {
            changes.append(AppointmentChange(
                appointmentID: old.id,
                changeType: .rescheduled,
                oldValueJSON: Self.jsonString(ScheduleSnapshot(startAt: old.startAt, endAt: old.endAt)),
                newValueJSON: Self.jsonString(ScheduleSnapshot(startAt: new.startAt, endAt: new.endAt)),
                changedAt: now
            ))
        }
        appendChange(&changes, type: .partySizeChanged, old: old.partySize, new: new.partySize, appointmentID: old.id, at: now)
        appendChange(&changes, type: .requestChanged, old: old.customerRequest, new: new.customerRequest, appointmentID: old.id, at: now)
        appendChange(&changes, type: .noteChanged, old: old.internalNote, new: new.internalNote, appointmentID: old.id, at: now)
        return changes
    }

    private func appendChange<Value: Encodable & Equatable>(
        _ changes: inout [AppointmentChange],
        type: AppointmentChangeType,
        old: Value,
        new: Value,
        appointmentID: UUID,
        at now: Date
    ) {
        guard old != new else { return }
        changes.append(AppointmentChange(
            appointmentID: appointmentID,
            changeType: type,
            oldValueJSON: Self.jsonString(old),
            newValueJSON: Self.jsonString(new),
            changedAt: now
        ))
    }

    private func applyTimestamp(for action: AppointmentAction, to appointment: inout Appointment, at now: Date) {
        switch action {
        case .confirm: appointment.confirmedAt = now
        case .arrive: appointment.arrivedAt = now
        case .complete: appointment.completedAt = now
        case .cancel: appointment.cancelledAt = now
        case .markNoShow: appointment.noShowAt = now
        case .submit, .markUpcoming, .reschedule: break
        }
    }

    private func activity(for action: AppointmentAction, appointment: Appointment, at now: Date) -> Activity {
        let type: ActivityType
        let title: String
        switch action {
        case .submit: (type, title) = (.appointmentCreated, "Appointment submitted")
        case .confirm: (type, title) = (.appointmentConfirmed, "Appointment confirmed")
        case .markUpcoming: (type, title) = (.appointmentConfirmed, "Appointment upcoming")
        case .arrive: (type, title) = (.appointmentArrived, "Appointment arrived")
        case .complete: (type, title) = (.appointmentCompleted, "Appointment completed")
        case .cancel: (type, title) = (.appointmentCancelled, "Appointment cancelled")
        case .reschedule: (type, title) = (.appointmentRescheduled, "Appointment rescheduled")
        case .markNoShow: (type, title) = (.appointmentNoShow, "Appointment no show")
        }
        return Activity(
            customerID: appointment.customerID,
            appointmentID: appointment.id,
            type: type,
            title: title,
            createdAt: now
        )
    }

    private static func jsonString<Value: Encodable>(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "null"
        }
        return string
    }
}

private struct ScheduleSnapshot: Codable {
    let startAt: Date
    let endAt: Date?
}
