# Architecture

## Direction

Goosegrass is a native macOS application built with Swift, SwiftUI, SwiftData, and UserNotifications. The minimum deployment target is macOS 14. Business functionality must remain available offline.

## Dependency flow

```text
SwiftUI View -> ViewModel -> Application Service / Use Case
             -> Repository protocol -> Local SwiftData implementation
```

Dependencies point inward. Domain code uses Foundation value types and pure rules. It does not import SwiftUI, SwiftData, UserNotifications, or storage implementations. Views do not perform complex persistence operations.

## Source boundaries

- `App`: application entry point and dependency composition.
- `Domain`: business states, initial models, and pure rules.
- `Application`: use cases, service contracts, and DTOs.
- `Infrastructure`: SwiftData, notifications, import/export, and backup adapters.
- `Features`: feature-local views and view models.
- `Shared`: reusable UI, design tokens, extensions, and utilities.

## Phase ownership

Phase 0 establishes the project, boundaries, and value-oriented domain contracts. Phase 1 owns SwiftData schema versions, persistence entities, repositories, model-container lifecycle, migrations, and CRUD/relationship verification. Phase 2 adds the Customers workflow through presentation DTOs, `CustomerService`, and an observable feature ViewModel without bypassing those boundaries. Later phases follow the same dependency direction.

## Local persistence composition

`PersistenceSchemaV1` is the first explicit SwiftData schema version and `GoosegrassMigrationPlan` is the only place schema evolution is registered. Persistence records remain internal to Infrastructure and map to Foundation domain values at repository boundaries.

`PersistenceController` owns the one application `ModelContainer` and its main `ModelContext`. The app injects that container once at the scene boundary. Local repositories receive a context; they never create hidden containers. Tests may create isolated in-memory containers or an explicitly located disk store.

Phase 1 implements Customer and Appointment repository/service foundations. Activity, FollowUp, LeadSource, Tag, and Reminder are present in the schema so later phases extend behavior without introducing an unversioned store.

## Customers feature composition

`GoosegrassApp` asks its single `PersistenceController` for a `CustomerService`; `ContentView` owns one `CustomerListViewModel` and injects it into the Customers route. Customer feature files do not import SwiftData. Aggregate list/detail reads, default-source seeding, tag resolution, activity insertion, duplicate detection, and merge transactions stay behind `CustomerRepository`.

Customer merge retains the chosen customer UUID, moves appointment/activity/follow-up relationships and their durable foreign keys, unions tags, archives the duplicate, and appends a `customerMerged` activity in one repository save. Archive is a state transition and never deletes related history.

## Identity and signing

The app bundle identifier is `com.gravityedge.goosegrass`. Bundle identity is independent of signing. No team, certificate, profile, or distribution identity is committed in Phase 0.
