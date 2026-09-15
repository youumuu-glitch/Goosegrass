import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentAcceptanceTests: XCTestCase {
    func testAllLifecyclePathsSurviveRelaunchWithHistoryAndRelationships() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let customerID = try XCTUnwrap(UUID(uuidString: "51515151-5151-5151-5151-515151515151"))
        let ids = try ["52", "53", "54", "55"].map { pair in
            try XCTUnwrap(UUID(uuidString: "\(pair)\(pair)\(pair)\(pair)-\(pair)\(pair)-\(pair)\(pair)-\(pair)\(pair)-\(pair)\(pair)\(pair)\(pair)\(pair)\(pair)"))
        }
        let base = Date(timeIntervalSince1970: 2_000_000_000)

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            try controller.makeCustomerService().create(Customer(
                id: customerID,
                displayName: "验收客户",
                phone: "13800008888",
                normalizedPhone: "13800008888"
            ))
            let repository = controller.makeAppointmentRepository()
            for (offset, id) in ids.enumerated() {
                try repository.create(Appointment(
                    id: id,
                    customerID: customerID,
                    startAt: base.addingTimeInterval(Double(offset * 3_600)),
                    partySize: offset + 1,
                    createdAt: base,
                    updatedAt: base
                ))
            }
        }

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let service = controller.makeAppointmentService()
            var tick = 1
            func at() -> Date { defer { tick += 1 }; return base.addingTimeInterval(Double(tick)) }

            for action in [AppointmentAction.submit, .confirm, .markUpcoming, .arrive, .complete] {
                _ = try service.transition(id: ids[0], action: action, at: at())
            }
            _ = try service.transition(id: ids[1], action: .cancel, at: at())
            for action in [AppointmentAction.submit, .confirm, .markUpcoming] {
                _ = try service.transition(id: ids[2], action: action, at: at())
            }
            _ = try service.reschedule(
                id: ids[2],
                startAt: base.addingTimeInterval(86_400),
                endAt: nil,
                reason: "客户改期",
                at: at()
            )
            _ = try service.transition(id: ids[2], action: .confirm, at: at())
            for action in [AppointmentAction.submit, .confirm, .markUpcoming, .markNoShow] {
                _ = try service.transition(id: ids[3], action: action, at: at())
            }
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let service = reopened.makeAppointmentService()
        let customer = try XCTUnwrap(reopened.makeCustomerService().fetch(id: customerID))
        XCTAssertEqual(Set(customer.appointmentIDs), Set(ids))
        let expected: [AppointmentStatus] = [.completed, .cancelled, .confirmed, .noShow]
        let expectedChanges = [5, 1, 5, 4]
        for index in ids.indices {
            let detail = try XCTUnwrap(service.detail(id: ids[index]))
            XCTAssertEqual(detail.listItem.appointment.id, ids[index])
            XCTAssertEqual(detail.listItem.appointment.customerID, customerID)
            XCTAssertEqual(detail.listItem.appointment.status, expected[index])
            XCTAssertEqual(detail.changes.count, expectedChanges[index])
            XCTAssertEqual(detail.activities.count, expectedChanges[index])
            XCTAssertEqual(detail.changes, detail.changes.sorted { $0.changedAt > $1.changedAt })
        }
        for id in [ids[0], ids[1], ids[3]] {
            let status = try XCTUnwrap(service.detail(id: id)?.listItem.appointment.status)
            XCTAssertTrue(AppointmentLifecycle.allowedActions(from: status).isEmpty)
        }
        XCTAssertNotNil(try service.detail(id: ids[0])?.listItem.appointment.completedAt)
        XCTAssertNotNil(try service.detail(id: ids[1])?.listItem.appointment.cancelledAt)
        XCTAssertNotNil(try service.detail(id: ids[3])?.listItem.appointment.noShowAt)
    }
}
