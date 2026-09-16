import SwiftUI

@MainActor
struct AppointmentsView: View {
    @ObservedObject var viewModel: AppointmentListViewModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filters
                Divider()
                appointmentTable
            }
            .frame(minWidth: 620, idealWidth: 780)

            Group {
                if let detail = viewModel.detail {
                    AppointmentDetailView(
                        detail: detail,
                        allowedActions: viewModel.allowedActions,
                        onEdit: viewModel.beginEdit,
                        onAction: viewModel.perform
                    )
                } else {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "Appointment details",
                        message: "Select an appointment to review its history and available actions."
                    )
                }
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Appointments")
        .toolbar {
            Button(action: { viewModel.beginAdd() }) {
                Label("New Appointment", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            Button(action: viewModel.beginEdit) { Label("Edit", systemImage: "pencil") }
                .disabled(viewModel.detail == nil)
        }
        .task { viewModel.load() }
        .sheet(isPresented: editorPresented) {
            AppointmentEditorView(
                draft: editorDraft,
                customers: viewModel.customerRows,
                sources: viewModel.catalog.sources,
                isEditing: viewModel.editingAppointment != nil,
                isRescheduling: viewModel.isReschedulingEditor,
                isHistorical: viewModel.isHistoricalDraft,
                onCancel: viewModel.cancelEditor,
                onSave: viewModel.saveEditor
            )
        }
        .sheet(isPresented: customFollowUpPresented) {
            FollowUpEditorView(
                draft: customFollowUpDraft,
                customers: viewModel.customerRows,
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
            Text("The appointment remains in history with a cancelled status.")
        }
        .alert("Appointment operation failed", isPresented: errorPresented) {
            Button("OK", action: viewModel.clearError)
        } message: { Text(viewModel.errorMessage ?? "Unknown error") }
    }

    private var filters: some View {
        HStack {
            Picker("Dates", selection: datePreset) {
                Text("Today").tag(AppointmentDatePreset.today)
                Text("Tomorrow").tag(AppointmentDatePreset.tomorrow)
                Text("This Week").tag(AppointmentDatePreset.thisWeek)
                Text("All").tag(AppointmentDatePreset.all)
            }
            .frame(width: 170)
            Picker("Customer", selection: customerFilter) {
                Text("All Customers").tag(UUID?.none)
                ForEach(viewModel.customerRows) { row in
                    Text(row.customer.displayName).tag(Optional(row.id))
                }
            }
            Picker("Source", selection: sourceFilter) {
                Text("All Sources").tag(UUID?.none)
                ForEach(viewModel.catalog.sources) { source in Text(source.name).tag(Optional(source.id)) }
            }
            Menu("Status") {
                ForEach(AppointmentStatus.allCases, id: \.self) { status in
                    Toggle(status.rawValue, isOn: statusBinding(status))
                }
            }
            Spacer()
        }
        .padding(10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appointment filters")
    }

    private var appointmentTable: some View {
        Table(viewModel.rows, selection: selection) {
            TableColumn("Date") { Text($0.appointment.startAt, format: .dateTime.month().day().hour().minute()) }
            TableColumn("Customer") { Text($0.customerName) }
            TableColumn("Phone") { Text($0.customerPhone) }
            TableColumn("Party") { Text("\($0.appointment.partySize)") }
            TableColumn("Status") { Text($0.appointment.status.rawValue) }
            TableColumn("Source") { Text($0.sourceName ?? "—") }
            TableColumn("Tags") { Text($0.tagNames.joined(separator: ", ")) }
            TableColumn("Reminders") { Text($0.reminderStatuses.map(\.rawValue).joined(separator: ", ")) }
        }
        .overlay {
            if viewModel.rows.isEmpty {
                EmptyStateView(icon: "calendar", title: "No appointments", message: "Adjust filters or create an appointment.")
            }
        }
        .accessibilityLabel("Appointments")
    }

    private var selection: Binding<UUID?> {
        Binding(get: { viewModel.selectedAppointmentID }, set: viewModel.select)
    }
    private var datePreset: Binding<AppointmentDatePreset> {
        Binding(get: { viewModel.datePreset }, set: viewModel.applyDatePreset)
    }
    private var customerFilter: Binding<UUID?> {
        Binding(get: { viewModel.filter.customerID }, set: { viewModel.filter.customerID = $0; viewModel.refresh() })
    }
    private var sourceFilter: Binding<UUID?> {
        Binding(get: { viewModel.filter.sourceID }, set: { viewModel.filter.sourceID = $0; viewModel.refresh() })
    }
    private func statusBinding(_ status: AppointmentStatus) -> Binding<Bool> {
        Binding(
            get: { viewModel.filter.statuses.contains(status) },
            set: { enabled in
                if enabled { viewModel.filter.statuses.insert(status) } else { viewModel.filter.statuses.remove(status) }
                viewModel.refresh()
            }
        )
    }
    private var editorPresented: Binding<Bool> {
        Binding(get: { viewModel.editorDraft != nil }, set: { if !$0 { viewModel.cancelEditor() } })
    }
    private var editorDraft: Binding<AppointmentEditorDraft> {
        Binding(get: { viewModel.editorDraft ?? AppointmentEditorDraft() }, set: { viewModel.editorDraft = $0 })
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
    private var customFollowUpAppointments: [AppointmentListItem] {
        guard let item = viewModel.detail?.listItem else { return [] }
        return [item]
    }
}
