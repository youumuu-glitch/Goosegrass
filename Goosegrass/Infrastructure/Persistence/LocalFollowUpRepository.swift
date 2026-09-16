import Foundation
import SwiftData

@MainActor
final class LocalFollowUpRepository: FollowUpRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch(id: UUID) throws -> FollowUp? {
        try record(id: id).map(PersistenceMapper.makeFollowUp)
    }

    func fetchList(filter: FollowUpListFilter) throws -> [FollowUpListItem] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.FollowUpRecord>())
            .compactMap { record -> FollowUpListItem? in
                guard let customer = record.customer, !customer.isArchived else { return nil }
                guard filter.customerID == nil || record.customerID == filter.customerID else { return nil }
                let followUp = try PersistenceMapper.makeFollowUp(from: record)
                if filter.scope == .active,
                   followUp.status != .pending && followUp.status != .snoozed {
                    return nil
                }
                return FollowUpListItem(
                    followUp: followUp,
                    customerName: customer.displayName,
                    customerPhone: customer.phone
                )
            }
            .sorted(by: Self.isOrderedBefore)
    }

    func fetchDetail(id: UUID) throws -> FollowUpDetail? {
        guard let record = try record(id: id),
              let customer = record.customer,
              !customer.isArchived else {
            return nil
        }
        return FollowUpDetail(
            listItem: FollowUpListItem(
                followUp: try PersistenceMapper.makeFollowUp(from: record),
                customerName: customer.displayName,
                customerPhone: customer.phone
            ),
            appointmentStartAt: record.appointment?.startAt
        )
    }

    func commit(_ mutation: FollowUpMutation) throws {
        let followUp = mutation.followUp
        guard let customer = try customerRecord(id: followUp.customerID), !customer.isArchived else {
            throw PersistenceError.customerNotFound(followUp.customerID)
        }

        let appointment: PersistenceSchemaV1.AppointmentRecord?
        if let appointmentID = followUp.appointmentID {
            guard let candidate = try appointmentRecord(id: appointmentID) else {
                throw PersistenceError.recordNotFound(appointmentID)
            }
            guard candidate.customerID == followUp.customerID else {
                throw PersistenceError.appointmentCustomerMismatch(
                    appointmentID: appointmentID,
                    customerID: followUp.customerID
                )
            }
            appointment = candidate
        } else {
            appointment = nil
        }

        guard mutation.activities.allSatisfy({
            $0.customerID == followUp.customerID && $0.appointmentID == followUp.appointmentID
        }) else {
            throw PersistenceError.recordNotFound(followUp.id)
        }

        let existing = try record(id: followUp.id)
        if mutation.isNew {
            guard existing == nil else {
                throw PersistenceError.duplicateIdentifier(followUp.id)
            }
        } else if existing == nil {
            throw PersistenceError.recordNotFound(followUp.id)
        }

        let activityIDs = Set(
            try context.fetch(FetchDescriptor<PersistenceSchemaV1.ActivityRecord>()).map(\.id)
        )
        if let duplicate = mutation.activities.first(where: { activityIDs.contains($0.id) }) {
            throw PersistenceError.duplicateIdentifier(duplicate.id)
        }

        if let existing {
            PersistenceMapper.update(
                existing,
                from: followUp,
                customer: customer,
                appointment: appointment
            )
        } else {
            context.insert(PersistenceMapper.makeFollowUpRecord(
                from: followUp,
                customer: customer,
                appointment: appointment
            ))
        }
        mutation.activities.forEach {
            context.insert(PersistenceMapper.makeActivityRecord(
                from: $0,
                customer: customer,
                appointment: appointment
            ))
        }
        try context.save()
    }

    private func record(id: UUID) throws -> PersistenceSchemaV1.FollowUpRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.FollowUpRecord>()).first { $0.id == id }
    }

    private func customerRecord(id: UUID) throws -> PersistenceSchemaV1.CustomerRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>()).first { $0.id == id }
    }

    private func appointmentRecord(id: UUID) throws -> PersistenceSchemaV1.AppointmentRecord? {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>()).first { $0.id == id }
    }

    private static func isOrderedBefore(_ lhs: FollowUpListItem, _ rhs: FollowUpListItem) -> Bool {
        if lhs.followUp.dueAt != rhs.followUp.dueAt {
            return lhs.followUp.dueAt < rhs.followUp.dueAt
        }
        let leftPriority = priorityRank(lhs.followUp.priority)
        let rightPriority = priorityRank(rhs.followUp.priority)
        if leftPriority != rightPriority {
            return leftPriority < rightPriority
        }
        if lhs.followUp.createdAt != rhs.followUp.createdAt {
            return lhs.followUp.createdAt < rhs.followUp.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func priorityRank(_ priority: FollowUpPriority) -> Int {
        switch priority {
        case .high:
            return 0
        case .normal:
            return 1
        case .low:
            return 2
        }
    }
}
