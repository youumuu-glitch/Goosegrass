import Foundation

struct CalendarDay: Identifiable, Equatable, Sendable {
    var id: Date { interval.start }

    let interval: DateInterval
    let dayNumber: Int
    let appointments: [AppointmentListItem]

    var statusSummary: String {
        let counts = Dictionary(grouping: appointments, by: { $0.appointment.status })
        return counts.keys.sorted { $0.rawValue < $1.rawValue }
            .map { "\($0.rawValue) \(counts[$0]?.count ?? 0)" }
            .joined(separator: ", ")
    }
}

struct CalendarMonthSnapshot: Equatable, Sendable {
    let monthInterval: DateInterval
    let weekdaySymbols: [String]
    let leadingBlankCount: Int
    let days: [CalendarDay]

    func day(containing date: Date) -> CalendarDay? {
        days.first { date >= $0.interval.start && date < $0.interval.end }
    }
}
