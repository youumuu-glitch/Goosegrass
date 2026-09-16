import XCTest
import SwiftData
@testable import Goosegrass

@MainActor
final class FollowUpRepositoryTests: XCTestCase {
    func testCommitCreatesRelationshipsAndActivityAtomically() throws {
        let system = try makeSystem()
        let followUp = FollowUp(
            id: try id(203),
            customerID: system.customerID,
            appointmentID: system.appointmentID,
            dueAt: Date(timeIntervalSince1970: 4_000),
            reason: "No-show follow-up",
            note: "Offer another time",
            priority: .high,
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let activity = Activity(
            id: try id(204),
            customerID: system.customerID,
            appointmentID: system.appointmentID,
            type: .followUpCreated,
            title: "Follow-up created",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try system.repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [activity],
            isNew: true
        ))

        let detail = try XCTUnwrap(system.repository.fetchDetail(id: followUp.id))
        XCTAssertEqual(detail.listItem.followUp, followUp)
        XCTAssertEqual(detail.listItem.customerName, "Follow-up Customer")
        XCTAssertEqual(detail.listItem.customerPhone, "13800000201")
        XCTAssertEqual(detail.appointmentStartAt, Date(timeIntervalSince1970: 3_000))
        XCTAssertEqual(try system.controller.makeCustomerRepository().fetch(id: system.customerID)?.followUpIDs, [followUp.id])
        XCTAssertEqual(
            try system.controller.makeCustomerRepository().fetchDetail(id: system.customerID)?.activities.map(\.id),
            [activity.id]
        )
        let appointmentRecord = try XCTUnwrap(
            system.controller.context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>())
                .first { $0.id == system.appointmentID }
        )
        XCTAssertEqual(appointmentRecord.followUps.map(\.id), [followUp.id])
    }

    func testActiveAndAllFiltersUseDeterministicDuePriorityCreationOrdering() throws {
        let system = try makeSystem()
        let commonDue = Date(timeIntervalSince1970: 5_000)
        let records = [
            FollowUp(id: try id(205), customerID: system.customerID, dueAt: commonDue, reason: "Normal", priority: .normal, createdAt: Date(timeIntervalSince1970: 30), updatedAt: Date(timeIntervalSince1970: 30)),
            FollowUp(id: try id(206), customerID: system.customerID, dueAt: commonDue, reason: "High newer", priority: .high, status: .snoozed, createdAt: Date(timeIntervalSince1970: 20), updatedAt: Date(timeIntervalSince1970: 20)),
            FollowUp(id: try id(207), customerID: system.customerID, dueAt: commonDue, reason: "High older", priority: .high, createdAt: Date(timeIntervalSince1970: 10), updatedAt: Date(timeIntervalSince1970: 10)),
            FollowUp(id: try id(208), customerID: system.customerID, dueAt: Date(timeIntervalSince1970: 4_000), reason: "Completed", status: .completed, completedAt: Date(timeIntervalSince1970: 3_000)),
            FollowUp(id: try id(209), customerID: system.customerID, dueAt: Date(timeIntervalSince1970: 6_000), reason: "Cancelled", status: .cancelled),
        ]
        for followUp in records {
            try system.repository.commit(FollowUpMutation(followUp: followUp, activities: [], isNew: true))
        }

        XCTAssertEqual(
            try system.repository.fetchList(filter: FollowUpListFilter(scope: .active)).map(\.id),
            [try id(207), try id(206), try id(205)]
        )
        XCTAssertEqual(
            try system.repository.fetchList(filter: FollowUpListFilter(scope: .all)).map(\.id),
            [try id(208), try id(207), try id(206), try id(205), try id(209)]
        )
    }

    func testAppointmentMustBelongToFollowUpCustomerAndFailureWritesNothing() throws {
        let system = try makeSystem()
        let otherCustomerID = try id(210)
        try system.controller.makeCustomerRepository().create(Customer(
            id: otherCustomerID,
            displayName: "Other",
            phone: "13900000210",
            normalizedPhone: "13900000210"
        ))
        let followUp = FollowUp(
            id: try id(211),
            customerID: otherCustomerID,
            appointmentID: system.appointmentID,
            dueAt: Date(timeIntervalSince1970: 8_000),
            reason: "Mismatch"
        )
        let activity = Activity(
            id: try id(212),
            customerID: otherCustomerID,
            appointmentID: system.appointmentID,
            type: .followUpCreated,
            title: "Should not persist"
        )

        XCTAssertThrowsError(try system.repository.commit(FollowUpMutation(
            followUp: followUp,
            activities: [activity],
            isNew: true
        ))) { error in
            XCTAssertEqual(
                error as? PersistenceError,
                .appointmentCustomerMismatch(appointmentID: system.appointmentID, customerID: otherCustomerID)
            )
        }
        XCTAssertNil(try system.repository.fetch(id: followUp.id))
        XCTAssertFalse(
            try system.controller.context.fetch(FetchDescriptor<PersistenceSchemaV1.ActivityRecord>())
                .contains { $0.id == activity.id }
        )
    }

    func testInvalidStoredPriorityAndStatusAreReported() throws {
        let system = try makeSystem()
        let invalidPriority = PersistenceSchemaV1.FollowUpRecord(
            id: try id(213),
            customerID: system.customerID,
            dueAt: Date(timeIntervalSince1970: 9_000),
            reason: "Invalid priority",
            priorityRawValue: "urgent",
            customer: try customerRecord(in: system)
        )
        system.controller.context.insert(invalidPriority)
        try system.controller.context.save()
        XCTAssertThrowsError(try system.repository.fetch(id: invalidPriority.id)) { error in
            XCTAssertEqual(error as? PersistenceError, .invalidStoredValue(field: "FollowUp.priority", value: "urgent"))
        }

        invalidPriority.priorityRawValue = FollowUpPriority.normal.rawValue
        invalidPriority.statusRawValue = "done-ish"
        try system.controller.context.save()
        XCTAssertThrowsError(try system.repository.fetch(id: invalidPriority.id)) { error in
            XCTAssertEqual(error as? PersistenceError, .invalidStoredValue(field: "FollowUp.status", value: "done-ish"))
        }
    }

    func testFollowUpSurvivesDiskRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let customerID = try id(214)
        let followUpID = try id(215)

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            try controller.makeCustomerRepository().create(Customer(
                id: customerID,
                displayName: "Disk Follow-up",
                phone: "13800000214",
                normalizedPhone: "13800000214"
            ))
            try controller.makeFollowUpRepository().commit(FollowUpMutation(
                followUp: FollowUp(
                    id: followUpID,
                    customerID: customerID,
                    dueAt: Date(timeIntervalSince1970: 10_000),
                    reason: "Persist me",
                    priority: .low
                ),
                activities: [],
                isNew: true
            ))
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let followUp = try XCTUnwrap(reopened.makeFollowUpRepository().fetch(id: followUpID))
        XCTAssertEqual(followUp.customerID, customerID)
        XCTAssertEqual(followUp.reason, "Persist me")
        XCTAssertEqual(followUp.priority, .low)
        XCTAssertEqual(followUp.status, .pending)
    }

    private func makeSystem() throws -> FollowUpRepositorySystem {
        let controller = try PersistenceController(inMemory: true)
        let customerID = try id(201)
        let appointmentID = try id(202)
        try controller.makeCustomerRepository().create(Customer(
            id: customerID,
            displayName: "Follow-up Customer",
            phone: "13800000201",
            normalizedPhone: "13800000201"
        ))
        try controller.makeAppointmentRepository().create(Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: Date(timeIntervalSince1970: 3_000),
            partySize: 2,
            status: .noShow
        ))
        return FollowUpRepositorySystem(
            controller: controller,
            repository: controller.makeFollowUpRepository(),
            customerID: customerID,
            appointmentID: appointmentID
        )
    }

    private func customerRecord(in system: FollowUpRepositorySystem) throws -> PersistenceSchemaV1.CustomerRecord {
        try XCTUnwrap(
            system.controller.context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>())
                .first { $0.id == system.customerID }
        )
    }

    private func id(_ value: Int) throws -> UUID {
        try XCTUnwrap(UUID(uuidString: String(format: "%08d-0000-0000-0000-%012d", value, value)))
    }
}

@MainActor
private struct FollowUpRepositorySystem {
    let controller: PersistenceController
    let repository: LocalFollowUpRepository
    let customerID: UUID
    let appointmentID: UUID
}
