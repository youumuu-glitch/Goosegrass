import SwiftUI
import SwiftData

@main
struct GoosegrassApp: App {
    private let persistenceController: PersistenceController
    private let reminderPreferencesStore: UserDefaultsReminderPreferencesStore
    private let reminderService: ReminderService

    init() {
        do {
            let controller = try PersistenceController()
            let store = UserDefaultsReminderPreferencesStore()
            persistenceController = controller
            reminderPreferencesStore = store
            reminderService = controller.makeReminderService(
                notificationCenter: UserNotificationCenterAdapter(),
                preferences: { store.preferences }
            )
        } catch {
            fatalError("Unable to initialize the local data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                customerService: persistenceController.makeCustomerService(),
                appointmentService: persistenceController.makeAppointmentService(reminderScheduler: reminderService),
                todayService: persistenceController.makeTodayService(reminderScheduler: reminderService),
                followUpService: persistenceController.makeFollowUpService(),
                reminderService: reminderService,
                reminderPreferencesStore: reminderPreferencesStore
            )
        }
        .modelContainer(persistenceController.container)
    }
}
