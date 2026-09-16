import Foundation

enum CalendarServiceError: Error, Equatable, Sendable {
    case unavailableMonth(Date)
    case unavailableDay(Date)
}

@MainActor
final class CalendarService {
    private let appointmentService: AppointmentService
    private let calendar: Calendar

    init(appointmentService: AppointmentService, calendar: Calendar = .current) {
        self.appointmentService = appointmentService
        self.calendar = calendar
    }

    func snapshot(monthContaining date: Date) throws -> CalendarMonthSnapshot {
        guard let month = calendar.dateInterval(of: .month, for: date) else {
            throw CalendarServiceError.unavailableMonth(date)
        }
        let queried = try appointmentService.list(filter: AppointmentFilter(dateInterval: month))
        let appointments = queried
            .filter { $0.appointment.startAt >= month.start && $0.appointment.startAt < month.end }
            .sorted(by: Self.isEarlier)
        guard let dayCount = calendar.range(of: .day, in: .month, for: month.start)?.count,
              let firstWeekday = calendar.dateComponents([.weekday], from: month.start).weekday else {
            throw CalendarServiceError.unavailableMonth(date)
        }
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let orderedSymbols = (0..<7).map { symbols[(calendar.firstWeekday - 1 + $0) % 7] }
        var days: [CalendarDay] = []
        for offset in 0..<dayCount {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: month.start),
                  let interval = calendar.dateInterval(of: .day, for: dayStart),
                  let dayNumber = calendar.dateComponents([.day], from: dayStart).day else {
                throw CalendarServiceError.unavailableDay(month.start)
            }
            let rows = appointments.filter {
                $0.appointment.startAt >= interval.start && $0.appointment.startAt < interval.end
            }
            days.append(CalendarDay(interval: interval, dayNumber: dayNumber, appointments: rows))
        }
        return CalendarMonthSnapshot(
            monthInterval: month,
            weekdaySymbols: orderedSymbols,
            leadingBlankCount: leading,
            days: days
        )
    }

    func detail(appointmentID: UUID) throws -> AppointmentDetail? {
        try appointmentService.detail(id: appointmentID)
    }

    private static func isEarlier(_ lhs: AppointmentListItem, _ rhs: AppointmentListItem) -> Bool {
        if lhs.appointment.startAt != rhs.appointment.startAt {
            return lhs.appointment.startAt < rhs.appointment.startAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
