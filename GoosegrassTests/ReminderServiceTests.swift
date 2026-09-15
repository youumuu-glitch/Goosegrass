import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class ReminderServiceTests: XCTestCase {
    func testPermissionAndIdempotentDefaultScheduling() async throws {
        let system = try makeSystem()
        let authorization = await system.service.authorizationStatus()
        let permissionGranted = try await system.service.requestPermission()
        XCTAssertEqual(authorization, .authorized)
        XCTAssertTrue(permissionGranted)

        let first = await system.service.rebuildForAppointment(system.appointment)
        let second = await system.service.rebuildForAppointment(system.appointment)

        XCTAssertEqual(first.map(\.type), [.oneDayBefore, .twoHoursBefore, .thirtyMinutesBefore])
        XCTAssertEqual(second.map(\.id), first.map(\.id))
        XCTAssertEqual(system.center.requests.count, 3)
        XCTAssertEqual(Set(system.center.requests.keys), Set(first.compactMap(\.systemNotificationID)))
        XCTAssertTrue(system.center.requests.values.allSatisfy { !$0.body.contains("13800008888") })
        XCTAssertEqual(try system.reminders.fetchAll().count, 3)
    }

    func testRescheduleReplacesOldRequestsAndTerminalStateCancels() async throws {
        let system = try makeSystem()
        let original = await system.service.schedule(system.appointment)
        var moved = system.appointment
        moved.startAt = moved.startAt.addingTimeInterval(4 * 3_600)
        moved.status = .rescheduled
        try system.appointments.update(moved)

        let rebuilt = await system.service.reschedule(moved)
        XCTAssertEqual(rebuilt.map(\.id), original.map(\.id))
        XCTAssertEqual(Set(system.center.removedIdentifiers), Set(original.compactMap(\.systemNotificationID)))
        XCTAssertEqual(system.center.requests.count, 3)
        XCTAssertTrue(rebuilt.allSatisfy { $0.status == .scheduled })

        moved.status = .cancelled
        try system.appointments.update(moved)
        let cancelled = await system.service.cancel(appointmentID: moved.id)
        XCTAssertTrue(system.center.requests.isEmpty)
        XCTAssertEqual(cancelled.map(\.status), [.cancelled, .cancelled, .cancelled])
    }

    func testDeniedAndSubmissionFailureAreDurablyFailed() async throws {
        let denied = try makeSystem(authorization: .denied)
        let deniedResults = await denied.service.rebuildForAppointment(denied.appointment)
        XCTAssertEqual(deniedResults.map(\.status), [.failed, .failed, .failed])
        XCTAssertTrue(denied.center.requests.isEmpty)

        let failing = try makeSystem()
        failing.center.failAdds = true
        let failed = await failing.service.rebuildForAppointment(failing.appointment)
        XCTAssertEqual(failed.map(\.status), [.failed, .failed, .failed])
        XCTAssertEqual(try failing.reminders.fetchAll().map(\.status), [.failed, .failed, .failed])
    }

    func testReconcileRepairsMissingRequestsAndRemovesOnlyOwnedGhosts() async throws {
        let system = try makeSystem()
        let failedID = try id(120)
        _ = try system.reminders.upsert(Reminder(
            id: failedID,
            appointmentID: system.appointment.id,
            type: .oneDayBefore,
            fireAt: system.appointment.startAt.addingTimeInterval(-86_400),
            systemNotificationID: ReminderNotificationIdentity.identifier(for: failedID),
            status: .failed
        ))
        system.center.requests["com.gravityedge.goosegrass.reminder.ghost"] = LocalNotificationRequest(
            identifier: "com.gravityedge.goosegrass.reminder.ghost",
            title: "Ghost",
            body: "Ghost",
            fireAt: system.appointment.startAt,
            soundEnabled: false,
            userInfo: [:]
        )
        system.center.requests["foreign.notification"] = LocalNotificationRequest(
            identifier: "foreign.notification",
            title: "Foreign",
            body: "Foreign",
            fireAt: system.appointment.startAt,
            soundEnabled: false,
            userInfo: [:]
        )

        await system.service.reconcilePendingNotifications()

        XCTAssertEqual(try system.reminders.fetchAll().map(\.status), [.scheduled, .scheduled, .scheduled])
        XCTAssertFalse(system.center.requests.keys.contains("com.gravityedge.goosegrass.reminder.ghost"))
        XCTAssertTrue(system.center.requests.keys.contains("foreign.notification"))
        XCTAssertEqual(system.center.requests.keys.filter { $0.hasPrefix(ReminderNotificationIdentity.prefix) }.count, 3)
    }

    private func makeSystem(
        authorization: LocalNotificationAuthorizationStatus = .authorized
    ) throws -> TestSystem {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(110)
        let appointmentID = try id(111)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-15T10:00:00Z"))
        let appointment = Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: now.addingTimeInterval(2 * 86_400),
            partySize: 2,
            status: .confirmed
        )
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Private Customer",
            phone: "13800008888",
            normalizedPhone: "13800008888",
            notes: "internal private note"
        ))
        let appointments = controller.makeAppointmentRepository()
        try appointments.create(appointment)
        let reminders = controller.makeReminderRepository()
        let center = FakeNotificationCenter(authorization: authorization)
        var nextID = 112
        let service = ReminderService(
            repository: reminders,
            appointmentRepository: appointments,
            notificationCenter: center,
            preferences: { ReminderPreferences() },
            calendar: Calendar(identifier: .gregorian),
            now: { now },
            makeID: {
                defer { nextID += 1 }
                return UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", nextID, nextID))!
            }
        )
        return TestSystem(
            controller: controller,
            appointments: appointments,
            reminders: reminders,
            center: center,
            service: service,
            appointment: appointment
        )
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private struct TestSystem {
    let controller: PersistenceController
    let appointments: LocalAppointmentRepository
    let reminders: LocalReminderRepository
    let center: FakeNotificationCenter
    let service: ReminderService
    let appointment: Appointment
}

@MainActor
final class FakeNotificationCenter: LocalNotificationCenter {
    var authorization: LocalNotificationAuthorizationStatus
    var permissionResult = true
    var failAdds = false
    var requests: [String: LocalNotificationRequest] = [:]
    var removedIdentifiers: [String] = []

    init(authorization: LocalNotificationAuthorizationStatus = .authorized) {
        self.authorization = authorization
    }

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus { authorization }
    func requestAuthorization() async throws -> Bool { permissionResult }
    func add(_ request: LocalNotificationRequest) async throws {
        if failAdds { throw FakeNotificationError.rejected }
        requests[request.identifier] = request
    }
    func pendingRequests() async -> [PendingLocalNotification] {
        requests.values.map { PendingLocalNotification(identifier: $0.identifier, fireAt: $0.fireAt) }
    }
    func removePendingRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        for identifier in identifiers { requests.removeValue(forKey: identifier) }
    }
}

private enum FakeNotificationError: Error { case rejected }
