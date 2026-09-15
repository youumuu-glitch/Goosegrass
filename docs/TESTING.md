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

The macOS test target now covers schema registration, Customer CRUD/search/archive, duplicate candidates, Appointment CRUD, inverse Customer/Appointment relationships, a disk-store reopen, and shared-container composition. GitHub Actions push run `34855677073` completed both `xcodebuild build` and `xcodebuild test` successfully on 2026-09-14.

Two persistence regressions were verified with macOS CI RED/GREEN cycles: run `34766301093` failed the new Customer source-identity round-trip assertion before run `34854777091` passed after the fix; run `34854907950` failed the new shared-main-context assertion before run `34855354576` passed after the fix. Pull-request run `34857548677` completed both build and test successfully for PR #2 on 2026-09-14.

Real Mac interactive UI, keyboard navigation, VoiceOver, notification permission and delivery, signing, notarization, and packaging remain **Not Verified**.

## Phase 2 gates

Windows runs `scripts/validate-phase2.ps1`, preserving all Phase 0/1 checks and verifying the customer source/test inventory, feature-to-persistence boundary, Xcode target membership, and required verification wording. It passed on 2026-09-15; as a static gate it cannot compile Swift or execute SwiftData.

The macOS suite covers service validation and lifecycle behavior, aggregate repository search/catalog/timeline/merge behavior, ViewModel state transitions, application-owned dependency composition, and a disk-backed `Create → Relaunch → Search → Edit → Archive → Relaunch` acceptance chain with stable UUID assertions. Push run `34940016333` completed unsigned `xcodebuild build` and the complete XCTest target successfully on 2026-09-15.

Phase 2 retained explicit RED/GREEN evidence: service boundary run `34859703564`, aggregate run `34860552262`, lifecycle run `34868753639`, ViewModel run `34869420174`, and composition run `34921577925` failed before their implementations; SwiftUI integration run `34921966148` exposed a compiler diagnostic before corrected run `34939712021` passed. Pull-request CI remains pending until the Phase 2 PR exists.

Real Mac UI appearance, keyboard navigation, focus behavior, VoiceOver, notification permission/delivery, Apple Developer Team configuration, signing, provisioning, notarization, and packaging remain **Not Verified**.
