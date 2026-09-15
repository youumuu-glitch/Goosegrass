import XCTest
@testable import Goosegrass

@MainActor
final class CustomerFeatureCompositionTests: XCTestCase {
    func testCustomerFeatureLoadsThroughServiceFromApplicationOwnedContext() throws {
        let controller = try PersistenceController(inMemory: true)
        let service = controller.makeCustomerService()
        let customer = Customer(displayName: "Composition", phone: "138", normalizedPhone: "138")
        try service.create(customer)

        let viewModel = CustomerListViewModel(service: service)
        viewModel.load()

        XCTAssertTrue(controller.makeCustomerRepository().container === controller.container)
        XCTAssertTrue(controller.context === controller.container.mainContext)
        XCTAssertEqual(viewModel.rows.map(\.id), [customer.id])
    }
}
