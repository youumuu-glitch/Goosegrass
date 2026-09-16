import Foundation
import UserNotifications

@MainActor
final class UserNotificationCenterAdapter: LocalNotificationCenter {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus {
        Self.map(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func add(_ request: LocalNotificationRequest) async throws {
        try await center.add(Self.makeSystemRequest(request, calendar: calendar))
    }

    func pendingRequests() async -> [PendingLocalNotification] {
        await center.pendingNotificationRequests().map { request in
            PendingLocalNotification(
                identifier: request.identifier,
                fireAt: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            )
        }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func map(_ status: UNAuthorizationStatus) -> LocalNotificationAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .notDetermined
        }
    }

    static func makeSystemRequest(
        _ request: LocalNotificationRequest,
        calendar: Calendar
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.userInfo
        if request.soundEnabled { content.sound = .default }

        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.fireAt
        )
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
    }
}
