# Phase 4 Today Workspace Design

**Status:** Approved on 2026-09-15

## Goal

Make Today the default Goosegrass workspace so the user can understand the day's workload within five seconds, inspect every appointment scheduled for the local civil day, and perform valid quick actions without introducing derived persistence state.

## Scope

Phase 4 delivers:

- four summary cards: Today Appointments, Upcoming Arrivals, Need Contact, and No Show;
- a time-ordered Today appointment list with complete same-day history;
- a Need Contact customer list selected by its summary card;
- appointment selection and the Phase 3 inspector;
- valid quick actions for arrive, reschedule, no-show, cancel, and open detail;
- authoritative refresh after every mutation;
- Today as the default application route;
- deterministic aggregate, ViewModel, composition, and disk-relaunch tests;
- a Windows Phase 4 static gate and macOS Build/XCTest evidence.

Phase 4 does not add a repository, cache, schema version, notification behavior, follow-up workflow, timer, or automatic appointment status mutation.

## Architecture

`TodayService` is a `@MainActor` application-layer runtime aggregator. It receives the existing `AppointmentService` and `CustomerService`, a `Calendar`, and a `now` clock. It loads the current local civil-day interval using `Calendar.dateInterval(of: .day, for:)`, asks the existing services for authoritative values, and produces immutable Today presentation values.

`TodayViewModel` owns screen selection, rows, counts, inspector state, reschedule draft state, confirmation state, and errors. It never imports SwiftData. Mutations are delegated to `AppointmentService`; after every successful mutation it reloads the entire Today snapshot and selected detail from the repository-backed services.

`TodayView` renders the approved dashboard and reuses `AppointmentDetailView` for the inspector. The application constructs Today, Appointments, and Customers state from services backed by the one `PersistenceController`.

Dependency flow remains:

```text
TodayView -> TodayViewModel -> TodayService
                              -> AppointmentService -> AppointmentRepository
                              -> CustomerService    -> CustomerRepository
```

## Runtime Semantics

### Local civil day

The Today interval is calculated from the injected calendar. No code may use a fixed 86,400-second duration to derive day boundaries.

### Main appointment list

The main list contains every appointment whose `startAt` is inside today's interval, including `completed`, `cancelled`, and `noShow`. It is sorted by `startAt`, then UUID for deterministic ties. Cards apply presentation filters only; they never delete records or rewrite status.

Each row exposes time, customer name, party size, phone tail, source, status text, tags, customer-request summary, and valid quick actions.

### Summary definitions

- **Today Appointments:** count appointments inside today's interval whose status is not `cancelled`.
- **Upcoming Arrivals:** count appointments inside today's interval with `startAt >= now` and a lifecycle status from which arrival can still occur. Phase 4 defines this set as `confirmed` and `upcoming`. A persisted `upcoming` transition remains valid, but a `confirmed` appointment is not omitted merely because no status write occurred.
- **Need Contact:** count non-archived customers whose status is `needContact`.
- **No Show:** count today's appointments whose status is `noShow`.

Upcoming Arrivals is derived only in memory. It must not modify Appointment status and must not schedule a timer.

### Card selection

The selected card controls presented rows:

- Today Appointments shows today's non-cancelled appointments.
- Upcoming Arrivals shows the derived upcoming-arrival subset.
- Need Contact shows `needContact` customers.
- No Show shows today's no-show appointments.
- clearing the card selection restores the complete Today appointment list, including terminal and cancelled records.

## Quick Actions and Inspector

Appointment rows and inspector actions are intersected with `AppointmentLifecycle.allowedActions`. Today exposes arrive, reschedule, mark no-show, cancel, and open detail only when valid for the selected appointment. Cancellation requires confirmation. Reschedule uses the Phase 3 editor/service path and preserves the appointment UUID.

After each successful arrive, reschedule, no-show, or cancel action, Today reloads counts, filtered rows, the full list, and selected detail from the authoritative services. Errors preserve the active reschedule draft and expose a user-visible error.

## Error Handling

Service and persistence errors are caught by `TodayViewModel` and represented as `errorMessage`. Failed actions do not optimistically modify counts or rows. Missing selected records clear the inspector on the next authoritative reload. Invalid lifecycle actions are rejected by the Phase 3 policy before any repository commit.

## UI Composition

Today becomes `ContentView`'s default destination. The main content uses compact clickable cards above a native table/list and a trailing inspector. Empty states exist for a day with no appointments and for no customers requiring contact. Status is always present as text and never communicated by color alone.

Keyboard and accessibility behavior includes semantic card/button labels, combined row labels, Command-N for a new appointment, Return/default action in sheets, and Escape/cancel action. Actual appearance, focus traversal, keyboard behavior, and VoiceOver on real Mac hardware remain **Not Verified** until manually tested.

## Persistence and Later-Phase Boundaries

Schema V2 remains unchanged. Today performs read-time aggregation over existing Appointment, Customer, and presentation values. UserNotifications stays in Phase 5; FollowUp entities and workflows stay in Phase 6. No Team ID, signing identity, or provisioning profile is added.

## Verification

Tests must prove:

- civil-day boundaries use the injected calendar, including a non-24-hour day;
- the four counts follow the exact approved definitions;
- a future `confirmed` appointment appears in Upcoming Arrivals without any status mutation;
- Today Appointments excludes cancelled only from its card count/filter while the complete main list retains cancelled, completed, and no-show history;
- card selection switches appointment/customer presentation without altering stored values;
- valid quick actions refresh all authoritative state and invalid actions commit nothing;
- selection, inspector, reschedule, confirmation, error, and empty states are deterministic;
- one disk store survives relaunch with counts and histories intact;
- the app composes all services from one persistence controller;
- Windows Phase 4 validation passes and GitHub Actions completes unsigned macOS build and XCTest.

Real-Mac UI appearance, keyboard/focus behavior, VoiceOver, notification delivery, Apple Developer Team configuration, signing, provisioning, notarization, and packaging remain **Not Verified**.
