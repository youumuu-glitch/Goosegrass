# Phase 6 Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the durable no-show follow-up loop and a complete local Follow-up workspace.

**Architecture:** Add a pure follow-up schedule/lifecycle rule, a repository over the existing V1 record, and a service that atomically writes follow-ups with timeline activities. Inject one FollowUpService into Follow-up, Appointments, and Today; UI prompts are transient and appear only after a successful no-show transition.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, XCTest, PowerShell, GitHub Actions macOS runner.

---

### Task 1: Add the Phase 6 gate and project scaffold

**Files:**
- Create: `scripts/validate-phase6.ps1`
- Modify: `.github/workflows/macos-build.yml`
- Modify: `Goosegrass.xcodeproj/project.pbxproj`
- Create: `GoosegrassTests/FollowUpScheduleTests.swift`
- Create: `GoosegrassTests/FollowUpRepositoryTests.swift`
- Create: `GoosegrassTests/FollowUpServiceTests.swift`
- Create: `GoosegrassTests/FollowUpViewModelTests.swift`
- Create: `GoosegrassTests/FollowUpFeatureCompositionTests.swift`
- Create: `GoosegrassTests/FollowUpAcceptanceTests.swift`

- [ ] Write `validate-phase6.ps1` so it invokes Phase 5, asserts all planned production/test files and Xcode memberships, keeps Schema V2 at `2.0.0`, rejects SwiftData outside Infrastructure, and records Phase 6 real-Mac checks as Not Verified.
- [ ] Run `./scripts/validate-phase6.ps1`; expect RED because Phase 6 files are absent.
- [ ] Add empty compilable source/test scaffolds and explicit PBX file/build references; update CI to invoke Phase 6.
- [ ] Run the gate again; expect `Phase 6 validation passed.`
- [ ] Commit with `chore(follow-up): scaffold Phase 6 verification` and require macOS Build/XCTest GREEN.

### Task 2: Implement pure schedule and lifecycle rules

**Files:**
- Create: `Goosegrass/Domain/Rules/FollowUpSchedule.swift`
- Create: `Goosegrass/Domain/Rules/FollowUpLifecycle.swift`
- Modify: `GoosegrassTests/FollowUpScheduleTests.swift`

- [ ] Add failing XCTest cases proving local tomorrow 11:00 across a DST boundary, allowed pending/snoozed transitions, terminal immutability, trimmed non-empty reason, and future create/snooze due dates.
- [ ] Push the RED test-only commit and require macOS XCTest to fail for missing `FollowUpSchedule`/`FollowUpLifecycle` symbols.
- [ ] Implement the minimal Foundation-only rules with injected `Calendar` and explicit typed validation errors.
- [ ] Run the Windows gate, commit `feat(follow-up): add schedule and lifecycle rules`, push, and require macOS GREEN.

### Task 3: Add the durable FollowUp repository

**Files:**
- Create: `Goosegrass/Application/DTO/FollowUpPresentation.swift`
- Create: `Goosegrass/Application/Repositories/FollowUpRepository.swift`
- Create: `Goosegrass/Infrastructure/Persistence/LocalFollowUpRepository.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Modify: `GoosegrassTests/FollowUpRepositoryTests.swift`

- [ ] Add failing tests for create/update/fetch, customer and appointment relationships, mismatched appointment rejection, atomic activities, active/all filtering, deterministic sorting, invalid enum raw values, and disk reopen.
- [ ] Push RED and require macOS XCTest failure.
- [ ] Implement `FollowUpListFilter`, `FollowUpListItem`, `FollowUpDetail`, `FollowUpMutation`, mapper functions, repository protocol/defaults, local repository, and controller factory. Reuse `PersistenceSchemaV1.FollowUpRecord`; do not edit either schema.
- [ ] Run the Windows gate, commit `feat(follow-up): add durable repository`, push, and require macOS GREEN.

### Task 4: Implement FollowUpService lifecycle

**Files:**
- Create: `Goosegrass/Application/Services/FollowUpService.swift`
- Modify: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Modify: `GoosegrassTests/FollowUpServiceTests.swift`

- [ ] Add failing tests for manual and appointment-linked creation, default no-show reason/priority, complete Activity, snooze, cancel, terminal transition rejection, future-date validation, and atomic failure behavior.
- [ ] Push RED and require macOS XCTest failure.
- [ ] Implement create/list/detail/complete/snooze/cancel. Generate `followUpCreated` and `followUpCompleted` activities inside repository mutations and always return authoritative rereads.
- [ ] Run the gate, commit `feat(follow-up): add lifecycle service`, push, and require macOS GREEN.

### Task 5: Build the Follow-up workspace

**Files:**
- Create: `Goosegrass/Features/FollowUp/FollowUpEditorDraft.swift`
- Create: `Goosegrass/Features/FollowUp/FollowUpListViewModel.swift`
- Create: `Goosegrass/Features/FollowUp/FollowUpEditorView.swift`
- Create: `Goosegrass/Features/FollowUp/FollowUpDetailView.swift`
- Create: `Goosegrass/Features/FollowUp/FollowUpView.swift`
- Modify: `Goosegrass/App/ContentView.swift`
- Modify: `Goosegrass/App/GoosegrassApp.swift`
- Modify: `GoosegrassTests/FollowUpViewModelTests.swift`
- Modify: `GoosegrassTests/FollowUpFeatureCompositionTests.swift`

- [ ] Add failing tests for default active filtering, all-history filtering, due sorting, selection/detail refresh, create editor validation, complete/snooze/cancel reload, and app composition.
- [ ] Push RED and require macOS XCTest failure.
- [ ] Implement the observable ViewModel, native split workspace, editor, inspector, keyboard/help/accessibility labels, and shared app composition. Keep overdue as a runtime presentation state.
- [ ] Run the gate, commit `feat(follow-up): build follow-up workspace`, push, and require macOS GREEN.

### Task 6: Integrate no-show prompts in Appointments and Today

**Files:**
- Create: `Goosegrass/Application/DTO/NoShowFollowUpRequest.swift`
- Modify: `Goosegrass/Features/Appointments/AppointmentListViewModel.swift`
- Modify: `Goosegrass/Features/Appointments/AppointmentsView.swift`
- Modify: `Goosegrass/Features/Today/TodayViewModel.swift`
- Modify: `Goosegrass/Features/Today/TodayView.swift`
- Modify: `Goosegrass/App/ContentView.swift`
- Modify: `GoosegrassTests/FollowUpViewModelTests.swift`
- Modify: `GoosegrassTests/FollowUpFeatureCompositionTests.swift`

- [ ] Add failing tests proving the prompt appears only after successful `.markNoShow`, never on failure/reload, Tomorrow creates exactly one linked normal-priority follow-up at local 11:00, Custom pre-fills the editor, Skip writes nothing, and both entry points use the same service.
- [ ] Push RED and require macOS XCTest failure.
- [ ] Implement transient request state and Tomorrow/Custom/Skip UI flows. Preserve AppointmentService as the owner of status, timestamp, appointment Activity, and reminder cancellation.
- [ ] Run the gate, commit `feat(follow-up): connect no-show recovery`, push, and require macOS GREEN.

### Task 7: Prove disk-backed acceptance and finish Phase 6

**Files:**
- Modify: `GoosegrassTests/FollowUpAcceptanceTests.swift`
- Modify: `README.md`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/DATA_MODEL.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/ROADMAP.md`
- Modify: `docs/superpowers/plans/2026-09-16-phase-6-follow-up.md`

- [ ] Add the disk-backed chain `No Show → Tomorrow 11:00 → close/reopen → active queue → Complete → close/reopen` and assert appointment, all Activities, reminder cancellation state, follow-up linkage, terminal timestamps, and absence of duplicate follow-ups.
- [ ] Add manual creation/snooze/cancel persistence coverage and prove no schema version change.
- [ ] Update documentation and mark real Mac dialog/sheet/keyboard/focus/VoiceOver plus signing/provisioning/notarization as Not Verified.
- [ ] Run `validate-phase6.ps1`, inspect the branch diff, commit `docs: record Phase 6 verification evidence`, and push the exact candidate SHA.
- [ ] Require macOS Build/XCTest GREEN on push and PR, verify a clean/conflict-free PR, merge to main, require post-merge main CI GREEN, safely remove the feature worktree/branches, and begin Phase 7.
