import Foundation

enum FollowUpSchedule {
    static func tomorrowAtEleven(from date: Date, calendar: Calendar) throws -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
              let result = calendar.date(
                bySettingHour: 11,
                minute: 0,
                second: 0,
                of: tomorrow
              ) else {
            throw FollowUpValidationError.invalidSchedule
        }
        return result
    }
}
