# Phase 5 Local Notifications Implementation Plan

> Execute with test-driven development and verification-before-completion. Preserve every prior phase gate.

**Goal:** Deliver permission-aware, durable, idempotent local appointment reminders with lifecycle integration and launch reconciliation.

**Architecture:** Add pure reminder calculations, a repository over the existing V1 Reminder record, an async Foundation-only notification-center port with a UserNotifications adapter, and a ReminderService that repairs database/system differences. Inject one production reminder graph into Appointments, Today, Settings, and launch composition without changing Schema V2.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, UserNotifications, XCTest, PowerShell, GitHub Actions macOS runner.

---

### Task 1: Add the Phase 5 gate and scaffold

**Status:** Complete (`92fc1cc`; macOS scaffold CI `34988911437`).

Create `scripts/validate-phase5.ps1`, required source/test placeholders, Xcode memberships, workflow integration, and a Phase 5 Not Verified testing stub. Require Schema V2 to remain `2.0.0`, reject SwiftData/UserNotifications outside approved Infrastructure files, and preserve Phase 0–4 checks. Prove Windows RED before scaffolding and GREEN afterward; push and require macOS scaffold CI.

### Task 2: Implement pure reminder calculation

**Status:** Complete (RED `0d536c4` / `34989245721`; GREEN `6a7f7ef` / `34989539790`).

Write RED tests for all standard presets, local-calendar one-day behavior across DST, stable system identifiers, disabled presets, and past-fire omission. Implement `ReminderPreferences`, `ReminderCalculation`, and `ReminderCalculator` in Domain with no framework imports beyond Foundation. Require macOS RED/GREEN evidence.

### Task 3: Add durable Reminder repository behavior

**Status:** Complete (RED `97abb2d` / `34989959426`; GREEN `84f273b` / `34990280651`).

Write RED repository tests for create/fetch/upsert-by-appointment-and-type, relationship attachment, deterministic ordering, cancellation/failure status changes, invalid stored values, and disk reopen. Add mapper functions, `ReminderRepository`, and `LocalReminderRepository` using the existing V1 record and the shared main context. Do not change Schema V2. Require full macOS GREEN.

### Task 4: Add the notification-center port and adapter

**Status:** Complete (RED `815b67b` / `34990712192`; macOS availability correction `d080ce2`; GREEN `34991319616`).

Write RED contract tests using a fake center. Add Foundation-only authorization/request/pending values and `LocalNotificationCenter`; implement `UserNotificationCenterAdapter` as the only UserNotifications import. Verify content privacy and stable request identity. Require unsigned macOS compilation and XCTest.

### Task 5: Implement ReminderService lifecycle and reconcile

**Status:** Complete (RED `126757a` / `34994971973`; GREEN `05d55e9` / `34995287430`).

Write RED service tests covering permission states, schedule, idempotent rebuild, immediate reschedule replacement, terminal-state cancellation, submission failure persistence, missing-request repair, obsolete/duplicate Goosegrass request removal, foreign-request preservation, and lightweight future-only reconciliation. Implement `requestPermission`, `schedule`, `reschedule`, `cancel`, `rebuildForAppointment`, and `reconcilePendingNotifications`. Require full macOS GREEN.

### Task 6: Integrate appointment mutations and application composition

**Status:** Complete (RED `6dec5d9` / `34995609792`; GREEN `b571e1e` / `34995913095`).

Write RED integration tests proving create/confirm/upcoming/reschedule/cancel/no-show mutations report authoritative appointments to the reminder handler, and that both Appointments and Today use the same production reminder graph. Add an optional reminder mutation port to `AppointmentService`; notify it only after successful commits. Add controller factories without hidden containers. Require full macOS GREEN.

### Task 7: Build notification settings and launch reconcile

**Status:** Complete (RED `bdf0294` / `35044192788`; GREEN `a3cde88` / `35044468228`).

Write RED ViewModel/composition tests. Add a UserDefaults-backed preferences store, observable Settings ViewModel, native Settings screen, authorization/reconcile controls, preset/sound toggles, accessibility labels/help, and app-launch reconcile. Keep actual prompting and delivery out of tests and marked Not Verified. Require full macOS GREEN.

### Task 8: Prove durable acceptance and finish Phase 5

**Acceptance status:** Complete (`9d3f084`; macOS CI `35044707134`). Candidate/PR/merge steps remain pending.

Add a disk-backed acceptance chain with a fake notification center:

```text
Confirm → schedule → relaunch/reconcile
Reschedule → old requests removed → new requests present
Cancel / No-show → all requests removed
Injected submission failure → failed Reminder → reconcile repair
```

Assert stable UUIDs/system identifiers, no duplicates, complete appointment history, and no FollowUp creation. Update README, architecture, data model, testing, changelog, roadmap, and Phase 4 completion evidence. Run `validate-phase5.ps1`, branch diff checks, exact-SHA macOS push CI, PR CI, conflict checks, merge, post-merge main CI, safe cleanup, then begin Phase 6.
