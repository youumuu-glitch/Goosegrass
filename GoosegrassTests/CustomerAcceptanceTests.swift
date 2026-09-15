import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class CustomerAcceptanceTests: XCTestCase {
    func testCustomerLifecycleSurvivesRelaunchThroughArchive() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let createdAt = Date(timeIntervalSince1970: 1_900_000_000)
        var createdID: UUID?

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let service = controller.makeCustomerService()
            var draft = CustomerEditorDraft()
            draft.displayName = "林女士"
            draft.phone = "+86 138 0000 8888"
            draft.notes = "首次咨询包间"

            let result = try service.submit(draft: draft, allowDuplicate: true, at: createdAt)
            guard case let .saved(customer) = result else {
                return XCTFail("Expected the customer to be persisted")
            }
            createdID = customer.id
            XCTAssertEqual(try service.list().map(\.customer.id), [customer.id])
        }

        let customerID = try XCTUnwrap(createdID)
        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let service = controller.makeCustomerService()

            let matches = try service.list(query: "8888")
            XCTAssertEqual(matches.map(\.customer.id), [customerID])

            let existing = try XCTUnwrap(service.fetch(id: customerID))
            var edit = CustomerEditorDraft(customer: existing)
            edit.displayName = "林女士（已联系）"
            edit.status = .active
            let editedAt = createdAt.addingTimeInterval(60)

            let result = try service.submit(draft: edit, editing: existing, at: editedAt)
            guard case let .saved(updated) = result else {
                return XCTFail("Expected the edited customer to be persisted")
            }
            XCTAssertEqual(updated.id, customerID)
            XCTAssertEqual(updated.createdAt, createdAt)
            XCTAssertEqual(updated.displayName, "林女士（已联系）")

            try service.archive(id: customerID, at: editedAt.addingTimeInterval(60))
            XCTAssertTrue(try service.list().isEmpty)
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let repository = reopened.makeCustomerRepository()
        XCTAssertTrue(try repository.fetchAll().isEmpty)
        let archived = try XCTUnwrap(repository.fetch(id: customerID, includeArchived: true))
        XCTAssertEqual(archived.id, customerID)
        XCTAssertEqual(archived.displayName, "林女士（已联系）")
        XCTAssertEqual(archived.status, .archived)
        XCTAssertTrue(archived.isArchived)
    }
}
