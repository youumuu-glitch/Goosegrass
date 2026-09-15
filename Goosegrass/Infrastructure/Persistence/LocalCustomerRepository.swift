import Foundation
import SwiftData

@MainActor
final class LocalCustomerRepository: CustomerRepository {
    private static let defaultSourceNames = ["小红书", "抖音", "大众点评", "微信", "电话", "朋友介绍", "线下", "其他"]
    private let context: ModelContext

    var container: ModelContainer { context.container }

    init(context: ModelContext) {
        self.context = context
    }

    func create(_ customer: Customer) throws {
        guard try record(id: customer.id) == nil else {
            throw PersistenceError.duplicateIdentifier(customer.id)
        }
        let customerRecord = PersistenceMapper.makeCustomerRecord(from: customer)
        customerRecord.source = try sourceRecord(id: customer.sourceID)
        customerRecord.tags = try tagRecords(ids: customer.tagIDs)
        context.insert(customerRecord)
        try context.save()
    }

    func update(_ customer: Customer) throws {
        guard let record = try record(id: customer.id) else {
            throw PersistenceError.recordNotFound(customer.id)
        }
        PersistenceMapper.update(record, from: customer)
        record.source = try sourceRecord(id: customer.sourceID)
        record.tags = try tagRecords(ids: customer.tagIDs)
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

    func fetchList(query: String) throws -> [CustomerListItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return try fetchAllRecords()
            .filter { !$0.isArchived }
            .compactMap { record -> CustomerListItem? in
                let item = try makeListItem(from: record)
                guard !needle.isEmpty else { return item }
                let searchableValues = [
                    record.displayName,
                    record.legalName ?? "",
                    record.phone,
                    record.normalizedPhone,
                    record.email ?? "",
                    record.notes,
                    record.source?.name ?? "",
                ] + record.tags.map(\.name)
                return searchableValues.contains { $0.localizedCaseInsensitiveContains(needle) } ? item : nil
            }
            .sorted {
                if $0.customer.updatedAt != $1.customer.updatedAt {
                    return $0.customer.updatedAt > $1.customer.updatedAt
                }
                return $0.customer.displayName.localizedStandardCompare($1.customer.displayName) == .orderedAscending
            }
    }

    func fetchDetail(id: UUID) throws -> CustomerDetail? {
        guard let record = try record(id: id), !record.isArchived else { return nil }
        return CustomerDetail(
            customer: try PersistenceMapper.makeCustomer(from: record),
            sourceName: record.source?.name,
            tagNames: record.tags.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            activities: try record.activities
                .map(PersistenceMapper.makeActivity)
                .sorted { $0.createdAt > $1.createdAt }
        )
    }

    func fetchCatalog() throws -> CustomerCatalog {
        let sources = try context.fetch(FetchDescriptor<PersistenceSchemaV1.LeadSourceRecord>())
        let sourceOrder = Dictionary(uniqueKeysWithValues: Self.defaultSourceNames.enumerated().map { ($0.element, $0.offset) })
        let mappedSources = sources
            .filter(\.isActive)
            .map(PersistenceMapper.makeLeadSource)
            .sorted {
                let lhs = sourceOrder[$0.name] ?? Int.max
                let rhs = sourceOrder[$1.name] ?? Int.max
                return lhs == rhs ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : lhs < rhs
            }
        let tags = try context.fetch(FetchDescriptor<PersistenceSchemaV1.TagRecord>())
            .map(PersistenceMapper.makeTag)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return CustomerCatalog(sources: mappedSources, tags: tags)
    }

    func seedDefaultSources() throws {
        let existing = try context.fetch(FetchDescriptor<PersistenceSchemaV1.LeadSourceRecord>())
        let existingNames = Set(existing.map { $0.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) })
        for name in Self.defaultSourceNames where !existingNames.contains(name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)) {
            context.insert(PersistenceSchemaV1.LeadSourceRecord(name: name))
        }
        if context.hasChanges {
            try context.save()
        }
    }

    func upsertTag(named name: String) throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CustomerRepositoryError.emptyTagName }
        let records = try context.fetch(FetchDescriptor<PersistenceSchemaV1.TagRecord>())
        if let existing = records.first(where: { $0.name.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return PersistenceMapper.makeTag(from: existing)
        }
        let record = PersistenceSchemaV1.TagRecord(name: trimmed)
        context.insert(record)
        try context.save()
        return PersistenceMapper.makeTag(from: record)
    }

    func assignTags(_ tagIDs: [UUID], to customerID: UUID) throws {
        guard let customer = try record(id: customerID) else {
            throw PersistenceError.recordNotFound(customerID)
        }
        customer.tags = try tagRecords(ids: tagIDs)
        try context.save()
    }

    func appendActivity(_ activity: Activity) throws {
        guard let customer = try record(id: activity.customerID) else {
            throw PersistenceError.customerNotFound(activity.customerID)
        }
        let appointment = try activity.appointmentID.flatMap { id in
            try context.fetch(FetchDescriptor<PersistenceSchemaV1.AppointmentRecord>()).first { $0.id == id }
        }
        context.insert(PersistenceMapper.makeActivityRecord(from: activity, customer: customer, appointment: appointment))
        try context.save()
    }

    func merge(retaining retainedID: UUID, archiving duplicateID: UUID, at: Date) throws {
        guard retainedID != duplicateID else { throw CustomerRepositoryError.cannotMergeSameCustomer }
        guard let retained = try record(id: retainedID) else { throw PersistenceError.recordNotFound(retainedID) }
        guard let duplicate = try record(id: duplicateID) else { throw PersistenceError.recordNotFound(duplicateID) }

        for appointment in Array(duplicate.appointments) {
            appointment.customerID = retainedID
            appointment.customer = retained
        }
        for activity in Array(duplicate.activities) {
            activity.customerID = retainedID
            activity.customer = retained
        }
        for followUp in Array(duplicate.followUps) {
            followUp.customerID = retainedID
            followUp.customer = retained
        }

        var tagsByID = Dictionary(uniqueKeysWithValues: retained.tags.map { ($0.id, $0) })
        duplicate.tags.forEach { tagsByID[$0.id] = $0 }
        retained.tags = tagsByID.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        duplicate.tags = []

        if retained.source == nil {
            retained.source = duplicate.source
            retained.sourceID = duplicate.source?.id ?? duplicate.sourceID
        }
        let duplicateNotes = duplicate.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !duplicateNotes.isEmpty && !retained.notes.contains(duplicateNotes) {
            retained.notes = [retained.notes, duplicateNotes].filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
        if let duplicateContact = duplicate.lastContactedAt {
            retained.lastContactedAt = max(retained.lastContactedAt ?? duplicateContact, duplicateContact)
        }
        retained.updatedAt = at
        duplicate.isArchived = true
        duplicate.statusRawValue = CustomerStatus.archived.rawValue
        duplicate.updatedAt = at

        let mergedActivity = Activity(
            customerID: retainedID,
            type: .customerMerged,
            title: "Merged customer",
            detail: duplicate.displayName,
            createdAt: at
        )
        context.insert(PersistenceMapper.makeActivityRecord(from: mergedActivity, customer: retained, appointment: nil))
        try context.save()
    }

    private func record(id: UUID) throws -> PersistenceSchemaV1.CustomerRecord? {
        try fetchAllRecords().first { $0.id == id }
    }

    private func fetchAllRecords() throws -> [PersistenceSchemaV1.CustomerRecord] {
        try context.fetch(FetchDescriptor<PersistenceSchemaV1.CustomerRecord>())
    }

    private func sourceRecord(id: UUID?) throws -> PersistenceSchemaV1.LeadSourceRecord? {
        guard let id else { return nil }
        return try context.fetch(FetchDescriptor<PersistenceSchemaV1.LeadSourceRecord>()).first { $0.id == id }
    }

    private func tagRecords(ids: [UUID]) throws -> [PersistenceSchemaV1.TagRecord] {
        guard !ids.isEmpty else { return [] }
        let records = try context.fetch(FetchDescriptor<PersistenceSchemaV1.TagRecord>())
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return try ids.map { id in
            guard let record = byID[id] else { throw PersistenceError.recordNotFound(id) }
            return record
        }
    }

    private func makeListItem(from record: PersistenceSchemaV1.CustomerRecord) throws -> CustomerListItem {
        let terminalStatuses: Set<String> = [
            AppointmentStatus.completed.rawValue,
            AppointmentStatus.cancelled.rawValue,
            AppointmentStatus.noShow.rawValue,
            AppointmentStatus.rescheduled.rawValue,
        ]
        let nextAppointment = record.appointments
            .filter { !terminalStatuses.contains($0.statusRawValue) }
            .map(\.startAt)
            .min()
        return CustomerListItem(
            customer: try PersistenceMapper.makeCustomer(from: record),
            sourceName: record.source?.name,
            tagNames: record.tags.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            nextAppointmentAt: nextAppointment
        )
    }
}
