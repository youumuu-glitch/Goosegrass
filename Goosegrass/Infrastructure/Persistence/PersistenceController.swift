import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    let container: ModelContainer
    let context: ModelContext

    convenience init(inMemory: Bool = false) throws {
        let schema = Schema(versionedSchema: PersistenceSchemaV2.self)
        let configuration = ModelConfiguration(
            "Goosegrass",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true,
            groupContainer: .automatic,
            cloudKitDatabase: .none
        )
        try self.init(schema: schema, configuration: configuration)
    }

    convenience init(storeURL: URL) throws {
        let schema = Schema(versionedSchema: PersistenceSchemaV2.self)
        let configuration = ModelConfiguration(
            "Goosegrass",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        try self.init(schema: schema, configuration: configuration)
    }

    private init(schema: Schema, configuration: ModelConfiguration) throws {
        container = try ModelContainer(
            for: schema,
            migrationPlan: GoosegrassMigrationPlan.self,
            configurations: [configuration]
        )
        context = container.mainContext
        context.autosaveEnabled = false
    }

    func makeCustomerRepository() -> LocalCustomerRepository {
        LocalCustomerRepository(context: context)
    }

    func makeAppointmentRepository() -> LocalAppointmentRepository {
        LocalAppointmentRepository(context: context)
    }

    func makeCustomerService() -> CustomerService {
        CustomerService(repository: makeCustomerRepository())
    }

    func makeAppointmentService() -> AppointmentService {
        AppointmentService(
            repository: makeAppointmentRepository(),
            customerRepository: makeCustomerRepository()
        )
    }

    func makeTodayService(
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) -> TodayService {
        TodayService(
            appointmentService: makeAppointmentService(),
            customerService: makeCustomerService(),
            calendar: calendar,
            now: now
        )
    }
}
