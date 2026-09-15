import Foundation

@MainActor
final class CustomerService {
    private let repository: any CustomerRepository

    init(repository: any CustomerRepository) {
        self.repository = repository
    }

    func create(_ customer: Customer) throws {
        try repository.create(customer)
    }

    func update(_ customer: Customer) throws {
        try repository.update(customer)
    }

    func fetch(id: UUID) throws -> Customer? {
        try repository.fetch(id: id)
    }

    func search(query: String) throws -> [Customer] {
        try repository.search(query: query)
    }

    func duplicateCandidates(normalizedPhone: String) throws -> [Customer] {
        try repository.findPossibleDuplicates(normalizedPhone: normalizedPhone)
    }

    func list(query: String = "") throws -> [CustomerListItem] {
        try repository.fetchList(query: query)
    }

    func detail(id: UUID) throws -> CustomerDetail? {
        try repository.fetchDetail(id: id)
    }

    func catalog() throws -> CustomerCatalog {
        try repository.seedDefaultSources()
        return try repository.fetchCatalog()
    }

    func submit(
        draft: CustomerEditorDraft,
        editing existing: Customer? = nil,
        allowDuplicate: Bool = false,
        at now: Date = Date()
    ) throws -> CustomerSubmissionResult {
        let customer = try draft.makeCustomer(existing: existing, now: now)
        if existing == nil && !allowDuplicate {
            let candidates = try repository.findPossibleDuplicates(normalizedPhone: customer.normalizedPhone)
                .filter { $0.id != customer.id }
            if !candidates.isEmpty {
                return .possibleDuplicates(draft: draft, candidates: candidates)
            }
        }

        if existing == nil {
            try repository.create(customer)
            try repository.appendActivity(Activity(
                customerID: customer.id,
                type: .customerCreated,
                title: "Customer created",
                createdAt: now
            ))
        } else {
            try repository.update(customer)
        }
        return .saved(try repository.fetch(id: customer.id) ?? customer)
    }

    func addNote(customerID: UUID, text: String, at now: Date = Date()) throws {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { throw CustomerEditorError.emptyNote }
        guard var customer = try repository.fetch(id: customerID) else {
            throw PersistenceError.customerNotFound(customerID)
        }
        customer.notes = [customer.notes, note].filter { !$0.isEmpty }.joined(separator: "\n\n")
        customer.updatedAt = now
        try repository.update(customer)
        try repository.appendActivity(Activity(
            customerID: customerID,
            type: .noteAdded,
            title: "Note added",
            detail: note,
            createdAt: now
        ))
    }

    func createTag(named name: String) throws -> Tag {
        try repository.upsertTag(named: name)
    }

    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at now: Date = Date()) throws {
        try repository.merge(retaining: retainedID, archiving: duplicateID, at: now)
    }

    func archive(id: UUID, at: Date = Date()) throws {
        try repository.archive(id: id, at: at)
    }
}
