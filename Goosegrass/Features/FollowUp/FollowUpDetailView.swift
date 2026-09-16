import SwiftUI

struct FollowUpDetailView: View {
    let detail: FollowUpDetail
    let onComplete: () -> Void
    let onSnooze: () -> Void
    let onCancel: () -> Void

    private var isActive: Bool {
        detail.listItem.followUp.status == .pending || detail.listItem.followUp.status == .snoozed
    }

    var body: some View {
        let followUp = detail.listItem.followUp
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.listItem.customerName).font(.largeTitle).fontWeight(.semibold)
                    Text(followUp.status.rawValue.capitalized).foregroundStyle(.secondary)
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    row("Phone", detail.listItem.customerPhone)
                    row("Due", followUp.dueAt.formatted(date: .abbreviated, time: .shortened))
                    row("Priority", followUp.priority.rawValue.capitalized)
                    row("Reason", followUp.reason)
                    row("Note", followUp.note.isEmpty ? "None" : followUp.note)
                    row("Appointment", detail.appointmentStartAt?.formatted(date: .abbreviated, time: .shortened) ?? "None")
                    row("Created", followUp.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let completedAt = followUp.completedAt {
                        row("Completed", completedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                if isActive {
                    HStack {
                        Button("Complete", action: onComplete)
                            .keyboardShortcut(.defaultAction)
                        Button("Snooze", action: onSnooze)
                        Button("Cancel Follow-up", role: .destructive, action: onCancel)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("Follow-up detail for \(detail.listItem.customerName)")
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}
