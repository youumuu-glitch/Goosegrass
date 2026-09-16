import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var viewModel: NotificationSettingsViewModel

    var body: some View {
        Form {
            Section("Notification Permission") {
                LabeledContent("Status", value: statusTitle)
                Button("Request Permission") {
                    Task { await viewModel.requestPermission() }
                }
                .disabled(viewModel.isWorking || viewModel.authorizationStatus == .authorized)
                .help("Ask macOS for local notification permission")
            }

            Section("Default Reminders") {
                Toggle("One day before", isOn: preferenceBinding(\.oneDayBeforeEnabled))
                Toggle("Two hours before", isOn: preferenceBinding(\.twoHoursBeforeEnabled))
                Toggle("Thirty minutes before", isOn: preferenceBinding(\.thirtyMinutesBeforeEnabled))
                Toggle("Play sound", isOn: preferenceBinding(\.soundEnabled))
            }

            Section("Consistency") {
                Button("Reconcile Pending Notifications") {
                    Task { await viewModel.reconcile() }
                }
                .disabled(viewModel.isWorking)
                .help("Repair differences between appointments, saved reminders, and pending system notifications")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task { await viewModel.load() }
        .alert("Notification operation failed", isPresented: errorPresented) {
            Button("OK", action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .accessibilityLabel("Notification settings")
    }

    private var statusTitle: String {
        switch viewModel.authorizationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        }
    }

    private func preferenceBinding(_ keyPath: WritableKeyPath<ReminderPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { viewModel.preferences[keyPath: keyPath] },
            set: { value in
                var preferences = viewModel.preferences
                preferences[keyPath: keyPath] = value
                viewModel.save(preferences)
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
    }
}
