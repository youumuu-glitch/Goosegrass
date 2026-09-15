import SwiftUI

struct AppointmentDetailView: View {
    let detail: AppointmentDetail
    let allowedActions: [AppointmentAction]
    let onEdit: () -> Void
    let onAction: (AppointmentAction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(detail.listItem.customerName).font(.largeTitle).fontWeight(.semibold)
                        Text(detail.listItem.appointment.status.rawValue).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit", action: onEdit)
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    row("Start", detail.listItem.appointment.startAt.formatted(date: .abbreviated, time: .shortened))
                    row("Party size", "\(detail.listItem.appointment.partySize)")
                    row("Phone", detail.listItem.customerPhone)
                    row("Source", detail.listItem.sourceName ?? "None")
                    row("Tags", detail.listItem.tagNames.isEmpty ? "None" : detail.listItem.tagNames.joined(separator: ", "))
                    row("Reminders", detail.listItem.reminderStatuses.map(\.rawValue).joined(separator: ", "))
                }
                HStack {
                    ForEach(allowedActions, id: \.self) { action in
                        Button(action.rawValue, role: action == .cancel ? .destructive : nil) { onAction(action) }
                            .help("Apply \(action.rawValue) to this appointment")
                    }
                }
                Divider()
                history("Changes", items: detail.changes.map { "\($0.changeType.rawValue) — \($0.changedAt.formatted())" })
                history("Activity", items: detail.activities.map { "\($0.title) — \($0.createdAt.formatted())" })
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Appointment detail for \(detail.listItem.customerName), status \(detail.listItem.appointment.status.rawValue)")
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow { Text(label).foregroundStyle(.secondary); Text(value.isEmpty ? "None" : value) }
    }
    private func history(_ title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if items.isEmpty { Text("No history.").foregroundStyle(.secondary) }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in Text(item) }
        }
    }
}
