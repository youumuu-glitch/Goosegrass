# Windows and macOS Workflow

## Windows lane

Windows is used for Git, documentation, source authoring, pure domain design, tests, CI configuration, and static checks. Run:

```powershell
pwsh -NoProfile -File scripts/validate-phase0.ps1
```

Windows must not be used to claim Xcode parsing, native build success, UI correctness, notification delivery, signing, or packaging.

## macOS CI lane

After pushing to GitHub, the macOS workflow compiles the application target and runs XCTest with signing disabled. Its logs are authoritative for the build/test gate.

## Real Mac lane

A real or remotely accessible Mac is required for Xcode inspection, interactive UI QA, notifications and permissions, accessibility, window behavior, signing, notarization, and distribution.

The application bundle identifier is `com.gravityedge.goosegrass`. Apple Development Team and signing values stay unset until the user supplies credentials in the real-Mac release workflow.
