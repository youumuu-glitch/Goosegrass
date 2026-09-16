import XCTest
@testable import Goosegrass

@MainActor
final class FollowUpServiceTests: XCTestCase {
    func testCreateTrimsReasonAndWritesCreatedActivity() throws {
        let system = try makeSystem()
        let created = try system.service.create(
            customerID: system.customerID,
            appointmentID: system.appointmentID,
            dueAt: system.now.addingTimeInterval(20_000),
            reason: "  Confirm another date  ",
            note: "Call after lunch",
            priority: .high,
            at: system.now
        )

        XCTAssertEqual(created.id, try id(303))
        XCTAssertEqual(created.reason, "Confirm another date")
        XCTAssertEqual(created.note, "Call after lunch")
        XCTAssertEqual(created.priority, .high)
        XCTAssertEqual(created.status, .pending)
        XCTAssertEqual(created.createdAt, system.now)
        XCTAssertEqual(created.updatedAt, system.now)
        let activities = try system.controller.makeCustomerRepository().fetchDetail(id: system.customerID)?.activities
        XCTAssertEqual(activities?.map(\.id), [try id(304)])
        XCTAssertEqual(activities?.first?.type, .followUpCreated)
        XCTAssertEqual(activities?.first?.appointmentID, system.appointmentID)
    }

    func testNoShowShortcutCreatesTomorrowAtElevenWithDefaults() throws {
        let system = try makeSystem()

        let created = try system.service.createNoShowFollowUp(
            customerID: system.customerID,
            appointmentID: system.appointmentID,
            at: system.now
        )

        XCTAssertEqual(created.reason, "No-show follow-up")
        XCTAssertEqual(created.priority, .normal)
        XCTAssertEqual(
            system.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: created.dueAt),
            DateComponents(year: 2026, month: 9, day: 17, hour: 11, minute: 0)
        )
    }

    func testCompleteWritesTimestampAndCompletedActivity() throws {
        let system = try makeSystem()
        let created = try system.service.create(
            customerID: system.customerID,
            dueAt: system.now.addingTimeInterval(20_000),
            reason: "Complete me",
            at: system.now
        )
        let completionTime = system.now.addingTimeInterval(60)

        let completed = try system.service.complete(id: created.id, at: completionTime)

        XCTAssertEqual(completed.status, .completed)
        XCTAssertEqual(completed.completedAt, completionTime)
        XCTAssertEqual(completed.updatedAt, completionTime)
        let activities = try system.controller.makeCustomerRepository().fetchDetail(id: system.customerID)?.activities
        XCTAssertEqual(activities?.map(\.type), [.followUpCompleted, .followUpCreated])
    }

    func testSnoozeAndCancelPersistWithoutDeletingHistory() throws {
        let system = try makeSystem()
        let created = try system.service.create(
            customerID: system.customerID,
            dueAt: system.now.addingTimeInterval(20_000),
            reason: "Lifecycle",
            at: system.now
        )
        let snoozeTime = system.now.addingTimeInterval(30_000)
        let snoozed = try system.service.snooze(
            id: created.id,
            until: snoozeTime,
            at: system.now.addingTimeInterval(60)
        )
        XCTAssertEqual(snoozed.status, .snoozed)
        XCTAssertEqual(snoozed.dueAt, snoozeTime)
        XCTAssertNil(snoozed.completedAt)

        let cancelled = try system.service.cancel(id: created.id, at: system.now.addingTimeInterval(120))
        XCTAssertEqual(cancelled.status, .cancelled)
        XCTAssertNil(cancelled.completedAt)
        XCTAssertNotNil(try system.service.detail(id: created.id))
        XCTAssertTrue(try system.service.list().isEmpty)
        XCTAssertEqual(try system.service.list(filter: FollowUpListFilter(scope: .all)).map(\.id), [created.id])
    }

    func testValidationAndTerminalTransitionFailuresDoNotPartiallyWrite() throws {
        let system = try makeSystem()
        XCTAssertThrowsError(try system.service.create(
            customerID: system.customerID,
            dueAt: system.now,
            reason: " ",
            at: system.now
        ))
        XCTAssertTrue(try system.service.list(filter: FollowUpListFilter(scope: .all)).isEmpty)
        XCTAssertTrue(try system.controller.makeCustomerRepository().fetchDetail(id: system.customerID)?.activities.isEmpty == true)

        let created = try system.service.create(
            customerID: system.customerID,
            dueAt: system.now.addingTimeInterval(20_000),
            reason: "Terminal",
            at: system.now
        )
        _ = try system.service.complete(id: created.id, at: system.now.addingTimeInterval(60))
        XCTAssertThrowsError(try system.service.snooze(
            id: created.id,
            until: system.now.addingTimeInterval(40_000),
            at: system.now.addingTimeInterval(120)
        )) { error in
            XCTAssertEqual(
                error as? FollowUpValidationError,
                .invalidTransition(from: .completed, action: .snooze)
            )
        }
        XCTAssertEqual(try system.service.detail(id: created.id)?.listItem.followUp.status, .completed)
        XCTAssertEqual(
            try system.controller.makeCustomerRepository().fetchDetail(id: system.customerID)?.activities.map(\.type),
            [.followUpCompleted, .followUpCreated]
        )
    }

    private func makeSystem() throws -> FollowUpServiceSystem {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(301)
        let appointmentID = try id(302)
        let now: Date
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        now = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 16,
            hour: 9
        )))
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Service Customer",
            phone: "13800000301",
            normalizedPhone: "13800000301"
        ))
        try controller.makeAppointmentRepository().create(Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: now.addingTimeInterval(-3_600),
            partySize: 2,
            status: .noShow,
            noShowAt: now
        ))
        var ids = [try id(303), try id(304), try id(305), try id(306)]
        let service = controller.makeFollowUpService(
            calendar: calendar,
            now: { now },
            makeID: { ids.removeFirst() }
        )
        return FollowUpServiceSystem(
            controller: controller,
            service: service,
            customerID: customerID,
            appointmentID: appointmentID,
            now: now,
            calendar: calendar
        )
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private struct FollowUpServiceSystem {
    let controller: PersistenceController
    let service: FollowUpService
    let customerID: UUID
    let appointmentID: UUID
    let now: Date
    let calendar: Calendar
}
