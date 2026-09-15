import XCTest
@testable import Goosegrass

@MainActor
final class CustomerListViewModelTests: XCTestCase {
    func testLoadAndRefreshExposePersistedRowsAndCatalog() throws {
        let system = try makeSystem()
        try system.service.create(Customer(displayName: "Ana", phone: "13800004321", normalizedPhone: "13800004321", notes: "靠窗"))

        system.viewModel.load()
        XCTAssertEqual(system.viewModel.rows.map { $0.customer.displayName }, ["Ana"])
        XCTAssertEqual(system.viewModel.catalog.sources.count, 8)

        system.viewModel.query = "4321"
        system.viewModel.refresh()
        XCTAssertEqual(system.viewModel.rows.map(\.customer.displayName), ["Ana"])
    }

    func testSelectionLoadsDetailAndEditDraft() throws {
        let system = try makeSystem()
        let customer = Customer(displayName: "Ana", phone: "138", normalizedPhone: "138")
        try system.service.create(customer)
        system.viewModel.load()

        system.viewModel.select(customer.id)
        system.viewModel.beginEdit()

        XCTAssertEqual(system.viewModel.detail?.customer.id, customer.id)
        XCTAssertEqual(system.viewModel.editorDraft?.displayName, "Ana")
        XCTAssertEqual(system.viewModel.editingCustomer?.id, customer.id)
    }

    func testDuplicateCanUseExistingOrCreateAnyway() throws {
        let system = try makeSystem()
        let existing = Customer(displayName: "Existing", phone: "138", normalizedPhone: "138")
        try system.service.create(existing)
        system.viewModel.load()
        system.viewModel.beginAdd()
        system.viewModel.editorDraft?.displayName = "New"
        system.viewModel.editorDraft?.phone = "138"

        system.viewModel.saveEditor()
        XCTAssertEqual(system.viewModel.duplicateReview?.candidates.map(\.id), [existing.id])

        system.viewModel.useExisting(existing.id)
        XCTAssertEqual(system.viewModel.selectedCustomerID, existing.id)
        XCTAssertNil(system.viewModel.duplicateReview)

        system.viewModel.beginAdd()
        system.viewModel.editorDraft?.displayName = "New"
        system.viewModel.editorDraft?.phone = "138"
        system.viewModel.saveEditor()
        system.viewModel.createAnyway()
        XCTAssertEqual(system.viewModel.rows.count, 2)
    }

    func testDuplicateMergeKeepsOneActiveCustomerAndSelectsRetainedRecord() throws {
        let system = try makeSystem()
        let existing = Customer(displayName: "Existing", phone: "138", normalizedPhone: "138")
        try system.service.create(existing)
        system.viewModel.load()
        system.viewModel.beginAdd()
        system.viewModel.editorDraft?.displayName = "Duplicate"
        system.viewModel.editorDraft?.phone = "138"
        system.viewModel.saveEditor()

        system.viewModel.mergeDuplicate(into: existing.id)

        XCTAssertEqual(system.viewModel.rows.map(\.id), [existing.id])
        XCTAssertEqual(system.viewModel.selectedCustomerID, existing.id)
        XCTAssertTrue(system.viewModel.detail?.activities.contains { $0.type == .customerMerged } == true)
    }

    func testEditAndArchiveRefreshVisibleState() throws {
        let system = try makeSystem()
        let customer = Customer(displayName: "Old", phone: "138", normalizedPhone: "138")
        try system.service.create(customer)
        system.viewModel.load()
        system.viewModel.select(customer.id)
        system.viewModel.beginEdit()
        system.viewModel.editorDraft?.displayName = "Updated"
        system.viewModel.saveEditor()
        XCTAssertEqual(system.viewModel.rows.first?.customer.displayName, "Updated")

        system.viewModel.requestArchive()
        XCTAssertEqual(system.viewModel.archiveTarget?.id, customer.id)
        system.viewModel.confirmArchive()
        XCTAssertTrue(system.viewModel.rows.isEmpty)
        XCTAssertNil(system.viewModel.selectedCustomerID)
    }

    func testValidationErrorPreservesDraft() throws {
        let system = try makeSystem()
        system.viewModel.load()
        system.viewModel.beginAdd()
        system.viewModel.editorDraft?.displayName = ""
        system.viewModel.editorDraft?.phone = "()"

        system.viewModel.saveEditor()

        XCTAssertNotNil(system.viewModel.errorMessage)
        XCTAssertNotNil(system.viewModel.editorDraft)
    }

    private func makeSystem() throws -> (controller: PersistenceController, service: CustomerService, viewModel: CustomerListViewModel) {
        let controller = try PersistenceController(inMemory: true)
        let service = CustomerService(repository: controller.makeCustomerRepository())
        let viewModel = CustomerListViewModel(service: service, now: { Date(timeIntervalSince1970: 100) })
        return (controller, service, viewModel)
    }
}
