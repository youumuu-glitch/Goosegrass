import Foundation

@MainActor
protocol AppointmentReminderScheduling: AnyObject {
    func synchronizeAfterAppointmentMutation(_ appointment: Appointment)
}

@MainActor
final class ReminderService: AppointmentReminderScheduling {
    private let repository: any ReminderRepository
    private let appointmentRepository: any AppointmentRepository
    private let notificationCenter: any LocalNotificationCenter
    private let preferences: () -> ReminderPreferences
    private let calendar: Calendar
    private let now: () -> Date
    private let makeID: () -> UUID

    init(
        repository: any ReminderRepository,
        appointmentRepository: any AppointmentRepository,
        notificationCenter: any LocalNotificationCenter,
        preferences: @escaping () -> ReminderPreferences,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        makeID: @escaping () -> UUID = UUID.init
    ) {
        self.repository = repository
        self.appointmentRepository = appointmentRepository
        self.notificationCenter = notificationCenter
        self.preferences = preferences
        self.calendar = calendar
        self.now = now
        self.makeID = makeID
    }

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus {
        await notificationCenter.authorizationStatus()
    }

    func synchronizeAfterAppointmentMutation(_ appointment: Appointment) {
        Task { [weak self] in
            guard let self else { return }
            if appointment.status == .rescheduled {
                _ = await reschedule(appointment)
            } else {
                _ = await rebuildForAppointment(appointment)
            }
        }
    }

    func requestPermission() async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization()
        if granted { await reconcilePendingNotifications() }
        return granted
    }

    func schedule(_ appointment: Appointment) async -> [Reminder] {
        await rebuildForAppointment(appointment)
    }

    func reschedule(_ appointment: Appointment) async -> [Reminder] {
        _ = await cancel(appointmentID: appointment.id)
        return await rebuildForAppointment(appointment)
    }

    func cancel(appointmentID: UUID) async -> [Reminder] {
        do {
            let existing = try repository.fetchAll(appointmentID: appointmentID)
            notificationCenter.removePendingRequests(
                withIdentifiers: existing.compactMap(\.systemNotificationID)
            )
            return try repository.cancelAll(appointmentID: appointmentID, at: now())
        } catch {
            return []
        }
    }

    func rebuildForAppointment(_ appointment: Appointment) async -> [Reminder] {
        guard Self.eligibleStatuses.contains(appointment.status), appointment.startAt > now() else {
            return await cancel(appointmentID: appointment.id)
        }
        do {
            let generatedAt = now()
            let schedules = ReminderCalculator.schedules(
                for: appointment.startAt,
                preferences: preferences(),
                calendar: calendar,
                now: generatedAt
            )
            let existing = try repository.fetchAll(appointmentID: appointment.id)
            let desiredTypes = Set(schedules.map(\.type))
            let obsolete = existing.filter { !desiredTypes.contains($0.type) }
            notificationCenter.removePendingRequests(
                withIdentifiers: obsolete.compactMap(\.systemNotificationID)
            )
            for reminder in obsolete {
                _ = try repository.updateStatus(id: reminder.id, status: .cancelled, at: generatedAt)
            }

            let authorization = await notificationCenter.authorizationStatus()
            var results: [Reminder] = []
            for schedule in schedules {
                let prior = existing.first { $0.type == schedule.type }
                let reminderID = prior?.id ?? makeID()
                var reminder = Reminder(
                    id: reminderID,
                    appointmentID: appointment.id,
                    type: schedule.type,
                    fireAt: schedule.fireAt,
                    systemNotificationID: ReminderNotificationIdentity.identifier(for: reminderID),
                    status: .scheduled,
                    createdAt: prior?.createdAt ?? generatedAt,
                    updatedAt: generatedAt
                )
                reminder = try repository.upsert(reminder)
                guard Self.canSchedule(authorization) else {
                    results.append(try repository.updateStatus(
                        id: reminder.id,
                        status: .failed,
                        at: generatedAt
                    ))
                    continue
                }
                do {
                    try await notificationCenter.add(request(for: reminder, appointment: appointment))
                    results.append(reminder)
                } catch {
                    results.append(try repository.updateStatus(
                        id: reminder.id,
                        status: .failed,
                        at: generatedAt
                    ))
                }
            }
            return results.sorted(by: Self.sort)
        } catch {
            return []
        }
    }

    func reconcilePendingNotifications() async {
        let current = now()
        let appointments = (try? appointmentRepository.fetchAll()) ?? []
        for appointment in appointments {
            if Self.eligibleStatuses.contains(appointment.status), appointment.startAt > current {
                _ = await rebuildForAppointment(appointment)
            } else {
                _ = await cancel(appointmentID: appointment.id)
            }
        }

        let reminders = (try? repository.fetchAll()) ?? []
        let desired = Set(reminders.compactMap { reminder in
            reminder.status == .scheduled && reminder.fireAt > current
                ? reminder.systemNotificationID
                : nil
        })
        let pending = await notificationCenter.pendingRequests()
        let ghosts = pending.map(\.identifier).filter {
            $0.hasPrefix(ReminderNotificationIdentity.prefix) && !desired.contains($0)
        }
        notificationCenter.removePendingRequests(withIdentifiers: ghosts)
    }

    private func request(
        for reminder: Reminder,
        appointment: Appointment
    ) -> LocalNotificationRequest {
        let time = DateFormatter.localizedString(
            from: appointment.startAt,
            dateStyle: .none,
            timeStyle: .short
        )
        return LocalNotificationRequest(
            identifier: reminder.systemNotificationID ?? ReminderNotificationIdentity.identifier(for: reminder.id),
            title: "Upcoming appointment",
            body: "Appointment at \(time) for party of \(appointment.partySize).",
            fireAt: reminder.fireAt,
            soundEnabled: preferences().soundEnabled,
            userInfo: ["appointmentID": appointment.id.uuidString]
        )
    }

    private static let eligibleStatuses: Set<AppointmentStatus> = [.confirmed, .upcoming, .rescheduled]

    private static func canSchedule(_ status: LocalNotificationAuthorizationStatus) -> Bool {
        [.authorized, .provisional, .ephemeral].contains(status)
    }

    private static func sort(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        if lhs.fireAt != rhs.fireAt { return lhs.fireAt < rhs.fireAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
