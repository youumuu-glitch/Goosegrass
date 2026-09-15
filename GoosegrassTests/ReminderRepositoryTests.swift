import Foundation
import SwiftData
import XCTest
@testable import Goosegrass

@MainActor
final class ReminderRepositoryTests: XCTestCase {
    func testUpsertKeepsIdentityAndAttachesAppointmentRelationship() throws {
        let system = try makeSystem()
        let originalID = try id(101)
        let original = Reminder(
            id: originalID,
            appointmentID: system.appointmentID,
            type: .oneDayBefore,
            fireAt: Date(timeIntervalSince1970: 2_000),
            systemNotificationID: ReminderNotificationIdentity.identifier(for: originalID),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(try system.repository.upsert(original), original)
        let replacement = Reminder(
            id: try id(102),
            appointmentID: system.appointmentID,
            type: .oneDayBefore,
            fireAt: Date(timeIntervalSince1970: 3_000),
            systemNotificationID: "replacement",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let updated = try system.repository.upsert(replacement)

        XCTAssertEqual(updated.id, originalID)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertEqual(updated.updatedAt, replacement.updatedAt)
        XCTAssertEqual(updated.fireAt, replacement.fireAt)
        XCTAssertEqual(updated.systemNotificationID, replacement.systemNotificationID)
        XCTAssertEqual(try system.repository.fetchAll(appointmentID: system.appointmentID), [updated])
        XCTAssertEqual(
            try system.controller.makeAppointmentService().detail(id: system.appointmentID)?.listItem.reminderStatuses,
            [.scheduled]
        )
    }

    func testOrderingStatusUpdatesAndCancellationPersist() throws {
        let system = try makeSystem()
        let laterID = try id(103)
        let earlierID = try id(104)
        _ = try system.repository.upsert(Reminder(
            id: laterID,
            appointmentID: system.appointmentID,
            type: .twoHoursBefore,
            fireAt: Date(timeIntervalSince1970: 4_000)
        ))
        _ = try system.repository.upsert(Reminder(
            id: earlierID,
            appointmentID: system.appointmentID,
            type: .thirtyMinutesBefore,
            fireAt: Date(timeIntervalSince1970: 3_000)
        ))

        XCTAssertEqual(try system.repository.fetchAll().map(\.id), [earlierID, laterID])
        let failed = try system.repository.updateStatus(
            id: laterID,
            status: .failed,
            at: Date(timeIntervalSince1970: 5_000)
        )
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.updatedAt, Date(timeIntervalSince1970: 5_000))

        let cancelled = try system.repository.cancelAll(
            appointmentID: system.appointmentID,
            at: Date(timeIntervalSince1970: 6_000)
        )
        XCTAssertEqual(cancelled.map(\.status), [.cancelled, .cancelled])
        XCTAssertEqual(try system.repository.fetchAll().map(\.status), [.cancelled, .cancelled])
    }

    func testInvalidStoredEnumIsReported() throws {
        let system = try makeSystem()
        let record = PersistenceSchemaV1.ReminderRecord(
            id: try id(105),
            appointmentID: system.appointmentID,
            typeRawValue: "not-a-type",
            fireAt: Date(timeIntervalSince1970: 7_000),
            statusRawValue: ReminderStatus.scheduled.rawValue
        )
        system.controller.context.insert(record)
        try system.controller.context.save()

        XCTAssertThrowsError(try system.repository.fetch(id: record.id)) { error in
            XCTAssertEqual(error as? PersistenceError, .invalidStoredValue(field: "Reminder.type", value: "not-a-type"))
        }
    }

    func testReminderSurvivesDiskRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let customerID = try id(106)
        let appointmentID = try id(107)
        let reminderID = try id(108)

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            try controller.makeCustomerRepository().create(Customer(
                id: customerID,
                displayName: "Reminder Relaunch",
                phone: "138",
                normalizedPhone: "138"
            ))
            try controller.makeAppointmentRepository().create(Appointment(
                id: appointmentID,
                customerID: customerID,
                startAt: Date(timeIntervalSince1970: 10_000),
                partySize: 2,
                status: .confirmed
            ))
            _ = try controller.makeReminderRepository().upsert(Reminder(
                id: reminderID,
                appointmentID: appointmentID,
                type: .twoHoursBefore,
                fireAt: Date(timeIntervalSince1970: 8_000),
                systemNotificationID: ReminderNotificationIdentity.identifier(for: reminderID)
            ))
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let reminder = try XCTUnwrap(reopened.makeReminderRepository().fetch(id: reminderID))
        XCTAssertEqual(reminder.appointmentID, appointmentID)
        XCTAssertEqual(reminder.type, .twoHoursBefore)
        XCTAssertEqual(reminder.status, .scheduled)
        XCTAssertEqual(
            try reopened.makeAppointmentService().detail(id: appointmentID)?.listItem.reminderStatuses,
            [.scheduled]
        )
    }

    private func makeSystem() throws -> TestSystem {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(99)
        let appointmentID = try id(100)
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Reminder",
            phone: "138",
            normalizedPhone: "138"
        ))
        try controller.makeAppointmentRepository().create(Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: Date(timeIntervalSince1970: 10_000),
            partySize: 2,
            status: .confirmed
        ))
        return TestSystem(
            controller: controller,
            repository: controller.makeReminderRepository(),
            appointmentID: appointmentID
        )
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private struct TestSystem {
    let controller: PersistenceController
    let repository: LocalReminderRepository
    let appointmentID: UUID
}
