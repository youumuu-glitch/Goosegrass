import SwiftUI

struct AppointmentEditorView: View {
    @Binding var draft: AppointmentEditorDraft
    let customers: [CustomerListItem]
    let sources: [LeadSource]
    let isEditing: Bool
    let isRescheduling: Bool
    let isHistorical: Bool
    let onCancel: () -> Void
    let onSave: (String) -> Void
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(isRescheduling ? "Reschedule Appointment" : isEditing ? "Edit Appointment" : "New Appointment")
                .font(.title2).fontWeight(.semibold)
            Form {
                Picker("Customer", selection: $draft.customerID) {
                    Text("Choose a customer").tag(UUID?.none)
                    ForEach(customers) { row in Text(row.customer.displayName).tag(Optional(row.id)) }
                }
                DatePicker("Start", selection: $draft.startAt)
                DatePicker("End", selection: endDate, displayedComponents: [.date, .hourAndMinute])
                Stepper("Party size: \(draft.partySize)", value: $draft.partySize, in: 1...999)
                Picker("Source", selection: $draft.sourceID) {
                    Text("None").tag(UUID?.none)
                    ForEach(sources) { source in Text(source.name).tag(Optional(source.id)) }
                }
                TextField("Customer request", text: $draft.customerRequest, axis: .vertical)
                TextField("Internal note", text: $draft.internalNote, axis: .vertical)
                if isRescheduling { TextField("Reason", text: $reason) }
                if isHistorical {
                    Label("This appointment is in the past and will be saved as historical data.", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Save") { onSave(reason) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
        .accessibilityLabel(isRescheduling ? "Reschedule appointment" : "Appointment editor")
    }

    private var endDate: Binding<Date> {
        Binding(get: { draft.endAt ?? draft.startAt }, set: { draft.endAt = $0 })
    }
}
