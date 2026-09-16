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

Phase 0 establishes the project, boundaries, and value-oriented domain contracts. Phase 1 owns SwiftData schema versions, persistence entities, repositories, model-container lifecycle, migrations, and CRUD/relationship verification. Phase 2 adds Customers, Phase 3 adds Appointments, and Phase 4 composes their application services into the Today workspace without bypassing those boundaries. Later phases follow the same dependency direction.

## Local persistence composition

`PersistenceSchemaV1` is the first explicit SwiftData schema version. Phase 3 adds `PersistenceSchemaV2` through a lightweight migration, preserving all seven V1 record definitions and adding one append-only `AppointmentChangeRecord`. `GoosegrassMigrationPlan` remains the only place schema evolution is registered. Persistence records remain internal to Infrastructure and map to Foundation domain values at repository boundaries.

`PersistenceController` owns the one application `ModelContainer` and its main `ModelContext`. The app injects that container once at the scene boundary. Local repositories receive a context; they never create hidden containers. Tests may create isolated in-memory containers or an explicitly located disk store.

Phase 1 implements Customer and Appointment repository/service foundations. Activity, FollowUp, LeadSource, Tag, and Reminder are present in the schema so later phases extend behavior without introducing an unversioned store.

## Appointments feature composition

`ContentView` owns one `AppointmentListViewModel` alongside the customer feature. Both services are created from the same application `PersistenceController`. The pure `AppointmentLifecycle` rejects illegal edges; `AppointmentService` creates changes and activities; `LocalAppointmentRepository.commit` validates the whole aggregate before one save. SwiftUI does not import SwiftData, and notification delivery remains Phase 5 work.

## Today feature composition

`TodayService` combines `AppointmentService` and `CustomerService` at runtime; it introduces no repository, cache, timer, or stored dashboard state. `Calendar.dateInterval(of: .day)` defines the local civil day. Upcoming Arrivals includes future `confirmed` and `upcoming` appointments without changing their persisted lifecycle status. The Today's Appointments card excludes cancelled records, while the default main list preserves every same-day record for complete operational history.

`TodayViewModel` replaces its snapshot, selected rows, counts, and inspector detail by rereading `TodayService` after every successful action. `ContentView` owns this ViewModel, makes Today the initial destination, and reuses the Phase 3 appointment inspector and editor. Schema V2 remains unchanged.

## Reminder and notification composition

Phase 5 reuses the V1 `ReminderRecord`; Schema V2 remains unchanged. `ReminderCalculator` uses injected local-calendar arithmetic, `ReminderRepository` owns durable intent, and `ReminderService` compares appointments, reminder records, and system pending requests. Standard system identifiers are namespaced by the stable Reminder UUID, making rebuilds idempotent.

Only `UserNotificationCenterAdapter` imports UserNotifications. Appointment commits report their authoritative result through `AppointmentReminderScheduling`; notification failure never rolls back committed business data and is instead persisted as a failed Reminder for later reconcile. `GoosegrassApp` constructs one reminder graph for Appointments, Today, Settings, and one launch reconcile. No timer or Phase 6 FollowUp behavior is introduced.

## Customers feature composition

`GoosegrassApp` asks its single `PersistenceController` for a `CustomerService`; `ContentView` owns one `CustomerListViewModel` and injects it into the Customers route. Customer feature files do not import SwiftData. Aggregate list/detail reads, default-source seeding, tag resolution, activity insertion, duplicate detection, and merge transactions stay behind `CustomerRepository`.

Customer merge retains the chosen customer UUID, moves appointment/activity/follow-up relationships and their durable foreign keys, unions tags, archives the duplicate, and appends a `customerMerged` activity in one repository save. Archive is a state transition and never deletes related history.

## Identity and signing

The app bundle identifier is `com.gravityedge.goosegrass`. Bundle identity is independent of signing. No team, certificate, profile, or distribution identity is committed in Phase 0.
