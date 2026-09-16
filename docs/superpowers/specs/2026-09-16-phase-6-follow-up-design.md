# Phase 6 Follow-up Design

## Objective

Close the V1 no-show recovery loop and provide a dedicated Follow-up workspace where staff can create, review, snooze, complete, or cancel customer follow-ups. Preserve Goosegrass's local-first architecture and the complete customer/appointment history.

## Chosen approach

Use a dedicated `FollowUpRepository` and `FollowUpService` over the existing V1 `FollowUpRecord`. This keeps follow-up lifecycle rules out of views and avoids coupling follow-up persistence to the larger appointment aggregate. Extending `AppointmentRepository` would make manual follow-ups awkward, while direct SwiftData access from a ViewModel would violate the established application boundary.

Phase 6 does not add a cache, background timer, follow-up notification scheduler, or schema migration. Schema V2 remains `2.0.0`.

## Domain lifecycle and due dates

The existing statuses remain authoritative:

- `pending`: actionable now or in the future.
- `snoozed`: intentionally deferred to a new `dueAt`; it remains visible in the active queue.
- `completed`: terminal, with `completedAt` set.
- `cancelled`: terminal, with `completedAt` cleared.

Allowed operations are deliberately small:

- pending or snoozed → completed
- pending or snoozed → snoozed with a strictly future due date
- pending or snoozed → cancelled
- terminal records remain read-only

`FollowUpSchedule.tomorrowAtEleven(from:calendar:)` is a pure Domain rule. It uses the injected local `Calendar`, advances by one calendar day, then constructs 11:00 local time. It never uses a fixed 24-hour interval, so daylight-saving boundaries retain the intended wall-clock time.

## Persistence and service boundary

`FollowUpRepository` supports authoritative list/detail reads and one atomic `FollowUpMutation`. The local repository validates that the customer exists and is not archived, validates an optional appointment belongs to that customer, attaches relationships, writes the follow-up plus its activities, and saves once.

Creating a follow-up writes `followUpCreated`; completing one writes `followUpCompleted`. Both activities link to the same customer and optional appointment. Snooze and cancel update the durable record without deleting history. Physical delete is not exposed in Phase 6.

`FollowUpService` owns creation validation and lifecycle transitions. Required reason text is trimmed and must not be empty. Due dates for create and snooze must be later than the injected operation time. After every mutation, callers re-read authoritative list/detail data rather than mutating cached presentation values.

## No-show integration

`AppointmentService` remains responsible for the existing atomic no-show transition, timestamp, Activity, and reminder cancellation callback. Only after that transition succeeds, the initiating ViewModel exposes a transient `NoShowFollowUpRequest` for the UI. The prompt offers:

- **Tomorrow 11:00**: create a normal-priority follow-up linked to the customer and appointment with reason `No-show follow-up`.
- **Custom…**: open the standard follow-up editor prefilled with that customer and appointment.
- **Skip**: dismiss without writing a follow-up.

No follow-up is auto-created merely because an appointment is `noShow`, and reopening an old no-show does not re-present the prompt. A failed appointment transition cannot present it. This preserves explicit user intent and prevents duplicates. Both Appointments and Today use the same shared `FollowUpService`, so the behavior is consistent regardless of entry point.

## Follow-up workspace

The Follow-up destination becomes a split workspace:

- A toolbar provides New Follow-up and active/all filtering.
- The list defaults to the active queue (`pending` and `snoozed`) and sorts by `dueAt`, then priority, then creation time.
- Rows show due time, customer, reason, priority, and status, with overdue state derived at runtime rather than persisted.
- The inspector shows customer contact context, linked appointment when present, note, timestamps, and the allowed Complete, Snooze, and Cancel actions.
- The editor supports customer, optional appointment belonging to that customer, due date, reason, note, and priority.

Completed and cancelled records remain available through the All filter. The workspace does not reinterpret Today's `needContact` customer-status queue; these are separate business concepts.

## Error handling

Validation errors remain actionable and do not write partial records or activities. Repository relationship errors surface through the existing persistence error family. ViewModels publish one user-visible error message and preserve selection where possible. Dialog cancellation and Skip are no-op paths.

## Verification

- Domain tests: tomorrow-at-11 calculation including a DST boundary, lifecycle permissions, and due-date validation.
- Repository tests: relationships, atomic Activity writes, deterministic filtering/sorting, invalid stored values, and disk reopen.
- Service tests: manual/no-show creation, complete, snooze, cancel, invalid transitions, and no partial writes.
- ViewModel/composition tests: active/all filters, selection refresh, no-show prompt only after successful transition, Tomorrow/Custom/Skip paths, and shared service wiring in Appointments and Today.
- Disk-backed acceptance: `No Show → Tomorrow 11:00 FollowUp → relaunch → Follow-up Page → Complete → relaunch`, with appointment/activity/reminder history retained.
- Windows Phase 0–6 static gate and unsigned macOS Build/XCTest on push and pull request.

Real Mac sheet/dialog behavior, keyboard focus, VoiceOver, locale/date presentation, and any future follow-up notification delivery remain **Not Verified**. Apple Developer Team, signing, provisioning, notarization, and packaging remain **Not Verified**.
