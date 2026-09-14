import XCTest
@testable import Goosegrass

final class CustomerServiceTests: XCTestCase {
    @MainActor
    func testListDelegatesExpandedQueryAndReturnsPresentationRows() throws {
        let customer = Customer(
            displayName: "Ana",
            phone: "+86 138 0000 8888",
            normalizedPhone: "8613800008888"
        )
        let expected = CustomerListItem(
            customer: customer,
            sourceName: "小红书",
            tagNames: ["VIP"],
            nextAppointmentAt: nil
        )
        let repository = CustomerServiceRepositoryStub(listItems: [expected])
        let service = CustomerService(repository: repository)

        let rows = try service.list(query: "VIP")

        XCTAssertEqual(repository.receivedQuery, "VIP")
        XCTAssertEqual(rows, [expected])
    }

    @MainActor
    func testDetailIncludesNewestActivityFirst() throws {
        let customer = Customer(displayName: "Ana", phone: "138", normalizedPhone: "138")
        let older = Activity(customerID: customer.id, type: .customerCreated, title: "Created", createdAt: Date(timeIntervalSince1970: 1))
        let newer = Activity(customerID: customer.id, type: .contacted, title: "Contacted", createdAt: Date(timeIntervalSince1970: 2))
        let detail = CustomerDetail(customer: customer, sourceName: nil, tagNames: [], activities: [newer, older])
        let repository = CustomerServiceRepositoryStub(detail: detail)
        let service = CustomerService(repository: repository)

        XCTAssertEqual(try service.detail(id: customer.id)?.activities, [newer, older])
    }

    @MainActor
    func testCatalogSeedsDefaultSourcesBeforeReturningChoices() throws {
        let repository = CustomerServiceRepositoryStub(catalog: CustomerCatalog(sources: [], tags: []))
        let service = CustomerService(repository: repository)

        _ = try service.catalog()

        XCTAssertEqual(repository.seedCallCount, 1)
    }

    @MainActor
    func testDuplicateCandidatesRemainAnExplicitDecision() throws {
        let existing = Customer(displayName: "Existing", phone: "138", normalizedPhone: "138")
        let repository = CustomerServiceRepositoryStub(duplicates: [existing])
        let service = CustomerService(repository: repository)

        XCTAssertEqual(try service.duplicateCandidates(normalizedPhone: "138"), [existing])
    }

    func testEditorDraftTrimsValuesAndPreservesExistingIdentity() throws {
        let createdAt = Date(timeIntervalSince1970: 10)
        let existing = Customer(
            displayName: "Old",
            phone: "100",
            normalizedPhone: "100",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        var draft = CustomerEditorDraft(customer: existing)
        draft.displayName = "  New Name  "
        draft.phone = "+86 (138) 0000-8888"
        draft.email = "  person@example.com  "

        let customer = try draft.makeCustomer(existing: existing, now: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(customer.id, existing.id)
        XCTAssertEqual(customer.createdAt, createdAt)
        XCTAssertEqual(customer.displayName, "New Name")
        XCTAssertEqual(customer.normalizedPhone, "+8613800008888")
        XCTAssertEqual(customer.email, "person@example.com")
    }

    func testEditorDraftRejectsMissingNameAndDigitlessPhone() {
        var draft = CustomerEditorDraft()
        draft.phone = "() -"
        XCTAssertThrowsError(try draft.makeCustomer()) { error in
            XCTAssertEqual(error as? CustomerEditorError, .missingDisplayName)
        }

        draft.displayName = "Name"
        XCTAssertThrowsError(try draft.makeCustomer()) { error in
            XCTAssertEqual(error as? CustomerEditorError, .invalidPhone)
        }
    }

    @MainActor
    func testSubmitReturnsDuplicateDecisionBeforeCreating() throws {
        let existing = Customer(displayName: "Existing", phone: "138", normalizedPhone: "138")
        let repository = CustomerServiceRepositoryStub(duplicates: [existing])
        let service = CustomerService(repository: repository)
        var draft = CustomerEditorDraft()
        draft.displayName = "New"
        draft.phone = "138"

        let result = try service.submit(draft: draft, at: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(result, .possibleDuplicates(draft: draft, candidates: [existing]))
        XCTAssertTrue(repository.createdCustomers.isEmpty)
    }

    @MainActor
    func testCreateAnywayPersistsCustomerAndCreatedActivity() throws {
        let repository = CustomerServiceRepositoryStub()
        let service = CustomerService(repository: repository)
        var draft = CustomerEditorDraft()
        draft.displayName = "New"
        draft.phone = "138"

        let result = try service.submit(draft: draft, allowDuplicate: true, at: Date(timeIntervalSince1970: 20))
        guard case let .saved(customer) = result else { return XCTFail("Expected saved customer") }

        XCTAssertEqual(repository.createdCustomers, [customer])
        XCTAssertEqual(repository.activities.map(\.type), [.customerCreated])
        XCTAssertEqual(repository.activities.first?.customerID, customer.id)
    }

    @MainActor
    func testEditAndNotePreserveIdentityAndWriteHistory() throws {
        let original = Customer(
            displayName: "Old",
            phone: "100",
            normalizedPhone: "100",
            notes: "First",
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let repository = CustomerServiceRepositoryStub(customersByID: [original.id: original])
        let service = CustomerService(repository: repository)
        var draft = CustomerEditorDraft(customer: original)
        draft.displayName = "Updated"

        _ = try service.submit(draft: draft, editing: original, at: Date(timeIntervalSince1970: 2))
        try service.addNote(customerID: original.id, text: "Second", at: Date(timeIntervalSince1970: 3))

        XCTAssertEqual(repository.updatedCustomers.first?.id, original.id)
        XCTAssertEqual(repository.updatedCustomers.first?.createdAt, original.createdAt)
        XCTAssertEqual(repository.updatedCustomers.last?.notes, "First\n\nSecond")
        XCTAssertEqual(repository.activities.last?.type, .noteAdded)
    }

    @MainActor
    func testArchiveDelegatesTimestamp() throws {
        let repository = CustomerServiceRepositoryStub()
        let service = CustomerService(repository: repository)
        let id = UUID()
        let at = Date(timeIntervalSince1970: 44)

        try service.archive(id: id, at: at)

        XCTAssertEqual(repository.archivedCustomerID, id)
        XCTAssertEqual(repository.archivedAt, at)
    }
}

@MainActor
private final class CustomerServiceRepositoryStub: CustomerRepository {
    var listItems: [CustomerListItem]
    var detailValue: CustomerDetail?
    var catalogValue: CustomerCatalog
    var duplicates: [Customer]
    var receivedQuery: String?
    var seedCallCount = 0
    var customersByID: [UUID: Customer]
    var createdCustomers: [Customer] = []
    var updatedCustomers: [Customer] = []
    var activities: [Activity] = []
    var archivedCustomerID: UUID?
    var archivedAt: Date?

    init(
        listItems: [CustomerListItem] = [],
        detail: CustomerDetail? = nil,
        catalog: CustomerCatalog = CustomerCatalog(sources: [], tags: []),
        duplicates: [Customer] = [],
        customersByID: [UUID: Customer] = [:]
    ) {
        self.listItems = listItems
        detailValue = detail
        catalogValue = catalog
        self.duplicates = duplicates
        self.customersByID = customersByID
    }

    func create(_ customer: Customer) throws {
        createdCustomers.append(customer)
        customersByID[customer.id] = customer
    }
    func update(_ customer: Customer) throws {
        updatedCustomers.append(customer)
        customersByID[customer.id] = customer
    }
    func fetch(id: UUID, includeArchived: Bool) throws -> Customer? { customersByID[id] ?? detailValue?.customer }
    func fetchAll(includeArchived: Bool) throws -> [Customer] { listItems.map(\.customer) }
    func search(query: String, includeArchived: Bool) throws -> [Customer] { listItems.map(\.customer) }
    func findPossibleDuplicates(normalizedPhone: String) throws -> [Customer] { duplicates }
    func archive(id: UUID, at: Date) throws {
        archivedCustomerID = id
        archivedAt = at
    }

    func fetchList(query: String) throws -> [CustomerListItem] {
        receivedQuery = query
        return listItems
    }

    func fetchDetail(id: UUID) throws -> CustomerDetail? { detailValue }
    func fetchCatalog() throws -> CustomerCatalog { catalogValue }
    func seedDefaultSources() throws { seedCallCount += 1 }
    func upsertTag(named name: String) throws -> Tag { Tag(name: name) }
    func assignTags(_ tagIDs: [UUID], to customerID: UUID) throws {}
    func appendActivity(_ activity: Activity) throws { activities.append(activity) }
    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at: Date) throws {}
}
