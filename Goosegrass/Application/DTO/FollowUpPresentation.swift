import Foundation

enum FollowUpListScope: String, CaseIterable, Sendable {
    case active
    case all
}

struct FollowUpListFilter: Equatable, Sendable {
    var scope: FollowUpListScope
    var customerID: UUID?

    init(scope: FollowUpListScope = .active, customerID: UUID? = nil) {
        self.scope = scope
        self.customerID = customerID
    }
}

struct FollowUpListItem: Identifiable, Equatable, Sendable {
    var id: UUID { followUp.id }

    let followUp: FollowUp
    let customerName: String
    let customerPhone: String
}

struct FollowUpDetail: Equatable, Sendable {
    let listItem: FollowUpListItem
    let appointmentStartAt: Date?
}

struct FollowUpMutation: Equatable, Sendable {
    let followUp: FollowUp
    let activities: [Activity]
    let isNew: Bool
}
