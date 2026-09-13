# Goosegrass Phase 0 Repository & Architecture Design

**Date:** 2026-09-13  
**Status:** Approved  
**Scope:** Phase 0 only

## Purpose

Establish a maintainable repository and native macOS application foundation for Goosegrass without implementing business UI or persistence behavior prematurely.

The project remains fixed to Swift, SwiftUI, SwiftData, UserNotifications, native macOS, local-first operation, and single-user V1 scope. Development occurs on Windows, while compilation and macOS behavior require evidence from GitHub Actions on a macOS runner or a real Mac.

## Repository

- Initialize Git with `main` as the initial branch.
- Preserve the supplied source specification and copy it to `docs/GOOSEGRASS_MASTER_SPEC.md` as the repository execution baseline.
- Add focused product, architecture, data-model, testing, workflow, roadmap, coding-convention, and changelog documents.
- Ignore generated build products, Xcode user state, macOS metadata, and local secrets.

## Xcode Project

- Commit a standard `Goosegrass.xcodeproj`; do not introduce XcodeGen, Tuist, or another project-generation dependency.
- Create two targets:
  - `Goosegrass`: native macOS application.
  - `GoosegrassTests`: XCTest unit-test bundle.
- Set the minimum deployment target to macOS 14 because SwiftData is a foundational V1 technology.
- Use the approved application bundle identifier `com.gravityedge.goosegrass`.

## Identity and Signing

- The application bundle identifier is exactly `com.gravityedge.goosegrass`.
- No Apple Development Team, signing certificate, provisioning profile, or distribution identity is configured in Phase 0.
- CI disables code signing for build and unit-test gates.
- Signing and packaging remain deferred until a real Mac and Apple credentials are available.

## Source Architecture

The application source is organized by stable responsibility:

```text
Goosegrass/
├── App/
├── Domain/
│   ├── Enums/
│   ├── Models/
│   └── Rules/
├── Application/
│   ├── DTO/
│   ├── Services/
│   └── UseCases/
├── Infrastructure/
│   ├── Backup/
│   ├── Export/
│   ├── Import/
│   ├── Notifications/
│   └── Persistence/
├── Features/
│   ├── Appointments/
│   ├── Calendar/
│   ├── Customers/
│   ├── FollowUp/
│   ├── History/
│   ├── Inbox/
│   ├── Settings/
│   └── Today/
└── Shared/
    ├── Components/
    ├── DesignSystem/
    ├── Extensions/
    └── Utilities/
```

Phase 0 creates the boundaries and minimal application entry point. Empty directories are represented with short README files only where their responsibility is otherwise unclear.

## Domain Foundation

Phase 0 defines:

- `CustomerStatus`
- `AppointmentStatus`
- `FollowUpStatus`
- `AppointmentChangeType`
- `ReminderType`
- `ReminderStatus`
- `ActivityType`
- initial value-oriented definitions for Customer, Appointment, AppointmentChange, Reminder, FollowUp, Activity, LeadSource, Tag, ImportBatch, and AppSettings
- pure domain validation and phone-normalization rules

These definitions remain independent of SwiftData annotations. Phase 1 owns SwiftData schema versioning, `@Model` persistence entities, repositories, container lifecycle, migrations, and CRUD/relationship tests. This preserves the boundary between architectural modeling and persistence implementation.

All primary identifiers use UUID. Business dates use `Date`. Naming follows the master specification (`createdAt`, `updatedAt`, `startAt`, `endAt`, and related names). Customer requests and internal notes remain separate.

## Application Shell

The app target contains only a minimal SwiftUI entry point and an informational root view. It proves target wiring without implementing navigation, visual design, persistence, reminders, or business workflows.

## Tests

The Phase 0 XCTest suite covers pure, deterministic rules:

- domain enum raw-value stability
- phone normalization
- appointment validation, including party size and required customer identity
- initial model construction and invariant defaults where useful

No test claims SwiftData persistence, notification delivery, or UI behavior.

## CI Build Gate

GitHub Actions runs on pushes and pull requests using a supported macOS runner. It executes explicit `xcodebuild` build and test commands against the committed shared scheme with code signing disabled.

Until an actual workflow run produces logs:

- macOS build: **Not Verified**
- macOS unit tests: **Not Verified**
- Xcode project parsing: **Not Verified**
- UI, notifications, permissions, signing, and packaging: **Not Verified**

Windows checks may validate repository structure, text consistency, JSON/plist syntax where applicable, and absence of signing credentials, but they are not substitutes for the macOS gate.

## Error and Safety Boundaries

- The minimal application shell does not create or mutate customer data.
- No credentials, tokens, customer PII, or final Apple signing values are stored.
- Release builds never seed demo data in Phase 0.
- Logs must not contain full phone numbers, notes, or customer details.

## Phase 0 Acceptance

Phase 0 is complete when:

- the repository and documentation are coherent;
- Git history contains clear checkpoints;
- the standard macOS project, application target, test target, and shared scheme exist;
- the directory boundaries, conventions, domain enums, and initial model definitions exist;
- the macOS CI workflow can be triggered after the repository is pushed to GitHub;
- all checks available on Windows pass;
- every macOS-only result without evidence is reported as **Not Verified**.

Phase 0 does not include SwiftData persistence, production UI, notifications, import, backup, search, or other later-phase behavior.
