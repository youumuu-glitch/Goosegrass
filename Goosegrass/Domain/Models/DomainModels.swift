import Foundation

struct Customer: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var displayName: String
    var legalName: String?
    var phone: String
    var normalizedPhone: String
    var email: String?
    var sourceID: UUID?
    var status: CustomerStatus
    var notes: String
    var isArchived: Bool
    var appointmentIDs: [UUID]
    var activityIDs: [UUID]
    var followUpIDs: [UUID]
    var tagIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date
    var lastContactedAt: Date?
    var serverID: String?
    var syncStatus: String?
    var lastSyncedAt: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        legalName: String? = nil,
        phone: String,
        normalizedPhone: String,
        email: String? = nil,
        sourceID: UUID? = nil,
        status: CustomerStatus = .new,
        notes: String = "",
        isArchived: Bool = false,
        appointmentIDs: [UUID] = [],
        activityIDs: [UUID] = [],
        followUpIDs: [UUID] = [],
        tagIDs: [UUID] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastContactedAt: Date? = nil,
        serverID: String? = nil,
        syncStatus: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.legalName = legalName
        self.phone = phone
        self.normalizedPhone = normalizedPhone
        self.email = email
        self.sourceID = sourceID
        self.status = status
        self.notes = notes
        self.isArchived = isArchived
        self.appointmentIDs = appointmentIDs
        self.activityIDs = activityIDs
        self.followUpIDs = followUpIDs
        self.tagIDs = tagIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastContactedAt = lastContactedAt
        self.serverID = serverID
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
    }
}

struct Appointment: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var customerID: UUID
    var startAt: Date
    var endAt: Date?
    var partySize: Int
    var status: AppointmentStatus
    var customerRequest: String
    var internalNote: String
    var sourceID: UUID?
    var confirmedAt: Date?
    var arrivedAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var noShowAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var serverID: String?
    var syncStatus: String?
    var lastSyncedAt: Date?

    init(
        id: UUID = UUID(),
        customerID: UUID,
        startAt: Date,
        endAt: Date? = nil,
        partySize: Int,
        status: AppointmentStatus = .draft,
        customerRequest: String = "",
        internalNote: String = "",
        sourceID: UUID? = nil,
        confirmedAt: Date? = nil,
        arrivedAt: Date? = nil,
        completedAt: Date? = nil,
        cancelledAt: Date? = nil,
        noShowAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serverID: String? = nil,
        syncStatus: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.customerID = customerID
        self.startAt = startAt
        self.endAt = endAt
        self.partySize = partySize
        self.status = status
        self.customerRequest = customerRequest
        self.internalNote = internalNote
        self.sourceID = sourceID
        self.confirmedAt = confirmedAt
        self.arrivedAt = arrivedAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
        self.noShowAt = noShowAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serverID = serverID
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
    }
}

struct AppointmentChange: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var appointmentID: UUID
    var changeType: AppointmentChangeType
    var oldValueJSON: String
    var newValueJSON: String
    var reason: String
    var changedAt: Date

    init(
        id: UUID = UUID(),
        appointmentID: UUID,
        changeType: AppointmentChangeType,
        oldValueJSON: String,
        newValueJSON: String,
        reason: String = "",
        changedAt: Date = Date()
    ) {
        self.id = id
        self.appointmentID = appointmentID
        self.changeType = changeType
        self.oldValueJSON = oldValueJSON
        self.newValueJSON = newValueJSON
        self.reason = reason
        self.changedAt = changedAt
    }
}

struct Reminder: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var appointmentID: UUID
    var type: ReminderType
    var fireAt: Date
    var systemNotificationID: String?
    var status: ReminderStatus
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        appointmentID: UUID,
        type: ReminderType,
        fireAt: Date,
        systemNotificationID: String? = nil,
        status: ReminderStatus = .scheduled,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.appointmentID = appointmentID
        self.type = type
        self.fireAt = fireAt
        self.systemNotificationID = systemNotificationID
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct FollowUp: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var customerID: UUID
    var appointmentID: UUID?
    var dueAt: Date
    var reason: String
    var note: String
    var priority: FollowUpPriority
    var status: FollowUpStatus
    var completedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        customerID: UUID,
        appointmentID: UUID? = nil,
        dueAt: Date,
        reason: String,
        note: String = "",
        priority: FollowUpPriority = .normal,
        status: FollowUpStatus = .pending,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.customerID = customerID
        self.appointmentID = appointmentID
        self.dueAt = dueAt
        self.reason = reason
        self.note = note
        self.priority = priority
        self.status = status
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Activity: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var customerID: UUID
    var appointmentID: UUID?
    var type: ActivityType
    var title: String
    var detail: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        customerID: UUID,
        appointmentID: UUID? = nil,
        type: ActivityType,
        title: String,
        detail: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.customerID = customerID
        self.appointmentID = appointmentID
        self.type = type
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}

struct LeadSource: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var iconName: String?
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.isActive = isActive
        self.createdAt = createdAt
    }
}

struct Tag: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct ImportBatch: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var fileName: String
    var sourceType: String
    var totalRows: Int
    var createdRows: Int
    var updatedRows: Int
    var duplicateRows: Int
    var failedRows: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        sourceType: String,
        totalRows: Int,
        createdRows: Int = 0,
        updatedRows: Int = 0,
        duplicateRows: Int = 0,
        failedRows: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.sourceType = sourceType
        self.totalRows = totalRows
        self.createdRows = createdRows
        self.updatedRows = updatedRows
        self.duplicateRows = duplicateRows
        self.failedRows = failedRows
        self.createdAt = createdAt
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var defaultReminderTypes: [ReminderType]
    var notificationSoundEnabled: Bool
    var automaticBackupEnabled: Bool
    var backupRetentionCount: Int

    init(
        defaultReminderTypes: [ReminderType] = [.oneDayBefore, .twoHoursBefore, .thirtyMinutesBefore],
        notificationSoundEnabled: Bool = true,
        automaticBackupEnabled: Bool = true,
        backupRetentionCount: Int = 30
    ) {
        self.defaultReminderTypes = defaultReminderTypes
        self.notificationSoundEnabled = notificationSoundEnabled
        self.automaticBackupEnabled = automaticBackupEnabled
        self.backupRetentionCount = backupRetentionCount
    }
}
