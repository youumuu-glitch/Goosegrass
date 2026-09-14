# Phase 2 Customers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the persistent Customers workflow from create through relaunch, search, edit, detail/timeline, duplicate handling, and archive.

**Architecture:** Keep SwiftData inside the existing injected local repository. Add customer presentation DTOs and aggregate operations at the Application boundary, then drive SwiftUI through a `@MainActor` observable ViewModel. Compose the feature from the single Phase 1 `PersistenceController`.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest, PowerShell static validation, GitHub Actions macOS runner.

---

### Task 1: Add the Phase 2 static gate

**Files:**
- Create: `scripts/validate-phase2.ps1`
- Modify: `.github/workflows/macos-build.yml`

- [ ] Add a validator that invokes `validate-phase1.ps1`, requires every Phase 2 source/test file, rejects `import SwiftData` in feature/ViewModel files, verifies Xcode target membership, and requires the Phase 2 Not Verified statement.
- [ ] Run `pwsh -NoProfile -File scripts/validate-phase2.ps1` and record the expected RED result listing the missing Phase 2 files.
- [ ] Update CI to run the latest static validator before `xcodebuild`, while retaining unsigned build/test commands.
- [ ] Commit the red gate with `test(customers): define Phase 2 acceptance gate`.

### Task 2: Define customer presentation models and aggregate contracts

**Files:**
- Create: `Goosegrass/Application/DTO/CustomerPresentation.swift`
- Modify: `Goosegrass/Application/Repositories/CustomerRepository.swift`
- Modify: `Goosegrass/Application/Services/CustomerService.swift`
- Create: `GoosegrassTests/CustomerServiceTests.swift`

- [ ] Write failing service tests for an active-customer list sorted by `updatedAt`, expanded search, reverse-chronological activities, source/tag choices, and duplicate choices.
- [ ] Add focused immutable values:

```swift
struct CustomerListItem: Identifiable, Equatable {
    let customer: Customer
    let sourceName: String?
    let tagNames: [String]
    let nextAppointmentAt: Date?
}

struct CustomerDetail: Equatable {
    let customer: Customer
    let sourceName: String?
    let tagNames: [String]
    let activities: [Activity]
}

struct CustomerCatalog: Equatable {
    let sources: [LeadSource]
    let tags: [Tag]
}
```

- [ ] Extend `CustomerRepository` with `fetchList(query:)`, `fetchDetail(id:)`, `fetchCatalog()`, `seedDefaultSources()`, `appendActivity(_:)`, and `merge(retaining:archiving:at:)`.
- [ ] Expose thin service methods with the same domain vocabulary; keep validation and duplicate decisions in the service, not in SwiftUI.
- [ ] Run the focused XCTest in macOS CI and require the expected RED compile/test result before implementation.

### Task 3: Implement aggregate persistence, history, search, and merge

**Files:**
- Modify: `Goosegrass/Infrastructure/Persistence/LocalCustomerRepository.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Modify: `GoosegrassTests/PersistenceRepositoryTests.swift`

- [ ] Add failing repository tests proving search matches notes, source name, tag name, and phone tail; source seeding is idempotent; activities are newest first; tags deduplicate case-insensitively.
- [ ] Add a failing merge test that creates both customers with appointments, activities, follow-ups, and overlapping tags, then requires every relationship to point at the retained customer, the duplicate to be archived, and one `customerMerged` activity to exist.
- [ ] Implement read-model assembly from the injected `ModelContext`, resolving source, tags, next active appointment, and activities without creating a container.
- [ ] Seed exactly `小红书`, `抖音`, `大众点评`, `微信`, `电话`, `朋友介绍`, `线下`, and `其他`, preserving existing records.
- [ ] Implement merge as one mutation/save operation. Move relationships, union tags by ID, update durable foreign-key UUIDs, archive the duplicate, and insert the merge activity before saving.
- [ ] Run all persistence tests and require GREEN; run the complete test target to detect regressions.
- [ ] Commit with `feat(customers): add customer aggregate persistence`.

### Task 4: Add validated editor drafts and lifecycle service behavior

**Files:**
- Create: `Goosegrass/Features/Customers/CustomerEditorDraft.swift`
- Modify: `Goosegrass/Application/Services/CustomerService.swift`
- Modify: `GoosegrassTests/CustomerServiceTests.swift`

- [ ] Write failing tests for trimmed required name, phone normalization, invalid empty phone, create activity, edit preservation of immutable identity/created date, note activity, duplicate warning, explicit create-anyway, and archive.
- [ ] Implement:

```swift
struct CustomerEditorDraft: Equatable {
    var displayName = ""
    var legalName = ""
    var phone = ""
    var email = ""
    var sourceID: UUID?
    var status: CustomerStatus = .new
    var notes = ""
    var tagIDs: Set<UUID> = []

    func makeCustomer(existing: Customer? = nil, now: Date = Date()) throws -> Customer
}

enum CustomerSubmissionResult: Equatable {
    case saved(Customer)
    case possibleDuplicates(draft: CustomerEditorDraft, candidates: [Customer])
}
```

- [ ] Make service create/update/note/archive operations write their required activities and reload authoritative persisted values.
- [ ] Run focused and full XCTest; require GREEN.
- [ ] Commit with `feat(customers): add validated customer lifecycle`.

### Task 5: Build a testable Customers ViewModel

**Files:**
- Create: `Goosegrass/Features/Customers/CustomerListViewModel.swift`
- Create: `GoosegrassTests/CustomerListViewModelTests.swift`

- [ ] Write failing tests for initial load, debounced/manual query refresh, selection/detail loading, add/edit sheet state, duplicate-warning routing, use-existing, create-anyway, merge, archive confirmation, and preserving drafts after errors.
- [ ] Implement a `@MainActor final class CustomerListViewModel: ObservableObject` with published rows, detail, query, selection, editor, duplicate candidates, archive target, catalog, and alert error.
- [ ] Inject `CustomerService` and a `now` closure. Do not import SwiftData or construct persistence objects.
- [ ] Ensure every successful mutation refreshes rows/detail and every failure preserves the relevant user input.
- [ ] Run focused and full XCTest; require GREEN.
- [ ] Commit with `feat(customers): add customer feature state`.

### Task 6: Implement the native Customers interface

**Files:**
- Create: `Goosegrass/Features/Customers/CustomersView.swift`
- Create: `Goosegrass/Features/Customers/CustomerEditorView.swift`
- Create: `Goosegrass/Features/Customers/CustomerDetailView.swift`
- Create: `Goosegrass/Features/Customers/DuplicateCustomerView.swift`
- Create: `Goosegrass/Shared/Components/EmptyStateView.swift`
- Modify: `Goosegrass/App/ContentView.swift`
- Modify: `Goosegrass/App/GoosegrassApp.swift`
- Create: `GoosegrassTests/CustomerFeatureCompositionTests.swift`

- [ ] Write a failing composition test proving app construction reuses `PersistenceController.context` and the Customers feature can load through the injected service.
- [ ] Replace the Phase 0 placeholder with a `NavigationSplitView` using the Master Spec destinations and a functional Customers route.
- [ ] Build a searchable customer table/list, selection-driven detail, toolbar Add/Edit/Archive commands, form validation, duplicate sheet with all three choices, and archive confirmation.
- [ ] Build a reverse-chronological timeline and clear empty/loading/error states. Add accessibility labels, help text, focus order, `Command-N`, Return, and Escape behavior where SwiftUI supports it.
- [ ] Keep future destination rows as clearly labeled placeholders without speculative services or containers.
- [ ] Run the complete XCTest target in macOS CI and require GREEN.
- [ ] Commit with `feat(customers): build customer workspace`.

### Task 7: Prove the Phase 2 relaunch acceptance chain

**Files:**
- Create: `GoosegrassTests/CustomerAcceptanceTests.swift`

- [ ] Write a disk-backed test that executes `Create → close container → reopen → Search → Edit → Archive`, asserting the same UUID survives and the default list becomes empty only after archive.
- [ ] Run the new test before any corrective code and confirm RED if the chain exposes a defect; fix only through a minimal tested change.
- [ ] Run all tests and `pwsh -NoProfile -File scripts/validate-phase2.ps1`; require GREEN/PASS.
- [ ] Commit with `test(customers): prove relaunch acceptance chain`.

### Task 8: Wire Xcode, document evidence, and finish the branch

**Files:**
- Modify: `Goosegrass.xcodeproj/project.pbxproj`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/DATA_MODEL.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/superpowers/plans/2026-09-14-phase-2-customers.md`

- [ ] Add every Phase 2 source and test to the correct Xcode Sources build phase.
- [ ] Update architecture, data model, testing, README, and changelog with exact implemented behavior and evidence IDs.
- [ ] Explicitly mark real Mac UI appearance, keyboard, focus, VoiceOver, and notification delivery as **Not Verified**; keep Team ID/signing/provisioning unset.
- [ ] Run `git diff --check` and `pwsh -NoProfile -File scripts/validate-phase2.ps1` from a clean candidate tree.
- [ ] Push `feature/phase-2-customers`, require macOS push CI Build/Test PASS, open a PR, and require PR CI Build/Test PASS.
- [ ] Merge only when PR checks pass and the PR is conflict-free; require post-merge `main` CI PASS before branch/worktree cleanup.
