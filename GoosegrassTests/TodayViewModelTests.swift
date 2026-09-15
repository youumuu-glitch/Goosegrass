import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testLoadAndCardsSwitchBetweenCompleteHistoryAndApprovedSubsets() throws {
        let system = try makeSystem()

        system.viewModel.load()
        XCTAssertEqual(system.viewModel.selection, .all)
        XCTAssertEqual(system.viewModel.appointmentRows.map(\.id), system.allAppointmentIDs)
        XCTAssertEqual(system.viewModel.snapshot?.counts, TodayCounts(
            todayAppointments: 4,
            upcomingArrivals: 2,
            needContact: 1,
            noShow: 1
        ))

        system.viewModel.selectCard(.todayAppointments)
        XCTAssertFalse(system.viewModel.appointmentRows.contains { $0.appointment.status == .cancelled })
        system.viewModel.selectCard(.upcomingArrivals)
        XCTAssertEqual(system.viewModel.appointmentRows.map(\.appointment.status), [.confirmed, .upcoming])
        system.viewModel.selectCard(.needContact)
        XCTAssertTrue(system.viewModel.appointmentRows.isEmpty)
        XCTAssertEqual(system.viewModel.customerRows.map(\.customer.status), [.needContact])
        system.viewModel.selectCard(.all)
        XCTAssertEqual(system.viewModel.appointmentRows.map(\.id), system.allAppointmentIDs)
    }

    func testQuickActionsUseLifecycleAndReloadAuthoritativeCounts() throws {
        let system = try makeSystem()
        system.viewModel.load()
        system.viewModel.selectAppointment(system.upcomingID)

        XCTAssertEqual(system.viewModel.availableQuickActions, [.arrive, .reschedule, .markNoShow, .cancel])
        system.viewModel.perform(.arrive)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .arrived)
        XCTAssertEqual(system.viewModel.snapshot?.counts.upcomingArrivals, 1)

        system.viewModel.selectAppointment(system.draftID)
        system.viewModel.perform(.cancel)
        XCTAssertEqual(system.viewModel.pendingAction, .cancel)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .draft)
        system.viewModel.confirmPendingAction()
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .cancelled)
        XCTAssertEqual(system.viewModel.snapshot?.counts.todayAppointments, 3)
        XCTAssertTrue(system.viewModel.snapshot?.allAppointments.contains { $0.id == system.draftID } == true)
    }

    func testRescheduleRefreshesFromServiceAndFailurePreservesDraft() throws {
        let system = try makeSystem()
        system.viewModel.load()
        system.viewModel.selectAppointment(system.upcomingID)
        system.viewModel.beginReschedule()
        let movedStart = system.now.addingTimeInterval(4 * 60 * 60)
        system.viewModel.rescheduleDraft?.startAt = movedStart
        system.viewModel.saveReschedule(reason: "客户改期")

        XCTAssertNil(system.viewModel.rescheduleDraft)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.status, .rescheduled)
        XCTAssertEqual(system.viewModel.detail?.listItem.appointment.startAt, movedStart)
        XCTAssertEqual(system.viewModel.snapshot?.counts.upcomingArrivals, 1)

        system.viewModel.selectAppointment(system.confirmedID)
        system.viewModel.beginReschedule()
        try system.customerRepository.archive(id: system.activeCustomerID, at: system.now)
        system.viewModel.rescheduleDraft?.startAt = movedStart.addingTimeInterval(60)
        system.viewModel.saveReschedule(reason: "应失败")
        XCTAssertNotNil(system.viewModel.errorMessage)
        XCTAssertNotNil(system.viewModel.rescheduleDraft)
        XCTAssertEqual(
            try system.appointmentRepository.fetch(id: system.confirmedID)?.status,
            .confirmed
        )
    }

    private func makeSystem() throws -> TestSystem {
        let controller = try PersistenceController(inMemory: true)
        let customers = controller.makeCustomerRepository()
        let appointments = controller.makeAppointmentRepository()
        let active = Customer(displayName: "Active", phone: "13800001234", normalizedPhone: "13800001234")
        let needContact = Customer(displayName: "Need", phone: "13900005678", normalizedPhone: "13900005678", status: .needContact)
        try customers.create(active)
        try customers.create(needContact)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-15T10:00:00Z"))
        let day = try XCTUnwrap(calendar.dateInterval(of: .day, for: now))
        let confirmedID = try id(71)
        let upcomingID = try id(72)
        let draftID = try id(73)
        let noShowID = try id(74)
        for appointment in [
            Appointment(id: confirmedID, customerID: active.id, startAt: day.start.addingTimeInterval(12 * 3_600), partySize: 1, status: .confirmed),
            Appointment(id: upcomingID, customerID: active.id, startAt: day.start.addingTimeInterval(13 * 3_600), partySize: 2, status: .upcoming),
            Appointment(id: draftID, customerID: active.id, startAt: day.start.addingTimeInterval(14 * 3_600), partySize: 3, status: .draft),
            Appointment(id: noShowID, customerID: active.id, startAt: day.start.addingTimeInterval(15 * 3_600), partySize: 4, status: .noShow),
        ] {
            try appointments.create(appointment)
        }
        let service = TodayService(
            appointmentService: controller.makeAppointmentService(),
            customerService: controller.makeCustomerService(),
            calendar: calendar,
            now: { now }
        )
        return TestSystem(
            controller: controller,
            customerRepository: customers,
            appointmentRepository: appointments,
            viewModel: TodayViewModel(service: service),
            activeCustomerID: active.id,
            confirmedID: confirmedID,
            upcomingID: upcomingID,
            draftID: draftID,
            allAppointmentIDs: [confirmedID, upcomingID, draftID, noShowID],
            now: now
        )
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private struct TestSystem {
    let controller: PersistenceController
    let customerRepository: LocalCustomerRepository
    let appointmentRepository: LocalAppointmentRepository
    let viewModel: TodayViewModel
    let activeCustomerID: UUID
    let confirmedID: UUID
    let upcomingID: UUID
    let draftID: UUID
    let allAppointmentIDs: [UUID]
    let now: Date
}
