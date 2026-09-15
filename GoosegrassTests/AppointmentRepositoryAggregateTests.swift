import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentRepositoryAggregateTests: XCTestCase {
    func testAggregateContractCarriesFiltersAndPresentationContext() throws {
        let customerID = try XCTUnwrap(UUID(uuidString: "41414141-4141-4141-4141-414141414141"))
        let sourceID = try XCTUnwrap(UUID(uuidString: "42424242-4242-4242-4242-424242424242"))
        let tagID = try XCTUnwrap(UUID(uuidString: "43434343-4343-4343-4343-434343434343"))
        let appointment = Appointment(
            customerID: customerID,
            startAt: Date(timeIntervalSince1970: 2_000_000_000),
            partySize: 2,
            status: .confirmed,
            sourceID: sourceID
        )
        let filter = AppointmentFilter(
            dateInterval: DateInterval(
                start: Date(timeIntervalSince1970: 1_999_999_000),
                end: Date(timeIntervalSince1970: 2_000_001_000)
            ),
            statuses: [.confirmed, .upcoming],
            customerID: customerID,
            sourceID: sourceID,
            tagID: tagID
        )
        let listItem = AppointmentListItem(
            appointment: appointment,
            customerName: "林女士",
            customerPhone: "13800004444",
            sourceName: "微信",
            tagNames: ["VIP"],
            reminderStatuses: [.scheduled, .delivered]
        )

        XCTAssertEqual(listItem.id, appointment.id)
        XCTAssertEqual(filter.statuses, [.confirmed, .upcoming])
        XCTAssertEqual(filter.customerID, customerID)
        XCTAssertEqual(filter.sourceID, sourceID)
        XCTAssertEqual(filter.tagID, tagID)
        XCTAssertEqual(listItem.customerName, "林女士")
        XCTAssertEqual(listItem.sourceName, "微信")
        XCTAssertEqual(listItem.tagNames, ["VIP"])
        XCTAssertEqual(listItem.reminderStatuses, [.scheduled, .delivered])
    }

    func testAggregateContractReturnsNewestHistoryAndAcceptsOneMutation() throws {
        let appointment = Appointment(
            customerID: UUID(),
            startAt: Date(timeIntervalSince1970: 2_000_000_000),
            partySize: 4
        )
        let olderChange = AppointmentChange(
            appointmentID: appointment.id,
            changeType: .statusChanged,
            oldValueJSON: "\"draft\"",
            newValueJSON: "\"pendingConfirmation\"",
            changedAt: Date(timeIntervalSince1970: 10)
        )
        let newerChange = AppointmentChange(
            appointmentID: appointment.id,
            changeType: .statusChanged,
            oldValueJSON: "\"pendingConfirmation\"",
            newValueJSON: "\"confirmed\"",
            changedAt: Date(timeIntervalSince1970: 20)
        )
        let olderActivity = Activity(
            customerID: appointment.customerID,
            appointmentID: appointment.id,
            type: .appointmentCreated,
            title: "Created",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let newerActivity = Activity(
            customerID: appointment.customerID,
            appointmentID: appointment.id,
            type: .appointmentConfirmed,
            title: "Confirmed",
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let item = AppointmentListItem(
            appointment: appointment,
            customerName: "周先生",
            customerPhone: "13900005555",
            sourceName: nil,
            tagNames: [],
            reminderStatuses: []
        )
        let detail = AppointmentDetail(
            listItem: item,
            changes: [newerChange, olderChange],
            activities: [newerActivity, olderActivity]
        )
        let mutation = AppointmentMutation(
            appointment: appointment,
            changes: [newerChange],
            activities: [newerActivity],
            isNew: false
        )
        let repository = AggregateContractRepository(detail: detail)

        XCTAssertEqual(try repository.fetchDetail(id: appointment.id), detail)
        XCTAssertEqual(try repository.fetchChanges(appointmentID: appointment.id), [newerChange, olderChange])
        try repository.commit(mutation)
        XCTAssertEqual(repository.committedMutation, mutation)
    }
}

@MainActor
private final class AggregateContractRepository: AppointmentRepository {
    private let detail: AppointmentDetail
    private(set) var committedMutation: AppointmentMutation?

    init(detail: AppointmentDetail) {
        self.detail = detail
    }

    func create(_ appointment: Appointment) throws {}
    func update(_ appointment: Appointment) throws {}
    func fetch(id: UUID) throws -> Appointment? { id == detail.listItem.id ? detail.listItem.appointment : nil }
    func fetchAll(customerID: UUID?) throws -> [Appointment] { [detail.listItem.appointment] }
    func deleteDraft(id: UUID) throws {}
    func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem] { [detail.listItem] }
    func fetchDetail(id: UUID) throws -> AppointmentDetail? { id == detail.listItem.id ? detail : nil }
    func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange] { detail.changes }
    func commit(_ mutation: AppointmentMutation) throws { committedMutation = mutation }
}
