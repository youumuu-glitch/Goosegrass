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

Phase 0 establishes the project, boundaries, and value-oriented domain contracts. Phase 1 owns SwiftData schema versions, persistence entities, repositories, model-container lifecycle, migrations, and CRUD/relationship verification. Later phases add product workflows without bypassing services and repositories.

## Identity and signing

The app bundle identifier is `com.gravityedge.goosegrass`. Bundle identity is independent of signing. No team, certificate, profile, or distribution identity is committed in Phase 0.
