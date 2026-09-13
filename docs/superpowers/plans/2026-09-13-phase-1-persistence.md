# Phase 1 Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a versioned SwiftData persistence foundation with durable Customer and Appointment CRUD, explicit relationships, and one application-owned model container.

**Architecture:** Keep Foundation domain values independent from persistence. Put `@Model` records, schema versions, migrations, mapping, and local repositories in Infrastructure; expose repository protocols and thin services from Application. Compose exactly one persistent `ModelContainer` in the app and inject it into SwiftUI.

**Tech Stack:** Swift 5, SwiftData on macOS 14+, SwiftUI, XCTest, PowerShell static validation, GitHub Actions macOS runner.

---

### Task 1: Add Phase 1 validation gates

- [ ] Add `scripts/validate-phase1.ps1` that invokes Phase 0 validation and requires all Phase 1 source/test files, imports, schema declarations, migrations, app container injection, and Xcode target membership.
- [ ] Run `pwsh -NoProfile -File scripts/validate-phase1.ps1` and confirm it fails because persistence files are absent.

### Task 2: Define the versioned SwiftData schema

**Files:**
- Create: `Goosegrass/Infrastructure/Persistence/PersistenceSchemaV1.swift`
- Create: `Goosegrass/Infrastructure/Persistence/GoosegrassMigrationPlan.swift`
- Create: `Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift`
- Test: `GoosegrassTests/PersistenceSchemaTests.swift`

- [ ] Write schema tests first for the seven required model types and Customer-to-Appointment inverse relationship.
- [ ] Implement `PersistenceSchemaV1` with Customer, Appointment, Activity, FollowUp, LeadSource, Tag, and Reminder records. Store enum values as stable raw strings and preserve UUID/Date business fields.
- [ ] Use nullifying inverse relationships where deleting a parent must not silently cascade business history; repositories perform explicit archive/cancel semantics.
- [ ] Add `GoosegrassMigrationPlan` with V1 as the only current schema and no migration stages.
- [ ] Add bidirectional mapping between Customer/Appointment records and domain values.

### Task 3: Add repository contracts and local SwiftData repositories

**Files:**
- Create: `Goosegrass/Application/Repositories/CustomerRepository.swift`
- Create: `Goosegrass/Application/Repositories/AppointmentRepository.swift`
- Create: `Goosegrass/Infrastructure/Persistence/LocalCustomerRepository.swift`
- Create: `Goosegrass/Infrastructure/Persistence/LocalAppointmentRepository.swift`
- Test: `GoosegrassTests/PersistenceRepositoryTests.swift`

- [ ] Write failing macOS tests for Customer CRUD/search/archive and Appointment CRUD.
- [ ] Write a failing relationship test proving a fetched appointment resolves its customer and the customer lists that appointment.
- [ ] Implement local repositories around an injected `ModelContext`; never construct a container inside a repository.
- [ ] Keep duplicate normalized phone numbers legal and return them as candidates rather than silently merging.

### Task 4: Add persistence lifecycle and application services

**Files:**
- Create: `Goosegrass/Infrastructure/Persistence/PersistenceController.swift`
- Create: `Goosegrass/Application/Services/CustomerService.swift`
- Create: `Goosegrass/Application/Services/AppointmentService.swift`
- Modify: `Goosegrass/App/GoosegrassApp.swift`
- Test: `GoosegrassTests/PersistenceLifecycleTests.swift`

- [ ] Write a failing disk-reopen test that creates data, releases its context/container, reopens the same store URL, and fetches the same UUID and relationship.
- [ ] Write a lifecycle test proving repository/service composition reuses one injected container rather than initializing hidden containers.
- [ ] Implement `PersistenceController` as the app composition owner with production and in-memory test factories.
- [ ] Implement thin Customer and Appointment services that depend only on repository protocols.
- [ ] Inject the controller's container once with SwiftUI `.modelContainer`.

### Task 5: Wire Xcode, documentation, and verification

**Files:**
- Modify: `Goosegrass.xcodeproj/project.pbxproj`
- Modify: `docs/ARCHITECTURE.md`
- Modify: `docs/DATA_MODEL.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `README.md`

- [ ] Add every Phase 1 source and test to the correct Xcode build phase.
- [ ] Run `pwsh -NoProfile -File scripts/validate-phase1.ps1` and require PASS.
- [ ] Commit and push `feature/phase-1-persistence`.
- [ ] Open a PR to `main`; require macOS `xcodebuild build` and `xcodebuild test` PASS.
- [ ] Fix CI failures using evidence from logs, then merge only when all checks pass.
- [ ] Mark real interactive Mac validation as **Not Verified**; Phase 1 does not claim signing or release validation.
