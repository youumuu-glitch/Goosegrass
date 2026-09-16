import SwiftUI
import XCTest
@testable import Goosegrass

@MainActor
final class NotificationFeatureCompositionTests: XCTestCase {
    func testApplicationReminderGraphSharesPersistenceAndComposesSettings() async throws {
        let controller = try PersistenceController(inMemory: true)
        let center = FakeNotificationCenter()
        let store = InMemoryReminderPreferencesStore(preferences: ReminderPreferences())
        let reminderService = controller.makeReminderService(
            notificationCenter: center,
            preferences: { store.preferences }
        )
        let settingsViewModel = NotificationSettingsViewModel(service: reminderService, store: store)

        XCTAssertTrue(controller.makeReminderRepository().container === controller.container)
        _ = SettingsView(viewModel: settingsViewModel).body
        _ = ContentView(
            customerService: controller.makeCustomerService(),
            appointmentService: controller.makeAppointmentService(reminderScheduler: reminderService),
            todayService: controller.makeTodayService(reminderScheduler: reminderService),
            followUpService: controller.makeFollowUpService(),
            reminderService: reminderService,
            reminderPreferencesStore: store
        ).body

        await reminderService.reconcilePendingNotifications()
        XCTAssertTrue(center.requests.isEmpty)
    }
}
