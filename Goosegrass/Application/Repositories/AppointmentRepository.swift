import Foundation

@MainActor
protocol AppointmentRepository {
    func create(_ appointment: Appointment) throws
    func update(_ appointment: Appointment) throws
    func fetch(id: UUID) throws -> Appointment?
    func fetchAll(customerID: UUID?) throws -> [Appointment]
    func deleteDraft(id: UUID) throws
    func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem]
    func fetchDetail(id: UUID) throws -> AppointmentDetail?
    func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange]
    func commit(_ mutation: AppointmentMutation) throws
}

extension AppointmentRepository {
    func fetchAll() throws -> [Appointment] {
        try fetchAll(customerID: nil)
    }

    func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem] {
        guard filter.tagID == nil else { return [] }
        return try fetchAll(customerID: filter.customerID)
            .filter { appointment in
                let matchesDate = filter.dateInterval?.contains(appointment.startAt) ?? true
                let matchesStatus = filter.statuses.isEmpty || filter.statuses.contains(appointment.status)
                let matchesSource = filter.sourceID == nil || appointment.sourceID == filter.sourceID
                return matchesDate && matchesStatus && matchesSource
            }
            .map {
                AppointmentListItem(
                    appointment: $0,
                    customerName: "",
                    customerPhone: "",
                    sourceName: nil,
                    tagNames: [],
                    reminderStatuses: []
                )
            }
    }

    func fetchDetail(id: UUID) throws -> AppointmentDetail? {
        guard let appointment = try fetch(id: id) else { return nil }
        return AppointmentDetail(
            listItem: AppointmentListItem(
                appointment: appointment,
                customerName: "",
                customerPhone: "",
                sourceName: nil,
                tagNames: [],
                reminderStatuses: []
            ),
            changes: try fetchChanges(appointmentID: id),
            activities: []
        )
    }

    func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange] {
        []
    }

    func commit(_ mutation: AppointmentMutation) throws {
        if mutation.isNew {
            try create(mutation.appointment)
        } else {
            try update(mutation.appointment)
        }
    }
}
