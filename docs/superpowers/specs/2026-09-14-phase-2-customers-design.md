# Phase 2 Customers Design

**Status:** Approved by the existing Goosegrass Master Spec and Autonomous Execution Mode.

## Scope

Phase 2 delivers the first complete user-facing workflow: create a customer, persist it, relaunch, search, edit, inspect its history, and archive it. It also warns when a normalized phone number matches an existing active customer and lets the user use the existing record, create a separate record, or merge records without losing related history.

The feature includes the Customers list, add/edit sheets, customer detail, activity timeline, source and tag presentation, empty/loading/error states, and keyboard-accessible primary actions. Appointment creation, follow-up creation, global search, CSV import, notifications, and visual-system polish remain in their later phases.

## Considered Approaches

1. **Direct SwiftData queries in every view.** This is compact, but it couples business rules and duplicate handling to SwiftUI and makes deterministic tests harder.
2. **Customer aggregate service with a feature ViewModel (selected).** Views render state and send intents; the service and repository own persistence, history, search, and merge rules. This fits the existing Phase 1 boundaries and supports XCTest without launching UI.
3. **A generic Redux-style application store.** This would centralize state, but it adds machinery before other features establish shared needs.

## Architecture

`GoosegrassApp` owns the single `PersistenceController` created in Phase 1 and constructs one `CustomerService`. `ContentView` receives that service and hosts a `NavigationSplitView`. Phase 2 enables the Customers destination; future destinations remain explicit placeholders rather than hidden alternate containers.

`CustomerListViewModel` is `@MainActor` and owns query text, visible rows, selection, sheet state, duplicate-warning state, and user-facing errors. It never imports SwiftData. `CustomerEditorDraft` provides form values and converts them into a validated domain `Customer` through `PhoneNormalizer`.

The customer repository remains the aggregate persistence boundary. It gains read models for list/detail presentation, activity retrieval, source/tag catalog access, activity append, and an atomic merge operation. The local implementation resolves SwiftData relationships using the injected Phase 1 `ModelContext`; it does not create another container.

## Data and Behavior

- Active customers are sorted by most recently updated, then display name.
- Search is case-insensitive and covers display name, phone, normalized phone, email, notes, source name, and tag name. Phone-tail queries work because both formatted and normalized values participate.
- New customer submission requires a non-empty display name and a phone that normalizes to at least one digit.
- A normalized-phone match opens a duplicate warning before persistence. `Use Existing` selects the existing customer. `Create Anyway` preserves both records. `Merge` transfers appointments, activities, follow-ups, and tags to the retained customer, archives the duplicate, and writes a `customerMerged` activity.
- Creating a customer writes `customerCreated`. Adding a note writes `noteAdded`. Archive changes both `isArchived` and status and removes the customer from the default list.
- Customer detail displays source, tags, status, created/last-contact dates, notes, and a reverse-chronological activity timeline.
- Source choices are seeded idempotently from the eight Master Spec defaults. Tags are user-created and deduplicated by trimmed, case-insensitive name.

## UI Structure

The sidebar uses the Master Spec navigation labels. The Customers page uses a searchable table/list with columns appropriate to the available width: name, phone, source, status, tags, recent contact, next appointment, and note excerpt. Toolbar actions provide Add, Edit, and Archive; double-click or selection opens detail in the content/inspector area.

Add and Edit share one form. Destructive archive requires an in-app confirmation dialog. Duplicate matches use a sheet that clearly identifies existing candidates and exposes the three explicit choices. Controls have text labels, help text where an icon alone is used, sensible focus order, and keyboard shortcuts (`Command-N` for add while Customers is active, Return for the default form action, Escape to cancel).

Real Mac appearance, window sizing, keyboard navigation, VoiceOver, and focus behavior remain **Not Verified** until tested interactively on macOS.

## Error Handling and Data Safety

Persistence errors are surfaced inline or in an alert while preserving the draft. Merge is performed and saved as one repository operation so a partial relationship transfer is not exposed. Archived records remain stored and fetchable only when explicitly requested. No hard delete is introduced.

## Verification

- Domain tests cover draft validation and phone normalization integration.
- Repository tests cover expanded search, source/tag resolution, activity ordering, idempotent source seeding, and history-preserving merge.
- ViewModel/service tests cover load, create, duplicate choices, edit, note, archive, selection, and error preservation.
- A disk-reopen XCTest proves the Phase 2 acceptance chain persists across container recreation.
- `scripts/validate-phase2.ps1` verifies Windows-visible source inventory, architecture boundaries, Xcode membership, and Not Verified declarations.
- GitHub Actions must pass `xcodebuild build` and `xcodebuild test` for both push and pull-request events before merge.

## Out of Scope

Appointment and follow-up action implementations, notification delivery, CSV import, backup/restore, release signing, notarization, and packaging are deferred to their named phases. Apple Developer Team ID, signing certificate, and provisioning profile remain unset.
