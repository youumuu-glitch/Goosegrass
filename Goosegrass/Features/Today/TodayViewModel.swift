import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var snapshot: TodaySnapshot?
    @Published private(set) var selection: TodaySelection = .all
    @Published private(set) var appointmentRows: [AppointmentListItem] = []
    @Published private(set) var customerRows: [CustomerListItem] = []
    @Published private(set) var selectedAppointmentID: UUID?
    @Published private(set) var detail: AppointmentDetail?
    @Published var rescheduleDraft: AppointmentEditorDraft?
    @Published private(set) var pendingAction: AppointmentAction?
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingNoShowFollowUpRequest: NoShowFollowUpRequest?
    @Published var customFollowUpDraft: FollowUpEditorDraft?

    private let service: TodayService
    private let followUpService: FollowUpService?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        service: TodayService,
        followUpService: FollowUpService? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.followUpService = followUpService
        self.calendar = calendar
        self.now = now
    }

    var availableQuickActions: [AppointmentAction] {
        guard let status = selectedAppointment?.status else { return [] }
        let quickActions: Set<AppointmentAction> = [.arrive, .reschedule, .markNoShow, .cancel]
        return AppointmentLifecycle.allowedActions(from: status).filter(quickActions.contains)
    }

    func load() {
        perform { try reloadThrowing() }
    }

    func selectCard(_ selection: TodaySelection) {
        self.selection = selection
        applySelection()
    }

    func selectAppointment(_ id: UUID?) {
        selectedAppointmentID = id
        guard let id else {
            detail = nil
            return
        }
        perform { detail = try service.detail(appointmentID: id) }
    }

    func beginReschedule() {
        guard let appointment = selectedAppointment,
              availableQuickActions.contains(.reschedule) else {
            return
        }
        errorMessage = nil
        rescheduleDraft = AppointmentEditorDraft(appointment: appointment)
    }

    func cancelReschedule() {
        rescheduleDraft = nil
        errorMessage = nil
    }

    func saveReschedule(reason: String = "") {
        guard let id = selectedAppointmentID,
              let draft = rescheduleDraft else {
            return
        }
        perform {
            _ = try service.reschedule(
                appointmentID: id,
                startAt: draft.startAt,
                endAt: draft.endAt,
                reason: reason
            )
            rescheduleDraft = nil
            try reloadThrowing()
        }
    }

    func perform(_ action: AppointmentAction) {
        guard selectedAppointmentID != nil,
              availableQuickActions.contains(action) else {
            return
        }
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
            ?? snapshot?.allAppointments.first(where: { $0.id == selectedAppointmentID })?.appointment
    }

    private func performSelected(_ action: AppointmentAction) {
        guard let id = selectedAppointmentID else { return }
        perform {
            let operationTime = now()
            let appointment = try service.transition(appointmentID: id, action: action)
            if action == .markNoShow {
                pendingNoShowFollowUpRequest = NoShowFollowUpRequest(
                    appointmentID: appointment.id,
                    customerID: appointment.customerID,
                    requestedAt: operationTime
                )
            }
            try reloadThrowing()
        }
    }

    private func reloadThrowing() throws {
        let authoritativeSnapshot = try service.snapshot()
        snapshot = authoritativeSnapshot
        applySelection()

        guard let selectedAppointmentID,
              authoritativeSnapshot.allAppointments.contains(where: { $0.id == selectedAppointmentID }) else {
            self.selectedAppointmentID = nil
            detail = nil
            return
        }
        detail = try service.detail(appointmentID: selectedAppointmentID)
    }

    private func applySelection() {
        guard let snapshot else {
            appointmentRows = []
            customerRows = []
            return
        }
        appointmentRows = snapshot.appointments(for: selection)
        customerRows = selection == .needContact ? snapshot.needContactCustomers : []
    }

    private func perform(_ operation: () throws -> Void) {
        errorMessage = nil
        do {
            try operation()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
