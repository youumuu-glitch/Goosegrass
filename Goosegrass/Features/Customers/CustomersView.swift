import SwiftUI

@MainActor
struct CustomersView: View {
    @ObservedObject var viewModel: CustomerListViewModel

    var body: some View {
        HSplitView {
            customerList
                .frame(minWidth: 420, idealWidth: 560)

            Group {
                if let detail = viewModel.detail {
                    CustomerDetailView(
                        detail: detail,
                        onEdit: viewModel.beginEdit,
                        onArchive: viewModel.requestArchive,
                        onAddNote: viewModel.addNote
                    )
                } else {
                    EmptyStateView(
                        icon: "person.crop.circle",
                        title: "Customer details",
                        message: "Select a customer to see contact details and activity history."
                    )
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Customers")
        .searchable(text: $viewModel.query, placement: .toolbar, prompt: "Name, phone, notes, tag, or source")
        .onSubmit(of: .search, viewModel.refresh)
        .onChange(of: viewModel.query) { _ in viewModel.refresh() }
        .toolbar {
            ToolbarItemGroup {
                Button(action: viewModel.beginAdd) {
                    Label("Add Customer", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Add Customer (⌘N)")

                Button(action: viewModel.beginEdit) {
                    Label("Edit Customer", systemImage: "pencil")
                }
                .disabled(viewModel.detail == nil)
                .help("Edit selected customer")

                Button(role: .destructive, action: viewModel.requestArchive) {
                    Label("Archive Customer", systemImage: "archivebox")
                }
                .disabled(viewModel.detail == nil)
                .help("Archive selected customer")
            }
        }
        .task { viewModel.load() }
        .sheet(isPresented: editorPresented) {
            CustomerEditorView(
                draft: editorDraft,
                catalog: viewModel.catalog,
                isEditing: viewModel.editingCustomer != nil,
                onCancel: viewModel.cancelEditor,
                onSave: { viewModel.saveEditor() }
            )
        }
        .sheet(isPresented: duplicatePresented) {
            if let review = viewModel.duplicateReview {
                DuplicateCustomerView(
                    review: review,
                    onUseExisting: viewModel.useExisting,
                    onCreateAnyway: viewModel.createAnyway,
                    onMerge: viewModel.mergeDuplicate,
                    onCancel: viewModel.cancelEditor
                )
            }
        }
        .confirmationDialog(
            "Archive this customer?",
            isPresented: archivePresented,
            presenting: viewModel.archiveTarget
        ) { _ in
            Button("Archive", role: .destructive, action: viewModel.confirmArchive)
            Button("Cancel", role: .cancel, action: viewModel.cancelArchive)
        } message: { customer in
            Text("\(customer.displayName) will be hidden from active customer lists. History remains stored.")
        }
        .alert("Customer operation failed", isPresented: errorPresented) {
            Button("OK", action: viewModel.clearError)
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var customerList: some View {
        Group {
            if viewModel.rows.isEmpty {
                if viewModel.query.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No customers yet",
                        message: "Add the first customer to start building history.",
                        actionTitle: "Add Customer",
                        action: viewModel.beginAdd
                    )
                } else {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No matching customers",
                        message: "Try a different name, phone, note, tag, or source."
                    )
                }
            } else {
                List(selection: selection) {
                    ForEach(viewModel.rows) { row in
                        CustomerRow(item: row)
                            .tag(row.id)
                    }
                }
                .accessibilityLabel("Customers")
            }
        }
    }

    private var selection: Binding<UUID?> {
        Binding(get: { viewModel.selectedCustomerID }, set: viewModel.select)
    }

    private var editorPresented: Binding<Bool> {
        Binding(
            get: { viewModel.editorDraft != nil && viewModel.duplicateReview == nil },
            set: { if !$0 { viewModel.cancelEditor() } }
        )
    }

    private var editorDraft: Binding<CustomerEditorDraft> {
        Binding(
            get: { viewModel.editorDraft ?? CustomerEditorDraft() },
            set: { viewModel.editorDraft = $0 }
        )
    }

    private var duplicatePresented: Binding<Bool> {
        Binding(get: { viewModel.duplicateReview != nil }, set: { if !$0 { viewModel.cancelEditor() } })
    }

    private var archivePresented: Binding<Bool> {
        Binding(get: { viewModel.archiveTarget != nil }, set: { if !$0 { viewModel.cancelArchive() } })
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.clearError() } })
    }
}

private struct CustomerRow: View {
    let item: CustomerListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.customer.displayName).font(.headline)
                Spacer()
                Text(item.customer.status.rawValue).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label(item.customer.phone, systemImage: "phone")
                if let sourceName = item.sourceName {
                    Label(sourceName, systemImage: "arrow.down.right.circle")
                }
                if !item.tagNames.isEmpty {
                    Text(item.tagNames.joined(separator: " · "))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if !item.customer.notes.isEmpty {
                Text(item.customer.notes).lineLimit(1).font(.caption)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
