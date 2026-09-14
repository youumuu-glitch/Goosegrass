# Changelog

All notable project changes are documented here.

## Unreleased

### Added

- Approved Phase 0 repository and architecture design.
- Phase 0 implementation plan.
- Repository guidance and focused product/engineering documentation.
- Native macOS application and XCTest target scaffold.
- Foundation-only domain states, initial models, normalization, and validation rules.
- GitHub Actions macOS build and test gate.
- Versioned SwiftData V1 schema for Customer, Appointment, Activity, FollowUp, LeadSource, Tag, and Reminder.
- Local Customer and Appointment repositories with domain/persistence mapping and application service boundaries.
- A single application-owned persistence controller plus in-memory and explicit disk-store test configurations.
- Phase 1 repository, relationship, and relaunch-persistence XCTest coverage.
- Windows Phase 1 static validation gate.

### Verification

- Xcode project parsing, macOS build, and XCTest: passed in GitHub Actions on 2026-09-13.
- macOS UI, notifications, permissions, signing, and packaging: **Not Verified**.
- Windows Phase 0 static validation: passed on 2026-09-13.
- Windows Phase 1 static validation: passed on 2026-09-13.
- Phase 1 macOS build and SwiftData XCTest: passed in GitHub Actions push run `34855354576` on 2026-09-14.
- Customer source identity and shared-main-context regressions have macOS CI RED/GREEN evidence.
- Phase 1 pull-request CI: **Not Verified** pending PR creation.
