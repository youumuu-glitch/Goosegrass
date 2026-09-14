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

    func archive(id: UUID, at: Date = Date()) throws {
        try repository.archive(id: id, at: at)
    }
}
