import SwiftUI

enum AppDestination: String, CaseIterable, Identifiable {
    case today = "Today"
    case inbox = "Inbox"
    case appointments = "Appointments"
    case calendar = "Calendar"
    case customers = "Customers"
    case followUp = "Follow-up"
    case history = "History"
    case settings = "Settings"

    var id: Self { self }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .inbox: "tray"
        case .appointments: "list.bullet.clipboard"
        case .calendar: "calendar"
        case .customers: "person.2"
        case .followUp: "arrowshape.turn.up.right"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

@MainActor
struct ContentView: View {
    static let initialDestination: AppDestination = .today

    @State private var destination: AppDestination? = Self.initialDestination
    @StateObject private var todayViewModel: TodayViewModel
    @StateObject private var customerViewModel: CustomerListViewModel
    @StateObject private var appointmentViewModel: AppointmentListViewModel
    @StateObject private var settingsViewModel: NotificationSettingsViewModel
    private let reminderService: ReminderService

    init(
        customerService: CustomerService,
        appointmentService: AppointmentService,
        todayService: TodayService,
        reminderService: ReminderService,
        reminderPreferencesStore: any ReminderPreferencesStoring
    ) {
        self.reminderService = reminderService
        _todayViewModel = StateObject(wrappedValue: TodayViewModel(service: todayService))
        _customerViewModel = StateObject(wrappedValue: CustomerListViewModel(service: customerService))
        _appointmentViewModel = StateObject(wrappedValue: AppointmentListViewModel(
            service: appointmentService,
            customerService: customerService
        ))
        _settingsViewModel = StateObject(wrappedValue: NotificationSettingsViewModel(
            service: reminderService,
            store: reminderPreferencesStore
        ))
    }

    var body: some View {
        NavigationSplitView {
            List(AppDestination.allCases, selection: $destination) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("Goosegrass")
            .frame(minWidth: 190)
        } detail: {
            switch destination {
            case .today:
                TodayView(viewModel: todayViewModel) {
                    appointmentViewModel.beginAdd()
                    destination = .appointments
                }
            case .appointments:
                AppointmentsView(viewModel: appointmentViewModel)
            case .customers:
                CustomersView(viewModel: customerViewModel) { customerID in
                    appointmentViewModel.beginAdd(customerID: customerID)
                    destination = .appointments
                }
            case .settings:
                SettingsView(viewModel: settingsViewModel)
            case let .some(item):
                EmptyStateView(
                    icon: item.icon,
                    title: item.rawValue,
                    message: "This workspace arrives in a later phase."
                )
            case .none:
                EmptyStateView(icon: "sidebar.left", title: "Choose a workspace", message: "Select an item in the sidebar.")
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .task { await reminderService.reconcilePendingNotifications() }
    }
}
