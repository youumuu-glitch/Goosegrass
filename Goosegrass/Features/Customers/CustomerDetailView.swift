import SwiftUI

struct CustomerDetailView: View {
    let detail: CustomerDetail
    let onEdit: () -> Void
    let onArchive: () -> Void
    let onAddNote: (String) -> Void
    let onNewAppointment: (UUID) -> Void

    @State private var note = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                Divider()
                metadata
                notes
                Divider()
                timeline
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Customer detail for \(detail.customer.displayName)")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.customer.displayName).font(.largeTitle).fontWeight(.semibold)
                Text(detail.customer.phone).textSelection(.enabled)
                if let email = detail.customer.email { Text(email).foregroundStyle(.secondary) }
            }
            Spacer()
            Button("Edit", action: onEdit)
            Button("New Appointment") { onNewAppointment(detail.customer.id) }
            Button("Archive", role: .destructive, action: onArchive)
        }
    }

    private var metadata: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            metadataRow("Status", detail.customer.status.rawValue)
            metadataRow("Source", detail.sourceName ?? "None")
            metadataRow("Tags", detail.tagNames.isEmpty ? "None" : detail.tagNames.joined(separator: ", "))
            GridRow { Text("Created").foregroundStyle(.secondary); Text(detail.customer.createdAt, style: .date) }
            GridRow {
                Text("Last contacted").foregroundStyle(.secondary)
                if let date = detail.customer.lastContactedAt { Text(date, style: .date) } else { Text("Not recorded") }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes").font(.headline)
            if detail.customer.notes.isEmpty {
                Text("No notes yet.").foregroundStyle(.secondary)
            } else {
                Text(detail.customer.notes).textSelection(.enabled)
            }
            HStack {
                TextField("Add a note", text: $note)
                    .onSubmit(submitNote)
                Button("Add Note", action: submitNote)
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity").font(.headline)
            if detail.activities.isEmpty {
                Text("No activity recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(detail.activities) { activity in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle.fill").font(.system(size: 7)).padding(.top, 6).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(activity.title).fontWeight(.medium)
                            if !activity.detail.isEmpty { Text(activity.detail).foregroundStyle(.secondary) }
                            Text(activity.createdAt, format: .dateTime.year().month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func metadataRow(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value) }
    }

    private func submitNote() {
        let value = note
        note = ""
        onAddNote(value)
    }
}
