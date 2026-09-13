import Foundation

enum CustomerStatus: String, CaseIterable, Codable, Sendable {
    case new
    case needContact
    case contacted
    case needConfirm
    case booked
    case active
    case followUp
    case dormant
    case invalid
    case archived
}

enum AppointmentStatus: String, CaseIterable, Codable, Sendable {
    case draft
    case pendingConfirmation
    case confirmed
    case upcoming
    case arrived
    case completed
    case rescheduled
    case noShow
    case cancelled
}

enum FollowUpStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case completed
    case snoozed
    case cancelled
}

enum FollowUpPriority: String, CaseIterable, Codable, Sendable {
    case low
    case normal
    case high
}

enum AppointmentChangeType: String, CaseIterable, Codable, Sendable {
    case rescheduled
    case partySizeChanged
    case statusChanged
    case noteChanged
    case requestChanged
}

enum ReminderType: String, CaseIterable, Codable, Sendable {
    case oneDayBefore
    case twoHoursBefore
    case thirtyMinutesBefore
    case custom
}

enum ReminderStatus: String, CaseIterable, Codable, Sendable {
    case scheduled
    case delivered
    case cancelled
    case failed
}

enum ActivityType: String, CaseIterable, Codable, Sendable {
    case customerCreated
    case customerImported
    case contacted
    case appointmentCreated
    case appointmentConfirmed
    case appointmentRescheduled
    case appointmentArrived
    case appointmentCompleted
    case appointmentNoShow
    case appointmentCancelled
    case followUpCreated
    case followUpCompleted
    case noteAdded
    case customerMerged
}
