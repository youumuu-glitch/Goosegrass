import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentListViewModelTests: XCTestCase {
    func testLoadDatePresetsAndCombinedFiltersUseCalendarBoundaries() throws {
        let system = try makeSystem()
        let start = system.calendar.startOfDay(for: system.now)
        let source = try XCTUnwrap(system.customers.catalog().sources.first)
        let tag = try system.customers.createTag(named: "VIP")
        var customer = Customer(
            displayName: "客户",
            phone: "138",
            normalizedPhone: "138",
            sourceID: source.id,
            tagIDs: [tag.id]
        )
        try system.customers.create(customer)
        customer = try XCTUnwrap(system.customers.fetch(id: customer.id))
        let today = try system.appointments.create(
            draft: AppointmentEditorDraft(customerID: customer.id, startAt: start.addingTimeInterval(3_600), partySize: 1),
            at: system.now
        )
        let tomorrow = try system.appointments.create(
            draft: AppointmentEditorDraft(customerID: customer.id, startAt: start.addingTimeInterval(90_000), partySize: 2),
            at: system.now
        )
        _ = try system.appointments.create(
            draft: AppointmentEditorDraft(customerID: customer.id, startAt: start.addingTimeInterval(8 * 86_400), partySize: 3),
            at: system.now
        )

        system.viewModel.load()
        XCTAssertEqual(system.viewModel.rows.map(\.id), [today.id])
        system.viewModel.applyDatePreset(.tomorrow)
        XCTAssertEqual(system.viewModel.rows.map(\.id), [tomorrow.id])
        system.viewModel.applyDatePreset(.all)
        system.viewModel.filter.statuses = [.draft]
        system.viewModel.filter.customerID = customer.id
        system.viewModel.refresh()
        XCTAssertEqual(system.viewModel.rows.count, 3)
    }

    func testSelectionEditingRescheduleAndCustomerPreselectionRefreshAuthoritatively() throws {
        let system = try makeSystem()
        let customer = Customer(displayName: "客户", phone: "138", normalizedPhone: "138")
        try system.customers.create(customer)
        let created = try system.appointments.create(
            draft: AppointmentEditorDraft(
                customerID: customer.id,
                startAt: system.now.addingTimeInterval(3_600),
                partySize: 2
            ),
            at: system.now
        )
        system.viewModel.applyDatePreset(.all)
        system.viewModel.select(created.id)
        XCTAssertEqual(system.viewModel.allowedActions, [.submit, .cancel])
        system.viewModel.beginEdit()
        system.viewModel.editorDraft?.partySize = 4
        system.viewModel.saveEditor()
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.partySize, 4)

        system.viewModel.perform(.submit)
        system.viewModel.perform(.confirm)
        system.viewModel.perform(.markUpcoming)
        system.viewModel.beginReschedule()
        let newStart = system.now.addingTimeInterval(7_200)
        system.viewModel.editorDraft?.startAt = newStart
        system.viewModel.saveEditor(reason: "客户改期")
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .rescheduled)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.startAt, newStart)

        system.viewModel.beginAdd(customerID: customer.id)
        XCTAssertEqual(system.viewModel.editorDraft?.customerID, customer.id)
        system.viewModel.editorDraft?.startAt = system.now.addingTimeInterval(-1)
        XCTAssertTrue(system.viewModel.isHistoricalDraft)
    }

    func testCancellationRequiresConfirmationAndErrorsPreserveDraft() throws {
        let system = try makeSystem()
        let customer = Customer(displayName: "客户", phone: "138", normalizedPhone: "138")
        try system.customers.create(customer)
        let appointment = try system.appointments.create(
            draft: AppointmentEditorDraft(
                customerID: customer.id,
                startAt: system.now.addingTimeInterval(3_600),
                partySize: 1
            ),
            at: system.now
        )
        system.viewModel.applyDatePreset(.all)
        system.viewModel.select(appointment.id)
        system.viewModel.perform(.cancel)
        XCTAssertEqual(system.viewModel.pendingAction, .cancel)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .draft)
        system.viewModel.confirmPendingAction()
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .cancelled)

        system.viewModel.beginAdd()
        system.viewModel.editorDraft?.partySize = 0
        system.viewModel.saveEditor()
        XCTAssertNotNil(system.viewModel.errorMessage)
        XCTAssertNotNil(system.viewModel.editorDraft)
    }

    private func makeSystem() throws -> (
        controller: PersistenceController,
        customers: CustomerService,
        appointments: AppointmentService,
        viewModel: AppointmentListViewModel,
        calendar: Calendar,
        now: Date
    ) {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerService()
        let appointments = controller.makeAppointmentService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let viewModel = AppointmentListViewModel(
            service: appointments,
            customerService: customers,
            calendar: calendar,
            now: { now }
        )
        return (controller, customers, appointments, viewModel, calendar, now)
    }
}
