import Combine
import Foundation

@MainActor
final class FollowUpListViewModel: ObservableObject {
    @Published private(set) var scope: FollowUpListScope = .active
    @Published private(set) var rows: [FollowUpListItem] = []
    @Published private(set) var detail: FollowUpDetail?
    @Published private(set) var selectedFollowUpID: UUID?
    @Published var editorDraft: FollowUpEditorDraft?
    @Published private(set) var customerRows: [CustomerListItem] = []
    @Published private(set) var appointmentRows: [AppointmentListItem] = []
    @Published var snoozeDraftDate: Date?
    @Published private(set) var isCancelConfirmationPresented = false
    @Published private(set) var errorMessage: String?

    private let service: FollowUpService
    private let customerService: CustomerService
    private let appointmentService: AppointmentService
    private let calendar: Calendar
    private let now: () -> Date

    init(
        service: FollowUpService,
        customerService: CustomerService,
        appointmentService: AppointmentService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.customerService = customerService
        self.appointmentService = appointmentService
        self.calendar = calendar
        self.now = now
    }

    var availableAppointments: [AppointmentListItem] {
        guard let customerID = editorDraft?.customerID else { return [] }
        return appointmentRows.filter { $0.appointment.customerID == customerID }
    }

    func load() {
        perform {
            customerRows = try customerService.list()
            appointmentRows = try appointmentService.list()
            try refreshThrowing()
        }
    }

    func refresh() {
        perform { try refreshThrowing() }
    }

    func applyScope(_ scope: FollowUpListScope) {
        self.scope = scope
        refresh()
    }

    func select(_ id: UUID?) {
        selectedFollowUpID = id
        guard let id else {
            detail = nil
            return
        }
        perform { detail = try service.detail(id: id) }
    }

    func beginAdd(customerID: UUID? = nil, appointmentID: UUID? = nil) {
        errorMessage = nil
        let current = now()
        let dueAt = (try? FollowUpSchedule.tomorrowAtEleven(from: current, calendar: calendar))
            ?? current.addingTimeInterval(3_600)
        editorDraft = FollowUpEditorDraft(
            customerID: customerID,
            appointmentID: appointmentID,
            dueAt: dueAt
        )
    }

    func cancelEditor() {
        editorDraft = nil
        errorMessage = nil
    }

    func saveEditor() {
        guard let draft = editorDraft else { return }
        perform {
            guard let customerID = draft.customerID else {
                throw FollowUpEditorError.customerRequired
            }
            let saved = try service.create(
                customerID: customerID,
                appointmentID: draft.appointmentID,
                dueAt: draft.dueAt,
                reason: draft.reason,
                note: draft.note,
                priority: draft.priority,
                at: now()
            )
            editorDraft = nil
            try refreshThrowing()
            selectedFollowUpID = saved.id
            detail = try service.detail(id: saved.id)
        }
    }

    func completeSelected() {
        guard let id = selectedFollowUpID else { return }
        performMutation(id: id) { try service.complete(id: id, at: now()) }
    }

    func beginSnooze() {
        guard selectedFollowUpID != nil else { return }
        snoozeDraftDate = (try? FollowUpSchedule.tomorrowAtEleven(from: now(), calendar: calendar))
            ?? now().addingTimeInterval(3_600)
    }

    func cancelSnooze() {
        snoozeDraftDate = nil
    }

    func confirmSnooze() {
        guard let dueAt = snoozeDraftDate else { return }
        snoozeDraftDate = nil
        snoozeSelected(until: dueAt)
    }

    func snoozeSelected(until dueAt: Date) {
        guard let id = selectedFollowUpID else { return }
        performMutation(id: id) { try service.snooze(id: id, until: dueAt, at: now()) }
    }

    func requestCancel() {
        guard selectedFollowUpID != nil else { return }
        isCancelConfirmationPresented = true
    }

    func confirmCancel() {
        guard let id = selectedFollowUpID else { return }
        isCancelConfirmationPresented = false
        performMutation(id: id) { try service.cancel(id: id, at: now()) }
    }

    func dismissCancel() {
        isCancelConfirmationPresented = false
    }

    func clearError() {
        errorMessage = nil
    }

    private func performMutation(id: UUID, operation: () throws -> FollowUp) {
        perform {
            _ = try operation()
            try refreshThrowing()
            detail = try service.detail(id: id)
        }
    }

    private func refreshThrowing() throws {
        rows = try service.list(filter: FollowUpListFilter(scope: scope))
        if let selectedFollowUpID {
            detail = try service.detail(id: selectedFollowUpID)
        }
    }

    private func perform(_ operation: () throws -> Void) {
        errorMessage = nil
        do {
            try operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
