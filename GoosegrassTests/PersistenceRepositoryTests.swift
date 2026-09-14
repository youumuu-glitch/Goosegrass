import Foundation
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
}
