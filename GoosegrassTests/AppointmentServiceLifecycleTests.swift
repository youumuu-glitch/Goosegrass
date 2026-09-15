import Foundation
import XCTest
@testable import Goosegrass

@MainActor
final class AppointmentServiceLifecycleTests: XCTestCase {
    func testDraftValidatesTrimsAndPreservesExistingIdentity() throws {
        let original = Appointment(
            customerID: UUID(),
            startAt: Date(timeIntervalSince1970: 100),
            partySize: 2,
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            serverID: "server-1",
            syncStatus: "synced",
            lastSyncedAt: Date(timeIntervalSince1970: 9)
        )
        var draft = AppointmentEditorDraft(appointment: original)
        draft.partySize = 3
        draft.customerRequest = "  靠窗  "
        draft.internalNote = "  生日  "

        let edited = try draft.makeAppointment(
            existing: original,
            now: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.createdAt, original.createdAt)
        XCTAssertEqual(edited.serverID, original.serverID)
        XCTAssertEqual(edited.syncStatus, original.syncStatus)
        XCTAssertEqual(edited.lastSyncedAt, original.lastSyncedAt)
        XCTAssertEqual(edited.customerRequest, "靠窗")
        XCTAssertEqual(edited.internalNote, "生日")
        XCTAssertTrue(draft.isHistorical(relativeTo: Date(timeIntervalSince1970: 101)))

        var invalid = AppointmentEditorDraft()
        invalid.partySize = 0
        XCTAssertThrowsError(try invalid.makeAppointment(now: Date()))
    }

    func testCreateAndEditCommitOnlyChangedCategories() throws {
        let customer = Customer(displayName: "客户", phone: "138", normalizedPhone: "138")
        let controller = try PersistenceController(inMemory: true)
        let customerRepository = LocalCustomerRepository(context: controller.context)
        try customerRepository.create(customer)
        let repository = RecordingAppointmentRepository()
        let service = AppointmentService(repository: repository, customerRepository: customerRepository)
        var draft = AppointmentEditorDraft()
        draft.customerID = customer.id
        draft.startAt = Date(timeIntervalSince1970: 100)
        draft.partySize = 2

        let created = try service.create(draft: draft, at: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(repository.mutations.count, 1)
        XCTAssertEqual(repository.mutations[0].activities.map(\.type), [.appointmentCreated])
        XCTAssertTrue(repository.mutations[0].isNew)

        draft.partySize = 4
        draft.customerRequest = "  靠窗  "
        draft.internalNote = "  生日  "
        let edited = try service.edit(id: created.id, draft: draft, at: Date(timeIntervalSince1970: 20))
        XCTAssertEqual(edited.id, created.id)
        XCTAssertEqual(
            Set(repository.mutations.last?.changes.map(\.changeType) ?? []),
            Set([.partySizeChanged, .requestChanged, .noteChanged])
        )
    }

    func testLifecycleTransitionsSetStatusesTimestampsAndActivities() throws {
        let customer = Customer(displayName: "客户", phone: "138", normalizedPhone: "138")
        let controller = try PersistenceController(inMemory: true)
        let customerRepository = LocalCustomerRepository(context: controller.context)
        try customerRepository.create(customer)
        let original = Appointment(
            customerID: customer.id,
            startAt: Date(timeIntervalSince1970: 1_000),
            partySize: 2
        )
        let repository = RecordingAppointmentRepository(appointments: [original.id: original])
        let service = AppointmentService(repository: repository, customerRepository: customerRepository)

        let submitted = try service.transition(id: original.id, action: .submit, at: Date(timeIntervalSince1970: 10))
        let confirmed = try service.transition(id: original.id, action: .confirm, at: Date(timeIntervalSince1970: 20))
        let upcoming = try service.transition(id: original.id, action: .markUpcoming, at: Date(timeIntervalSince1970: 30))
        let arrived = try service.transition(id: original.id, action: .arrive, at: Date(timeIntervalSince1970: 40))
        let completed = try service.transition(id: original.id, action: .complete, at: Date(timeIntervalSince1970: 50))

        XCTAssertEqual([submitted.status, confirmed.status, upcoming.status, arrived.status, completed.status], [
            .pendingConfirmation, .confirmed, .upcoming, .arrived, .completed,
        ])
        XCTAssertEqual(confirmed.confirmedAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(arrived.arrivedAt, Date(timeIntervalSince1970: 40))
        XCTAssertEqual(completed.completedAt, Date(timeIntervalSince1970: 50))
        XCTAssertEqual(repository.mutations.map { $0.activities.first?.type }, [
            .appointmentCreated,
            .appointmentConfirmed,
            .appointmentConfirmed,
            .appointmentArrived,
            .appointmentCompleted,
        ])
        XCTAssertTrue(repository.mutations.allSatisfy { $0.changes.map(\.changeType) == [.statusChanged] })
    }

    func testCancelNoShowAndRescheduleRecordExactOutcome() throws {
        let customer = Customer(displayName: "客户", phone: "138", normalizedPhone: "138")
        let controller = try PersistenceController(inMemory: true)
        let customerRepository = LocalCustomerRepository(context: controller.context)
        try customerRepository.create(customer)

        let cancelStart = Appointment(customerID: customer.id, startAt: Date(timeIntervalSince1970: 100), partySize: 1)
        let cancelRepository = RecordingAppointmentRepository(appointments: [cancelStart.id: cancelStart])
        let cancelService = AppointmentService(repository: cancelRepository, customerRepository: customerRepository)
        let cancelled = try cancelService.transition(id: cancelStart.id, action: .cancel, at: Date(timeIntervalSince1970: 11))
        XCTAssertEqual(cancelled.cancelledAt, Date(timeIntervalSince1970: 11))
        XCTAssertEqual(cancelRepository.mutations.last?.activities.map(\.type), [.appointmentCancelled])

        let upcoming = Appointment(customerID: customer.id, startAt: Date(timeIntervalSince1970: 200), partySize: 1, status: .upcoming)
        let noShowRepository = RecordingAppointmentRepository(appointments: [upcoming.id: upcoming])
        let noShowService = AppointmentService(repository: noShowRepository, customerRepository: customerRepository)
        let noShow = try noShowService.transition(id: upcoming.id, action: .markNoShow, at: Date(timeIntervalSince1970: 22))
        XCTAssertEqual(noShow.noShowAt, Date(timeIntervalSince1970: 22))
        XCTAssertEqual(noShowRepository.mutations.last?.activities.map(\.type), [.appointmentNoShow])

        let rescheduleRepository = RecordingAppointmentRepository(appointments: [upcoming.id: upcoming])
        let rescheduleService = AppointmentService(repository: rescheduleRepository, customerRepository: customerRepository)
        let moved = try rescheduleService.reschedule(
            id: upcoming.id,
            startAt: Date(timeIntervalSince1970: 300),
            endAt: Date(timeIntervalSince1970: 360),
            reason: "  客户改期  ",
            at: Date(timeIntervalSince1970: 33)
        )
        XCTAssertEqual(moved.id, upcoming.id)
        XCTAssertEqual(moved.status, .rescheduled)
        let change = try XCTUnwrap(rescheduleRepository.mutations.last?.changes.first)
        XCTAssertEqual(change.changeType, .rescheduled)
        XCTAssertEqual(change.reason, "客户改期")
        XCTAssertTrue(change.oldValueJSON.contains("1970-01-01T00:03:20"))
        XCTAssertTrue(change.newValueJSON.contains("1970-01-01T00:05:00"))
        XCTAssertEqual(rescheduleRepository.mutations.last?.activities.map(\.type), [.appointmentRescheduled])
    }

    func testInvalidTransitionAndUnavailableCustomerCommitNothing() throws {
        let missingCustomer = UUID()
        let appointment = Appointment(
            customerID: missingCustomer,
            startAt: Date(timeIntervalSince1970: 100),
            partySize: 1,
            status: .completed
        )
        let controller = try PersistenceController(inMemory: true)
        let customerRepository = LocalCustomerRepository(context: controller.context)
        let repository = RecordingAppointmentRepository(appointments: [appointment.id: appointment])
        let service = AppointmentService(repository: repository, customerRepository: customerRepository)

        XCTAssertThrowsError(try service.transition(
            id: appointment.id,
            action: .cancel,
            at: Date(timeIntervalSince1970: 10)
        ))
        XCTAssertTrue(repository.mutations.isEmpty)

        var draft = AppointmentEditorDraft()
        draft.customerID = missingCustomer
        draft.partySize = 1
        XCTAssertThrowsError(try service.create(draft: draft, at: Date(timeIntervalSince1970: 20)))
        XCTAssertTrue(repository.mutations.isEmpty)
    }
}

@MainActor
private final class RecordingAppointmentRepository: AppointmentRepository {
    var appointments: [UUID: Appointment]
    private(set) var mutations: [AppointmentMutation] = []

    init(appointments: [UUID: Appointment] = [:]) {
        self.appointments = appointments
    }

    func create(_ appointment: Appointment) throws { appointments[appointment.id] = appointment }
    func update(_ appointment: Appointment) throws { appointments[appointment.id] = appointment }
    func fetch(id: UUID) throws -> Appointment? { appointments[id] }
    func fetchAll(customerID: UUID?) throws -> [Appointment] {
        appointments.values.filter { customerID == nil || $0.customerID == customerID }
    }
    func deleteDraft(id: UUID) throws { appointments[id] = nil }
    func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem] { [] }
    func fetchDetail(id: UUID) throws -> AppointmentDetail? { nil }
    func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange] { [] }
    func commit(_ mutation: AppointmentMutation) throws {
        mutations.append(mutation)
        appointments[mutation.appointment.id] = mutation.appointment
    }
}
