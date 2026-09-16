# Changelog

All notable project changes are documented here.

## Phase 6 — Follow-up workflows

- Added pure calendar-aware FollowUp scheduling and lifecycle validation without adding a timer or changing Schema V2.
- Added the durable FollowUp repository/service with active/all scopes, deterministic ordering, atomic timeline activities, and authoritative rereads.
- Added a native Follow-up workspace for manual create, inspect, complete, snooze, cancel, and retained terminal history.
- Connected successful no-show transitions in Appointments and Today to transient Tomorrow 11:00, Custom, or Skip recovery flows using one shared service.
- Added disk-backed two-relaunch acceptance coverage for no-show recovery, completion, reminder cancellation, complete appointment/customer history, and manual snooze/cancel persistence.
- Passed Windows Phase 0–6 static validation and macOS Build/XCTest run `35066929093`; real Mac UI/accessibility and release operations remain Not Verified.

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
- Persistent Customers workspace with searchable list, detail and activity timeline, add/edit/archive flows, source/tag choices, and duplicate review with use-existing/create-anyway/merge decisions.
- Customer aggregate repository behavior for expanded search, source seeding, tag deduplication, relationship-preserving merge, and reverse-chronological history.
- Customer service, ViewModel, composition, and disk-backed relaunch acceptance tests plus the Windows Phase 2 static validation gate.
- Schema V2 with durable appointment-change records and a tested V1 lightweight migration.
- Explicit appointment lifecycle policy, aggregate repository/service boundary, filters, histories, observable feature state, and native Appointments workspace.
- Disk-backed acceptance for complete, cancel, reschedule/reconfirm, and no-show lifecycle paths.
- Default Today workspace with four summary cards, a complete same-day appointment list, Need Contact queue, Phase 3 inspector reuse, and lifecycle-derived quick actions.
- Runtime Upcoming Arrivals aggregation for future confirmed/upcoming appointments, card/list semantic separation, authoritative post-action refresh, and two-relaunch disk acceptance without a schema change.
- Calendar-aware default reminders, durable Reminder repository behavior, permission/settings UI, UserNotifications adapter, appointment lifecycle scheduling, and launch reconciliation without a schema change.

### Verification

- Xcode project parsing, macOS build, and XCTest: passed in GitHub Actions on 2026-09-13.
- macOS UI, notifications, permissions, signing, and packaging: **Not Verified**.
- Windows Phase 0 static validation: passed on 2026-09-13.
- Windows Phase 1 static validation: passed on 2026-09-13.
- Phase 1 macOS build and SwiftData XCTest: passed in GitHub Actions push run `34855677073` on 2026-09-14.
- Customer source identity and shared-main-context regressions have macOS CI RED/GREEN evidence.
- Phase 1 pull-request CI: passed in GitHub Actions run `34857548677` for PR #2 on 2026-09-14.
- Windows Phase 2 static validation: passed on 2026-09-15.
- Phase 2 disk-backed customer acceptance chain: passed in GitHub Actions push run `34940016333` on 2026-09-15.
- Phase 2 latest source candidate build and full XCTest target: passed in GitHub Actions push run `34940456953` on 2026-09-15, with no Swift compiler warnings.
- Phase 2 pull-request CI: passed in GitHub Actions run `34941002213` for PR #3 on 2026-09-15.
- Phase 2 post-merge main CI: passed in GitHub Actions run `34941490470` on 2026-09-15.
- Windows Phase 3 static validation: passed on 2026-09-15.
- Phase 3 Schema V2 migration, workspace, and lifecycle acceptance passed in macOS runs `34944143389`, `34947553894`, and `34947854294`.
- Phase 3 PR #4 and post-merge main CI passed in runs `34948458801` and `34948667447`.
- Windows Phase 4 static validation passed on 2026-09-15.
- Phase 4 aggregation, ViewModel, workspace, disk-relaunch acceptance, and documented source candidate passed in macOS runs `34984242542`, `34985334535`, `34986213102`, `34986598003`, and `34987024444`.
- Phase 4 PR #5 and post-merge main CI passed in `34987583693` and `34987950782`.
- Windows Phase 5 static validation passed on 2026-09-16.
- Phase 5 calculator, persistence, adapter, service, integration, settings, and disk acceptance passed in macOS runs `34989539790`, `34990280651`, `34991319616`, `34995287430`, `34995913095`, `35044468228`, and `35044707134`.
- Real Mac Customers UI appearance, keyboard navigation, focus behavior, and VoiceOver: **Not Verified**.
- Apple Developer Team, signing, provisioning, notarization, and packaging: **Not Verified**.
