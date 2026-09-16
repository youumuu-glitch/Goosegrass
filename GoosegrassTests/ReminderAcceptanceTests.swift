import Foundation
import SwiftData
import XCTest
@testable import Goosegrass

@MainActor
final class ReminderAcceptanceTests: XCTestCase {
    func testReminderLifecycleSurvivesRelaunchAndReconcileWithoutFollowUps() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let center = FakeNotificationCenter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T10:00:00Z"))
        let customerID = try id(200)
        let appointmentIDs = try [201, 202, 203].map(id)
        var stableReminderIDs: [UUID] = []

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            try controller.makeCustomerRepository().create(Customer(
                id: customerID,
                displayName: "Durable Reminder",
                phone: "13800008888",
                normalizedPhone: "13800008888"
            ))
            let appointments = controller.makeAppointmentRepository()
            let statuses: [AppointmentStatus] = [.confirmed, .upcoming, .confirmed]
            for index in appointmentIDs.indices {
                try appointments.create(Appointment(
                    id: appointmentIDs[index],
                    customerID: customerID,
                    startAt: now.addingTimeInterval(Double(index + 3) * 86_400),
                    partySize: index + 1,
                    status: statuses[index]
                ))
            }
            var nextReminderID = 210
            let service = controller.makeReminderService(
                notificationCenter: center,
                preferences: { ReminderPreferences() },
                calendar: calendar,
                now: { now },
                makeID: {
                    defer { nextReminderID += 1 }
                    return UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", nextReminderID, nextReminderID))!
                }
            )
            _ = await service.schedule(try XCTUnwrap(appointments.fetch(id: appointmentIDs[0])))
            _ = await service.schedule(try XCTUnwrap(appointments.fetch(id: appointmentIDs[1])))
            center.failAdds = true
            let failed = await service.schedule(try XCTUnwrap(appointments.fetch(id: appointmentIDs[2])))
            XCTAssertEqual(failed.map(\.status), [.failed, .failed, .failed])
            center.failAdds = false
            stableReminderIDs = try controller.makeReminderRepository().fetchAll().map(\.id)
            XCTAssertEqual(stableReminderIDs.count, 9)
            XCTAssertEqual(center.requests.count, 6)
        }

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let reminders = controller.makeReminderRepository()
            let service = controller.makeReminderService(
                notificationCenter: center,
                preferences: { ReminderPreferences() },
                calendar: calendar,
                now: { now }
            )
            await service.reconcilePendingNotifications()
            XCTAssertEqual(center.requests.count, 9)
            XCTAssertEqual(Set(try reminders.fetchAll().map(\.id)), Set(stableReminderIDs))
            XCTAssertTrue(try reminders.fetchAll().allSatisfy { $0.status == .scheduled })

            let appointments = controller.makeAppointmentService()
            let moved = try appointments.reschedule(
                id: appointmentIDs[0],
                startAt: now.addingTimeInterval(7 * 86_400),
                endAt: nil,
                reason: "acceptance reschedule",
                at: now.addingTimeInterval(60)
            )
            _ = await service.reschedule(moved)
            XCTAssertEqual(center.requests.count, 9)
            XCTAssertEqual(Set(try reminders.fetchAll().map(\.id)), Set(stableReminderIDs))

            let cancelled = try appointments.transition(
                id: appointmentIDs[0],
                action: .cancel,
                at: now.addingTimeInterval(120)
            )
            _ = await service.rebuildForAppointment(cancelled)
            let noShow = try appointments.transition(
                id: appointmentIDs[1],
                action: .markNoShow,
                at: now.addingTimeInterval(180)
            )
            _ = await service.rebuildForAppointment(noShow)
            XCTAssertEqual(center.requests.count, 3)
            XCTAssertEqual(
                try reminders.fetchAll().filter { $0.status == .cancelled }.count,
                6
            )
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let reminders = try reopened.makeReminderRepository().fetchAll()
        XCTAssertEqual(Set(reminders.map(\.id)), Set(stableReminderIDs))
        XCTAssertEqual(reminders.filter { $0.status == .scheduled }.count, 3)
        XCTAssertEqual(reminders.filter { $0.status == .cancelled }.count, 6)
        XCTAssertEqual(Set(center.requests.keys), Set(reminders.compactMap {
            $0.status == .scheduled ? $0.systemNotificationID : nil
        }))

        let appointmentService = reopened.makeAppointmentService()
        XCTAssertEqual(try appointmentService.detail(id: appointmentIDs[0])?.changes.count, 2)
        XCTAssertEqual(try appointmentService.detail(id: appointmentIDs[0])?.activities.count, 2)
        XCTAssertEqual(try appointmentService.detail(id: appointmentIDs[1])?.changes.count, 1)
        XCTAssertEqual(try appointmentService.detail(id: appointmentIDs[1])?.activities.count, 1)
        XCTAssertTrue(try reopened.context.fetch(FetchDescriptor<PersistenceSchemaV1.FollowUpRecord>()).isEmpty)
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}
