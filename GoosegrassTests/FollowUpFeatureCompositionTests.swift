import XCTest
import SwiftUI
@testable import Goosegrass

@MainActor
final class FollowUpFeatureCompositionTests: XCTestCase {
    func testFollowUpWorkspaceUsesSharedPersistenceGraph() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerService()
        let appointments = controller.makeAppointmentService()
        let followUps = controller.makeFollowUpService()
        let customer = Customer(displayName: "Shared Follow-up", phone: "138", normalizedPhone: "138")
        try customers.create(customer)
        let appointment = Appointment(
            customerID: customer.id,
            startAt: Date(timeIntervalSince1970: 2_000_010_000),
            partySize: 2,
            status: .noShow
        )
        try appointments.create(appointment)
        let followUp = try followUps.create(
            customerID: customer.id,
            appointmentID: appointment.id,
            dueAt: Date(timeIntervalSince1970: 2_000_020_000),
            reason: "Shared graph",
            at: Date(timeIntervalSince1970: 2_000_000_000)
        )

        XCTAssertEqual(try customers.fetch(id: customer.id)?.followUpIDs, [followUp.id])
        XCTAssertEqual(try followUps.detail(id: followUp.id)?.listItem.customerName, "Shared Follow-up")
    }

    func testFollowUpWorkspaceAndApplicationRouteCompose() throws {
        let controller = try PersistenceController(inMemory: true)
        let followUpService = controller.makeFollowUpService()
        let viewModel = FollowUpListViewModel(
            service: followUpService,
            customerService: controller.makeCustomerService(),
            appointmentService: controller.makeAppointmentService()
        )
        let reminderService = controller.makeReminderService(
            notificationCenter: FakeNotificationCenter(),
            preferences: { ReminderPreferences() }
        )

        _ = FollowUpView(viewModel: viewModel).body
        _ = ContentView(
            customerService: controller.makeCustomerService(),
            appointmentService: controller.makeAppointmentService(),
            todayService: controller.makeTodayService(),
            followUpService: followUpService,
            reminderService: reminderService,
            reminderPreferencesStore: InMemoryReminderPreferencesStore()
        ).body

        XCTAssertTrue(AppDestination.allCases.contains(.followUp))
    }
}
