import Foundation

enum TodaySelection: String, CaseIterable, Equatable, Sendable {
    case all
    case todayAppointments
    case upcomingArrivals
    case needContact
    case noShow
}

struct TodayCounts: Equatable, Sendable {
    let todayAppointments: Int
    let upcomingArrivals: Int
    let needContact: Int
    let noShow: Int
}

struct TodaySnapshot: Equatable, Sendable {
    let interval: DateInterval
    let generatedAt: Date
    let counts: TodayCounts
    let allAppointments: [AppointmentListItem]
    let needContactCustomers: [CustomerListItem]

    func appointments(for selection: TodaySelection) -> [AppointmentListItem] {
        switch selection {
        case .all:
            return allAppointments
        case .todayAppointments:
            return allAppointments.filter { $0.appointment.status != .cancelled }
        case .upcomingArrivals:
            return allAppointments.filter { row in
                row.appointment.startAt >= generatedAt
                    && [.confirmed, .upcoming].contains(row.appointment.status)
            }
        case .needContact:
            return []
        case .noShow:
            return allAppointments.filter { $0.appointment.status == .noShow }
        }
    }
}
