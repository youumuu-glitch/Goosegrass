import Foundation

@MainActor
protocol ReminderPreferencesStoring: AnyObject {
    var preferences: ReminderPreferences { get set }
}

@MainActor
final class UserDefaultsReminderPreferencesStore: ReminderPreferencesStoring {
    private enum Key {
        static let oneDay = "com.gravityedge.goosegrass.reminders.oneDayBefore"
        static let twoHours = "com.gravityedge.goosegrass.reminders.twoHoursBefore"
        static let thirtyMinutes = "com.gravityedge.goosegrass.reminders.thirtyMinutesBefore"
        static let sound = "com.gravityedge.goosegrass.reminders.sound"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferences: ReminderPreferences {
        get {
            ReminderPreferences(
                oneDayBeforeEnabled: value(forKey: Key.oneDay),
                twoHoursBeforeEnabled: value(forKey: Key.twoHours),
                thirtyMinutesBeforeEnabled: value(forKey: Key.thirtyMinutes),
                soundEnabled: value(forKey: Key.sound)
            )
        }
        set {
            defaults.set(newValue.oneDayBeforeEnabled, forKey: Key.oneDay)
            defaults.set(newValue.twoHoursBeforeEnabled, forKey: Key.twoHours)
            defaults.set(newValue.thirtyMinutesBeforeEnabled, forKey: Key.thirtyMinutes)
            defaults.set(newValue.soundEnabled, forKey: Key.sound)
        }
    }

    private func value(forKey key: String) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }
}

@MainActor
final class InMemoryReminderPreferencesStore: ReminderPreferencesStoring {
    var preferences: ReminderPreferences
    init(preferences: ReminderPreferences = ReminderPreferences()) {
        self.preferences = preferences
    }
}
