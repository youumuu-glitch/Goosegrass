import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class PersistenceLifecycleTests: XCTestCase {
    func testDiskStoreRetainsCustomerAndAppointmentAcrossContainerReopen() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let customerID = try XCTUnwrap(UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"))
        let appointmentID = try XCTUnwrap(UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE"))

        do {
            let controller = try PersistenceController(storeURL: storeURL)
            let customers = LocalCustomerRepository(context: controller.context)
            let appointments = LocalAppointmentRepository(context: controller.context)
            try customers.create(Customer(
                id: customerID,
                displayName: "张女士",
                phone: "13700002222",
                normalizedPhone: "13700002222"
            ))
            try appointments.create(Appointment(
                id: appointmentID,
                customerID: customerID,
                startAt: Date(timeIntervalSince1970: 1_900_000_000),
                partySize: 2
            ))
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let customers = LocalCustomerRepository(context: reopened.context)
        let appointments = LocalAppointmentRepository(context: reopened.context)
        XCTAssertEqual(try customers.fetch(id: customerID, includeArchived: true)?.appointmentIDs, [appointmentID])
        XCTAssertEqual(try appointments.fetch(id: appointmentID)?.customerID, customerID)
    }

    func testRepositoriesReuseApplicationOwnedContainer() throws {
        let controller = try PersistenceController(inMemory: true)
        let customers = LocalCustomerRepository(context: controller.context)
        let appointments = LocalAppointmentRepository(context: controller.context)

        XCTAssertTrue(controller.context === controller.container.mainContext)
        XCTAssertTrue(customers.container === controller.container)
        XCTAssertTrue(appointments.container === controller.container)
    }
}
