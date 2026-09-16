import SwiftUI

struct FollowUpEditorView: View {
    @Binding var draft: FollowUpEditorDraft
    let customers: [CustomerListItem]
    let appointments: [AppointmentListItem]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Follow-up").font(.title2).fontWeight(.semibold)
            Form {
                Picker("Customer", selection: $draft.customerID) {
                    Text("Choose Customer").tag(UUID?.none)
                    ForEach(customers) { row in
                        Text(row.customer.displayName).tag(Optional(row.id))
                    }
                }
                Picker("Appointment", selection: $draft.appointmentID) {
                    Text("None").tag(UUID?.none)
                    ForEach(appointments) { row in
                        Text("\(row.customerName) — \(row.appointment.startAt.formatted(date: .abbreviated, time: .shortened))")
                            .tag(Optional(row.id))
                    }
                }
                DatePicker("Due", selection: $draft.dueAt)
                TextField("Reason", text: $draft.reason)
                TextField("Note", text: $draft.note, axis: .vertical)
                    .lineLimit(3...6)
                Picker("Priority", selection: $draft.priority) {
                    ForEach(FollowUpPriority.allCases, id: \.self) { priority in
                        Text(priority.rawValue.capitalized).tag(priority)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                Button("Create", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 420)
        .accessibilityLabel("Follow-up editor")
    }
}
