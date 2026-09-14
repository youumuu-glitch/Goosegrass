import Foundation

@MainActor
protocol CustomerRepository {
    func create(_ customer: Customer) throws
    func update(_ customer: Customer) throws
    func fetch(id: UUID, includeArchived: Bool) throws -> Customer?
    func fetchAll(includeArchived: Bool) throws -> [Customer]
    func search(query: String, includeArchived: Bool) throws -> [Customer]
    func findPossibleDuplicates(normalizedPhone: String) throws -> [Customer]
    func archive(id: UUID, at: Date) throws
}

extension CustomerRepository {
    func fetch(id: UUID) throws -> Customer? {
        try fetch(id: id, includeArchived: false)
    }

    func fetchAll() throws -> [Customer] {
        try fetchAll(includeArchived: false)
    }

    func search(query: String) throws -> [Customer] {
        try search(query: query, includeArchived: false)
    }
}
