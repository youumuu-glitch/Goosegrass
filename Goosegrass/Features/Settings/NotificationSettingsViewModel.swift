import Combine
import Foundation

@MainActor
final class NotificationSettingsViewModel: ObservableObject {
    @Published private(set) var preferences: ReminderPreferences
    @Published private(set) var authorizationStatus: LocalNotificationAuthorizationStatus = .notDetermined
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    private let service: any NotificationSettingsServicing
    private let store: any ReminderPreferencesStoring

    init(
        service: any NotificationSettingsServicing,
        store: any ReminderPreferencesStoring
    ) {
        self.service = service
        self.store = store
        preferences = store.preferences
    }

    func load() async {
        preferences = store.preferences
        authorizationStatus = await service.authorizationStatus()
    }

    func save(_ preferences: ReminderPreferences) {
        self.preferences = preferences
        store.preferences = preferences
    }

    func requestPermission() async {
        await perform {
            _ = try await service.requestPermission()
            authorizationStatus = await service.authorizationStatus()
        }
    }

    func reconcile() async {
        await perform { await service.reconcilePendingNotifications() }
    }

    func clearError() {
        errorMessage = nil
    }

    private func perform(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await operation()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
