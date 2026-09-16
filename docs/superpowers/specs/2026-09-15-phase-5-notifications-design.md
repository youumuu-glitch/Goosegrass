# Phase 5 Local Notifications Design

## Objective

Add reliable local appointment reminders with explicit permission handling, the three V1 default presets, reschedule/cancel behavior, and launch reconciliation. Preserve Goosegrass as a local-first macOS app and keep actual notification delivery and permission UI behavior **Not Verified** until tested on a real Mac.

## Boundaries

- Use Apple `UserNotifications` only behind an Infrastructure adapter.
- Keep Domain, Application DTOs/services, and feature ViewModels free of `UserNotifications` and SwiftData imports.
- Reuse the existing V1 `ReminderRecord`; Phase 5 does not change Schema V2.
- Do not implement Phase 6 Follow-up behavior, including the no-show follow-up prompt.
- Do not configure an Apple Developer Team, signing certificate, or provisioning profile.

## Reminder calculation

`ReminderCalculator` is a pure Domain rule. The standard presets are one local calendar day, two hours, and thirty minutes before `Appointment.startAt`. Calendar component subtraction is used so the one-day preset retains the intended local wall-clock time across daylight-saving changes. Fire dates at or before the injected current time are omitted.

Default preferences enable all three standard presets and sound. Preferences live in `UserDefaults`, not SwiftData, and are exposed as a value type so tests can inject deterministic settings. Custom reminders remain representable by the existing model but do not gain an editor in this phase.

## Persistence and identity

Add a `ReminderRepository` application protocol and `LocalReminderRepository` backed by the existing `ReminderRecord`. The repository supports appointment-scoped reads, all-record reconciliation reads, upsert, and status updates. Standard presets are unique per appointment and type. Existing matching records retain their UUID; each system request uses the stable identifier:

```text
com.gravityedge.goosegrass.reminder.<reminder UUID>
```

Rebuilding therefore replaces the same pending request instead of creating duplicates. Cancelling changes durable reminder status to `cancelled`; notification submission failures change it to `failed`.

## Notification adapter

Define Foundation-only authorization, request, and pending-request values plus an async `LocalNotificationCenter` protocol. `UserNotificationCenterAdapter` is the sole type importing `UserNotifications`; it translates those values to `UNUserNotificationCenter` calls. Notification content excludes phone numbers, customer/internal notes, and other private history.

Actual authorization prompts and delivery cannot be validated on Windows or a headless CI runner. Unit/service tests use a deterministic fake adapter, while macOS CI proves compilation and logic.

## Reminder service and consistency model

`ReminderService` owns permission, schedule, reschedule, cancel, rebuild, and reconcile behavior. A rebuild follows this order:

1. Calculate the desired reminders from the appointment and current preferences.
2. Persist or update durable reminder intent.
3. Remove obsolete system requests and mark obsolete records cancelled.
4. Submit desired system requests.
5. Persist submission failures as failed reminders.

Eligible appointment states are `confirmed`, `upcoming`, and `rescheduled`. Draft, pending-confirmation, arrived, completed, cancelled, and no-show appointments have all pending reminders cancelled. Treating `rescheduled` as eligible implements the Master Spec rule that old requests disappear and new-time requests are built immediately; a later reconfirm is idempotent.

There is no cross-system transaction between SwiftData and Notification Center. Durable intent is written first, and lightweight launch reconciliation repairs interruption between the database and system scheduler. Reconciliation compares future eligible appointments, durable reminders, and Goosegrass-owned pending identifiers; it schedules missing requests, removes obsolete/duplicate requests, cancels invalid reminders, and never removes requests belonging to another app feature.

## Appointment integration

`AppointmentService` receives an optional application-level reminder mutation handler. After a successful appointment commit it reports the authoritative appointment to that handler. The production `ReminderService` queues the async synchronization on the main actor. Notification failure never rolls back a successfully committed appointment; it is represented by a failed Reminder and repaired by later reconcile.

The application constructs one ReminderService and injects it into both the Appointments and Today appointment-service graphs. This keeps create/confirm/reschedule/cancel/no-show behavior consistent regardless of which workspace initiated the action.

## Settings and launch

The Settings destination displays authorization state, a permission button, toggles for the three presets and sound, and a reconcile action. Launch starts one lightweight reconcile after the shared persistence graph is open. It does not perform a periodic scan or add a timer.

## Verification

- Domain tests: preset calculation, daylight-saving boundary, past-fire omission.
- Repository tests: CRUD/upsert uniqueness, relationships, status persistence, disk reopen.
- Service tests with fake notification center: permission, schedule, idempotency, reschedule, cancel, failure, and reconcile/ghost removal.
- Appointment integration tests: lifecycle mutations invoke reminder synchronization from Appointments and Today service graphs.
- Windows Phase 0–5 static gate and macOS unsigned Build/XCTest on push and pull request.
- Real Mac permission prompt, sound, banner delivery, reschedule removal, cancellation non-delivery, keyboard/focus, VoiceOver, signing, provisioning, notarization, and packaging remain **Not Verified**.
