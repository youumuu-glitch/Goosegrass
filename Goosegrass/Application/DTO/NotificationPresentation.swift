import Foundation

enum LocalNotificationAuthorizationStatus: String, Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

struct LocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let fireAt: Date
    let soundEnabled: Bool
    let userInfo: [String: String]
}

struct PendingLocalNotification: Equatable, Sendable {
    let identifier: String
    let fireAt: Date?
}

@MainActor
protocol LocalNotificationCenter: AnyObject {
    func authorizationStatus() async -> LocalNotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: LocalNotificationRequest) async throws
    func pendingRequests() async -> [PendingLocalNotification]
    func removePendingRequests(withIdentifiers identifiers: [String])
}
