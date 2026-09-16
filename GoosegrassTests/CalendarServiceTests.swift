import XCTest
@testable import Goosegrass

@MainActor
final class CalendarServiceTests: XCTestCase {
    func testMonthQueryUsesLocalHalfOpenBoundaryAndKeepsTerminalHistory() throws {
        let controller = try PersistenceController(inMemory: true)
        let customer = Customer(
            displayName: "Calendar Customer",
            phone: "13800000701",
            normalizedPhone: "13800000701"
        )
        try controller.makeCustomerService().create(customer)
        let appointments = controller.makeAppointmentService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let september = try date("2026-09-15T12:00:00Z")
        let cases: [(String, AppointmentStatus)] = [
            ("2026-08-31T23:59:59Z", .completed),
            ("2026-09-01T00:00:00Z", .confirmed),
            ("2026-09-15T12:00:00Z", .noShow),
            ("2026-09-30T23:59:59Z", .cancelled),
            ("2026-10-01T00:00:00Z", .upcoming),
        ]
        for (index, item) in cases.enumerated() {
            try appointments.create(Appointment(
                id: try id(index + 701),
                customerID: customer.id,
                startAt: try date(item.0),
                partySize: 1,
                status: item.1
            ))
        }

        let snapshot = try CalendarService(
            appointmentService: appointments,
            calendar: calendar
        ).snapshot(monthContaining: september)

        XCTAssertEqual(snapshot.days.count, 30)
        XCTAssertEqual(snapshot.days.flatMap(\.appointments).map(\.appointment.status),
                       [.confirmed, .noShow, .cancelled])
        XCTAssertEqual(snapshot.days.first?.appointments.count, 1)
        XCTAssertEqual(snapshot.days.last?.appointments.count, 1)
        XCTAssertEqual(snapshot.days[14].appointments.map(\.appointment.status), [.noShow])
        XCTAssertEqual(snapshot.monthInterval.start, try date("2026-09-01T00:00:00Z"))
        XCTAssertEqual(snapshot.monthInterval.end, try date("2026-10-01T00:00:00Z"))
    }

    private func date(_ text: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: text))
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}
