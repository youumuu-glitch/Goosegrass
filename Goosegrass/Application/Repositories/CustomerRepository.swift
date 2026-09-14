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
    func fetchList(query: String) throws -> [CustomerListItem]
    func fetchDetail(id: UUID) throws -> CustomerDetail?
    func fetchCatalog() throws -> CustomerCatalog
    func seedDefaultSources() throws
    func upsertTag(named name: String) throws -> Tag
    func assignTags(_ tagIDs: [UUID], to customerID: UUID) throws
    func appendActivity(_ activity: Activity) throws
    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at: Date) throws
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

    func fetchList(query: String) throws -> [CustomerListItem] {
        try search(query: query).map {
            CustomerListItem(customer: $0, sourceName: nil, tagNames: [], nextAppointmentAt: nil)
        }
    }

    func fetchDetail(id: UUID) throws -> CustomerDetail? {
        try fetch(id: id).map {
            CustomerDetail(customer: $0, sourceName: nil, tagNames: [], activities: [])
        }
    }

    func fetchCatalog() throws -> CustomerCatalog {
        CustomerCatalog(sources: [], tags: [])
    }

    func seedDefaultSources() throws {}

    func upsertTag(named name: String) throws -> Tag {
        throw CustomerRepositoryError.emptyTagName
    }

    func assignTags(_ tagIDs: [UUID], to customerID: UUID) throws {}

    func appendActivity(_ activity: Activity) throws {}

    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at: Date) throws {
        throw CustomerRepositoryError.mergeNotImplemented
    }
}

enum CustomerRepositoryError: Error, Equatable {
    case mergeNotImplemented
    case cannotMergeSameCustomer
    case emptyTagName
}
