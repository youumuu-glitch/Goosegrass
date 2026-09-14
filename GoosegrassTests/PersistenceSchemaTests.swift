import Foundation
import SwiftData
import XCTest
@testable import Goosegrass

@MainActor
final class PersistenceSchemaTests: XCTestCase {
    func testV1SchemaContainsEveryPhaseOneModel() {
        XCTAssertEqual(PersistenceSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        XCTAssertEqual(PersistenceSchemaV1.models.count, 7)
    }

    func testCustomerAppointmentRelationshipHasAnInverse() throws {
        let controller = try PersistenceController(inMemory: true)
        let customer = PersistenceSchemaV1.CustomerRecord(
            displayName: "王女士",
            phone: "138 0000 8888",
            normalizedPhone: "13800008888"
        )
        let appointment = PersistenceSchemaV1.AppointmentRecord(
            customerID: customer.id,
            startAt: Date(timeIntervalSince1970: 1_800_000_000),
            partySize: 2,
            customer: customer
        )

        controller.context.insert(customer)
        controller.context.insert(appointment)
        try controller.context.save()

        XCTAssertTrue(appointment.customer === customer)
        XCTAssertEqual(customer.appointments.map(\.id), [appointment.id])
    }
}
