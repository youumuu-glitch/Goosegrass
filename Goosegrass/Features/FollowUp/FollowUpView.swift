import SwiftUI

@MainActor
struct FollowUpView: View {
    @ObservedObject var viewModel: FollowUpListViewModel

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                filterBar
                Divider()
                followUpTable
            }
            .frame(minWidth: 620, idealWidth: 780)

            Group {
                if let detail = viewModel.detail {
                    FollowUpDetailView(
                        detail: detail,
                        onComplete: viewModel.completeSelected,
                        onSnooze: viewModel.beginSnooze,
                        onCancel: viewModel.requestCancel
                    )
                } else {
                    EmptyStateView(
                        icon: "arrowshape.turn.up.right",
                        title: "Follow-up details",
                        message: "Select a follow-up to review customer context and available actions."
                    )
                }
            }
            .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Follow-up")
        .toolbar {
            Button(action: { viewModel.beginAdd() }) {
                Label("New Follow-up", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: .command)
            .help("New Follow-up (⌘N)")
        }
        .task { viewModel.load() }
        .sheet(isPresented: editorPresented) {
            FollowUpEditorView(
                draft: editorDraft,
                customers: viewModel.customerRows,
                appointments: viewModel.availableAppointments,
                onCancel: viewModel.cancelEditor,
                onSave: viewModel.saveEditor
            )
        }
        .sheet(isPresented: snoozePresented) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Snooze Follow-up").font(.title2).fontWeight(.semibold)
                DatePicker("New due time", selection: snoozeDate)
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel, action: viewModel.cancelSnooze)
                    Button("Snooze", action: viewModel.confirmSnooze)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 420, minHeight: 180)
        }
        .confirmationDialog("Cancel this follow-up?", isPresented: cancelPresented) {
            Button("Cancel Follow-up", role: .destructive, action: viewModel.confirmCancel)
            Button("Keep Follow-up", role: .cancel, action: viewModel.dismissCancel)
        } message: {
            Text("The record remains available in All follow-ups as cancelled history.")
        }
        .alert("Follow-up operation failed", isPresented: errorPresented) {
            Button("OK", action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var filterBar: some View {
        HStack {
            Picker("Queue", selection: scope) {
                Text("Active").tag(FollowUpListScope.active)
                Text("All").tag(FollowUpListScope.all)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            Spacer()
        }
        .padding(10)
        .accessibilityLabel("Follow-up filters")
    }

    private var followUpTable: some View {
        Table(viewModel.rows, selection: selection) {
            TableColumn("Due") { Text($0.followUp.dueAt, format: .dateTime.month().day().hour().minute()) }
            TableColumn("Customer") { Text($0.customerName) }
            TableColumn("Reason") { Text($0.followUp.reason).lineLimit(1) }
            TableColumn("Priority") { Text($0.followUp.priority.rawValue.capitalized) }
            TableColumn("Status") { Text($0.followUp.status.rawValue.capitalized) }
        }
        .overlay {
            if viewModel.rows.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: viewModel.scope == .active ? "No active follow-ups" : "No follow-ups",
                    message: viewModel.scope == .active
                        ? "New and snoozed follow-ups will appear here."
                        : "Create a follow-up to start the customer recovery queue."
                )
            }
        }
        .accessibilityLabel("Follow-up queue")
    }

    private var scope: Binding<FollowUpListScope> {
        Binding(get: { viewModel.scope }, set: viewModel.applyScope)
    }
    private var selection: Binding<UUID?> {
        Binding(get: { viewModel.selectedFollowUpID }, set: viewModel.select)
    }
    private var editorPresented: Binding<Bool> {
        Binding(get: { viewModel.editorDraft != nil }, set: { if !$0 { viewModel.cancelEditor() } })
    }
    private var editorDraft: Binding<FollowUpEditorDraft> {
        Binding(get: { viewModel.editorDraft ?? FollowUpEditorDraft() }, set: { viewModel.editorDraft = $0 })
    }
    private var snoozePresented: Binding<Bool> {
        Binding(get: { viewModel.snoozeDraftDate != nil }, set: { if !$0 { viewModel.cancelSnooze() } })
    }
    private var snoozeDate: Binding<Date> {
        Binding(get: { viewModel.snoozeDraftDate ?? Date() }, set: { viewModel.snoozeDraftDate = $0 })
    }
    private var cancelPresented: Binding<Bool> {
        Binding(
            get: { viewModel.isCancelConfirmationPresented },
            set: { if !$0 { viewModel.dismissCancel() } }
        )
    }
    private var errorPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
    }
}
