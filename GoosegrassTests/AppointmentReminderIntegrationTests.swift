import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentReminderIntegrationTests: XCTestCase {
    func testEverySuccessfulAppointmentMutationReportsAuthoritativeState() throws {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(130)
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Reminder Integration",
            phone: "138",
            normalizedPhone: "138"
        ))
        let handler = CapturingReminderScheduler()
        let service = controller.makeAppointmentService(reminderScheduler: handler)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let created = try service.create(
            draft: AppointmentEditorDraft(
                customerID: customerID,
                startAt: now.addingTimeInterval(86_400),
                partySize: 2
            ),
            at: now
        )
        _ = try service.transition(id: created.id, action: .submit, at: now.addingTimeInterval(1))
        _ = try service.transition(id: created.id, action: .confirm, at: now.addingTimeInterval(2))
        _ = try service.transition(id: created.id, action: .markUpcoming, at: now.addingTimeInterval(3))
        _ = try service.reschedule(
            id: created.id,
            startAt: now.addingTimeInterval(172_800),
            endAt: nil,
            reason: "integration",
            at: now.addingTimeInterval(4)
        )

        XCTAssertEqual(handler.appointments.map(\.status), [
            .draft, .pendingConfirmation, .confirmed, .upcoming, .rescheduled,
        ])
        XCTAssertTrue(handler.appointments.allSatisfy { $0.id == created.id })
        XCTAssertEqual(handler.appointments.last, try service.fetch(id: created.id))
    }

    func testFailedCommitDoesNotNotifyAndTodayUsesInjectedHandler() throws {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(131)
        let appointmentID = try id(132)
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Today Reminder",
            phone: "139",
            normalizedPhone: "139"
        ))
        try controller.makeAppointmentRepository().create(Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: Date(timeIntervalSince1970: 2_100_000_000),
            partySize: 2,
            status: .upcoming
        ))
        let handler = CapturingReminderScheduler()
        let today = controller.makeTodayService(
            reminderScheduler: handler,
            now: { Date(timeIntervalSince1970: 2_000_000_000) }
        )

        _ = try today.transition(appointmentID: appointmentID, action: .markNoShow)
        XCTAssertEqual(handler.appointments.map(\.status), [.noShow])

        XCTAssertThrowsError(try today.transition(appointmentID: try id(999), action: .cancel))
        XCTAssertEqual(handler.appointments.count, 1)
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private final class CapturingReminderScheduler: AppointmentReminderScheduling {
    private(set) var appointments: [Appointment] = []
    func synchronizeAfterAppointmentMutation(_ appointment: Appointment) {
        appointments.append(appointment)
    }
}
