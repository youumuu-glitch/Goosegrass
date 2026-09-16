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

    func testAppointmentsNoShowOffersTomorrowAndSkipOnlyAfterSuccessfulTransition() throws {
        let system = try makeNoShowIntegrationSystem()
        let skipAppointment = try system.createUpcomingAppointment(offset: 3_600)
        let createAppointment = try system.createUpcomingAppointment(offset: 7_200)
        let viewModel = AppointmentListViewModel(
            service: system.appointments,
            customerService: system.customers,
            followUpService: system.followUps,
            calendar: system.calendar,
            now: { system.now }
        )
        viewModel.applyDatePreset(.all)
        viewModel.select(skipAppointment.id)

        viewModel.perform(.markNoShow)

        XCTAssertEqual(viewModel.pendingNoShowFollowUpRequest?.appointmentID, skipAppointment.id)
        viewModel.skipNoShowFollowUp()
        XCTAssertNil(viewModel.pendingNoShowFollowUpRequest)
        XCTAssertTrue(try system.followUps.list(filter: FollowUpListFilter(scope: .all)).isEmpty)

        viewModel.select(createAppointment.id)
        viewModel.perform(.markNoShow)
        viewModel.createNoShowFollowUpTomorrow()
        let rows = try system.followUps.list(filter: FollowUpListFilter(scope: .all))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.followUp.appointmentID, createAppointment.id)
        XCTAssertEqual(rows.first?.followUp.reason, "No-show follow-up")
        XCTAssertNil(viewModel.pendingNoShowFollowUpRequest)
    }

    func testAppointmentsCustomNoShowPrefillWritesOnlyOnSaveAndFailureDoesNotPrompt() throws {
        let system = try makeNoShowIntegrationSystem()
        let customAppointment = try system.createUpcomingAppointment(offset: 3_600)
        let failingAppointment = try system.createUpcomingAppointment(offset: 7_200)
        let viewModel = AppointmentListViewModel(
            service: system.appointments,
            customerService: system.customers,
            followUpService: system.followUps,
            calendar: system.calendar,
            now: { system.now }
        )
        viewModel.applyDatePreset(.all)
        viewModel.select(customAppointment.id)
        viewModel.perform(.markNoShow)

        viewModel.beginCustomNoShowFollowUp()

        XCTAssertNil(viewModel.pendingNoShowFollowUpRequest)
        XCTAssertEqual(viewModel.customFollowUpDraft?.customerID, system.customer.id)
        XCTAssertEqual(viewModel.customFollowUpDraft?.appointmentID, customAppointment.id)
        XCTAssertEqual(viewModel.customFollowUpDraft?.reason, "No-show follow-up")
        XCTAssertTrue(try system.followUps.list(filter: FollowUpListFilter(scope: .all)).isEmpty)
        viewModel.customFollowUpDraft?.dueAt = system.now.addingTimeInterval(20_000)
        viewModel.saveCustomNoShowFollowUp()
        XCTAssertNil(viewModel.customFollowUpDraft)
        XCTAssertEqual(try system.followUps.list(filter: FollowUpListFilter(scope: .all)).count, 1)

        viewModel.select(failingAppointment.id)
        try system.controller.makeCustomerRepository().archive(id: system.customer.id, at: system.now)
        viewModel.perform(.markNoShow)
        XCTAssertNil(viewModel.pendingNoShowFollowUpRequest)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testTodayNoShowUsesSameFollowUpService() throws {
        let system = try makeNoShowIntegrationSystem()
        let appointment = try system.createUpcomingAppointment(offset: 3_600)
        let today = system.controller.makeTodayService(
            calendar: system.calendar,
            now: { system.now }
        )
        let viewModel = TodayViewModel(
            service: today,
            followUpService: system.followUps,
            calendar: system.calendar,
            now: { system.now }
        )
        viewModel.load()
        viewModel.selectAppointment(appointment.id)

        viewModel.perform(.markNoShow)
        viewModel.createNoShowFollowUpTomorrow()

        let row = try XCTUnwrap(system.followUps.list(filter: FollowUpListFilter(scope: .all)).first)
        XCTAssertEqual(row.followUp.appointmentID, appointment.id)
        XCTAssertEqual(row.followUp.customerID, system.customer.id)
        XCTAssertEqual(
            system.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: row.followUp.dueAt),
            DateComponents(year: 2033, month: 5, day: 19, hour: 11, minute: 0)
        )
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

    private func makeNoShowIntegrationSystem() throws -> NoShowIntegrationSystem {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerService()
        let appointments = controller.makeAppointmentService()
        let followUps = controller.makeFollowUpService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let customer = Customer(
            displayName: "No-show Customer",
            phone: "13800000402",
            normalizedPhone: "13800000402"
        )
        try customers.create(customer)
        return NoShowIntegrationSystem(
            controller: controller,
            customers: customers,
            appointments: appointments,
            followUps: followUps,
            customer: customer,
            calendar: calendar,
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

@MainActor
private struct NoShowIntegrationSystem {
    let controller: PersistenceController
    let customers: CustomerService
    let appointments: AppointmentService
    let followUps: FollowUpService
    let customer: Customer
    let calendar: Calendar
    let now: Date

    func createUpcomingAppointment(offset: TimeInterval) throws -> Appointment {
        let appointment = Appointment(
            customerID: customer.id,
            startAt: now.addingTimeInterval(offset),
            partySize: 2,
            status: .upcoming
        )
        try appointments.create(appointment)
        return appointment
    }
}
