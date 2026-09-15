# Goosegrass

Goosegrass is a local-first, single-user macOS workspace for customer leads, appointments, reminders, follow-up, and durable customer history.

## Technology

- Swift and SwiftUI
- SwiftData with a versioned local schema
- UserNotifications (notification integration begins in Phase 5)
- Native macOS application, minimum deployment target macOS 14
- Application bundle identifier: `com.gravityedge.goosegrass`

No Apple Development Team, signing identity, or provisioning profile is configured. Those values require a real Mac and user-provided Apple credentials.

## Repository map

- [`docs/GOOSEGRASS_MASTER_SPEC.md`](docs/GOOSEGRASS_MASTER_SPEC.md) — authoritative product and engineering baseline
- [`docs/PRODUCT.md`](docs/PRODUCT.md) — product scope and success criteria
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — layers and dependency rules
- [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) — Phase 0 domain model contract
- [`docs/UX.md`](docs/UX.md) — information architecture and UX principles
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — phase sequence
- [`docs/TESTING.md`](docs/TESTING.md) — verification strategy and current evidence
- [`docs/WINDOWS_MACOS_WORKFLOW.md`](docs/WINDOWS_MACOS_WORKFLOW.md) — host-specific workflow
- [`docs/CODING_CONVENTIONS.md`](docs/CODING_CONVENTIONS.md) — Swift and repository conventions
- [`docs/CHANGELOG.md`](docs/CHANGELOG.md) — project changes

## Windows validation

```powershell
pwsh -NoProfile -File scripts/validate-phase4.ps1
```

This preserves earlier gates and checks the Phase 4 Today source/test inventory, feature boundaries, unchanged Schema V2, documentation, and Xcode target membership. It does not compile Swift or execute SwiftData.

## macOS build and test

```bash
xcodebuild build \
  -project Goosegrass.xcodeproj \
  -scheme Goosegrass \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project Goosegrass.xcodeproj \
  -scheme Goosegrass \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

## Verification status

| Gate | Status |
| --- | --- |
| Windows repository validation | Passed on 2026-09-13 |
| Phase 0 Xcode project parse | Passed in GitHub Actions on 2026-09-13 |
| Phase 0 macOS build | Passed in GitHub Actions on 2026-09-13 |
| Phase 0 macOS unit tests | Passed in GitHub Actions on 2026-09-13 |
| Phase 1 macOS build and SwiftData tests | Passed in GitHub Actions push run `34855677073` and PR run `34857548677` on 2026-09-14 |
| Phase 2 macOS build and customer tests | Disk-relaunch acceptance passed in push run `34940016333`; latest source candidate passed in push run `34940456953`; PR run `34941002213` passed on 2026-09-15 |
| Phase 3 macOS build and appointment tests | Schema migration passed in `34944143389`; workspace passed in `34947553894`; disk lifecycle acceptance passed in `34947854294` on 2026-09-15 |
| Phase 3 PR and post-merge verification | PR #4 passed in `34948458801`; merged `main` passed in `34948667447` on 2026-09-15 |
| Phase 4 macOS build and Today tests | Aggregation passed in `34984242542`; ViewModel in `34985334535`; workspace in `34986213102`; disk-relaunch acceptance in `34986598003`; documented source candidate in `34987024444` on 2026-09-15 |
| Real Mac UI, keyboard, focus, and VoiceOver QA | Not Verified |
| Notifications and permissions | Not Verified |
| Signing and packaging | Not Verified |

Phase 4 now provides the default Today workspace, runtime-only upcoming-arrival aggregation, complete same-day history, quick actions with authoritative reloads, and disk-backed relaunch acceptance. Interactive UX, notification, permission, signing, and packaging validation still require a real Mac.
