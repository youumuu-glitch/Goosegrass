import Foundation
import SwiftData
import XCTest
@testable import Goosegrass

@MainActor
final class PersistenceRepositoryTests: XCTestCase {
    func testCustomerCRUDSearchDuplicateCandidatesAndArchive() throws {
        let controller = try PersistenceController(inMemory: true)
        let repository = LocalCustomerRepository(context: controller.context)
        let id = try XCTUnwrap(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let sourceID = try XCTUnwrap(UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB"))
        var customer = Customer(
            id: id,
            displayName: "王女士",
            phone: "138 0000 8888",
            normalizedPhone: "13800008888",
            sourceID: sourceID,
            notes: "初次咨询",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        try repository.create(customer)
        XCTAssertEqual(try repository.fetch(id: id)?.displayName, "王女士")
        XCTAssertEqual(try repository.fetch(id: id)?.sourceID, sourceID)
        XCTAssertEqual(try repository.search(query: "0000").map(\.id), [id])
        XCTAssertEqual(try repository.findPossibleDuplicates(normalizedPhone: "13800008888").map(\.id), [id])

        customer.displayName = "王女士（更新）"
        customer.updatedAt = Date(timeIntervalSince1970: 200)
        try repository.update(customer)
        XCTAssertEqual(try repository.fetch(id: id)?.displayName, "王女士（更新）")

        try repository.archive(id: id, at: Date(timeIntervalSince1970: 300))
        XCTAssertNil(try repository.fetch(id: id))
        XCTAssertEqual(try repository.fetch(id: id, includeArchived: true)?.status, .archived)
    }

    func testAppointmentCRUDPreservesCustomerRelationship() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = LocalCustomerRepository(context: controller.context)
        let appointments = LocalAppointmentRepository(context: controller.context)
        let customerID = try XCTUnwrap(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        let appointmentID = try XCTUnwrap(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))
        try customers.create(Customer(
            id: customerID,
            displayName: "李先生",
            phone: "13900001111",
            normalizedPhone: "13900001111"
        ))
        var appointment = Appointment(
            id: appointmentID,
            customerID: customerID,
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            partySize: 3
        )

        try appointments.create(appointment)
        XCTAssertEqual(try appointments.fetch(id: appointmentID)?.customerID, customerID)
        XCTAssertEqual(try customers.fetch(id: customerID)?.appointmentIDs, [appointmentID])

        appointment.partySize = 4
        appointment.internalNote = "靠窗"
        try appointments.update(appointment)
        XCTAssertEqual(try appointments.fetch(id: appointmentID)?.partySize, 4)
        XCTAssertEqual(try appointments.fetch(id: appointmentID)?.internalNote, "靠窗")

        try appointments.deleteDraft(id: appointmentID)
        XCTAssertNil(try appointments.fetch(id: appointmentID))
    }

    func testCustomerPresentationSearchCatalogAndTimeline() throws {
        let controller = try PersistenceController(inMemory: true)
        let repository = LocalCustomerRepository(context: controller.context)
        try repository.seedDefaultSources()
        try repository.seedDefaultSources()
        let catalog = try repository.fetchCatalog()
        XCTAssertEqual(catalog.sources.map(\.name), ["小红书", "抖音", "大众点评", "微信", "电话", "朋友介绍", "线下", "其他"])

        let vip = try repository.upsertTag(named: " VIP ")
        XCTAssertEqual(try repository.upsertTag(named: "vip").id, vip.id)
        let source = try XCTUnwrap(catalog.sources.first)
        let customer = Customer(
            displayName: "陈女士",
            phone: "+86 138 0000 4321",
            normalizedPhone: "8613800004321",
            sourceID: source.id,
            notes: "需要靠窗",
            tagIDs: [vip.id],
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        try repository.create(customer)
        try repository.appendActivity(Activity(
            customerID: customer.id,
            type: .customerCreated,
            title: "Created",
            createdAt: Date(timeIntervalSince1970: 1)
        ))
        try repository.appendActivity(Activity(
            customerID: customer.id,
            type: .contacted,
            title: "Contacted",
            createdAt: Date(timeIntervalSince1970: 2)
        ))

        for query in ["靠窗", "小红书", "vip", "4321"] {
            XCTAssertEqual(try repository.fetchList(query: query).map(\.id), [customer.id])
        }
        let detail = try XCTUnwrap(repository.fetchDetail(id: customer.id))
        XCTAssertEqual(detail.sourceName, "小红书")
        XCTAssertEqual(detail.tagNames, ["VIP"])
        XCTAssertEqual(detail.activities.map(\.title), ["Contacted", "Created"])
    }

    func testMergePreservesRelationshipsAndArchivesDuplicate() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = LocalCustomerRepository(context: controller.context)
        let appointments = LocalAppointmentRepository(context: controller.context)
        let retained = Customer(displayName: "Retained", phone: "138", normalizedPhone: "138")
        let duplicate = Customer(displayName: "Duplicate", phone: "138", normalizedPhone: "138")
        try customers.create(retained)
        try customers.create(duplicate)
        let retainedTag = try customers.upsertTag(named: "VIP")
        let duplicateTag = try customers.upsertTag(named: "High Intent")
        try customers.assignTags([retainedTag.id], to: retained.id)
        try customers.assignTags([retainedTag.id, duplicateTag.id], to: duplicate.id)

        let retainedAppointment = Appointment(customerID: retained.id, startAt: Date(timeIntervalSince1970: 10), partySize: 1)
        let duplicateAppointment = Appointment(customerID: duplicate.id, startAt: Date(timeIntervalSince1970: 20), partySize: 2)
        try appointments.create(retainedAppointment)
        try appointments.create(duplicateAppointment)
        try customers.appendActivity(Activity(customerID: duplicate.id, type: .contacted, title: "Duplicate history"))

        let duplicateRecord = try XCTUnwrap(controller.context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>()).first { $0.id == duplicate.id })
        let followUp = PersistenceSchemaV1.FollowUpRecord(
            customerID: duplicate.id,
            dueAt: Date(timeIntervalSince1970: 30),
            reason: "Call",
            customer: duplicateRecord
        )
        controller.context.insert(followUp)
        try controller.context.save()

        try customers.merge(retaining: retained.id, archiving: duplicate.id, at: Date(timeIntervalSince1970: 40))

        let merged = try XCTUnwrap(customers.fetch(id: retained.id))
        XCTAssertEqual(Set(merged.appointmentIDs), Set([retainedAppointment.id, duplicateAppointment.id]))
        XCTAssertEqual(Set(merged.tagIDs), Set([retainedTag.id, duplicateTag.id]))
        XCTAssertEqual(merged.followUpIDs, [followUp.id])
        XCTAssertEqual(try appointments.fetch(id: duplicateAppointment.id)?.customerID, retained.id)
        XCTAssertEqual(try customers.fetch(id: duplicate.id, includeArchived: true)?.status, .archived)
        XCTAssertTrue(try XCTUnwrap(customers.fetchDetail(id: retained.id)).activities.contains { $0.type == .customerMerged })
    }
}
