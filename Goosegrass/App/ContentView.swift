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
    @State private var destination: AppDestination? = .customers
    @StateObject private var customerViewModel: CustomerListViewModel

    init(customerService: CustomerService) {
        _customerViewModel = StateObject(wrappedValue: CustomerListViewModel(service: customerService))
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
            case .customers:
                CustomersView(viewModel: customerViewModel)
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
    }
}
