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
