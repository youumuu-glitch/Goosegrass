import SwiftUI
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentFeatureCompositionTests: XCTestCase {
    func testApplicationCompositionSharesOnePersistenceGraph() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerService()
        let appointments = controller.makeAppointmentService()
        let customer = Customer(displayName: "共享客户", phone: "138", normalizedPhone: "138")
        try customers.create(customer)

        let appointment = try appointments.create(
            draft: AppointmentEditorDraft(
                customerID: customer.id,
                startAt: Date(timeIntervalSince1970: 2_000),
                partySize: 2
            ),
            at: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(try customers.fetch(id: customer.id)?.appointmentIDs, [appointment.id])
        XCTAssertEqual(try appointments.detail(id: appointment.id)?.listItem.customerName, "共享客户")
        XCTAssertTrue(controller.makeAppointmentRepository().container === controller.container)
        XCTAssertTrue(controller.makeCustomerRepository().container === controller.container)
    }

    func testAppointmentsWorkspaceAndApplicationRouteCompose() throws {
        let controller = try PersistenceController(inMemory: true)
        let viewModel = AppointmentListViewModel(
            service: controller.makeAppointmentService(),
            customerService: controller.makeCustomerService()
        )

        _ = AppointmentsView(viewModel: viewModel).body
        _ = ContentView(
            customerService: controller.makeCustomerService(),
            appointmentService: controller.makeAppointmentService()
        ).body
    }
}
