# Phase 3 Appointments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the persistent Appointments workspace and a complete, durable, explicitly validated appointment lifecycle.

**Architecture:** Add a pure appointment transition policy, then keep lifecycle orchestration in `AppointmentService` and all SwiftData work in the injected local repository. Add an append-only `AppointmentChangeRecord` through Schema V2, expose immutable list/detail DTOs to a `@MainActor` ViewModel, and compose the feature from the one application `PersistenceController`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData versioned schemas, XCTest, PowerShell static validation, GitHub Actions macOS runner.

---

### Task 1: Add the Phase 3 repository gate and scaffold

**Files:**
- Create: `scripts/validate-phase3.ps1`
- Modify: `.github/workflows/macos-build.yml`
- Modify: `Goosegrass.xcodeproj/project.pbxproj`
- Create empty source/test files listed by the validator

- [x] **Write the Phase 3 validator and run the expected RED gate**

Require these production files:

```powershell
$productionFiles = @(
    'Goosegrass/Domain/Rules/AppointmentLifecycle.swift'
    'Goosegrass/Application/DTO/AppointmentPresentation.swift'
    'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
    'Goosegrass/Features/Appointments/AppointmentEditorDraft.swift'
    'Goosegrass/Features/Appointments/AppointmentListViewModel.swift'
    'Goosegrass/Features/Appointments/AppointmentsView.swift'
    'Goosegrass/Features/Appointments/AppointmentEditorView.swift'
    'Goosegrass/Features/Appointments/AppointmentDetailView.swift'
)
```

Require these tests:

```powershell
$testFiles = @(
    'GoosegrassTests/AppointmentLifecycleTests.swift'
    'GoosegrassTests/AppointmentServiceLifecycleTests.swift'
    'GoosegrassTests/AppointmentRepositoryAggregateTests.swift'
    'GoosegrassTests/AppointmentMigrationTests.swift'
    'GoosegrassTests/AppointmentListViewModelTests.swift'
    'GoosegrassTests/AppointmentFeatureCompositionTests.swift'
    'GoosegrassTests/AppointmentAcceptanceTests.swift'
)
```

The script must invoke `validate-phase2.ps1`, reject `import SwiftData` in `Features/Appointments`, require every file in the correct Xcode Sources phase, require `PersistenceSchemaV1.versionIdentifier` to remain `1.0.0`, require Phase 3 documentation, and require the real-Mac **Not Verified** statement.

Run:

```powershell
pwsh -NoProfile -File scripts/validate-phase3.ps1
```

Expected: FAIL listing the absent Phase 3 source/test files.

- [x] **Wire CI and add compile-neutral placeholders**

Change the workflow validation step to:

```yaml
- name: Validate repository
  shell: pwsh
  run: ./scripts/validate-phase3.ps1
```

Create empty Swift placeholders and add all file references/build entries to the appropriate app or test Sources phase. Re-run the validator and require `Phase 3 static validation passed.`

- [ ] **Commit and push the gate**

```powershell
git add scripts/validate-phase3.ps1 .github/workflows/macos-build.yml Goosegrass.xcodeproj/project.pbxproj Goosegrass GoosegrassTests
git commit -m "test(appointments): define Phase 3 acceptance gate"
git push -u origin feature/phase-3-appointments
```

Require the scaffold macOS Build/Test run to pass before adding RED tests.

### Task 2: Implement the exhaustive appointment transition policy

**Files:**
- Create: `Goosegrass/Domain/Rules/AppointmentLifecycle.swift`
- Create: `GoosegrassTests/AppointmentLifecycleTests.swift`
- Modify: `GoosegrassTests/DomainRulesTests.swift`

- [ ] **Write a table-driven failing state-machine test**

Define the full action set and expected legal edges in the test:

```swift
let legal: [AppointmentStatus: [AppointmentAction: AppointmentStatus]] = [
    .draft: [.submit: .pendingConfirmation, .cancel: .cancelled],
    .pendingConfirmation: [.confirm: .confirmed, .reschedule: .rescheduled, .cancel: .cancelled],
    .confirmed: [.markUpcoming: .upcoming, .reschedule: .rescheduled, .cancel: .cancelled],
    .upcoming: [.arrive: .arrived, .reschedule: .rescheduled, .markNoShow: .noShow, .cancel: .cancelled],
    .arrived: [.complete: .completed],
    .rescheduled: [.confirm: .confirmed, .cancel: .cancelled],
]

for status in AppointmentStatus.allCases {
    for action in AppointmentAction.allCases {
        if let destination = legal[status]?[action] {
            XCTAssertEqual(try AppointmentLifecycle.destination(from: status, action: action), destination)
        } else {
            XCTAssertThrowsError(try AppointmentLifecycle.destination(from: status, action: action))
        }
    }
}
```

Push this test alone and require the expected RED compile failure for missing lifecycle types.

- [ ] **Implement the minimal pure lifecycle API**

```swift
enum AppointmentAction: String, CaseIterable, Equatable, Sendable {
    case submit, confirm, markUpcoming, arrive, complete, cancel, reschedule, markNoShow
}

enum AppointmentLifecycleError: Error, Equatable, Sendable {
    case invalidTransition(from: AppointmentStatus, action: AppointmentAction)
}

enum AppointmentLifecycle {
    static func destination(from status: AppointmentStatus, action: AppointmentAction) throws -> AppointmentStatus
    static func allowedActions(from status: AppointmentStatus) -> [AppointmentAction]
}
```

Keep the transition table in this Foundation-only file. Preserve the existing validator behavior: nil customer and party size below one fail, while past dates remain allowed.

- [ ] **Run full CI and commit GREEN**

Require the complete test target to pass, then commit:

```powershell
git add Goosegrass/Domain/Rules/AppointmentLifecycle.swift GoosegrassTests/AppointmentLifecycleTests.swift GoosegrassTests/DomainRulesTests.swift
git commit -m "feat(appointments): add explicit lifecycle policy"
git push
```

### Task 3: Add durable appointment changes through Schema V2

**Files:**
- Create: `Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/GoosegrassMigrationPlan.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift`
- Modify: `GoosegrassTests/PersistenceSchemaTests.swift`
- Create: `GoosegrassTests/AppointmentMigrationTests.swift`

- [ ] **Write RED schema and disk migration tests**

Require V1 to remain unchanged and V2 to add exactly one model:

```swift
XCTAssertEqual(PersistenceSchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
XCTAssertEqual(PersistenceSchemaV1.models.count, 7)
XCTAssertEqual(PersistenceSchemaV2.versionIdentifier, Schema.Version(2, 0, 0))
XCTAssertEqual(PersistenceSchemaV2.models.count, 8)
```

In `AppointmentMigrationTests`, create a V1-only disk container at a temporary URL, insert a V1 customer and appointment, close the scope, reopen using `PersistenceController(storeURL:)`, and assert both UUIDs and relationships survive. Then insert/fetch an `AppointmentChange` for that appointment.

Push the tests and require RED because `PersistenceSchemaV2` and change mapping do not exist.

- [ ] **Implement the additive schema and migration stage**

```swift
enum PersistenceSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        PersistenceSchemaV1.models + [AppointmentChangeRecord.self]
    }

    @Model
    final class AppointmentChangeRecord {
        @Attribute(.unique) var id: UUID
        var appointmentID: UUID
        var changeTypeRawValue: String
        var oldValueJSON: String
        var newValueJSON: String
        var reason: String
        var changedAt: Date
    }
}
```

Register:

```swift
static var schemas: [any VersionedSchema.Type] { [PersistenceSchemaV1.self, PersistenceSchemaV2.self] }
static var stages: [MigrationStage] {
    [.lightweight(fromVersion: PersistenceSchemaV1.self, toVersion: PersistenceSchemaV2.self)]
}
```

Change `PersistenceController` to construct `Schema(versionedSchema: PersistenceSchemaV2.self)`. Add mapper functions in both directions; invalid change-type raw values must throw `PersistenceError.invalidStoredValue`.

- [ ] **Run migration/full CI and commit GREEN**

Require the disk migration and complete test target to pass on macOS, then commit:

```powershell
git add Goosegrass/Infrastructure/Persistence GoosegrassTests/PersistenceSchemaTests.swift GoosegrassTests/AppointmentMigrationTests.swift
git commit -m "feat(persistence): add appointment change schema"
git push
```

### Task 4: Define appointment aggregate presentation and repository contracts

**Files:**
- Create: `Goosegrass/Application/DTO/AppointmentPresentation.swift`
- Modify: `Goosegrass/Application/Repositories/AppointmentRepository.swift`
- Create: `GoosegrassTests/AppointmentRepositoryAggregateTests.swift`

- [ ] **Write RED contract tests**

Require list results to expose customer/source/tag/reminder information, detail to return newest changes and activities first, and filter values to cover date, status, customer, source, and tag.

Use these public values:

```swift
struct AppointmentFilter: Equatable, Sendable {
    var dateInterval: DateInterval?
    var statuses: Set<AppointmentStatus>
    var customerID: UUID?
    var sourceID: UUID?
    var tagID: UUID?
}

struct AppointmentListItem: Identifiable, Equatable, Sendable {
    let appointment: Appointment
    let customerName: String
    let customerPhone: String
    let sourceName: String?
    let tagNames: [String]
    let reminderStatuses: [ReminderStatus]
}

struct AppointmentDetail: Equatable, Sendable {
    let listItem: AppointmentListItem
    let changes: [AppointmentChange]
    let activities: [Activity]
}

struct AppointmentMutation: Equatable, Sendable {
    let appointment: Appointment
    let changes: [AppointmentChange]
    let activities: [Activity]
    let isNew: Bool
}
```

Extend `AppointmentRepository` with:

```swift
func fetchList(filter: AppointmentFilter) throws -> [AppointmentListItem]
func fetchDetail(id: UUID) throws -> AppointmentDetail?
func fetchChanges(appointmentID: UUID) throws -> [AppointmentChange]
func commit(_ mutation: AppointmentMutation) throws
```

Push and require the expected RED compile failure.

- [ ] **Add minimal DTOs and protocol defaults**

Keep existing CRUD methods for compatibility. Default aggregate methods may assemble simple DTOs from existing values, while the local repository will provide the complete implementation in Task 5.

- [ ] **Run full CI and commit GREEN contract boundary**

```powershell
git add Goosegrass/Application/DTO/AppointmentPresentation.swift Goosegrass/Application/Repositories/AppointmentRepository.swift GoosegrassTests/AppointmentRepositoryAggregateTests.swift
git commit -m "feat(appointments): define aggregate boundary"
git push
```

### Task 5: Implement aggregate persistence and filters

**Files:**
- Modify: `Goosegrass/Infrastructure/Persistence/LocalAppointmentRepository.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift`
- Modify: `GoosegrassTests/AppointmentRepositoryAggregateTests.swift`

- [ ] **Add focused RED repository behavior**

Create customers with distinct sources/tags and appointments across date/status ranges. Assert each filter independently and in combination, list ordering by `startAt`, source/tag resolution, reminder summaries, detail change/activity ordering, and exclusion of appointments whose customer is archived from active workflow lists.

Add an invalid-customer mutation test:

```swift
let mutation = AppointmentMutation(appointment: orphan, changes: [change], activities: [activity], isNew: true)
XCTAssertThrowsError(try repository.commit(mutation))
XCTAssertNil(try repository.fetch(id: orphan.id))
XCTAssertTrue(try repository.fetchChanges(appointmentID: orphan.id).isEmpty)
```

- [ ] **Implement aggregate reads and a single-save mutation**

Resolve customer, source, tags, reminders, appointment-scoped activities, and V2 change records in the injected context. `commit(_:)` must validate all referenced IDs first, insert/update the appointment, insert every change/activity, and invoke `context.save()` once. Do not create a container or import SwiftUI.

- [ ] **Run focused/full CI and commit GREEN**

```powershell
git add Goosegrass/Infrastructure/Persistence/LocalAppointmentRepository.swift Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift GoosegrassTests/AppointmentRepositoryAggregateTests.swift
git commit -m "feat(appointments): persist lifecycle aggregates"
git push
```

### Task 6: Implement validated drafts and lifecycle service orchestration

**Files:**
- Create: `Goosegrass/Features/Appointments/AppointmentEditorDraft.swift`
- Modify: `Goosegrass/Application/Services/AppointmentService.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Create: `GoosegrassTests/AppointmentServiceLifecycleTests.swift`

- [ ] **Write RED service tests for every operation**

Use recording repository stubs to prove:

- create preserves the supplied customer and writes `appointmentCreated`;
- edit preserves UUID/created/sync fields and emits change records only for changed categories;
- submit, confirm, mark-upcoming, arrive, complete, cancel, reschedule, and no-show set exact statuses/timestamps;
- reschedule keeps the UUID and records old/new ISO-8601 time JSON plus reason;
- invalid transition and archived/missing customer produce zero repository commits;
- every supported lifecycle event maps to the required Activity type.

Push RED before implementation.

- [ ] **Implement the editor draft and service API**

```swift
struct AppointmentEditorDraft: Equatable, Sendable {
    var customerID: UUID?
    var startAt: Date
    var endAt: Date?
    var partySize: Int
    var sourceID: UUID?
    var customerRequest: String
    var internalNote: String

    func makeAppointment(existing: Appointment? = nil, now: Date) throws -> Appointment
    func isHistorical(relativeTo now: Date) -> Bool
}
```

```swift
final class AppointmentService {
    init(repository: any AppointmentRepository, customerRepository: any CustomerRepository)
    func create(draft: AppointmentEditorDraft, at: Date) throws -> Appointment
    func edit(id: UUID, draft: AppointmentEditorDraft, at: Date) throws -> Appointment
    func transition(id: UUID, action: AppointmentAction, at: Date) throws -> Appointment
    func reschedule(id: UUID, startAt: Date, endAt: Date?, reason: String, at: Date) throws -> Appointment
    func list(filter: AppointmentFilter) throws -> [AppointmentListItem]
    func detail(id: UUID) throws -> AppointmentDetail?
}
```

Use Codable field snapshots and stable ISO-8601 encoding. Trim request/note/reason fields. Route all writes through one `AppointmentMutation` commit. Add `PersistenceController.makeAppointmentService()` using repositories from the same context.

- [ ] **Run service/full CI and commit GREEN**

```powershell
git add Goosegrass/Features/Appointments/AppointmentEditorDraft.swift Goosegrass/Application/Services/AppointmentService.swift Goosegrass/Infrastructure/Persistence/PersistenceController.swift GoosegrassTests/AppointmentServiceLifecycleTests.swift
git commit -m "feat(appointments): enforce lifecycle service"
git push
```

### Task 7: Build the Appointments ViewModel

**Files:**
- Create: `Goosegrass/Features/Appointments/AppointmentListViewModel.swift`
- Create: `GoosegrassTests/AppointmentListViewModelTests.swift`

- [ ] **Write RED observable-state tests**

Cover initial load, date presets, combined filters, selection/detail, add/edit/reschedule draft state, historical warning, cancel confirmation, allowed action list, each lifecycle command, authoritative refresh, customer preselection, and preservation of drafts after errors.

- [ ] **Implement injected feature state**

```swift
@MainActor
final class AppointmentListViewModel: ObservableObject {
    @Published var filter: AppointmentFilter
    @Published private(set) var rows: [AppointmentListItem]
    @Published private(set) var detail: AppointmentDetail?
    @Published private(set) var selectedAppointmentID: UUID?
    @Published var editorDraft: AppointmentEditorDraft?
    @Published private(set) var editingAppointment: Appointment?
    @Published private(set) var pendingAction: AppointmentAction?
    @Published private(set) var errorMessage: String?
}
```

Inject `AppointmentService`, `CustomerService`, `Calendar`, and `now`. Compute today/tomorrow/week intervals using `Calendar`; never hard-code seconds for civil-day boundaries. Do not import SwiftData.

- [ ] **Run ViewModel/full CI and commit GREEN**

```powershell
git add Goosegrass/Features/Appointments/AppointmentListViewModel.swift GoosegrassTests/AppointmentListViewModelTests.swift
git commit -m "feat(appointments): add appointment feature state"
git push
```

### Task 8: Build and compose the native Appointments interface

**Files:**
- Create: `Goosegrass/Features/Appointments/AppointmentsView.swift`
- Create: `Goosegrass/Features/Appointments/AppointmentEditorView.swift`
- Create: `Goosegrass/Features/Appointments/AppointmentDetailView.swift`
- Modify: `Goosegrass/App/ContentView.swift`
- Modify: `Goosegrass/App/GoosegrassApp.swift`
- Modify: `Goosegrass/Features/Customers/CustomersView.swift`
- Modify: `Goosegrass/Features/Customers/CustomerDetailView.swift`
- Create: `GoosegrassTests/AppointmentFeatureCompositionTests.swift`

- [ ] **Write a RED composition test**

Assert the app-created appointment service uses repositories backed by `PersistenceController.context`, can load the same customer created through the customer service, and persists an appointment visible from both appointment and customer aggregates.

- [ ] **Implement the workspace**

Build a navigation-compatible Appointments route with:

- date preset and custom range controls;
- status/customer/source/tag filters;
- localized list columns required by Master Spec;
- selection-driven inspector;
- add/edit/reschedule sheets;
- action buttons generated from `AppointmentLifecycle.allowedActions`;
- explicit cancellation confirmation;
- structured change and activity histories;
- non-color status text, accessibility labels/help, Command-N, Return, and Escape behavior.

Wire `ContentView` with one `AppointmentListViewModel`. Add “New Appointment” to customer detail; it switches to Appointments and preselects the customer. Keep Calendar, Today, notifications, and follow-up behavior as later-phase placeholders.

- [ ] **Run full CI and commit GREEN**

```powershell
git add Goosegrass/App Goosegrass/Features/Appointments Goosegrass/Features/Customers GoosegrassTests/AppointmentFeatureCompositionTests.swift
git commit -m "feat(appointments): build appointment workspace"
git push
```

### Task 9: Prove lifecycle acceptance and finish Phase 3

**Files:**
- Create: `GoosegrassTests/AppointmentAcceptanceTests.swift`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/DATA_MODEL.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/superpowers/plans/2026-09-14-phase-2-customers.md`
- Modify: `docs/superpowers/plans/2026-09-15-phase-3-appointments.md`

- [ ] **Write disk-backed RED/acceptance coverage**

Use temporary disk stores and stable timestamps to prove:

```text
Create → Relaunch → Submit → Confirm → Upcoming → Arrive → Complete → Relaunch
Create → Confirm path → Cancel → Relaunch
Create → Confirm → Upcoming → Reschedule → Relaunch → Confirm
Create → Confirm → Upcoming → No Show → Relaunch
```

Assert stable appointment/customer UUIDs, exact lifecycle timestamps, ordered AppointmentChanges, required Activities, preserved customer relationship/history, and zero outgoing actions for terminal states. Run before corrective code; if it exposes a defect, apply only a minimal tested fix.

- [ ] **Update authoritative evidence docs**

Record Schema V2, transition rules, filters, acceptance runs, Phase 2 post-merge main run `34941490470`, and all Phase 3 RED/GREEN run IDs. Mark real Mac appearance, keyboard/focus, VoiceOver, notification delivery, Team ID, signing, provisioning, notarization, and packaging **Not Verified**.

- [ ] **Run candidate verification**

```powershell
pwsh -NoProfile -File scripts/validate-phase3.ps1
git diff --check origin/main...HEAD
git status --short
```

Require a clean candidate and a successful macOS push Build/Test run.

- [ ] **Create, verify, and merge the PR**

Create a PR from `feature/phase-3-appointments` to `main`. Require pull-request Build/Test success, `mergeable=true`, and no conflict before merge. After merging, synchronize local main and require post-merge main Build/Test success.

- [ ] **Clean up only after post-merge success**

From `E:\Goosegrass`, verify the worktree path resolves under `E:\Goosegrass\.worktrees`, remove it with `git worktree remove`, prune, delete the merged local branch, and delete the remote feature branch. Then begin Phase 4 from the verified main commit.
