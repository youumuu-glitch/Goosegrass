# Coding Conventions

## Swift

- Prefer focused files and types with one clear responsibility.
- Use `UpperCamelCase` for types and `lowerCamelCase` for members.
- Use the timestamp names from the master specification.
- Prefer value semantics in the domain layer and explicit dependency injection at boundaries.
- Keep UI state changes on the main actor when concurrency is introduced.
- Avoid force unwraps and silent error swallowing.
- Do not log full phone numbers, customer notes, or other customer PII.

## Architecture

- Domain code cannot import UI, persistence, notification, or platform-adapter frameworks.
- Views delegate business workflows to view models and application services.
- Application services depend on repository protocols, not concrete SwiftData types.
- Important state transitions create traceable activity/change records in their implementation phases.
- Persistence schema changes require versioning and migration tests.

## Tests and commits

- Add a failing behavior test before production behavior.
- Use deterministic dates and identifiers in tests.
- Keep commits phase-scoped and use descriptive conventional prefixes such as `feat(domain):`, `test(domain):`, and `ci:`.
