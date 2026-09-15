# Phase 4 Today Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a default Today workspace whose runtime counts, complete same-day history, quick actions, and inspector always reflect authoritative Appointment and Customer data.

**Architecture:** Add immutable Today presentation values and a `@MainActor` `TodayService` that combines the existing application services using an injected calendar and clock. Keep screen state in a SwiftData-free `TodayViewModel`, reuse the Phase 3 inspector/editor flows, and preserve Schema V2 unchanged.

**Tech Stack:** Swift 5, SwiftUI, Foundation Calendar, SwiftData through existing repositories, XCTest, PowerShell static validation, GitHub Actions macOS runner.

---

### Task 1: Add the Phase 4 repository gate and scaffold

**Files:**
- Create: `scripts/validate-phase4.ps1`
- Modify: `.github/workflows/macos-build.yml`
- Modify: `Goosegrass.xcodeproj/project.pbxproj`
- Create: `Goosegrass/Application/DTO/TodayPresentation.swift`
- Create: `Goosegrass/Application/Services/TodayService.swift`
- Create: `Goosegrass/Features/Today/TodayViewModel.swift`
- Create: `Goosegrass/Features/Today/TodayView.swift`
- Create: `Goosegrass/Features/Today/TodaySummaryCard.swift`
- Create: `GoosegrassTests/TodayAggregationTests.swift`
- Create: `GoosegrassTests/TodayViewModelTests.swift`
- Create: `GoosegrassTests/TodayFeatureCompositionTests.swift`
- Create: `GoosegrassTests/TodayAcceptanceTests.swift`

- [ ] **Write and run the expected RED repository validator**

Create a PowerShell validator that invokes `validate-phase3.ps1`, requires all Phase 4 files above, rejects `import SwiftData` and `import UserNotifications` under `Features/Today`, verifies every source/test belongs to the correct Xcode Sources phase, requires the workflow to call `validate-phase4.ps1`, proves `PersistenceSchemaV2.versionIdentifier` remains `2.0.0`, and requires Phase 4 evidence plus the real-Mac **Not Verified** statement in `docs/TESTING.md`.

Run:

```powershell
pwsh -NoProfile -File scripts/validate-phase4.ps1
```

Expected: FAIL listing missing Today files, target membership, workflow wiring, and evidence.

- [ ] **Add compile-neutral placeholders and CI wiring**

Create the empty Swift files, add app/test build references to `Goosegrass.xcodeproj/project.pbxproj`, and change the workflow validation command to:

```yaml
- name: Validate repository
  shell: pwsh
  run: ./scripts/validate-phase4.ps1
```

Add a Phase 4 Not Verified stub to `docs/TESTING.md`. Re-run the validator and require `Phase 4 static validation passed.`

- [ ] **Commit, push, and require scaffold macOS GREEN**

```powershell
git add scripts/validate-phase4.ps1 .github/workflows/macos-build.yml Goosegrass.xcodeproj/project.pbxproj Goosegrass GoosegrassTests docs/TESTING.md
git commit -m "test(today): define Phase 4 acceptance gate"
git push -u origin feature/phase-4-today
```

Require unsigned macOS Build and the complete XCTest target to pass before adding behavior tests.

### Task 2: Define deterministic Today presentation and runtime aggregation

**Files:**
- Create: `Goosegrass/Application/DTO/TodayPresentation.swift`
- Create: `Goosegrass/Application/Services/TodayService.swift`
- Create: `GoosegrassTests/TodayAggregationTests.swift`

- [ ] **Write RED aggregation tests**

Define fixtures covering yesterday, today, tomorrow, every terminal status, a future `confirmed` appointment, a future `upcoming` appointment, a past confirmed appointment, archived customers, and `needContact` customers. Require these public values:

```swift
enum TodaySelection: String, CaseIterable, Equatable, Sendable {
    case all, todayAppointments, upcomingArrivals, needContact, noShow
}

struct TodayCounts: Equatable, Sendable {
    let todayAppointments: Int
    let upcomingArrivals: Int
    let needContact: Int
    let noShow: Int
}

struct TodaySnapshot: Equatable, Sendable {
    let interval: DateInterval
    let generatedAt: Date
    let counts: TodayCounts
    let allAppointments: [AppointmentListItem]
    let needContactCustomers: [CustomerListItem]

    func appointments(for selection: TodaySelection) -> [AppointmentListItem]
}
```

Assert:

```swift
XCTAssertEqual(snapshot.counts.todayAppointments, today.filter { $0.status != .cancelled }.count)
XCTAssertEqual(snapshot.counts.upcomingArrivals, 2) // future confirmed + future upcoming
XCTAssertEqual(snapshot.allAppointments.map(\.appointment.status), [
    .confirmed, .completed, .cancelled, .noShow, .upcoming,
])
XCTAssertEqual(snapshot.appointments(for: .todayAppointments).contains { $0.appointment.status == .cancelled }, false)
XCTAssertEqual(snapshot.appointments(for: .all).contains { $0.appointment.status == .cancelled }, true)
```

Use `America/Los_Angeles` on the spring-forward date and assert the generated interval is the calendar's day interval rather than a fixed 86,400 seconds. Push the tests and require expected RED for absent Today types.

- [ ] **Implement the minimal runtime aggregator**

Implement:

```swift
@MainActor
final class TodayService {
    init(
        appointmentService: AppointmentService,
        customerService: CustomerService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    )

    func snapshot() throws -> TodaySnapshot
    func detail(appointmentID: UUID) throws -> AppointmentDetail?
    func transition(appointmentID: UUID, action: AppointmentAction) throws -> Appointment
    func reschedule(appointmentID: UUID, startAt: Date, endAt: Date?, reason: String) throws -> Appointment
}
```

Build the interval with `calendar.dateInterval(of: .day, for: now())`. Load appointments with `AppointmentFilter(dateInterval: interval)` and customers with `customerService.list()`. Sort appointments by start time then UUID and need-contact customers by display name then UUID. Derive Upcoming Arrivals with:

```swift
row.appointment.startAt >= generatedAt
    && [.confirmed, .upcoming].contains(row.appointment.status)
```

Do not mutate status while taking a snapshot and do not create a timer.

- [ ] **Run full CI and commit aggregation GREEN**

```powershell
git add Goosegrass/Application/DTO/TodayPresentation.swift Goosegrass/Application/Services/TodayService.swift GoosegrassTests/TodayAggregationTests.swift
git commit -m "feat(today): add runtime dashboard aggregation"
git push
```

Require the complete macOS test target to pass and record RED/GREEN run IDs in this plan.

### Task 3: Implement authoritative Today ViewModel state

**Files:**
- Create: `Goosegrass/Features/Today/TodayViewModel.swift`
- Create: `GoosegrassTests/TodayViewModelTests.swift`

- [ ] **Write RED ViewModel tests**

Cover initial load, card selection, all-history restoration, appointment selection/detail, Need Contact selection, quick-action availability, cancellation confirmation, reschedule draft, successful authoritative refresh, record disappearance, and error preservation.

Require this observable state:

```swift
@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var snapshot: TodaySnapshot?
    @Published private(set) var selection: TodaySelection
    @Published private(set) var appointmentRows: [AppointmentListItem]
    @Published private(set) var customerRows: [CustomerListItem]
    @Published private(set) var selectedAppointmentID: UUID?
    @Published private(set) var detail: AppointmentDetail?
    @Published var rescheduleDraft: AppointmentEditorDraft?
    @Published private(set) var pendingAction: AppointmentAction?
    @Published private(set) var errorMessage: String?
}
```

Prove that a future confirmed appointment appears under Upcoming Arrivals while its stored status remains confirmed. After arrive/no-show/cancel/reschedule, assert counts and rows are reloaded from the service rather than patched optimistically. Push and require expected RED for the missing ViewModel.

- [ ] **Implement injected state and commands**

Provide:

```swift
func load()
func selectCard(_ selection: TodaySelection)
func selectAppointment(_ id: UUID?)
func beginReschedule()
func saveReschedule(reason: String)
func perform(_ action: AppointmentAction)
func confirmPendingAction()
func cancelPendingAction()
func cancelReschedule()
func clearError()
```

Cancellation sets `pendingAction` before mutation. Reschedule opens a draft only when `.reschedule` is allowed. Every successful mutation calls one `reloadThrowing()` that replaces snapshot, visible rows, and selected detail from `TodayService`. Failed operations keep the reschedule draft and expose the error.

- [ ] **Run full CI and commit ViewModel GREEN**

```powershell
git add Goosegrass/Features/Today/TodayViewModel.swift GoosegrassTests/TodayViewModelTests.swift
git commit -m "feat(today): add authoritative dashboard state"
git push
```

### Task 4: Build the Today dashboard and app composition

**Files:**
- Create: `Goosegrass/Features/Today/TodaySummaryCard.swift`
- Create: `Goosegrass/Features/Today/TodayView.swift`
- Modify: `Goosegrass/App/ContentView.swift`
- Modify: `Goosegrass/App/GoosegrassApp.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Create: `GoosegrassTests/TodayFeatureCompositionTests.swift`

- [ ] **Write RED composition tests**

Create one in-memory `PersistenceController`, write a customer and appointment through its services, construct `TodayService` from a new `makeTodayService(calendar:now:)` factory, and assert the Today snapshot sees the same UUIDs. Instantiate `TodayView(viewModel:)` and `ContentView` and require Today to be the default destination.

- [ ] **Implement native dashboard UI**

Build four compact buttons using `TodaySummaryCard`, each with a text label and numeric value. Render a native appointment table for appointment selections and a customer list for Need Contact. Appointment rows must include time, customer, party size, phone tail, source, status text, tags, and request summary. Add valid quick actions from the intersection of:

```swift
Set([AppointmentAction.arrive, .reschedule, .markNoShow, .cancel])
    .intersection(AppointmentLifecycle.allowedActions(from: status))
```

Reuse `AppointmentDetailView` in the trailing inspector, use `AppointmentEditorView` for reschedule, and provide cancellation confirmation, empty states, semantic accessibility labels/help, Command-N, Return, and Escape behavior. `TodayView` accepts an `onNewAppointment` closure with a no-op default; `ContentView` supplies a closure that opens the Appointments route and starts its editor. No Today feature file may import SwiftData or UserNotifications.

Change `ContentView`'s initial destination to `.today`, accept `TodayService` in its initializer, own one `TodayViewModel`, and route the Today destination to `TodayView`. Add `PersistenceController.makeTodayService(calendar:now:)` using the same appointment/customer repositories; `GoosegrassApp` supplies that service together with the existing appointment and customer services.

- [ ] **Run full CI and commit UI GREEN**

```powershell
git add Goosegrass/App Goosegrass/Features/Today Goosegrass/Infrastructure/Persistence/PersistenceController.swift GoosegrassTests/TodayFeatureCompositionTests.swift
git commit -m "feat(today): build default daily workspace"
git push
```

### Task 5: Prove disk-relaunch and refresh acceptance

**Files:**
- Create: `GoosegrassTests/TodayAcceptanceTests.swift`

- [ ] **Write disk-backed acceptance coverage before corrective code**

Create a temporary disk store with stable UUIDs and a fixed local calendar. Persist same-day confirmed, upcoming, completed, cancelled, and no-show appointments plus a need-contact customer. Relaunch, build a Today snapshot, and assert exact counts and complete main-list IDs. Then perform arrive, cancel, no-show, and reschedule commands through `TodayViewModel`, relaunch again, and assert counts, statuses, histories, and customer relationships remain correct.

The test must explicitly assert that taking a snapshot leaves a future confirmed appointment's stored status unchanged.

- [ ] **Run acceptance/full CI and make only tested corrections**

If the test exposes a defect, preserve the failing commit/run, add the smallest correction, and re-run the complete macOS target. Commit the final acceptance state:

```powershell
git add GoosegrassTests/TodayAcceptanceTests.swift Goosegrass
git commit -m "test(today): prove durable dashboard refresh"
git push
```

### Task 6: Update authoritative evidence and verify the candidate

**Files:**
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/superpowers/plans/2026-09-15-phase-3-appointments.md`
- Modify: `docs/superpowers/plans/2026-09-15-phase-4-today.md`

- [ ] **Record behavior and verification evidence**

Document runtime-only Upcoming Arrivals, card/list semantic separation, authoritative refresh, unchanged Schema V2, all Phase 4 RED/GREEN run IDs, Phase 3 post-merge main run `34948667447`, and every remaining **Not Verified** real-Mac/signing item.

- [ ] **Run fresh candidate verification**

```powershell
pwsh -NoProfile -File scripts/validate-phase4.ps1
git diff --check origin/main...HEAD
git status --short
```

Require a clean worktree and successful macOS push Build/Test for the exact candidate SHA.

### Task 7: Create, verify, merge, and clean Phase 4

- [ ] **Create PR and require all gates**

Create a PR from `feature/phase-4-today` to `main`. Require the pull-request Build/Test check to succeed, `mergeable=true`, `mergeable_state=clean`, and no conflict before merging.

- [ ] **Merge and verify main**

Merge without rewriting history, synchronize local main with `git pull --ff-only`, and require the post-merge `main` Build/Test run to succeed.

- [ ] **Clean safely and begin Phase 5**

Confirm the worktree is clean and its resolved path is under `E:\Goosegrass\.worktrees`, remove it with `git worktree remove`, prune, delete the merged local and remote branch, then create `feature/phase-5-notifications` from the verified main commit in a new isolated worktree.
