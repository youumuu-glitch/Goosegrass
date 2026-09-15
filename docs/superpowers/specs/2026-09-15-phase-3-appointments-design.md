# Phase 3 Appointments Design

**Status:** Approved on 2026-09-15

**Source of truth:** `docs/GOOSEGRASS_MASTER_SPEC.md`, especially sections 5.3, 8.2, 9.2–9.4, 13, 31–32, 55, and 72–75.

## Goal

Deliver a persistent native Appointments workspace whose lifecycle rules are centralized, exhaustively tested, and reflected in durable customer history. Phase 3 includes create, edit, submit, confirm, mark upcoming, arrive, complete, cancel, reschedule, and no-show operations. A reschedule keeps the same appointment UUID and records structured before/after history.

## Chosen approach

Use an explicit domain transition policy, an application-owned `AppointmentService`, aggregate repository mutations, and an additive SwiftData Schema V2. This keeps business rules out of SwiftUI, lets every state/action pair be tested, and preserves a stable appointment identity.

Rejected alternatives:

- Activity-only history is insufficient because it cannot reliably reconstruct structured old and new appointment values.
- Creating a new appointment for each reschedule fragments identity and conflicts with the Master Spec recommendation to retain the same UUID.
- Letting views directly mutate status would distribute state rules across UI paths and make invalid transitions possible.

## Schema evolution

`PersistenceSchemaV1` remains unchanged. `PersistenceSchemaV2` reuses the seven V1 record models and adds an independent `AppointmentChangeRecord` containing `appointmentID`, change type, old/new JSON, reason, and `changedAt`. It uses the durable appointment UUID rather than requiring a new inverse relationship on the V1 appointment record.

`GoosegrassMigrationPlan` registers V1 and V2 with a lightweight V1-to-V2 stage. `PersistenceController` opens the latest schema. A disk migration test first writes a V1 customer and appointment, closes that container, opens the same store using the application controller, and verifies the records survive and accept new change history. Migration safety remains unverified until that test runs successfully on macOS CI.

## Domain lifecycle

The service recognizes these actions:

```swift
enum AppointmentAction: CaseIterable, Sendable {
    case submit
    case confirm
    case markUpcoming
    case arrive
    case complete
    case cancel
    case reschedule
    case markNoShow
}
```

Legal status transitions are:

```text
draft               --submit-------> pendingConfirmation
pendingConfirmation --confirm------> confirmed
confirmed           --markUpcoming-> upcoming
upcoming            --arrive-------> arrived
arrived             --complete-----> completed

pendingConfirmation --reschedule---> rescheduled
confirmed           --reschedule---> rescheduled
upcoming            --reschedule---> rescheduled
rescheduled         --confirm------> confirmed

draft               --cancel-------> cancelled
pendingConfirmation --cancel-------> cancelled
confirmed           --cancel-------> cancelled
upcoming            --cancel-------> cancelled
rescheduled         --cancel-------> cancelled

upcoming            --markNoShow---> noShow
```

Every other status/action pair is invalid. Terminal states `completed`, `cancelled`, and `noShow` have no outgoing transitions. `arrived` may only complete. An invalid transition returns a domain error before persistence is invoked.

Transition timestamps are deterministic and supplied by the service caller for tests. Confirm sets `confirmedAt`; arrive sets `arrivedAt`; complete sets `completedAt`; cancel sets `cancelledAt`; no-show sets `noShowAt`. Reschedule updates `startAt`/`endAt`, moves to `rescheduled`, and clears confirmation and terminal timestamps that no longer describe the revised occurrence. Every mutation updates `updatedAt`.

## Validation and editing

Appointment input requires an existing, non-archived customer and `partySize >= 1`. `startAt` is non-optional by type. Past appointments are allowed for historical entry and surface a non-blocking warning in the editor. Original customer phone validation remains owned by the customer domain; selecting a persisted customer satisfies the appointment customer requirement.

Editing preserves appointment UUID, `createdAt`, relationship identity, and sync metadata. Material differences produce one structured `AppointmentChange` per changed category:

- start/end time: `rescheduled`
- party size: `partySizeChanged`
- customer request: `requestChanged`
- internal note: `noteChanged`
- explicit status action: `statusChanged`

JSON payloads use a small Codable snapshot structure and ISO-8601 date encoding. They contain appointment fields only and never embed customer names, phone numbers, or private notes unrelated to the changed field.

## Atomic repository boundary

`AppointmentRepository` gains aggregate list/detail reads, change-history reads, and one mutation method that receives the authoritative appointment plus zero or more changes and activities. The local repository resolves the customer relationship, updates/inserts all records in the shared `ModelContext`, and calls `save()` once. If validation or relationship resolution fails, nothing is saved.

Activity types map as follows:

- create: `appointmentCreated`
- confirm: `appointmentConfirmed`
- reschedule: `appointmentRescheduled`
- arrive: `appointmentArrived`
- complete: `appointmentCompleted`
- no-show: `appointmentNoShow`
- cancel: `appointmentCancelled`

Submit, mark-upcoming, and ordinary edits record `statusChanged` or field changes in `AppointmentChange`; they do not invent unsupported Activity enum cases. Existing customer history remains intact.

## Presentation and filtering

Application DTOs expose immutable list and detail values rather than SwiftData records. An appointment list item contains the appointment, customer display name and phone, source name, customer tags, and reminder summary. Detail contains the same aggregate plus ordered appointment changes and customer activities for that appointment.

The Appointments workspace supports all, today, tomorrow, this week, and custom date ranges plus status, customer, source, and tag filters. Date boundaries use the injected system calendar and current time zone; stored values remain `Date`. Phase 9 may optimize global filtering, but Phase 3 behavior must be correct for persisted data.

The list shows date, localized time, customer, phone, party size, source, status text, reminder status, request summary, and last update. Status is never communicated by color alone. Selection drives a detail inspector containing lifecycle actions, structured change history, and appointment-scoped activities.

The editor selects an active customer, date/time, optional end time, party size, source, customer request, and internal note. Return triggers the primary save where appropriate; Escape cancels modal editing. Destructive cancellation uses confirmation. Buttons are enabled only for actions allowed by the transition policy.

Phase 5 owns notification scheduling. Phase 3 reads existing reminder records only to show a summary and does not request notification permission or call UserNotifications.

## State and error handling

`AppointmentListViewModel` is `@MainActor`, observable, and receives `AppointmentService`, `CustomerService`, `Calendar`, and a `now` closure. It owns filters, rows, selection/detail, editor draft, reschedule draft, destructive confirmation, and user-facing error state. It never imports SwiftData or constructs persistence objects.

Failures preserve the active draft or confirmation context. Error messages use application-level descriptions and do not expose SwiftData types or stack traces. A successful mutation reloads the authoritative list and selected detail.

## Testing and evidence

Phase 3 requires:

1. A table-driven domain test covering every `AppointmentStatus × AppointmentAction` pair.
2. Validator tests for customer requirement, party size, and allowed historical dates.
3. Service tests for timestamps, invalid-transition zero writes, edit changes, stable identity, and Activity mapping.
4. Repository tests for filters, aggregate details, one-save mutations, ordered changes, and relationship preservation.
5. A real disk V1-to-V2 migration test on macOS CI.
6. ViewModel tests for filtering, selection, editor state, confirmation, action availability, success refresh, and failure preservation.
7. Disk-backed acceptance chains covering complete, cancel, reschedule/reconfirm, and no-show paths.
8. Windows Phase 3 repository validation followed by unsigned macOS push, pull-request, and post-merge Build/Test gates.

Real Mac appearance, keyboard/focus behavior, VoiceOver, notification delivery, Apple Developer Team configuration, signing, provisioning, notarization, and packaging remain **Not Verified** until genuine evidence exists.

## Scope boundary

Phase 3 does not implement Today, Calendar, notification delivery, automatic no-show follow-up creation, global search, import, backup, visual-system polish, or release signing. Those remain assigned to later phases. It may expose stable service and presentation boundaries those phases can consume without bypassing the appointment lifecycle.
