# Data Model

Phase 0 defines Foundation-only value models. They are architectural contracts, not SwiftData persistence entities. Phase 1 will introduce a versioned SwiftData schema after migration and relationship behavior can be tested on macOS.

## Primary entities

- `Customer`: durable customer identity, original and normalized phone, lifecycle status, notes, archive flag, and optional sync metadata.
- `Appointment`: customer-linked time, party size, independent appointment status, customer request, internal note, lifecycle timestamps, and optional source/sync metadata.
- `AppointmentChange`: immutable description of a reschedule or other material field change.
- `Reminder`: appointment-linked reminder intent and system notification identifier.
- `FollowUp`: customer-linked next action, optional appointment context, priority, status, and completion time.
- `Activity`: customer timeline event with optional appointment context.
- `LeadSource`, `Tag`, `ImportBatch`, and `AppSettings`: supporting domain records and preferences.

All main records use UUID identifiers and `Date` values. Business timestamps use the master names `createdAt`, `updatedAt`, `startAt`, `endAt`, `dueAt`, `arrivedAt`, `completedAt`, and `cancelledAt`.

## Integrity rules

- Original phone input remains separate from normalized matching input.
- A matching normalized phone suggests a duplicate; it never silently deletes or merges a customer.
- Appointment party size is at least one.
- Past appointments are permitted for historical entry.
- Customer requests and internal notes are separate fields.
- Archive/cancel operations must retain related history.
- Rescheduling must produce change history before Phase 3 can be accepted.
