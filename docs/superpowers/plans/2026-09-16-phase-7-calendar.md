# Phase 7 Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a month-first Calendar workspace with local-day appointment history and read-only appointment detail.

**Architecture:** `CalendarService` derives month/day snapshots from the existing `AppointmentService`; `CalendarViewModel` owns transient navigation and selection; SwiftUI renders a two-pane month grid and day inspector. No new repository, cache, timer, or schema version is added.

**Tech Stack:** Swift 5, Foundation Calendar, SwiftUI, SwiftData through existing Infrastructure, XCTest, PowerShell, GitHub Actions macOS runner.

---

## File map

- `Goosegrass/Application/DTO/CalendarPresentation.swift`: value snapshots for month cells and selected day.
- `Goosegrass/Application/Services/CalendarService.swift`: local calendar interval/grid calculations and authoritative appointment reads.
- `Goosegrass/Features/Calendar/CalendarViewModel.swift`: month navigation, date/row selection, refresh, and errors.
- `Goosegrass/Features/Calendar/CalendarView.swift`: native month grid and day inspector.
- `Goosegrass/Features/Appointments/AppointmentDetailView.swift`: optional read-only mode hiding mutation controls.
- `Goosegrass/Infrastructure/Persistence/PersistenceController.swift` and `Goosegrass/App/ContentView.swift`: shared service composition and Calendar route.
- `GoosegrassTests/CalendarServiceTests.swift`, `CalendarViewModelTests.swift`, `CalendarFeatureCompositionTests.swift`, `CalendarAcceptanceTests.swift`: focused and disk-backed proof.
- `Goosegrass.xcodeproj/project.pbxproj`, `scripts/validate-phase7.ps1`, `.github/workflows/macos-build.yml`: project membership and static/macOS gates.
- `README.md`, `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `docs/ROADMAP.md`, `docs/CHANGELOG.md`: evidence and boundaries.

## Task 1: Static gate and compilable test scaffold

- [ ] Add `scripts/validate-phase7.ps1` that runs Phase 6, requires the files above and Xcode source/test memberships, rejects SwiftData imports outside Infrastructure, checks Schema V2 remains `2.0.0`, and requires Phase 7 real-Mac Not Verified wording. Run it before files exist; expect a missing-file failure.
- [ ] Add empty compilable Calendar source/test files and explicit PBX references/build members; append Phase 7 gate to `.github/workflows/macos-build.yml`. Run `./scripts/validate-phase7.ps1`; expect `Phase 7 static validation passed.`
- [ ] Commit scaffold, push `feature/phase-7-calendar`, and require unsigned macOS Build/XCTest GREEN before behavioral TDD.

## Task 2: CalendarService month/day behavior

- [ ] In `CalendarServiceTests.swift`, add a test that constructs UTC 2026-09 appointments at the month start, final instant, and October start; assert September includes only the first two. Add separate tests for leap-day February, year rollover, non-default `firstWeekday`, a daylight-saving day, all appointment statuses, stable start-time/UUID ordering, and detail retrieval.
- [ ] Push the test-only commit and require macOS XCTest RED because `CalendarService`/snapshot APIs do not yet exist.
- [ ] Implement `CalendarMonthSnapshot` with `monthInterval`, seven weekday symbols, leading blank-cell count, and `[CalendarDay]`. Give each `CalendarDay` a local day interval, all appointment items, count, and textual status summary. Implement `CalendarService.snapshot(monthContaining:)` using `calendar.dateInterval(of: .month, for:)`, one `AppointmentService.list(filter:)` call, and local day bucketing; implement `detail(appointmentID:)` via `AppointmentService.detail(id:)`. Throw a typed interval error if Calendar cannot construct an interval.
- [ ] Run Windows gate, commit and push; require macOS Build/XCTest GREEN.

## Task 3: CalendarViewModel navigation and selection

- [ ] In `CalendarViewModelTests.swift`, add initial-today, previous/next-month-first-day, Today return, day selection, detail selection, external reschedule refresh, missing-row selection clearing, and surfaced-error tests. Push RED and verify macOS XCTest fails for absent ViewModel behavior.
- [ ] Implement observable state: displayed month, selected day, selected appointment ID/detail, snapshot, error. `load`/`refresh` reread service; month moves use `calendar.date(byAdding: .month, value:, to:)`; day changes clear appointment detail; refresh clears a selected appointment if it no longer belongs to the selected day.
- [ ] Run Windows gate, commit and push; require macOS Build/XCTest GREEN.

## Task 4: Native month workspace and application composition

- [ ] In `CalendarFeatureCompositionTests.swift`, assert Calendar route and one shared appointment graph, compiled month/day view, and read-only `AppointmentDetailView` configuration. Push RED and verify macOS failure.
- [ ] Add the Calendar route to `ContentView`; render a seven-column grid with textual day/status labels, Previous/Today/Next buttons, day list, and selected read-only detail below it. Reuse `AppointmentDetailView` with a defaulted `isReadOnly` flag so Appointments/Today retain current controls. Loading the route rereads authoritative data. Add help/accessibility labels and visible error/empty states.
- [ ] Run Windows gate, commit and push; require macOS Build/XCTest GREEN.

## Task 5: Disk acceptance and phase close

- [ ] Add `CalendarAcceptanceTests.swift` with a named disk store: create cross-month and terminal-status appointments; reopen, assert month/day membership and detail; externally reschedule one; refresh, reopen again, assert new membership plus retained change/activity history. Run macOS XCTest and fix only evidenced failures.
- [ ] Update README/architecture/testing/roadmap/changelog with exact CI run IDs and explicit Not Verified boundaries. Run `git diff --check`, `./scripts/validate-phase7.ps1`, and full branch diff review; commit and push exact candidate SHA.
- [ ] Require macOS push and PR Build/XCTest GREEN, clean/conflict-free PR, merge to main, and post-merge main CI GREEN. Then safely remove only the verified merged Phase 7 worktree/branches and start Phase 8.
