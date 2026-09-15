import Foundation
import SwiftData
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

    func testLocalRepositoryFiltersEnrichesAndOrdersAggregates() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = LocalCustomerRepository(context: controller.context)
        let appointments = LocalAppointmentRepository(context: controller.context)
        try customers.seedDefaultSources()
        let source = try XCTUnwrap(customers.fetchCatalog().sources.first { $0.name == "微信" })
        let tag = try customers.upsertTag(named: "VIP")
        let activeCustomer = Customer(
            displayName: "活跃客户",
            phone: "13800006666",
            normalizedPhone: "13800006666",
            sourceID: source.id,
            tagIDs: [tag.id]
        )
        let archivedCustomer = Customer(
            displayName: "归档客户",
            phone: "13800007777",
            normalizedPhone: "13800007777",
            status: .archived,
            isArchived: true
        )
        try customers.create(activeCustomer)
        try customers.create(archivedCustomer)

        let earlier = Appointment(
            customerID: activeCustomer.id,
            startAt: Date(timeIntervalSince1970: 1_000),
            partySize: 1,
            status: .draft
        )
        let target = Appointment(
            customerID: activeCustomer.id,
            startAt: Date(timeIntervalSince1970: 2_000),
            partySize: 2,
            status: .confirmed,
            sourceID: source.id
        )
        let archived = Appointment(
            customerID: archivedCustomer.id,
            startAt: Date(timeIntervalSince1970: 2_000),
            partySize: 3,
            status: .confirmed
        )
        let olderChange = AppointmentChange(
            appointmentID: target.id,
            changeType: .statusChanged,
            oldValueJSON: "\"draft\"",
            newValueJSON: "\"pendingConfirmation\"",
            changedAt: Date(timeIntervalSince1970: 10)
        )
        let newerChange = AppointmentChange(
            appointmentID: target.id,
            changeType: .statusChanged,
            oldValueJSON: "\"pendingConfirmation\"",
            newValueJSON: "\"confirmed\"",
            changedAt: Date(timeIntervalSince1970: 20)
        )
        let olderActivity = Activity(
            customerID: activeCustomer.id,
            appointmentID: target.id,
            type: .appointmentCreated,
            title: "Created",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let newerActivity = Activity(
            customerID: activeCustomer.id,
            appointmentID: target.id,
            type: .appointmentConfirmed,
            title: "Confirmed",
            createdAt: Date(timeIntervalSince1970: 20)
        )

        try appointments.commit(AppointmentMutation(appointment: earlier, changes: [], activities: [], isNew: true))
        try appointments.commit(AppointmentMutation(
            appointment: target,
            changes: [olderChange, newerChange],
            activities: [olderActivity, newerActivity],
            isNew: true
        ))
        // Compatibility CRUD models legacy appointment data whose customer is now archived.
        try appointments.create(archived)

        let targetRecord = try XCTUnwrap(
            controller.context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>())
                .first { $0.id == target.id }
        )
        controller.context.insert(PersistenceSchemaV1.ReminderRecord(
            appointmentID: target.id,
            typeRawValue: ReminderType.twoHoursBefore.rawValue,
            fireAt: Date(timeIntervalSince1970: 1_900),
            statusRawValue: ReminderStatus.scheduled.rawValue,
            appointment: targetRecord
        ))
        try controller.context.save()

        XCTAssertEqual(try appointments.fetchList(filter: AppointmentFilter()).map(\.id), [earlier.id, target.id])
        let dateFilter = AppointmentFilter(dateInterval: DateInterval(
            start: Date(timeIntervalSince1970: 1_900),
            end: Date(timeIntervalSince1970: 2_100)
        ))
        XCTAssertEqual(try appointments.fetchList(filter: dateFilter).map(\.id), [target.id])
        XCTAssertEqual(
            try appointments.fetchList(filter: AppointmentFilter(statuses: [.confirmed])).map(\.id),
            [target.id]
        )
        XCTAssertEqual(
            try appointments.fetchList(filter: AppointmentFilter(customerID: activeCustomer.id)).map(\.id),
            [earlier.id, target.id]
        )
        XCTAssertEqual(
            try appointments.fetchList(filter: AppointmentFilter(sourceID: source.id)).map(\.id),
            [target.id]
        )
        XCTAssertEqual(
            try appointments.fetchList(filter: AppointmentFilter(tagID: tag.id)).map(\.id),
            [earlier.id, target.id]
        )

        let combined = AppointmentFilter(
            dateInterval: dateFilter.dateInterval,
            statuses: [.confirmed],
            customerID: activeCustomer.id,
            sourceID: source.id,
            tagID: tag.id
        )
        let row = try XCTUnwrap(appointments.fetchList(filter: combined).first)
        XCTAssertEqual(row.customerName, "活跃客户")
        XCTAssertEqual(row.customerPhone, "13800006666")
        XCTAssertEqual(row.sourceName, "微信")
        XCTAssertEqual(row.tagNames, ["VIP"])
        XCTAssertEqual(row.reminderStatuses, [.scheduled])

        let detail = try XCTUnwrap(appointments.fetchDetail(id: target.id))
        XCTAssertEqual(detail.changes.map(\.id), [newerChange.id, olderChange.id])
        XCTAssertEqual(detail.activities.map(\.id), [newerActivity.id, olderActivity.id])
    }

    func testInvalidCustomerMutationWritesNothing() throws {
        let controller = try PersistenceController(inMemory: true)
        let appointments = LocalAppointmentRepository(context: controller.context)
        let orphan = Appointment(
            customerID: UUID(),
            startAt: Date(timeIntervalSince1970: 3_000),
            partySize: 1
        )
        let change = AppointmentChange(
            appointmentID: orphan.id,
            changeType: .statusChanged,
            oldValueJSON: "null",
            newValueJSON: "\"draft\""
        )
        let activity = Activity(
            customerID: orphan.customerID,
            appointmentID: orphan.id,
            type: .appointmentCreated,
            title: "Created"
        )

        XCTAssertThrowsError(try appointments.commit(AppointmentMutation(
            appointment: orphan,
            changes: [change],
            activities: [activity],
            isNew: true
        )))
        XCTAssertNil(try appointments.fetch(id: orphan.id))
        XCTAssertTrue(try appointments.fetchChanges(appointmentID: orphan.id).isEmpty)
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
