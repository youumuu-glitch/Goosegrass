import SwiftUI

struct DuplicateCustomerView: View {
    let review: DuplicateCustomerReview
    let onUseExisting: (UUID) -> Void
    let onCreateAnyway: () -> Void
    let onMerge: (UUID) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Possible duplicate", systemImage: "person.2.badge.gearshape")
                .font(.title2)
            Text("The normalized phone number matches an active customer. Choose how to preserve the records.")
                .foregroundStyle(.secondary)

            List(review.candidates) { candidate in
                VStack(alignment: .leading, spacing: 8) {
                    Text(candidate.displayName).font(.headline)
                    Text(candidate.phone).foregroundStyle(.secondary)
                    HStack {
                        Button("Use Existing") { onUseExisting(candidate.id) }
                        Button("Merge") { onMerge(candidate.id) }
                    }
                }
                .padding(.vertical, 6)
            }

            HStack {
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create Anyway", action: onCreateAnyway)
            }
        }
        .padding(24)
        .frame(width: 500, height: 380)
    }
}
