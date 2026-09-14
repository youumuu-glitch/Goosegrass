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
}

@MainActor
private final class CustomerServiceRepositoryStub: CustomerRepository {
    var listItems: [CustomerListItem]
    var detailValue: CustomerDetail?
    var catalogValue: CustomerCatalog
    var duplicates: [Customer]
    var receivedQuery: String?
    var seedCallCount = 0

    init(
        listItems: [CustomerListItem] = [],
        detail: CustomerDetail? = nil,
        catalog: CustomerCatalog = CustomerCatalog(sources: [], tags: []),
        duplicates: [Customer] = []
    ) {
        self.listItems = listItems
        detailValue = detail
        catalogValue = catalog
        self.duplicates = duplicates
    }

    func create(_ customer: Customer) throws {}
    func update(_ customer: Customer) throws {}
    func fetch(id: UUID, includeArchived: Bool) throws -> Customer? { detailValue?.customer }
    func fetchAll(includeArchived: Bool) throws -> [Customer] { listItems.map(\.customer) }
    func search(query: String, includeArchived: Bool) throws -> [Customer] { listItems.map(\.customer) }
    func findPossibleDuplicates(normalizedPhone: String) throws -> [Customer] { duplicates }
    func archive(id: UUID, at: Date) throws {}

    func fetchList(query: String) throws -> [CustomerListItem] {
        receivedQuery = query
        return listItems
    }

    func fetchDetail(id: UUID) throws -> CustomerDetail? { detailValue }
    func fetchCatalog() throws -> CustomerCatalog { catalogValue }
    func seedDefaultSources() throws { seedCallCount += 1 }
    func appendActivity(_ activity: Activity) throws {}
    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at: Date) throws {}
}
