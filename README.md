# Goosegrass

Goosegrass is a local-first, single-user macOS workspace for customer leads, appointments, reminders, follow-up, and durable customer history.

## Technology

- Swift and SwiftUI
- SwiftData (persistence begins in Phase 1)
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
pwsh -NoProfile -File scripts/validate-phase0.ps1
```

This checks repository shape and configuration only. It does not compile Swift or parse the Xcode project.

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
| Xcode project parse | Passed in GitHub Actions on 2026-09-13 |
| macOS build | Passed in GitHub Actions on 2026-09-13 |
| macOS unit tests | Passed in GitHub Actions on 2026-09-13 |
| macOS UI and manual QA | Not Verified |
| Notifications and permissions | Not Verified |
| Signing and packaging | Not Verified |

The Phase 0 pull-request workflow completed its Xcode build and XCTest steps successfully. Interactive UX, notification, permission, signing, and packaging validation still require a real Mac.
