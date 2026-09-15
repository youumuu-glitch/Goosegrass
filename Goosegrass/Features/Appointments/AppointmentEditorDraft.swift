import Foundation

enum AppointmentEditorError: Error, Equatable, Sendable {
    case missingCustomer
    case invalidPartySize
}

struct AppointmentEditorDraft: Equatable, Sendable {
    var customerID: UUID?
    var startAt: Date
    var endAt: Date?
    var partySize: Int
    var sourceID: UUID?
    var customerRequest: String
    var internalNote: String

    init(
        customerID: UUID? = nil,
        startAt: Date = Date(),
        endAt: Date? = nil,
        partySize: Int = 1,
        sourceID: UUID? = nil,
        customerRequest: String = "",
        internalNote: String = ""
    ) {
        self.customerID = customerID
        self.startAt = startAt
        self.endAt = endAt
        self.partySize = partySize
        self.sourceID = sourceID
        self.customerRequest = customerRequest
        self.internalNote = internalNote
    }

    init(appointment: Appointment) {
        self.init(
            customerID: appointment.customerID,
            startAt: appointment.startAt,
            endAt: appointment.endAt,
            partySize: appointment.partySize,
            sourceID: appointment.sourceID,
            customerRequest: appointment.customerRequest,
            internalNote: appointment.internalNote
        )
    }

    func makeAppointment(existing: Appointment? = nil, now: Date = Date()) throws -> Appointment {
        let errors = AppointmentValidator.validate(
            customerID: customerID,
            startAt: startAt,
            partySize: partySize
        )
        if errors.contains(.missingCustomer) { throw AppointmentEditorError.missingCustomer }
        if errors.contains(.invalidPartySize) { throw AppointmentEditorError.invalidPartySize }
        guard let customerID else { throw AppointmentEditorError.missingCustomer }

        return Appointment(
            id: existing?.id ?? UUID(),
            customerID: customerID,
            startAt: startAt,
            endAt: endAt,
            partySize: partySize,
            status: existing?.status ?? .draft,
            customerRequest: customerRequest.trimmingCharacters(in: .whitespacesAndNewlines),
            internalNote: internalNote.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceID: sourceID,
            confirmedAt: existing?.confirmedAt,
            arrivedAt: existing?.arrivedAt,
            completedAt: existing?.completedAt,
            cancelledAt: existing?.cancelledAt,
            noShowAt: existing?.noShowAt,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
            serverID: existing?.serverID,
            syncStatus: existing?.syncStatus,
            lastSyncedAt: existing?.lastSyncedAt
        )
    }

    func isHistorical(relativeTo now: Date = Date()) -> Bool {
        startAt < now
    }
}
