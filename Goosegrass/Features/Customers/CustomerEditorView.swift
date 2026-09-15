import SwiftUI

struct CustomerEditorView: View {
    @Binding var draft: CustomerEditorDraft
    let catalog: CustomerCatalog
    let isEditing: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field { case name, phone, email, notes }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Contact") {
                    TextField("Display name", text: $draft.displayName)
                        .focused($focusedField, equals: .name)
                    TextField("Legal name", text: $draft.legalName)
                    TextField("Phone", text: $draft.phone)
                        .focused($focusedField, equals: .phone)
                    TextField("Email", text: $draft.email)
                        .focused($focusedField, equals: .email)
                }

                Section("Classification") {
                    Picker("Source", selection: $draft.sourceID) {
                        Text("None").tag(UUID?.none)
                        ForEach(catalog.sources) { source in
                            Text(source.name).tag(Optional(source.id))
                        }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(CustomerStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    if !catalog.tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags").font(.caption).foregroundStyle(.secondary)
                            ForEach(catalog.tags) { tag in
                                Toggle(tag.name, isOn: tagBinding(tag.id))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 90)
                        .accessibilityLabel("Customer notes")
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "Save Changes" : "Add Customer", action: onSave)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 520, height: 560)
        .navigationTitle(isEditing ? "Edit Customer" : "Add Customer")
        .onAppear { focusedField = .name }
    }

    private func tagBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { draft.tagIDs.contains(id) },
            set: { selected in
                if selected { draft.tagIDs.insert(id) } else { draft.tagIDs.remove(id) }
            }
        )
    }
}
