import SwiftUI

@MainActor
struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel
    let onNewAppointment: () -> Void

    init(viewModel: TodayViewModel, onNewAppointment: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onNewAppointment = onNewAppointment
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                summaryCards
                Divider()
                workspaceList
            }
            .frame(minWidth: 680, idealWidth: 860)

            inspector
                .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Today")
        .toolbar {
            Button(action: onNewAppointment) {
                Label("New Appointment", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("New Appointment (⌘N)")

            Button("Mark Arrived", action: { viewModel.perform(.arrive) })
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.availableQuickActions.contains(.arrive))
                .help("Mark the selected upcoming appointment as arrived (Return)")
        }
        .task { viewModel.load() }
        .sheet(isPresented: reschedulePresented) {
            AppointmentEditorView(
                draft: rescheduleDraft,
                customers: rescheduleCustomers,
                sources: rescheduleSources,
                isEditing: true,
                isRescheduling: true,
                isHistorical: viewModel.rescheduleDraft?.isHistorical() ?? false,
                onCancel: viewModel.cancelReschedule,
                onSave: viewModel.saveReschedule
            )
        }
        .sheet(isPresented: customFollowUpPresented) {
            FollowUpEditorView(
                draft: customFollowUpDraft,
                customers: customFollowUpCustomers,
                appointments: customFollowUpAppointments,
                onCancel: viewModel.cancelCustomNoShowFollowUp,
                onSave: viewModel.saveCustomNoShowFollowUp
            )
        }
        .confirmationDialog("Create a follow-up?", isPresented: noShowFollowUpPresented) {
            Button("Tomorrow 11:00", action: viewModel.createNoShowFollowUpTomorrow)
            Button("Custom…", action: viewModel.beginCustomNoShowFollowUp)
            Button("Skip", role: .cancel, action: viewModel.skipNoShowFollowUp)
        } message: {
            Text("The appointment is already marked no-show. Choose whether to add a customer follow-up.")
        }
        .confirmationDialog("Cancel this appointment?", isPresented: cancellationPresented) {
            Button("Cancel Appointment", role: .destructive, action: viewModel.confirmPendingAction)
            Button("Keep Appointment", role: .cancel, action: viewModel.cancelPendingAction)
        } message: {
            Text("The appointment remains visible in today's complete history with a cancelled status.")
        }
        .alert("Today operation failed", isPresented: errorPresented) {
            Button("OK", action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var summaryCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily overview").font(.headline)
                Spacer()
                if viewModel.selection != .all {
                    Button("Show All") { viewModel.selectCard(.all) }
                        .help("Restore the complete appointment history for today")
                }
            }
            HStack(spacing: 10) {
                card("Today's Appointments", value: viewModel.snapshot?.counts.todayAppointments ?? 0, icon: "calendar", selection: .todayAppointments)
                card("Upcoming Arrivals", value: viewModel.snapshot?.counts.upcomingArrivals ?? 0, icon: "clock", selection: .upcomingArrivals)
                card("Need Contact", value: viewModel.snapshot?.counts.needContact ?? 0, icon: "phone", selection: .needContact)
                card("No-show", value: viewModel.snapshot?.counts.noShow ?? 0, icon: "person.crop.circle.badge.xmark", selection: .noShow)
            }
        }
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today summary")
    }

    private func card(
        _ title: String,
        value: Int,
        icon: String,
        selection: TodaySelection
    ) -> some View {
        TodaySummaryCard(
            title: title,
            value: value,
            systemImage: icon,
            isSelected: viewModel.selection == selection,
            action: { viewModel.selectCard(selection) }
        )
    }

    @ViewBuilder
    private var workspaceList: some View {
        if viewModel.selection == .needContact {
            if viewModel.customerRows.isEmpty {
                EmptyStateView(icon: "phone", title: "No customers need contact", message: "Customers marked for contact appear here.")
            } else {
                List(viewModel.customerRows) { row in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(row.customer.displayName).font(.headline)
                            Spacer()
                            Text(row.customer.status.rawValue).foregroundStyle(.secondary)
                        }
                        Label(row.customer.phone, systemImage: "phone")
                            .font(.caption)
                        if !row.tagNames.isEmpty {
                            Text(row.tagNames.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
                .accessibilityLabel("Customers needing contact")
            }
        } else if viewModel.appointmentRows.isEmpty {
            EmptyStateView(
                icon: "calendar",
                title: "No matching appointments",
                message: viewModel.selection == .all
                    ? "Today's appointments will appear here."
                    : "Choose another summary card or show all appointments."
            )
        } else {
            Table(viewModel.appointmentRows, selection: appointmentSelection) {
                TableColumn("Time") { Text($0.appointment.startAt, format: .dateTime.hour().minute()) }
                TableColumn("Customer") { Text($0.customerName) }
                TableColumn("Party") { Text("\($0.appointment.partySize)") }
                TableColumn("Phone") { Text(phoneTail($0.customerPhone)) }
                TableColumn("Source") { Text($0.sourceName ?? "—") }
                TableColumn("Status") { Text($0.appointment.status.rawValue) }
                TableColumn("Tags") { Text($0.tagNames.isEmpty ? "—" : $0.tagNames.joined(separator: ", ")).lineLimit(1) }
                TableColumn("Request") { Text($0.appointment.customerRequest.isEmpty ? "—" : $0.appointment.customerRequest).lineLimit(1) }
                TableColumn("Actions") { row in
                    HStack(spacing: 5) {
                        ForEach(quickActions(for: row), id: \.self) { action in
                            Button(actionTitle(action)) {
                                viewModel.selectAppointment(row.id)
                                viewModel.perform(action)
                            }
                            .buttonStyle(.borderless)
                            .help("\(actionTitle(action)) for \(row.customerName)")
                        }
                    }
                }
            }
            .accessibilityLabel("Today's appointment history")
        }
    }

    @ViewBuilder
    private var inspector: some View {
        if let detail = viewModel.detail {
            AppointmentDetailView(
                detail: detail,
                allowedActions: viewModel.availableQuickActions,
                onEdit: viewModel.beginReschedule,
                onAction: viewModel.perform
            )
        } else {
            EmptyStateView(
                icon: viewModel.selection == .needContact ? "phone" : "calendar.badge.clock",
                title: viewModel.selection == .needContact ? "Contact queue" : "Appointment details",
                message: viewModel.selection == .needContact
                    ? "The contact queue is a focused customer list; customer detail remains in Customers."
                    : "Select an appointment to inspect its history and available actions."
            )
        }
    }

    private func quickActions(for row: AppointmentListItem) -> [AppointmentAction] {
        let allowed: Set<AppointmentAction> = [.arrive, .reschedule, .markNoShow, .cancel]
        return AppointmentLifecycle.allowedActions(from: row.appointment.status).filter(allowed.contains)
    }

    private func actionTitle(_ action: AppointmentAction) -> String {
        switch action {
        case .arrive: "Arrive"
        case .reschedule: "Reschedule"
        case .markNoShow: "No-show"
        case .cancel: "Cancel"
        default: action.rawValue
        }
    }

    private func phoneTail(_ phone: String) -> String {
        let tail = phone.suffix(4)
        return tail.isEmpty ? "—" : "•••• \(tail)"
    }

    private var appointmentSelection: Binding<UUID?> {
        Binding(get: { viewModel.selectedAppointmentID }, set: viewModel.selectAppointment)
    }

    private var reschedulePresented: Binding<Bool> {
        Binding(get: { viewModel.rescheduleDraft != nil }, set: { if !$0 { viewModel.cancelReschedule() } })
    }

    private var rescheduleDraft: Binding<AppointmentEditorDraft> {
        Binding(get: { viewModel.rescheduleDraft ?? AppointmentEditorDraft() }, set: { viewModel.rescheduleDraft = $0 })
    }

    private var rescheduleCustomers: [CustomerListItem] {
        guard let item = viewModel.detail?.listItem else { return [] }
        return [CustomerListItem(
            customer: Customer(
                id: item.appointment.customerID,
                displayName: item.customerName,
                phone: item.customerPhone,
                normalizedPhone: item.customerPhone,
                sourceID: item.appointment.sourceID
            ),
            sourceName: item.sourceName,
            tagNames: item.tagNames,
            nextAppointmentAt: item.appointment.startAt
        )]
    }

    private var rescheduleSources: [LeadSource] {
        guard let item = viewModel.detail?.listItem,
              let sourceID = item.appointment.sourceID,
              let sourceName = item.sourceName else {
            return []
        }
        return [LeadSource(id: sourceID, name: sourceName)]
    }

    private var cancellationPresented: Binding<Bool> {
        Binding(get: { viewModel.pendingAction == .cancel }, set: { if !$0 { viewModel.cancelPendingAction() } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
    }

    private var noShowFollowUpPresented: Binding<Bool> {
        Binding(
            get: { viewModel.pendingNoShowFollowUpRequest != nil },
            set: { if !$0 { viewModel.skipNoShowFollowUp() } }
        )
    }

    private var customFollowUpPresented: Binding<Bool> {
        Binding(
            get: { viewModel.customFollowUpDraft != nil },
            set: { if !$0 { viewModel.cancelCustomNoShowFollowUp() } }
        )
    }

    private var customFollowUpDraft: Binding<FollowUpEditorDraft> {
        Binding(
            get: { viewModel.customFollowUpDraft ?? FollowUpEditorDraft() },
            set: { viewModel.customFollowUpDraft = $0 }
        )
    }

    private var customFollowUpCustomers: [CustomerListItem] {
        guard let item = viewModel.detail?.listItem else { return [] }
        return [CustomerListItem(
            customer: Customer(
                id: item.appointment.customerID,
                displayName: item.customerName,
                phone: item.customerPhone,
                normalizedPhone: item.customerPhone,
                sourceID: item.appointment.sourceID
            ),
            sourceName: item.sourceName,
            tagNames: item.tagNames,
            nextAppointmentAt: item.appointment.startAt
        )]
    }

    private var customFollowUpAppointments: [AppointmentListItem] {
        guard let item = viewModel.detail?.listItem else { return [] }
        return [item]
    }
}
