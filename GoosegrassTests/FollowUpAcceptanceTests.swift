import XCTest
import SwiftData
@testable import Goosegrass

@MainActor
final class FollowUpAcceptanceTests: XCTestCase {
    func testNoShowTomorrowFollowUpAndCompletionSurviveTwoRelaunches() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let center = FakeNotificationCenter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-16T10:00:00Z"))
        let customerID = try id(501)
        let appointmentID = try id(502)
        var followUpID: UUID?

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let customers = controller.makeCustomerService()
            let appointments = controller.makeAppointmentService()
            try customers.create(Customer(
                id: customerID,
                displayName: "Acceptance Customer",
                phone: "13800000501",
                normalizedPhone: "13800000501"
            ))
            let appointment = Appointment(
                id: appointmentID,
                customerID: customerID,
                startAt: now.addingTimeInterval(3 * 86_400),
                partySize: 2,
                status: .upcoming
            )
            try appointments.create(appointment)
            var reminderIndex = 510
            let reminders = controller.makeReminderService(
                notificationCenter: center,
                preferences: { ReminderPreferences() },
                calendar: calendar,
                now: { now },
                makeID: {
                    defer { reminderIndex += 1 }
                    return UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", reminderIndex, reminderIndex))!
                }
            )
            XCTAssertEqual(await reminders.schedule(appointment).count, 3)
            XCTAssertEqual(center.requests.count, 3)

            let followUps = controller.makeFollowUpService(calendar: calendar, now: { now })
            let viewModel = AppointmentListViewModel(
                service: appointments,
                customerService: customers,
                followUpService: followUps,
                calendar: calendar,
                now: { now }
            )
            viewModel.applyDatePreset(.all)
            viewModel.select(appointmentID)
            viewModel.perform(.markNoShow)
            viewModel.createNoShowFollowUpTomorrow()

            let noShow = try XCTUnwrap(appointments.fetch(id: appointmentID))
            _ = await reminders.rebuildForAppointment(noShow)
            let row = try XCTUnwrap(followUps.list().first)
            followUpID = row.id
            XCTAssertEqual(row.followUp.appointmentID, appointmentID)
            XCTAssertEqual(row.followUp.status, .pending)
            XCTAssertTrue(center.requests.isEmpty)
            XCTAssertTrue(try controller.makeReminderRepository().fetchAll().allSatisfy { $0.status == .cancelled })
        }

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let followUps = controller.makeFollowUpService(calendar: calendar, now: { now })
            let viewModel = FollowUpListViewModel(
                service: followUps,
                customerService: controller.makeCustomerService(),
                appointmentService: controller.makeAppointmentService(),
                calendar: calendar,
                now: { now.addingTimeInterval(120) }
            )
            viewModel.load()
            XCTAssertEqual(viewModel.rows.map(\.id), [try XCTUnwrap(followUpID)])
            viewModel.select(followUpID)
            viewModel.completeSelected()
            XCTAssertTrue(viewModel.rows.isEmpty)
            XCTAssertEqual(viewModel.detail?.listItem.followUp.status, .completed)
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let finalFollowUp = try XCTUnwrap(
            reopened.makeFollowUpService().list(filter: FollowUpListFilter(scope: .all)).first?.followUp
        )
        XCTAssertEqual(finalFollowUp.id, followUpID)
        XCTAssertEqual(finalFollowUp.status, .completed)
        XCTAssertEqual(finalFollowUp.completedAt, now.addingTimeInterval(120))
        XCTAssertEqual(
            try reopened.context.fetch(FetchDescriptor<PersistenceSchemaV1.FollowUpRecord>()).count,
            1
        )
        let appointmentDetail = try XCTUnwrap(reopened.makeAppointmentService().detail(id: appointmentID))
        XCTAssertEqual(appointmentDetail.listItem.appointment.status, .noShow)
        XCTAssertEqual(appointmentDetail.changes.count, 1)
        XCTAssertEqual(appointmentDetail.activities.map(\.type), [.appointmentNoShow])
        let customerActivities = try reopened.makeCustomerService().detail(id: customerID)?.activities.map(\.type)
        XCTAssertEqual(customerActivities?.first, .followUpCompleted)
        XCTAssertEqual(Set(customerActivities?.dropFirst() ?? []), Set([.followUpCreated, .appointmentNoShow]))
        XCTAssertTrue(try reopened.makeReminderRepository().fetchAll().allSatisfy { $0.status == .cancelled })
        XCTAssertTrue(center.requests.isEmpty)
    }

    func testManualSnoozeAndCancelSurviveRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let customerID = try id(520)
        var snoozedID: UUID?
        var cancelledID: UUID?

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            try controller.makeCustomerService().create(Customer(
                id: customerID,
                displayName: "Manual Follow-up",
                phone: "13800000520",
                normalizedPhone: "13800000520"
            ))
            let service = controller.makeFollowUpService(now: { now })
            let snoozed = try service.create(
                customerID: customerID,
                dueAt: now.addingTimeInterval(3_600),
                reason: "Snooze",
                at: now
            )
            snoozedID = snoozed.id
            _ = try service.snooze(
                id: snoozed.id,
                until: now.addingTimeInterval(7_200),
                at: now.addingTimeInterval(60)
            )
            let cancelled = try service.create(
                customerID: customerID,
                dueAt: now.addingTimeInterval(10_800),
                reason: "Cancel",
                at: now
            )
            cancelledID = cancelled.id
            _ = try service.cancel(id: cancelled.id, at: now.addingTimeInterval(120))
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let rows = try reopened.makeFollowUpService().list(filter: FollowUpListFilter(scope: .all))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first { $0.id == snoozedID }?.followUp.status, .snoozed)
        XCTAssertEqual(rows.first { $0.id == snoozedID }?.followUp.dueAt, now.addingTimeInterval(7_200))
        XCTAssertEqual(rows.first { $0.id == cancelledID }?.followUp.status, .cancelled)
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}
