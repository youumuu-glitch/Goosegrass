import Foundation
import SwiftData
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentMigrationTests: XCTestCase {
    func testV1StoreMigratesAndAcceptsAppointmentChanges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Goosegrass.store")
        let customerID = try XCTUnwrap(UUID(uuidString: "31313131-3131-3131-3131-313131313131"))
        let appointmentID = try XCTUnwrap(UUID(uuidString: "32323232-3232-3232-3232-323232323232"))
        let changeID = try XCTUnwrap(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))

        do {
            let schema = Schema(versionedSchema: PersistenceSchemaV1.self)
            let configuration = ModelConfiguration(
                "GoosegrassV1",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            context.autosaveEnabled = false
            let customer = PersistenceSchemaV1.CustomerRecord(
                id: customerID,
                displayName: "迁移客户",
                phone: "13800003333",
                normalizedPhone: "13800003333"
            )
            let appointment = PersistenceSchemaV1.AppointmentRecord(
                id: appointmentID,
                customerID: customerID,
                startAt: Date(timeIntervalSince1970: 1_900_000_000),
                partySize: 3,
                customer: customer
            )
            context.insert(customer)
            context.insert(appointment)
            try context.save()
        }

        let reopened = try PersistenceController(storeURL: storeURL)
        let customers = LocalCustomerRepository(context: reopened.context)
        let appointments = LocalAppointmentRepository(context: reopened.context)
        XCTAssertEqual(try customers.fetch(id: customerID)?.appointmentIDs, [appointmentID])
        XCTAssertEqual(try appointments.fetch(id: appointmentID)?.customerID, customerID)

        let change = AppointmentChange(
            id: changeID,
            appointmentID: appointmentID,
            changeType: .statusChanged,
            oldValueJSON: "\"draft\"",
            newValueJSON: "\"pendingConfirmation\"",
            reason: "提交确认",
            changedAt: Date(timeIntervalSince1970: 1_900_000_100)
        )
        reopened.context.insert(PersistenceMapper.makeAppointmentChangeRecord(from: change))
        try reopened.context.save()

        let stored = try XCTUnwrap(
            reopened.context.fetch(FetchDescriptor<PersistenceSchemaV2.AppointmentChangeRecord>())
                .first { $0.id == changeID }
        )
        XCTAssertEqual(try PersistenceMapper.makeAppointmentChange(from: stored), change)
    }
}
