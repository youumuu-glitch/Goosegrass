import Combine
import Foundation

struct DuplicateCustomerReview: Equatable, Sendable {
    let draft: CustomerEditorDraft
    let candidates: [Customer]
}

@MainActor
final class CustomerListViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var rows: [CustomerListItem] = []
    @Published private(set) var catalog = CustomerCatalog(sources: [], tags: [])
    @Published private(set) var selectedCustomerID: UUID?
    @Published private(set) var detail: CustomerDetail?
    @Published var editorDraft: CustomerEditorDraft?
    @Published private(set) var editingCustomer: Customer?
    @Published private(set) var duplicateReview: DuplicateCustomerReview?
    @Published private(set) var archiveTarget: Customer?
    @Published private(set) var errorMessage: String?

    private let service: CustomerService
    private let now: () -> Date

    init(service: CustomerService, now: @escaping () -> Date = Date.init) {
        self.service = service
        self.now = now
    }

    func load() {
        perform {
            catalog = try service.catalog()
            try refreshThrowing()
        }
    }

    func refresh() {
        perform { try refreshThrowing() }
    }

    func select(_ id: UUID?) {
        selectedCustomerID = id
        guard let id else {
            detail = nil
            return
        }
        perform { detail = try service.detail(id: id) }
    }

    func beginAdd() {
        errorMessage = nil
        editingCustomer = nil
        editorDraft = CustomerEditorDraft()
    }

    func beginEdit() {
        guard let customer = detail?.customer
            ?? rows.first(where: { $0.id == selectedCustomerID })?.customer else { return }
        errorMessage = nil
        editingCustomer = customer
        editorDraft = CustomerEditorDraft(customer: customer)
    }

    func cancelEditor() {
        editorDraft = nil
        editingCustomer = nil
        duplicateReview = nil
        errorMessage = nil
    }

    func saveEditor(allowDuplicate: Bool = false) {
        guard let draft = editorDraft else { return }
        perform {
            let result = try service.submit(
                draft: draft,
                editing: editingCustomer,
                allowDuplicate: allowDuplicate,
                at: now()
            )
            switch result {
            case let .saved(customer):
                try finishMutation(selecting: customer.id)
            case let .possibleDuplicates(pendingDraft, candidates):
                duplicateReview = DuplicateCustomerReview(draft: pendingDraft, candidates: candidates)
            }
        }
    }

    func useExisting(_ id: UUID) {
        duplicateReview = nil
        editorDraft = nil
        editingCustomer = nil
        refresh()
        select(id)
    }

    func createAnyway() {
        guard let review = duplicateReview else { return }
        editorDraft = review.draft
        duplicateReview = nil
        saveEditor(allowDuplicate: true)
    }

    func mergeDuplicate(into retainedID: UUID) {
        guard let review = duplicateReview else { return }
        perform {
            let result = try service.submit(draft: review.draft, allowDuplicate: true, at: now())
            guard case let .saved(duplicate) = result else { return }
            try service.merge(retaining: retainedID, archiving: duplicate.id, at: now())
            try finishMutation(selecting: retainedID)
        }
    }

    func requestArchive() {
        archiveTarget = detail?.customer
            ?? rows.first(where: { $0.id == selectedCustomerID })?.customer
    }

    func cancelArchive() {
        archiveTarget = nil
    }

    func confirmArchive() {
        guard let customer = archiveTarget else { return }
        perform {
            try service.archive(id: customer.id, at: now())
            archiveTarget = nil
            selectedCustomerID = nil
            detail = nil
            try refreshThrowing()
        }
    }

    func addNote(_ text: String) {
        guard let id = selectedCustomerID else { return }
        perform {
            try service.addNote(customerID: id, text: text, at: now())
            try refreshThrowing()
            detail = try service.detail(id: id)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func finishMutation(selecting id: UUID) throws {
        duplicateReview = nil
        editorDraft = nil
        editingCustomer = nil
        try refreshThrowing()
        selectedCustomerID = id
        detail = try service.detail(id: id)
    }

    private func refreshThrowing() throws {
        rows = try service.list(query: query)
        if let selectedCustomerID,
           rows.contains(where: { $0.id == selectedCustomerID }) {
            detail = try service.detail(id: selectedCustomerID)
        }
    }

    private func perform(_ operation: () throws -> Void) {
        errorMessage = nil
        do {
            try operation()
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
