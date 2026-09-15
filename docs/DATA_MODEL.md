# Data Model

Foundation-only value models remain the domain contracts. Phase 1 adds `PersistenceSchemaV1` records in Infrastructure and maps them at repository boundaries; domain code still does not import SwiftData.

## Schema version and relationships

- Schema version: `1.0.0`, registered through `GoosegrassMigrationPlan`.
- Persisted Phase 1 records: Customer, Appointment, Activity, FollowUp, LeadSource, Tag, and Reminder.
- Customer owns navigable collections for appointments, activities, follow-ups, and tags.
- Appointment retains its durable `customerID` and a SwiftData relationship back to Customer.
- Relationship delete rules nullify references rather than cascading business history. Customer deletion is represented by archive, and only draft appointments have a repository-level hard-delete operation.
- Status/type values are stored using stable enum raw values. Invalid stored values surface as persistence errors instead of silently changing business state.

Future schema changes require a new `VersionedSchema`, an explicit migration assessment, and macOS migration tests before being described as safe.

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

## Phase 2 customer aggregates

- Customer lists resolve source and tag names plus the next active appointment without exposing persistence records to SwiftUI.
- Customer detail resolves source, tags, and activities ordered newest first.
- Search covers display/legal name, original and normalized phone (including phone tail), email, notes, source name, and tag name; archived customers remain excluded from the default list.
- The initial source catalog is seeded idempotently with `小红书`, `抖音`, `大众点评`, `微信`, `电话`, `朋友介绍`, `线下`, and `其他`.
- Tags deduplicate case-insensitively. A normalized-phone match creates an explicit duplicate decision; create-anyway, use-existing, and merge remain separate user choices.
- Customer updates preserve UUID and `createdAt`. Archive sets the archive flag and status while retaining relationships and timeline history.
