import Foundation
import UserNotifications
import XCTest
@testable import Goosegrass

@MainActor
final class LocalNotificationCenterContractTests: XCTestCase {
    func testAuthorizationMappingCoversEverySystemState() {
        XCTAssertEqual(UserNotificationCenterAdapter.map(.notDetermined), .notDetermined)
        XCTAssertEqual(UserNotificationCenterAdapter.map(.denied), .denied)
        XCTAssertEqual(UserNotificationCenterAdapter.map(.authorized), .authorized)
        XCTAssertEqual(UserNotificationCenterAdapter.map(.provisional), .provisional)
        XCTAssertEqual(UserNotificationCenterAdapter.map(.ephemeral), .ephemeral)
    }

    func testRequestMappingPreservesIdentityDateSoundAndPrivacyBoundary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let fireAt = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T12:00:00Z"))
        let request = LocalNotificationRequest(
            identifier: "com.gravityedge.goosegrass.reminder.test",
            title: "Upcoming appointment",
            body: "Appointment at 12:00 PM for party of 2.",
            fireAt: fireAt,
            soundEnabled: true,
            userInfo: ["appointmentID": "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"]
        )

        let mapped = UserNotificationCenterAdapter.makeSystemRequest(request, calendar: calendar)
        XCTAssertEqual(mapped.identifier, request.identifier)
        XCTAssertEqual(mapped.content.title, request.title)
        XCTAssertEqual(mapped.content.body, request.body)
        XCTAssertNotNil(mapped.content.sound)
        XCTAssertEqual(mapped.content.userInfo["appointmentID"] as? String, request.userInfo["appointmentID"])
        let trigger = try XCTUnwrap(mapped.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(calendar.date(from: trigger.dateComponents), fireAt)
        XCTAssertFalse(mapped.content.body.contains("138"))
        XCTAssertFalse(mapped.content.body.localizedCaseInsensitiveContains("internal"))
    }

    func testFoundationPortCanBeUsedWithoutSystemCenter() async throws {
        let fake: any LocalNotificationCenter = ContractFakeNotificationCenter()
        let status = await fake.authorizationStatus()
        let granted = try await fake.requestAuthorization()
        let pending = await fake.pendingRequests()
        XCTAssertEqual(status, .authorized)
        XCTAssertTrue(granted)
        XCTAssertTrue(pending.isEmpty)
    }
}

@MainActor
private final class ContractFakeNotificationCenter: LocalNotificationCenter {
    func authorizationStatus() async -> LocalNotificationAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func add(_ request: LocalNotificationRequest) async throws {}
    func pendingRequests() async -> [PendingLocalNotification] { [] }
    func removePendingRequests(withIdentifiers identifiers: [String]) {}
}
