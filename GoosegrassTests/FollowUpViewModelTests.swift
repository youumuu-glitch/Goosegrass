import XCTest
@testable import Goosegrass

@MainActor
final class FollowUpViewModelTests: XCTestCase {
    func testLoadDefaultsToActiveAndAllScopeRestoresTerminalHistory() throws {
        let system = try makeSystem()
        let active = try system.followUps.create(
            customerID: system.customer.id,
            dueAt: system.now.addingTimeInterval(3_600),
            reason: "Active",
            at: system.now
        )
        let terminal = try system.followUps.create(
            customerID: system.customer.id,
            dueAt: system.now.addingTimeInterval(7_200),
            reason: "Done",
            at: system.now
        )
        _ = try system.followUps.complete(id: terminal.id, at: system.now.addingTimeInterval(60))

        system.viewModel.load()

        XCTAssertEqual(system.viewModel.scope, .active)
        XCTAssertEqual(system.viewModel.rows.map(\.id), [active.id])
        system.viewModel.applyScope(.all)
        XCTAssertEqual(system.viewModel.rows.map(\.id), [active.id, terminal.id])
    }

    func testCreateSelectionAndCompletionRefreshAuthoritatively() throws {
        let system = try makeSystem()
        system.viewModel.load()
        system.viewModel.beginAdd(customerID: system.customer.id, appointmentID: system.appointment.id)
        system.viewModel.editorDraft?.dueAt = system.now.addingTimeInterval(4_000)
        system.viewModel.editorDraft?.reason = "  Confirm return  "
        system.viewModel.editorDraft?.note = "Call once"
        system.viewModel.editorDraft?.priority = .high

        system.viewModel.saveEditor()

        let createdID = try XCTUnwrap(system.viewModel.selectedFollowUpID)
        XCTAssertNil(system.viewModel.editorDraft)
        XCTAssertEqual(system.viewModel.rows.map(\.id), [createdID])
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.reason, "Confirm return")
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.appointmentID, system.appointment.id)
        system.viewModel.completeSelected()
        XCTAssertTrue(system.viewModel.rows.isEmpty)
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.status, .completed)
        system.viewModel.applyScope(.all)
        XCTAssertEqual(system.viewModel.rows.map(\.id), [createdID])
    }

    func testSnoozeAndConfirmedCancelReloadDurableState() throws {
        let system = try makeSystem()
        let followUp = try system.followUps.create(
            customerID: system.customer.id,
            dueAt: system.now.addingTimeInterval(3_600),
            reason: "Lifecycle",
            at: system.now
        )
        system.viewModel.load()
        system.viewModel.select(followUp.id)
        let deferred = system.now.addingTimeInterval(9_000)

        system.viewModel.snoozeSelected(until: deferred)

        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.status, .snoozed)
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.dueAt, deferred)
        system.viewModel.requestCancel()
        XCTAssertTrue(system.viewModel.isCancelConfirmationPresented)
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.status, .snoozed)
        system.viewModel.confirmCancel()
        XCTAssertFalse(system.viewModel.isCancelConfirmationPresented)
        XCTAssertTrue(system.viewModel.rows.isEmpty)
        XCTAssertEqual(system.viewModel.detail?.listItem.followUp.status, .cancelled)
    }

    func testInvalidEditorPreservesDraftAndPublishesError() throws {
        let system = try makeSystem()
        system.viewModel.load()
        system.viewModel.beginAdd(customerID: system.customer.id)
        system.viewModel.editorDraft?.dueAt = system.now
        system.viewModel.editorDraft?.reason = " "

        system.viewModel.saveEditor()

        XCTAssertNotNil(system.viewModel.editorDraft)
        XCTAssertNotNil(system.viewModel.errorMessage)
        XCTAssertTrue(system.viewModel.rows.isEmpty)
    }

    private func makeSystem() throws -> FollowUpViewModelSystem {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerService()
        let appointments = controller.makeAppointmentService()
        let followUps = controller.makeFollowUpService()
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let customer = Customer(
            displayName: "Workspace Customer",
            phone: "13800000401",
            normalizedPhone: "13800000401"
        )
        try customers.create(customer)
        let appointment = Appointment(
            customerID: customer.id,
            startAt: now.addingTimeInterval(-3_600),
            partySize: 2,
            status: .noShow,
            noShowAt: now
        )
        try appointments.create(appointment)
        let viewModel = FollowUpListViewModel(
            service: followUps,
            customerService: customers,
            appointmentService: appointments,
            now: { now }
        )
        return FollowUpViewModelSystem(
            controller: controller,
            followUps: followUps,
            viewModel: viewModel,
            customer: customer,
            appointment: appointment,
            now: now
        )
    }
}

@MainActor
private struct FollowUpViewModelSystem {
    let controller: PersistenceController
    let followUps: FollowUpService
    let viewModel: FollowUpListViewModel
    let customer: Customer
    let appointment: Appointment
    let now: Date
}
