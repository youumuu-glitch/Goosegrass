import Foundation

enum CustomerEditorError: Error, Equatable {
    case missingDisplayName
    case invalidPhone
    case emptyNote
}

struct CustomerEditorDraft: Equatable, Sendable {
    var displayName = ""
    var legalName = ""
    var phone = ""
    var email = ""
    var sourceID: UUID?
    var status: CustomerStatus = .new
    var notes = ""
    var tagIDs: Set<UUID> = []

    init() {}

    init(customer: Customer) {
        displayName = customer.displayName
        legalName = customer.legalName ?? ""
        phone = customer.phone
        email = customer.email ?? ""
        sourceID = customer.sourceID
        status = customer.status
        notes = customer.notes
        tagIDs = Set(customer.tagIDs)
    }

    func makeCustomer(existing: Customer? = nil, now: Date = Date()) throws -> Customer {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw CustomerEditorError.missingDisplayName }
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPhone = PhoneNormalizer.normalize(trimmedPhone)
        guard normalizedPhone.contains(where: \.isNumber) else { throw CustomerEditorError.invalidPhone }

        let trimmedLegalName = legalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return Customer(
            id: existing?.id ?? UUID(),
            displayName: trimmedName,
            legalName: trimmedLegalName.isEmpty ? nil : trimmedLegalName,
            phone: trimmedPhone,
            normalizedPhone: normalizedPhone,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            sourceID: sourceID,
            status: status,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            isArchived: existing?.isArchived ?? false,
            appointmentIDs: existing?.appointmentIDs ?? [],
            activityIDs: existing?.activityIDs ?? [],
            followUpIDs: existing?.followUpIDs ?? [],
            tagIDs: tagIDs.sorted { $0.uuidString < $1.uuidString },
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            lastContactedAt: existing?.lastContactedAt,
            serverID: existing?.serverID,
            syncStatus: existing?.syncStatus,
            lastSyncedAt: existing?.lastSyncedAt
        )
    }
}

enum CustomerSubmissionResult: Equatable, Sendable {
    case saved(Customer)
    case possibleDuplicates(draft: CustomerEditorDraft, candidates: [Customer])
}
