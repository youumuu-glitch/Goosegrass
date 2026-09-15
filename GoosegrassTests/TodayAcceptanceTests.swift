import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class TodayAcceptanceTests: XCTestCase {
    func testDashboardSemanticsAndActionsSurviveTwoRelaunches() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-15T10:00:00Z"))
        let day = try XCTUnwrap(calendar.dateInterval(of: .day, for: now))
        let activeCustomerID = try id(80)
        let needContactCustomerID = try id(89)
        let ids = try (81...88).map(id)

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let customers = controller.makeCustomerService()
            try customers.create(Customer(
                id: activeCustomerID,
                displayName: "Today Acceptance",
                phone: "13800008888",
                normalizedPhone: "13800008888"
            ))
            try customers.create(Customer(
                id: needContactCustomerID,
                displayName: "Need Contact",
                phone: "13900009999",
                normalizedPhone: "13900009999",
                status: .needContact
            ))

            let statuses: [AppointmentStatus] = [
                .confirmed, .confirmed, .upcoming, .upcoming,
                .upcoming, .completed, .cancelled, .noShow,
            ]
            let appointments = controller.makeAppointmentRepository()
            for index in ids.indices {
                try appointments.create(Appointment(
                    id: ids[index],
                    customerID: activeCustomerID,
                    startAt: day.start.addingTimeInterval(Double(index + 11) * 3_600),
                    partySize: index + 1,
                    status: statuses[index],
                    createdAt: day.start,
                    updatedAt: day.start
                ))
            }
        }

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let service = controller.makeTodayService(calendar: calendar, now: { now })
            let initial = try service.snapshot()

            XCTAssertEqual(initial.counts, TodayCounts(
                todayAppointments: 7,
                upcomingArrivals: 5,
                needContact: 1,
                noShow: 1
            ))
            XCTAssertEqual(initial.allAppointments.map(\.id), ids)
            XCTAssertEqual(initial.appointments(for: .todayAppointments).map(\.id), ids.filter { $0 != ids[6] })
            XCTAssertEqual(try controller.makeAppointmentRepository().fetch(id: ids[0])?.status, .confirmed)

            let viewModel = TodayViewModel(service: service)
            viewModel.load()

            viewModel.selectAppointment(ids[2])
            viewModel.perform(.arrive)
            viewModel.selectAppointment(ids[1])
            viewModel.perform(.cancel)
            XCTAssertEqual(viewModel.pendingAction, .cancel)
            viewModel.confirmPendingAction()
            viewModel.selectAppointment(ids[3])
            viewModel.perform(.markNoShow)
            viewModel.selectAppointment(ids[4])
            viewModel.beginReschedule()
            let movedStart = day.start.addingTimeInterval(19 * 3_600)
            viewModel.rescheduleDraft?.startAt = movedStart
            viewModel.saveReschedule(reason: "磁盘验收改期")

            XCTAssertNil(viewModel.errorMessage)
            XCTAssertEqual(viewModel.snapshot?.counts, TodayCounts(
                todayAppointments: 6,
                upcomingArrivals: 1,
                needContact: 1,
                noShow: 2
            ))
            XCTAssertEqual(viewModel.snapshot?.allAppointments.count, ids.count)
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let service = reopened.makeTodayService(calendar: calendar, now: { now })
        let final = try service.snapshot()
        XCTAssertEqual(final.counts, TodayCounts(
            todayAppointments: 6,
            upcomingArrivals: 1,
            needContact: 1,
            noShow: 2
        ))
        XCTAssertEqual(Set(final.allAppointments.map(\.id)), Set(ids))
        XCTAssertEqual(final.appointments(for: .upcomingArrivals).map(\.id), [ids[0]])

        let expectedStatuses: [AppointmentStatus] = [
            .confirmed, .cancelled, .arrived, .noShow,
            .rescheduled, .completed, .cancelled, .noShow,
        ]
        let appointmentService = reopened.makeAppointmentService()
        for index in ids.indices {
            let detail = try XCTUnwrap(appointmentService.detail(id: ids[index]))
            XCTAssertEqual(detail.listItem.appointment.status, expectedStatuses[index])
            XCTAssertEqual(detail.listItem.appointment.customerID, activeCustomerID)
            XCTAssertEqual(detail.changes.count, (1...4).contains(index) ? 1 : 0)
            XCTAssertEqual(detail.activities.count, (1...4).contains(index) ? 1 : 0)
        }
        XCTAssertEqual(
            Set(try XCTUnwrap(reopened.makeCustomerService().fetch(id: activeCustomerID)).appointmentIDs),
            Set(ids)
        )
        XCTAssertEqual(try reopened.makeAppointmentRepository().fetch(id: ids[0])?.status, .confirmed)
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}
