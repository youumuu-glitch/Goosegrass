# Goosegrass Phase 0 Repository & Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a documented Git repository, a minimal native macOS SwiftUI/Xcode scaffold, pure domain foundations, unit-test structure, and a triggerable macOS CI build gate without claiming unverified Mac results.

**Architecture:** A standard Xcode project contains a thin SwiftUI application shell and a pure Foundation-based domain layer. Presentation, application, infrastructure, feature, and shared boundaries are documented now; SwiftData persistence implementations remain deferred to Phase 1. XCTest exercises deterministic domain rules, while GitHub Actions provides the authoritative macOS build/test gate.

**Tech Stack:** Swift 5, SwiftUI, Foundation, XCTest, Xcode project format, GitHub Actions, PowerShell static validation on Windows.

---

### Task 1: Repository baseline and documentation structure

**Files:**
- Create: `.gitignore`
- Create: `README.md`
- Create: `docs/GOOSEGRASS_MASTER_SPEC.md`
- Create: `docs/PRODUCT.md`
- Create: `docs/ARCHITECTURE.md`
- Create: `docs/DATA_MODEL.md`
- Create: `docs/UX.md`
- Create: `docs/ROADMAP.md`
- Create: `docs/TESTING.md`
- Create: `docs/WINDOWS_MACOS_WORKFLOW.md`
- Create: `docs/CODING_CONVENTIONS.md`
- Create: `docs/CHANGELOG.md`
- Create: `scripts/validate-phase0.ps1`

- [ ] **Step 1: Write the failing repository validation script**

Create a PowerShell script that requires the agreed repository files, verifies `docs/GOOSEGRASS_MASTER_SPEC.md` is byte-identical to the supplied master specification, requires the approved bundle ID in the Xcode project, rejects `DEVELOPMENT_TEAM`, and checks the shared scheme and CI workflow exist. The script exits non-zero with a list of failures and prints `Phase 0 static validation passed.` on success.

- [ ] **Step 2: Run the validator to confirm the baseline fails**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: non-zero exit with missing-file failures.

- [ ] **Step 3: Add repository and documentation files**

Copy the source specification without editing it:

```powershell
Copy-Item -LiteralPath Goosegrass_Product_Architecture_and_Codex_Execution_Spec.md -Destination docs/GOOSEGRASS_MASTER_SPEC.md
```

Document these exact decisions across the focused documents:

```text
Product: local-first, single-user macOS customer appointment workspace
Technology: Swift + SwiftUI + SwiftData + UserNotifications
Minimum deployment: macOS 14
Bundle ID: com.gravityedge.goosegrass
Signing: intentionally unconfigured
Architecture: UI -> ViewModel -> Service -> Repository -> SwiftData
Phase 0 persistence status: not implemented
macOS build status until evidence exists: Not Verified
```

The root README links to every focused document, provides the Phase 0 Windows validation command, the macOS `xcodebuild` commands, and a current verification-status table.

- [ ] **Step 4: Add repository ignore rules**

Use these categories:

```gitignore
.DS_Store
DerivedData/
build/
*.xcuserstate
xcuserdata/
*.xccheckout
*.xcscmblueprint
.swiftpm/
.build/
.env
.env.*
!.env.example
```

- [ ] **Step 5: Commit the documentation baseline**

```powershell
git add .gitignore README.md docs scripts/validate-phase0.ps1
git commit -m "docs: establish repository guidance"
```

### Task 2: Minimal macOS application and Xcode target scaffold

**Files:**
- Create: `Goosegrass/App/GoosegrassApp.swift`
- Create: `Goosegrass/App/ContentView.swift`
- Create: `Goosegrass/Assets.xcassets/Contents.json`
- Create: `Goosegrass/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `Goosegrass/Preview Content/Preview Assets.xcassets/Contents.json`
- Create: `Goosegrass.xcodeproj/project.pbxproj`
- Create: `Goosegrass.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `Goosegrass.xcodeproj/xcshareddata/xcschemes/Goosegrass.xcscheme`
- Create: architecture boundary README files under `Goosegrass/Application`, `Goosegrass/Infrastructure`, `Goosegrass/Features`, and `Goosegrass/Shared`

- [ ] **Step 1: Extend static validation for Xcode settings**

Require these project settings and reject any development-team assignment:

```text
MACOSX_DEPLOYMENT_TARGET = 14.0;
PRODUCT_BUNDLE_IDENTIFIER = com.gravityedge.goosegrass;
PRODUCT_BUNDLE_IDENTIFIER = com.gravityedge.goosegrassTests;
CODE_SIGN_STYLE = Automatic;
GENERATE_INFOPLIST_FILE = YES;
SWIFT_VERSION = 5.0;
```

- [ ] **Step 2: Run validation and confirm it fails for the missing scaffold**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: non-zero exit naming the missing project and source files.

- [ ] **Step 3: Create the minimal SwiftUI shell**

```swift
import SwiftUI

@main
struct GoosegrassApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 36))
                .accessibilityHidden(true)
            Text("Goosegrass")
                .font(.title)
            Text("Repository and architecture foundation")
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 360)
    }
}
```

- [ ] **Step 4: Create the standard Xcode project**

Create an application target named `Goosegrass`, a unit-test target named `GoosegrassTests`, explicit Sources/Frameworks/Resources build phases, a target dependency from tests to the app, and Debug/Release configurations. Do not add `DEVELOPMENT_TEAM`, provisioning profiles, entitlements, SwiftData containers, package dependencies, or signing identities.

- [ ] **Step 5: Create and inspect the shared scheme**

The scheme must build both targets and run `GoosegrassTests` in the Test action. Confirm it is committed under `xcshareddata`, not user data.

- [ ] **Step 6: Run Windows static validation**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: it may still fail only for domain, test, or CI files from later tasks; Xcode scaffold checks pass.

- [ ] **Step 7: Commit the application scaffold**

```powershell
git add Goosegrass Goosegrass.xcodeproj scripts/validate-phase0.ps1
git commit -m "build: scaffold native macOS targets"
```

### Task 3: Domain enums and initial model definitions

**Files:**
- Create: `Goosegrass/Domain/Enums/DomainEnums.swift`
- Create: `Goosegrass/Domain/Models/DomainModels.swift`
- Create: `GoosegrassTests/DomainModelTests.swift`
- Modify: `Goosegrass.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing enum and model tests**

Tests must assert stable raw values and initial model construction:

```swift
import XCTest
@testable import Goosegrass

final class DomainModelTests: XCTestCase {
    func testAppointmentStatusRawValuesRemainStable() {
        XCTAssertEqual(AppointmentStatus.pendingConfirmation.rawValue, "pendingConfirmation")
        XCTAssertEqual(AppointmentStatus.noShow.rawValue, "noShow")
        XCTAssertEqual(AppointmentStatus.allCases.count, 9)
    }

    func testCustomerKeepsOriginalAndNormalizedPhoneSeparately() {
        let customer = Customer(
            displayName: "王女士",
            phone: "138 0000-8888",
            normalizedPhone: "13800008888"
        )
        XCTAssertEqual(customer.phone, "138 0000-8888")
        XCTAssertEqual(customer.normalizedPhone, "13800008888")
        XCTAssertFalse(customer.isArchived)
    }

    func testAppointmentDefaultsToDraftAndKeepsNotesSeparate() {
        let appointment = Appointment(
            customerID: UUID(),
            startAt: Date(),
            partySize: 2,
            customerRequest: "安静座位",
            internalNote: "首次到店"
        )
        XCTAssertEqual(appointment.status, .draft)
        XCTAssertNotEqual(appointment.customerRequest, appointment.internalNote)
    }
}
```

- [ ] **Step 2: Record that XCTest execution is unavailable on Windows**

Run: `xcodebuild -version`

Expected on the current host: command unavailable. Record macOS unit tests as **Not Verified**, not failed or passed.

- [ ] **Step 3: Implement stable string-backed domain enums**

Define `CustomerStatus`, `AppointmentStatus`, `FollowUpStatus`, `AppointmentChangeType`, `ReminderType`, `ReminderStatus`, and `ActivityType` as `String`, `CaseIterable`, `Codable`, `Sendable` enums using the exact cases from the master specification.

- [ ] **Step 4: Implement value-oriented initial domain models**

Define Foundation-only structs for Customer, Appointment, AppointmentChange, Reminder, FollowUp, Activity, LeadSource, Tag, ImportBatch, and AppSettings. Use UUID identifiers and Date timestamps, keep optional sync fields value-only, preserve customer requests separately from internal notes, and do not use `@Model`, `ModelContainer`, repositories, or database behavior.

- [ ] **Step 5: Add sources and tests to the Xcode project**

Ensure domain files belong only to the application target and XCTest files belong only to `GoosegrassTests`. The test target links XCTest and depends on the application target.

- [ ] **Step 6: Run static validation**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: domain and test file checks pass; CI may remain missing.

- [ ] **Step 7: Commit domain foundations**

```powershell
git add Goosegrass/Domain GoosegrassTests Goosegrass.xcodeproj scripts/validate-phase0.ps1
git commit -m "feat(domain): define phase zero models and states"
```

### Task 4: Pure domain rules and unit tests

**Files:**
- Create: `Goosegrass/Domain/Rules/PhoneNormalizer.swift`
- Create: `Goosegrass/Domain/Rules/AppointmentValidator.swift`
- Create: `GoosegrassTests/DomainRulesTests.swift`
- Modify: `Goosegrass.xcodeproj/project.pbxproj`

- [ ] **Step 1: Write failing rule tests**

```swift
import XCTest
@testable import Goosegrass

final class DomainRulesTests: XCTestCase {
    func testPhoneNormalizerRemovesBasicFormattingOnly() {
        XCTAssertEqual(PhoneNormalizer.normalize("+86 (138) 0000-8888"), "+8613800008888")
    }

    func testPhoneNormalizerPreservesOriginalCountryPrefix() {
        XCTAssertTrue(PhoneNormalizer.possibleDuplicate("138 0000 8888", "138-0000-8888"))
        XCTAssertFalse(PhoneNormalizer.possibleDuplicate("+86 13800008888", "13800008888"))
    }

    func testAppointmentValidatorRejectsPartySizeBelowOne() {
        XCTAssertEqual(
            AppointmentValidator.validate(customerID: UUID(), startAt: Date(), partySize: 0),
            [.invalidPartySize]
        )
    }

    func testAppointmentValidatorAllowsPastAppointments() {
        XCTAssertTrue(
            AppointmentValidator.validate(
                customerID: UUID(),
                startAt: Date(timeIntervalSince1970: 0),
                partySize: 1
            ).isEmpty
        )
    }
}
```

- [ ] **Step 2: Implement minimal phone normalization**

```swift
enum PhoneNormalizer {
    static func normalize(_ phone: String) -> String {
        phone.filter { ![" ", "-", "(", ")"].contains($0) }
    }

    static func possibleDuplicate(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalize(lhs)
        return !left.isEmpty && left == normalize(rhs)
    }
}
```

- [ ] **Step 3: Implement minimal appointment validation**

```swift
enum AppointmentValidationError: Equatable, Sendable {
    case missingCustomer
    case invalidPartySize
}

enum AppointmentValidator {
    static func validate(customerID: UUID?, startAt: Date, partySize: Int) -> [AppointmentValidationError] {
        var errors: [AppointmentValidationError] = []
        if customerID == nil { errors.append(.missingCustomer) }
        if partySize < 1 { errors.append(.invalidPartySize) }
        return errors
    }
}
```

`startAt` is intentionally accepted even when it is in the past, matching the history-entry requirement.

- [ ] **Step 4: Add rules and tests to the project and run static validation**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: all implemented structure and source checks pass except a missing CI workflow if Task 5 has not started.

- [ ] **Step 5: Commit domain rules**

```powershell
git add Goosegrass/Domain/Rules GoosegrassTests Goosegrass.xcodeproj scripts/validate-phase0.ps1
git commit -m "test(domain): cover foundational business rules"
```

### Task 5: macOS CI gate and final Phase 0 verification

**Files:**
- Create: `.github/workflows/macos-build.yml`
- Modify: `README.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `scripts/validate-phase0.ps1`

- [ ] **Step 1: Add the GitHub Actions macOS workflow**

Use push and pull-request triggers, `macos-latest`, concurrency cancellation, a 20-minute timeout, and these commands:

```yaml
- name: Build
  run: >-
    xcodebuild build
    -project Goosegrass.xcodeproj
    -scheme Goosegrass
    -configuration Debug
    -destination 'platform=macOS'
    CODE_SIGNING_ALLOWED=NO

- name: Test
  run: >-
    xcodebuild test
    -project Goosegrass.xcodeproj
    -scheme Goosegrass
    -configuration Debug
    -destination 'platform=macOS'
    CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 2: Run the complete Windows validation gate**

Run: `pwsh -NoProfile -File scripts/validate-phase0.ps1`

Expected: `Phase 0 static validation passed.` and exit code 0.

- [ ] **Step 3: Inspect the repository for secrets and accidental signing configuration**

Run:

```powershell
rg -n "DEVELOPMENT_TEAM|PROVISIONING_PROFILE|CODE_SIGN_IDENTITY|API_KEY|TOKEN|PASSWORD" -g '!docs/GOOSEGRASS_MASTER_SPEC.md' -g '!Goosegrass_Product_Architecture_and_Codex_Execution_Spec.md'
```

Expected: only intentional documentation/validator references; no assigned team, identity, profile, or secret value.

- [ ] **Step 4: Review repository status and diff**

Run:

```powershell
git status --short
git diff --check
git diff --stat HEAD
```

Expected: only planned Phase 0 files, no whitespace errors, and no unrelated changes.

- [ ] **Step 5: Keep macOS-only checks explicitly unverified**

Record these statuses in README and the final report until workflow logs exist:

```text
Xcode project parse: Not Verified
macOS build: Not Verified
macOS unit tests: Not Verified
macOS UI/manual QA: Not Verified
Notifications/permissions: Not Verified
Signing/packaging: Not Verified
```

- [ ] **Step 6: Commit the Phase 0 checkpoint**

```powershell
git add .github README.md docs scripts/validate-phase0.ps1
git commit -m "ci: add macOS build and test gate"
```

- [ ] **Step 7: Produce the Phase 0 completion report**

Report completed items, changed files, database changes (`None; SwiftData deferred to Phase 1`), Windows validation evidence, macOS build status (`Not Verified` unless actual CI logs are obtained), risks, required real-Mac verification, Git checkpoint, and the recommended next step.
