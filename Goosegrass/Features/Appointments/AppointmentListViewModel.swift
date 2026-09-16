import Combine
import Foundation

enum AppointmentDatePreset: String, CaseIterable, Equatable, Sendable {
    case today
    case tomorrow
    case thisWeek
    case custom
    case all
}

@MainActor
final class AppointmentListViewModel: ObservableObject {
    @Published var filter: AppointmentFilter
    @Published private(set) var rows: [AppointmentListItem] = []
    @Published private(set) var detail: AppointmentDetail?
    @Published private(set) var selectedAppointmentID: UUID?
    @Published var editorDraft: AppointmentEditorDraft?
    @Published private(set) var editingAppointment: Appointment?
    @Published private(set) var pendingAction: AppointmentAction?
    @Published private(set) var datePreset: AppointmentDatePreset = .today
    @Published private(set) var customerRows: [CustomerListItem] = []
    @Published private(set) var catalog = CustomerCatalog(sources: [], tags: [])
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingNoShowFollowUpRequest: NoShowFollowUpRequest?
    @Published var customFollowUpDraft: FollowUpEditorDraft?

    private let service: AppointmentService
    private let customerService: CustomerService
    private let followUpService: FollowUpService?
    private let calendar: Calendar
    private let now: () -> Date
    private var isRescheduling = false

    init(
        service: AppointmentService,
        customerService: CustomerService,
        followUpService: FollowUpService? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.customerService = customerService
        self.followUpService = followUpService
        self.calendar = calendar
        self.now = now
        filter = AppointmentFilter(dateInterval: Self.dayInterval(
            containing: now(),
            calendar: calendar
        ))
    }

    var allowedActions: [AppointmentAction] {
        guard let status = detail?.listItem.appointment.status else { return [] }
        return AppointmentLifecycle.allowedActions(from: status)
    }

    var isHistoricalDraft: Bool {
        editorDraft?.isHistorical(relativeTo: now()) ?? false
    }

    var isReschedulingEditor: Bool { isRescheduling }

    func load() {
        perform {
            catalog = try customerService.catalog()
            customerRows = try customerService.list()
            try refreshThrowing()
        }
    }

    func refresh() {
        perform { try refreshThrowing() }
    }

    func applyDatePreset(_ preset: AppointmentDatePreset) {
        datePreset = preset
        let current = now()
        switch preset {
        case .today:
            filter.dateInterval = Self.dayInterval(containing: current, calendar: calendar)
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: current) else { return }
            filter.dateInterval = Self.dayInterval(containing: tomorrow, calendar: calendar)
        case .thisWeek:
            filter.dateInterval = calendar.dateInterval(of: .weekOfYear, for: current)
        case .custom:
            break
        case .all:
            filter.dateInterval = nil
        }
        refresh()
    }

    func setCustomDateInterval(_ interval: DateInterval?) {
        datePreset = .custom
        filter.dateInterval = interval
        refresh()
    }

    func select(_ id: UUID?) {
        selectedAppointmentID = id
        guard let id else {
            detail = nil
            return
        }
        perform { detail = try service.detail(id: id) }
    }

    func beginAdd(customerID: UUID? = nil) {
        errorMessage = nil
        editingAppointment = nil
        isRescheduling = false
        editorDraft = AppointmentEditorDraft(customerID: customerID)
    }

    func beginEdit() {
        guard let appointment = selectedAppointment else { return }
        errorMessage = nil
        editingAppointment = appointment
        isRescheduling = false
        editorDraft = AppointmentEditorDraft(appointment: appointment)
    }

    func beginReschedule() {
        guard let appointment = selectedAppointment,
              AppointmentLifecycle.allowedActions(from: appointment.status).contains(.reschedule) else {
            return
        }
        errorMessage = nil
        editingAppointment = appointment
        isRescheduling = true
        editorDraft = AppointmentEditorDraft(appointment: appointment)
    }

    func cancelEditor() {
        editorDraft = nil
        editingAppointment = nil
        isRescheduling = false
        errorMessage = nil
    }

    func saveEditor(reason: String = "") {
        guard let draft = editorDraft else { return }
        perform {
            let saved: Appointment
            if let editingAppointment {
                if isRescheduling {
                    saved = try service.reschedule(
                        id: editingAppointment.id,
                        startAt: draft.startAt,
                        endAt: draft.endAt,
                        reason: reason,
                        at: now()
                    )
                } else {
                    saved = try service.edit(
                        id: editingAppointment.id,
                        draft: draft,
                        at: now()
                    )
                }
            } else {
                saved = try service.create(draft: draft, at: now())
            }
            editorDraft = nil
            self.editingAppointment = nil
            isRescheduling = false
            try refreshThrowing()
            selectedAppointmentID = saved.id
            detail = try service.detail(id: saved.id)
        }
    }

    func perform(_ action: AppointmentAction) {
        guard selectedAppointmentID != nil else { return }
        if action == .cancel {
            pendingAction = action
            return
        }
        if action == .reschedule {
            beginReschedule()
            return
        }
        performSelected(action)
    }

    func confirmPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        performSelected(action)
    }

    func cancelPendingAction() {
        pendingAction = nil
    }

    func clearError() {
        errorMessage = nil
    }

    func createNoShowFollowUpTomorrow() {
        guard let request = pendingNoShowFollowUpRequest else { return }
        perform {
            guard let followUpService else { throw NoShowFollowUpError.serviceUnavailable }
            _ = try followUpService.createNoShowFollowUp(
                customerID: request.customerID,
                appointmentID: request.appointmentID,
                at: request.requestedAt
            )
            pendingNoShowFollowUpRequest = nil
        }
    }

    func beginCustomNoShowFollowUp() {
        guard let request = pendingNoShowFollowUpRequest else { return }
        let dueAt = (try? FollowUpSchedule.tomorrowAtEleven(
            from: request.requestedAt,
            calendar: calendar
        )) ?? request.requestedAt.addingTimeInterval(3_600)
        customFollowUpDraft = FollowUpEditorDraft(
            customerID: request.customerID,
            appointmentID: request.appointmentID,
            dueAt: dueAt,
            reason: "No-show follow-up"
        )
        pendingNoShowFollowUpRequest = nil
    }

    func skipNoShowFollowUp() {
        pendingNoShowFollowUpRequest = nil
    }

    func cancelCustomNoShowFollowUp() {
        customFollowUpDraft = nil
    }

    func saveCustomNoShowFollowUp() {
        guard let draft = customFollowUpDraft else { return }
        perform {
            guard let followUpService else { throw NoShowFollowUpError.serviceUnavailable }
            guard let customerID = draft.customerID else { throw NoShowFollowUpError.customerRequired }
            _ = try followUpService.create(
                customerID: customerID,
                appointmentID: draft.appointmentID,
                dueAt: draft.dueAt,
                reason: draft.reason,
                note: draft.note,
                priority: draft.priority,
                at: now()
            )
            customFollowUpDraft = nil
        }
    }

    private var selectedAppointment: Appointment? {
        detail?.listItem.appointment
            ?? rows.first(where: { $0.id == selectedAppointmentID })?.appointment
    }

    private func performSelected(_ action: AppointmentAction) {
        guard let id = selectedAppointmentID else { return }
        perform {
            let operationTime = now()
            let appointment = try service.transition(id: id, action: action, at: operationTime)
            if action == .markNoShow {
                pendingNoShowFollowUpRequest = NoShowFollowUpRequest(
                    appointmentID: appointment.id,
                    customerID: appointment.customerID,
                    requestedAt: operationTime
                )
            }
            try refreshThrowing()
            detail = try service.detail(id: id)
        }
    }

    private func refreshThrowing() throws {
        rows = try service.list(filter: filter)
        if let selectedAppointmentID {
            detail = try service.detail(id: selectedAppointmentID)
        }
    }

    private func perform(_ operation: () throws -> Void) {
        errorMessage = nil
        do {
            try operation()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private static func dayInterval(containing date: Date, calendar: Calendar) -> DateInterval? {
        calendar.dateInterval(of: .day, for: date)
    }
}
