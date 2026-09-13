import Foundation
import SwiftData

@MainActor
final class LocalCustomerRepository: CustomerRepository {
    private let context: ModelContext

    var container: ModelContainer { context.container }

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ customer: Customer) throws {
        guard try record(id: customer.id) == nil else {
            throw PersistenceError.duplicateIdentifier(customer.id)
        }
        context.insert(PersistenceMapper.makeCustomerRecord(from: customer))
        try context.save()
    }

    func update(_ customer: Customer) throws {
        guard let record = try record(id: customer.id) else {
            throw PersistenceError.recordNotFound(customer.id)
        }
        PersistenceMapper.update(record, from: customer)
        try context.save()
    }

    func fetch(id: UUID, includeArchived: Bool) throws -> Customer? {
        guard let record = try record(id: id), includeArchived || !record.isArchived else {
            return nil
        }
        return try PersistenceMapper.makeCustomer(from: record)
    }

    func fetchAll(includeArchived: Bool) throws -> [Customer] {
        let records = try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>())
        return try records
            .filter { includeArchived || !$0.isArchived }
            .sorted { $0.createdAt < $1.createdAt }
            .map(PersistenceMapper.makeCustomer)
    }

    func search(query: String, includeArchived: Bool) throws -> [Customer] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try fetchAll(includeArchived: includeArchived) }
        return try fetchAll(includeArchived: includeArchived).filter {
            $0.displayName.localizedCaseInsensitiveContains(needle)
                || $0.phone.localizedCaseInsensitiveContains(needle)
                || $0.normalizedPhone.localizedCaseInsensitiveContains(needle)
                || ($0.email?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    func findPossibleDuplicates(normalizedPhone: String) throws -> [Customer] {
        let normalized = normalizedPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        return try fetchAllRecords().filter {
            !$0.isArchived && $0.normalizedPhone == normalized
        }.map(PersistenceMapper.makeCustomer)
    }

    func archive(id: UUID, at: Date) throws {
        guard let record = try record(id: id) else {
            throw PersistenceError.recordNotFound(id)
        }
        record.isArchived = true
        record.statusRawValue = CustomerStatus.archived.rawValue
        record.updatedAt = at
        try context.save()
    }

    private func record(id: UUID) throws -> PersistenceSchemaV1.CustomerRecord? {
        try fetchAllRecords().first { $0.id == id }
    }

    private func fetchAllRecords() throws -> [PersistenceSchemaV1.CustomerRecord] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>())
    }
}
