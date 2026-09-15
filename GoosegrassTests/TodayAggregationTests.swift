import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class TodayAggregationTests: XCTestCase {
    func testSnapshotDerivesApprovedCountsFiltersAndCompleteHistoryWithoutMutatingStatus() throws {
        let controller = try PersistenceController(inMemory: true)
        let customerRepository = controller.makeCustomerRepository()
        let appointmentRepository = controller.makeAppointmentRepository()
        let customerService = controller.makeCustomerService()
        let appointmentService = controller.makeAppointmentService()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-08T19:00:00Z"))
        let interval = try XCTUnwrap(calendar.dateInterval(of: .day, for: now))
        XCTAssertEqual(interval.duration, 23 * 60 * 60)

        let active = Customer(
            displayName: "Active",
            phone: "13800001234",
            normalizedPhone: "13800001234"
        )
        let needContact = Customer(
            displayName: "Need Contact",
            phone: "13900005678",
            normalizedPhone: "13900005678",
            status: .needContact
        )
        let archived = Customer(
            displayName: "Archived",
            phone: "13700009999",
            normalizedPhone: "13700009999"
        )
        try customerRepository.create(active)
        try customerRepository.create(needContact)
        try customerRepository.create(archived)

        let fixtures: [(UUID, Date, AppointmentStatus)] = [
            (try id(61), interval.start.addingTimeInterval(60 * 60), .confirmed),
            (try id(62), interval.start.addingTimeInterval(13 * 60 * 60), .confirmed),
            (try id(63), interval.start.addingTimeInterval(14 * 60 * 60), .completed),
            (try id(64), interval.start.addingTimeInterval(15 * 60 * 60), .cancelled),
            (try id(65), interval.start.addingTimeInterval(16 * 60 * 60), .noShow),
            (try id(66), interval.start.addingTimeInterval(17 * 60 * 60), .upcoming),
        ]
        for (id, startAt, status) in fixtures {
            try appointmentRepository.create(Appointment(
                id: id,
                customerID: active.id,
                startAt: startAt,
                partySize: 2,
                status: status
            ))
        }
        try appointmentRepository.create(Appointment(
            id: try id(67),
            customerID: active.id,
            startAt: interval.start.addingTimeInterval(-60),
            partySize: 1,
            status: .upcoming
        ))
        try appointmentRepository.create(Appointment(
            id: try id(68),
            customerID: active.id,
            startAt: interval.end.addingTimeInterval(60),
            partySize: 1,
            status: .confirmed
        ))
        let archivedAppointment = Appointment(
            id: try id(69),
            customerID: archived.id,
            startAt: interval.start.addingTimeInterval(12 * 60 * 60),
            partySize: 1,
            status: .upcoming
        )
        try appointmentRepository.create(archivedAppointment)
        try customerRepository.archive(id: archived.id, at: now)

        let service = TodayService(
            appointmentService: appointmentService,
            customerService: customerService,
            calendar: calendar,
            now: { now }
        )
        let snapshot = try service.snapshot()

        XCTAssertEqual(snapshot.interval, interval)
        XCTAssertEqual(snapshot.generatedAt, now)
        XCTAssertEqual(snapshot.counts, TodayCounts(
            todayAppointments: 5,
            upcomingArrivals: 2,
            needContact: 1,
            noShow: 1
        ))
        XCTAssertEqual(snapshot.allAppointments.map(\.id), try [61, 62, 63, 64, 65, 66].map(id))
        XCTAssertEqual(snapshot.appointments(for: .todayAppointments).map(\.id), try [61, 62, 63, 65, 66].map(id))
        XCTAssertEqual(snapshot.appointments(for: .upcomingArrivals).map(\.id), try [62, 66].map(id))
        XCTAssertEqual(snapshot.appointments(for: .noShow).map(\.id), [try id(65)])
        XCTAssertTrue(snapshot.appointments(for: .needContact).isEmpty)
        XCTAssertEqual(snapshot.needContactCustomers.map(\.id), [needContact.id])
        XCTAssertEqual(try appointmentRepository.fetch(id: id(62))?.status, .confirmed)
        XCTAssertNil(try appointmentRepository.fetchList(filter: AppointmentFilter()).first { $0.id == archivedAppointment.id })
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}
