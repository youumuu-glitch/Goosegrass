import Foundation

enum PersistenceError: Error, Equatable {
    case duplicateIdentifier(UUID)
    case customerNotFound(UUID)
    case recordNotFound(UUID)
    case invalidStoredValue(field: String, value: String)
}

enum PersistenceMapper {
    static func makeCustomerRecord(from customer: Customer) -> PersistenceSchemaV1.CustomerRecord {
        PersistenceSchemaV1.CustomerRecord(
            id: customer.id,
            displayName: customer.displayName,
            legalName: customer.legalName,
            phone: customer.phone,
            normalizedPhone: customer.normalizedPhone,
            email: customer.email,
            sourceID: customer.sourceID,
            statusRawValue: customer.status.rawValue,
            notes: customer.notes,
            isArchived: customer.isArchived,
            createdAt: customer.createdAt,
            updatedAt: customer.updatedAt,
            lastContactedAt: customer.lastContactedAt,
            serverID: customer.serverID,
            syncStatus: customer.syncStatus,
            lastSyncedAt: customer.lastSyncedAt
        )
    }

    static func update(_ record: PersistenceSchemaV1.CustomerRecord, from customer: Customer) {
        record.displayName = customer.displayName
        record.legalName = customer.legalName
        record.phone = customer.phone
        record.normalizedPhone = customer.normalizedPhone
        record.email = customer.email
        record.sourceID = customer.sourceID
        record.statusRawValue = customer.status.rawValue
        record.notes = customer.notes
        record.isArchived = customer.isArchived
        record.updatedAt = customer.updatedAt
        record.lastContactedAt = customer.lastContactedAt
        record.serverID = customer.serverID
        record.syncStatus = customer.syncStatus
        record.lastSyncedAt = customer.lastSyncedAt
    }

    static func makeCustomer(from record: PersistenceSchemaV1.CustomerRecord) throws -> Customer {
        guard let status = CustomerStatus(rawValue: record.statusRawValue) else {
            throw PersistenceError.invalidStoredValue(field: "Customer.status", value: record.statusRawValue)
        }
        return Customer(
            id: record.id,
            displayName: record.displayName,
            legalName: record.legalName,
            phone: record.phone,
            normalizedPhone: record.normalizedPhone,
            email: record.email,
            sourceID: record.source?.id ?? record.sourceID,
            status: status,
            notes: record.notes,
            isArchived: record.isArchived,
            appointmentIDs: record.appointments.map(\.id).sorted { $0.uuidString < $1.uuidString },
            activityIDs: record.activities.map(\.id).sorted { $0.uuidString < $1.uuidString },
            followUpIDs: record.followUps.map(\.id).sorted { $0.uuidString < $1.uuidString },
            tagIDs: record.tags.map(\.id).sorted { $0.uuidString < $1.uuidString },
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            lastContactedAt: record.lastContactedAt,
            serverID: record.serverID,
            syncStatus: record.syncStatus,
            lastSyncedAt: record.lastSyncedAt
        )
    }

    static func makeAppointmentRecord(from appointment: Appointment, customer: PersistenceSchemaV1.CustomerRecord) -> PersistenceSchemaV1.AppointmentRecord {
        PersistenceSchemaV1.AppointmentRecord(
            id: appointment.id,
            customerID: appointment.customerID,
            startAt: appointment.startAt,
            endAt: appointment.endAt,
            partySize: appointment.partySize,
            statusRawValue: appointment.status.rawValue,
            customerRequest: appointment.customerRequest,
            internalNote: appointment.internalNote,
            sourceID: appointment.sourceID,
            confirmedAt: appointment.confirmedAt,
            arrivedAt: appointment.arrivedAt,
            completedAt: appointment.completedAt,
            cancelledAt: appointment.cancelledAt,
            noShowAt: appointment.noShowAt,
            createdAt: appointment.createdAt,
            updatedAt: appointment.updatedAt,
            serverID: appointment.serverID,
            syncStatus: appointment.syncStatus,
            lastSyncedAt: appointment.lastSyncedAt,
            customer: customer
        )
    }

    static func update(_ record: PersistenceSchemaV1.AppointmentRecord, from appointment: Appointment, customer: PersistenceSchemaV1.CustomerRecord) {
        record.customerID = appointment.customerID
        record.startAt = appointment.startAt
        record.endAt = appointment.endAt
        record.partySize = appointment.partySize
        record.statusRawValue = appointment.status.rawValue
        record.customerRequest = appointment.customerRequest
        record.internalNote = appointment.internalNote
        record.sourceID = appointment.sourceID
        record.confirmedAt = appointment.confirmedAt
        record.arrivedAt = appointment.arrivedAt
        record.completedAt = appointment.completedAt
        record.cancelledAt = appointment.cancelledAt
        record.noShowAt = appointment.noShowAt
        record.updatedAt = appointment.updatedAt
        record.serverID = appointment.serverID
        record.syncStatus = appointment.syncStatus
        record.lastSyncedAt = appointment.lastSyncedAt
        record.customer = customer
    }

    static func makeAppointment(from record: PersistenceSchemaV1.AppointmentRecord) throws -> Appointment {
        guard let status = AppointmentStatus(rawValue: record.statusRawValue) else {
            throw PersistenceError.invalidStoredValue(field: "Appointment.status", value: record.statusRawValue)
        }
        return Appointment(
            id: record.id,
            customerID: record.customerID,
            startAt: record.startAt,
            endAt: record.endAt,
            partySize: record.partySize,
            status: status,
            customerRequest: record.customerRequest,
            internalNote: record.internalNote,
            sourceID: record.sourceID,
            confirmedAt: record.confirmedAt,
            arrivedAt: record.arrivedAt,
            completedAt: record.completedAt,
            cancelledAt: record.cancelledAt,
            noShowAt: record.noShowAt,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            serverID: record.serverID,
            syncStatus: record.syncStatus,
            lastSyncedAt: record.lastSyncedAt
        )
    }

    static func makeActivityRecord(
        from activity: Activity,
        customer: PersistenceSchemaV1.CustomerRecord,
        appointment: PersistenceSchemaV1.AppointmentRecord?
    ) -> PersistenceSchemaV1.ActivityRecord {
        PersistenceSchemaV1.ActivityRecord(
            id: activity.id,
            customerID: activity.customerID,
            appointmentID: activity.appointmentID,
            typeRawValue: activity.type.rawValue,
            title: activity.title,
            detail: activity.detail,
            createdAt: activity.createdAt,
            customer: customer,
            appointment: appointment
        )
    }

    static func makeActivity(from record: PersistenceSchemaV1.ActivityRecord) throws -> Activity {
        guard let type = ActivityType(rawValue: record.typeRawValue) else {
            throw PersistenceError.invalidStoredValue(field: "Activity.type", value: record.typeRawValue)
        }
        return Activity(
            id: record.id,
            customerID: record.customerID,
            appointmentID: record.appointmentID,
            type: type,
            title: record.title,
            detail: record.detail,
            createdAt: record.createdAt
        )
    }

    static func makeLeadSource(from record: PersistenceSchemaV1.LeadSourceRecord) -> LeadSource {
        LeadSource(
            id: record.id,
            name: record.name,
            iconName: record.iconName,
            isActive: record.isActive,
            createdAt: record.createdAt
        )
    }

    static func makeTag(from record: PersistenceSchemaV1.TagRecord) -> Tag {
        Tag(id: record.id, name: record.name, createdAt: record.createdAt)
    }
}
