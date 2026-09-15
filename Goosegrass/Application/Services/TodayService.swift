import Foundation

enum TodayServiceError: Error, Equatable, Sendable {
    case unavailableCivilDay(Date)
}

@MainActor
final class TodayService {
    private let appointmentService: AppointmentService
    private let customerService: CustomerService
    private let calendar: Calendar
    private let now: () -> Date

    init(
        appointmentService: AppointmentService,
        customerService: CustomerService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.appointmentService = appointmentService
        self.customerService = customerService
        self.calendar = calendar
        self.now = now
    }

    func snapshot() throws -> TodaySnapshot {
        let generatedAt = now()
        guard let interval = calendar.dateInterval(of: .day, for: generatedAt) else {
            throw TodayServiceError.unavailableCivilDay(generatedAt)
        }
        let appointments = try appointmentService.list(
            filter: AppointmentFilter(dateInterval: interval)
        ).sorted {
            if $0.appointment.startAt != $1.appointment.startAt {
                return $0.appointment.startAt < $1.appointment.startAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
        let needContactCustomers = try customerService.list()
            .filter { $0.customer.status == .needContact && !$0.customer.isArchived }
            .sorted {
                let order = $0.customer.displayName.localizedStandardCompare($1.customer.displayName)
                return order == .orderedSame
                    ? $0.id.uuidString < $1.id.uuidString
                    : order == .orderedAscending
            }
        let provisional = TodaySnapshot(
            interval: interval,
            generatedAt: generatedAt,
            counts: TodayCounts(
                todayAppointments: 0,
                upcomingArrivals: 0,
                needContact: needContactCustomers.count,
                noShow: 0
            ),
            allAppointments: appointments,
            needContactCustomers: needContactCustomers
        )
        return TodaySnapshot(
            interval: interval,
            generatedAt: generatedAt,
            counts: TodayCounts(
                todayAppointments: provisional.appointments(for: .todayAppointments).count,
                upcomingArrivals: provisional.appointments(for: .upcomingArrivals).count,
                needContact: needContactCustomers.count,
                noShow: provisional.appointments(for: .noShow).count
            ),
            allAppointments: appointments,
            needContactCustomers: needContactCustomers
        )
    }

    func detail(appointmentID: UUID) throws -> AppointmentDetail? {
        try appointmentService.detail(id: appointmentID)
    }

    func transition(
        appointmentID: UUID,
        action: AppointmentAction
    ) throws -> Appointment {
        try appointmentService.transition(id: appointmentID, action: action, at: now())
    }

    func reschedule(
        appointmentID: UUID,
        startAt: Date,
        endAt: Date?,
        reason: String
    ) throws -> Appointment {
        try appointmentService.reschedule(
            id: appointmentID,
            startAt: startAt,
            endAt: endAt,
            reason: reason,
            at: now()
        )
    }
}
