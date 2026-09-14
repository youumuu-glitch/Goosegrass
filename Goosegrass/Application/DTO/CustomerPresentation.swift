import Foundation

struct CustomerListItem: Identifiable, Equatable, Sendable {
    var id: UUID { customer.id }

    let customer: Customer
    let sourceName: String?
    let tagNames: [String]
    let nextAppointmentAt: Date?
}

struct CustomerDetail: Equatable, Sendable {
    let customer: Customer
    let sourceName: String?
    let tagNames: [String]
    let activities: [Activity]
}

struct CustomerCatalog: Equatable, Sendable {
    let sources: [LeadSource]
    let tags: [Tag]
}
