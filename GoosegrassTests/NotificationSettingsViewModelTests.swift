import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class NotificationSettingsViewModelTests: XCTestCase {
    func testPreferenceStoreDefaultsAndRoundTripsInIsolatedDefaults() throws {
        let suite = "GoosegrassTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsReminderPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.preferences, ReminderPreferences())
        let changed = ReminderPreferences(
            oneDayBeforeEnabled: false,
            twoHoursBeforeEnabled: true,
            thirtyMinutesBeforeEnabled: false,
            soundEnabled: false
        )
        store.preferences = changed

        XCTAssertEqual(UserDefaultsReminderPreferencesStore(defaults: defaults).preferences, changed)
    }

    func testViewModelLoadsPersistsRequestsPermissionAndReconciles() async {
        let store = InMemoryReminderPreferencesStore(preferences: ReminderPreferences())
        let service = FakeNotificationSettingsService()
        service.status = .notDetermined
        let viewModel = NotificationSettingsViewModel(service: service, store: store)

        await viewModel.load()
        XCTAssertEqual(viewModel.authorizationStatus, .notDetermined)
        var changed = viewModel.preferences
        changed.soundEnabled = false
        changed.oneDayBeforeEnabled = false
        viewModel.save(changed)
        XCTAssertEqual(store.preferences, changed)

        await viewModel.requestPermission()
        XCTAssertEqual(viewModel.authorizationStatus, .authorized)
        XCTAssertEqual(service.permissionRequests, 1)
        await viewModel.reconcile()
        XCTAssertEqual(service.reconcileRequests, 1)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testPermissionFailureIsExposedWithoutChangingPreferences() async {
        let initial = ReminderPreferences(soundEnabled: false)
        let store = InMemoryReminderPreferencesStore(preferences: initial)
        let service = FakeNotificationSettingsService()
        service.permissionError = TestPermissionError.denied
        let viewModel = NotificationSettingsViewModel(service: service, store: store)

        await viewModel.requestPermission()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.preferences, initial)
        XCTAssertEqual(store.preferences, initial)
    }
}

@MainActor
private final class FakeNotificationSettingsService: NotificationSettingsServicing {
    var status: LocalNotificationAuthorizationStatus = .authorized
    var permissionError: Error?
    var permissionRequests = 0
    var reconcileRequests = 0

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus { status }
    func requestPermission() async throws -> Bool {
        permissionRequests += 1
        if let permissionError { throw permissionError }
        status = .authorized
        return true
    }
    func reconcilePendingNotifications() async { reconcileRequests += 1 }
}

private enum TestPermissionError: Error { case denied }
