# Phase 7 Calendar Design

## Objective and scope

Deliver the V1 Calendar destination specified by the Master Spec: a month view, date selection, daily appointments, visible status indicators, and access to appointment detail. Week view, drag-and-drop rescheduling, EventKit, external sync, and calendar-owned lifecycle mutations are outside Phase 7.

## Chosen architecture

`CalendarService` composes the existing `AppointmentService` at runtime. It reads appointment list items for one local civil month and resolves selected appointment detail through the same service. It creates no repository, cache, timer, or stored calendar state. `CalendarViewModel` owns only transient displayed-month, selected-day, selected-appointment, snapshot, and error state. `CalendarView` renders the native macOS workspace. This follows the Today composition boundary while keeping month arithmetic testable outside SwiftUI.

Directly querying SwiftData from the view would break the application boundary. Putting all month calculations in the ViewModel would couple aggregation to UI state. A separate calendar repository would duplicate the existing appointment read path without a new persistence requirement.

## Month and day semantics

The injected `Calendar` defines local month/day intervals with `dateInterval(of:for:)`; no fixed 24-hour or 30-day arithmetic is used. The month query is the half-open interval `[month.start, month.end)`, so records on either boundary belong to exactly one displayed month. The week header and leading empty cells use the calendar's `firstWeekday`. Only dates in the displayed month are selectable; outside-month cells are blank rather than showing adjacent-month appointments.

The month snapshot includes all appointment statuses, including draft, completed, cancelled, and noShow. A day selection filters the already loaded month snapshot by the selected local-day interval and sorts by start time, then UUID for ties. Neither month counts nor day lists rewrite status. Month cells show a total appointment count and a compact textual status summary; color may reinforce but never be the sole status cue.

The initial displayed month and selected day are the injected current local date. Previous/next month navigation selects the first local day of the new month. Today returns to the current local month and day. Refresh reloads the authoritative month query and selection detail; reopening Calendar also refreshes, so edits made in Appointments or Today become visible without a timer.

## Interaction and layout

The Calendar route replaces its placeholder with a two-pane native SwiftUI workspace. The main pane contains a seven-column month grid and Previous, Today, Next controls. Selecting a date populates the right inspector with that day's complete appointment list. Selecting a row opens the existing Phase 3 `AppointmentDetailView` below the day list in the same right pane. A small optional read-only configuration hides that component's Edit button and action row for Calendar; edit and lifecycle actions remain in Appointments and Today. Empty days show a clear empty state; an unavailable or failed read presents an actionable error without fabricating zero results.

Month buttons, day rows, and controls have readable labels/help; status text accompanies any color indicator. Keyboard tab/arrow behavior and VoiceOver output must be checked on a real Mac before claiming interactive accessibility verified.

## Data and failure boundaries

`CalendarService` depends on `AppointmentService` only; it does not modify appointment, reminder, follow-up, Activity, or AppointmentChange records. It validates that month/day intervals can be constructed and propagates read errors. If a selected appointment disappears or moves outside the visible day after an authoritative refresh, the ViewModel clears that selection and detail while preserving the selected date. No Schema V2 change is permitted; the version remains `2.0.0`.

## Verification

- Pure/calendar-service tests: local month/day boundaries, leap year, year rollover, first-weekday alignment, daylight-saving day, month-boundary exclusivity, all-status inclusion, deterministic daily ordering, and authoritative detail reads.
- ViewModel tests: initial today state, month navigation, Today return, date/appointment selection, refresh after external reschedule, stale-selection clearing, and error display.
- Composition tests: Calendar route uses the shared appointment graph, no new repository or schema, and native SwiftUI target membership.
- Disk-backed acceptance: create appointments across two months with terminal statuses, relaunch, select a day and open detail, externally reschedule one, reload, and relaunch again to verify updated month/day membership and retained history.
- Windows Phase 0–7 static gate, then unsigned macOS `xcodebuild build` and full XCTest on push, PR, and merged `main`.

Real Mac month-grid appearance, date navigation, keyboard/focus behavior, VoiceOver, notification delivery, Apple Developer Team, signing, provisioning, notarization, and packaging remain **Not Verified** until genuine evidence exists.
