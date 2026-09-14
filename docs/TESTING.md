# Testing

## Layers

- Domain unit tests cover pure state, validation, normalization, and calculations.
- Repository tests cover CRUD, relationships, search, archive, and migrations beginning in Phase 1.
- Service tests cover appointment/reminder/follow-up lifecycles in their implementation phases.
- macOS UI tests cover critical end-to-end flows once those features exist.

## Phase 0 gates

Windows runs `scripts/validate-phase0.ps1` to verify repository shape, master-spec integrity, identity, unsigned Xcode configuration, shared scheme, and CI configuration.

The Phase 0 Windows repository validation passed on 2026-09-13. This result proves only the static checks implemented by that script.

GitHub Actions runs `xcodebuild build` and `xcodebuild test` on a macOS runner with code signing disabled. The Phase 0 pull-request workflow completed both steps successfully on 2026-09-13.

Real Mac verification is required for window behavior, UI appearance, keyboard navigation, VoiceOver, notification authorization and delivery, signing, notarization, and packaging.

## Phase 1 gates

Windows runs `scripts/validate-phase1.ps1`, which first preserves every Phase 0 check and then verifies the Phase 1 source/test inventory, seven-record versioned schema, migration plan, scene-level container injection, and Xcode target membership. This static gate passed on 2026-09-13; it cannot compile or execute SwiftData.

The macOS test target now covers schema registration, Customer CRUD/search/archive, duplicate candidates, Appointment CRUD, inverse Customer/Appointment relationships, a disk-store reopen, and shared-container composition. GitHub Actions push run `34855354576` completed both `xcodebuild build` and `xcodebuild test` successfully on 2026-09-14.

Two persistence regressions were verified with macOS CI RED/GREEN cycles: run `34766301093` failed the new Customer source-identity round-trip assertion before run `34854777091` passed after the fix; run `34854907950` failed the new shared-main-context assertion before run `34855354576` passed after the fix. Pull-request CI remains **Not Verified** until the Phase 1 PR is opened.
