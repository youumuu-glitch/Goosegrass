import Foundation

struct AppointmentFilter: Equatable, Sendable {
    var dateInterval: DateInterval?
    var statuses: Set<AppointmentStatus>
    var customerID: UUID?
    var sourceID: UUID?
    var tagID: UUID?

    init(
        dateInterval: DateInterval? = nil,
        statuses: Set<AppointmentStatus> = [],
        customerID: UUID? = nil,
        sourceID: UUID? = nil,
        tagID: UUID? = nil
    ) {
        self.dateInterval = dateInterval
        self.statuses = statuses
        self.customerID = customerID
        self.sourceID = sourceID
        self.tagID = tagID
    }
}

struct AppointmentListItem: Identifiable, Equatable, Sendable {
    var id: UUID { appointment.id }

    let appointment: Appointment
    let customerName: String
    let customerPhone: String
    let sourceName: String?
    let tagNames: [String]
    let reminderStatuses: [ReminderStatus]
}

struct AppointmentDetail: Equatable, Sendable {
    let listItem: AppointmentListItem
    let changes: [AppointmentChange]
    let activities: [Activity]
}

struct AppointmentMutation: Equatable, Sendable {
    let appointment: Appointment
    let changes: [AppointmentChange]
    let activities: [Activity]
    let isNew: Bool
}
