$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate-phase4.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Domain/Rules/ReminderCalculator.swift'
    'Goosegrass/Application/DTO/NotificationPresentation.swift'
    'Goosegrass/Application/Repositories/ReminderRepository.swift'
    'Goosegrass/Application/Services/ReminderService.swift'
    'Goosegrass/Infrastructure/Persistence/LocalReminderRepository.swift'
    'Goosegrass/Infrastructure/Notifications/UserNotificationCenterAdapter.swift'
    'Goosegrass/Infrastructure/Preferences/ReminderPreferencesStore.swift'
    'Goosegrass/Features/Settings/NotificationSettingsViewModel.swift'
    'Goosegrass/Features/Settings/SettingsView.swift'
)
$testFiles = @(
    'GoosegrassTests/ReminderCalculatorTests.swift'
    'GoosegrassTests/ReminderRepositoryTests.swift'
    'GoosegrassTests/LocalNotificationCenterContractTests.swift'
    'GoosegrassTests/ReminderServiceTests.swift'
    'GoosegrassTests/AppointmentReminderIntegrationTests.swift'
    'GoosegrassTests/NotificationSettingsViewModelTests.swift'
    'GoosegrassTests/NotificationFeatureCompositionTests.swift'
    'GoosegrassTests/ReminderAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Missing Phase 5 file: $relativePath")
    }
}

foreach ($relativePath in $productionFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $content = Get-Content -Raw -LiteralPath $path
    if ($relativePath -notlike 'Goosegrass/Infrastructure/Persistence/*' -and $content.Contains('import SwiftData')) {
        $failures.Add("SwiftData import outside Phase 5 persistence adapter: $relativePath")
    }
    if ($relativePath -ne 'Goosegrass/Infrastructure/Notifications/UserNotificationCenterAdapter.swift' -and $content.Contains('import UserNotifications')) {
        $failures.Add("UserNotifications import outside its adapter: $relativePath")
    }
}

$schemaV2Path = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
if ((Test-Path -LiteralPath $schemaV2Path) -and -not (Get-Content -Raw -LiteralPath $schemaV2Path).Contains('Schema.Version(2, 0, 0)')) {
    $failures.Add('PersistenceSchemaV2 version changed; Phase 5 must reuse the existing Reminder record.')
}

$projectPath = Join-Path $repositoryRoot 'Goosegrass.xcodeproj/project.pbxproj'
if (Test-Path -LiteralPath $projectPath) {
    $project = Get-Content -Raw -LiteralPath $projectPath
    foreach ($relativePath in $requiredFiles) {
        $fileName = Split-Path -Leaf $relativePath
        if (-not $project.Contains("$fileName in Sources")) {
            $failures.Add("Xcode target membership is missing: $fileName")
        }
    }
}

$workflowPath = Join-Path $repositoryRoot '.github/workflows/macos-build.yml'
if ((Test-Path -LiteralPath $workflowPath) -and -not (Get-Content -Raw -LiteralPath $workflowPath).Contains('./scripts/validate-phase5.ps1')) {
    $failures.Add('macOS workflow does not invoke validate-phase5.ps1.')
}

$testingPath = Join-Path $repositoryRoot 'docs/TESTING.md'
if (Test-Path -LiteralPath $testingPath) {
    $testing = Get-Content -Raw -LiteralPath $testingPath
    if (-not $testing.Contains('Phase 5')) {
        $failures.Add('Testing documentation does not contain a Phase 5 section.')
    }
    if (-not $testing.Contains('Real Mac notification permission, sound, and delivery') -or -not $testing.Contains('**Not Verified**')) {
        $failures.Add('Phase 5 testing documentation does not preserve notification Not Verified boundaries.')
    }
}

$designPath = Join-Path $repositoryRoot 'docs/superpowers/specs/2026-09-15-phase-5-notifications-design.md'
if ((Test-Path -LiteralPath $designPath) -and -not (Get-Content -Raw -LiteralPath $designPath).Contains('remain **Not Verified**')) {
    $failures.Add('Phase 5 design does not preserve the real-Mac Not Verified boundary.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 5 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 5 static validation passed.'
