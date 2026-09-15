import Foundation

struct ReminderPreferences: Equatable, Sendable {
    var oneDayBeforeEnabled: Bool
    var twoHoursBeforeEnabled: Bool
    var thirtyMinutesBeforeEnabled: Bool
    var soundEnabled: Bool

    init(
        oneDayBeforeEnabled: Bool = true,
        twoHoursBeforeEnabled: Bool = true,
        thirtyMinutesBeforeEnabled: Bool = true,
        soundEnabled: Bool = true
    ) {
        self.oneDayBeforeEnabled = oneDayBeforeEnabled
        self.twoHoursBeforeEnabled = twoHoursBeforeEnabled
        self.thirtyMinutesBeforeEnabled = thirtyMinutesBeforeEnabled
        self.soundEnabled = soundEnabled
    }

    var enabledTypes: [ReminderType] {
        var types: [ReminderType] = []
        if oneDayBeforeEnabled { types.append(.oneDayBefore) }
        if twoHoursBeforeEnabled { types.append(.twoHoursBefore) }
        if thirtyMinutesBeforeEnabled { types.append(.thirtyMinutesBefore) }
        return types
    }
}

struct ReminderSchedule: Equatable, Sendable {
    let type: ReminderType
    let fireAt: Date
}

enum ReminderCalculator {
    static func schedules(
        for appointmentStart: Date,
        preferences: ReminderPreferences,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> [ReminderSchedule] {
        preferences.enabledTypes.compactMap { type in
            guard let fireAt = fireDate(
                for: type,
                appointmentStart: appointmentStart,
                calendar: calendar
            ), fireAt > now else {
                return nil
            }
            return ReminderSchedule(type: type, fireAt: fireAt)
        }
    }

    static func fireDate(
        for type: ReminderType,
        appointmentStart: Date,
        calendar: Calendar = .current
    ) -> Date? {
        switch type {
        case .oneDayBefore:
            return calendar.date(byAdding: .day, value: -1, to: appointmentStart)
        case .twoHoursBefore:
            return calendar.date(byAdding: .hour, value: -2, to: appointmentStart)
        case .thirtyMinutesBefore:
            return calendar.date(byAdding: .minute, value: -30, to: appointmentStart)
        case .custom:
            return nil
        }
    }
}

enum ReminderNotificationIdentity {
    static let prefix = "com.gravityedge.goosegrass.reminder."

    static func identifier(for reminderID: UUID) -> String {
        prefix + reminderID.uuidString.lowercased()
    }
}
