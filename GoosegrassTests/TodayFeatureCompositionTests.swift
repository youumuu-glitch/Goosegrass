import SwiftUI
import XCTest
@testable import Goosegrass

@MainActor
final class TodayFeatureCompositionTests: XCTestCase {
    func testTodayUsesTheApplicationPersistenceGraph() throws {
        let controller = try PersistenceController(inMemory: true)
        let customerService = controller.makeCustomerService()
        let appointmentService = controller.makeAppointmentService()
        let customer = Customer(displayName: "Today Composition", phone: "138", normalizedPhone: "138")
        try customerService.create(customer)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-15T10:00:00Z"))
        let appointment = Appointment(
            customerID: customer.id,
            startAt: now.addingTimeInterval(3_600),
            partySize: 2,
            status: .confirmed
        )
        try appointmentService.create(appointment)

        let todayService = controller.makeTodayService(calendar: calendar, now: { now })
        let snapshot = try todayService.snapshot()

        XCTAssertEqual(snapshot.allAppointments.map(\.id), [appointment.id])
        XCTAssertEqual(snapshot.allAppointments.first?.appointment.customerID, customer.id)
        XCTAssertTrue(controller.makeAppointmentRepository().container === controller.container)
        XCTAssertTrue(controller.makeCustomerRepository().container === controller.container)
    }

    func testTodayWorkspaceComposesAsTheDefaultDestination() throws {
        let controller = try PersistenceController(inMemory: true)
        let todayService = controller.makeTodayService()
        let viewModel = TodayViewModel(service: todayService)

        _ = TodayView(viewModel: viewModel).body
        _ = ContentView(
            customerService: controller.makeCustomerService(),
            appointmentService: controller.makeAppointmentService(),
            todayService: todayService,
            followUpService: controller.makeFollowUpService(),
            reminderService: controller.makeReminderService(
                notificationCenter: FakeNotificationCenter(),
                preferences: { ReminderPreferences() }
            ),
            reminderPreferencesStore: InMemoryReminderPreferencesStore()
        ).body

        XCTAssertEqual(ContentView.initialDestination, .today)
    }
}
