$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate-phase5.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Domain/Rules/FollowUpSchedule.swift'
    'Goosegrass/Domain/Rules/FollowUpLifecycle.swift'
    'Goosegrass/Application/DTO/FollowUpPresentation.swift'
    'Goosegrass/Application/DTO/NoShowFollowUpRequest.swift'
    'Goosegrass/Application/Repositories/FollowUpRepository.swift'
    'Goosegrass/Application/Services/FollowUpService.swift'
    'Goosegrass/Infrastructure/Persistence/LocalFollowUpRepository.swift'
    'Goosegrass/Features/FollowUp/FollowUpEditorDraft.swift'
    'Goosegrass/Features/FollowUp/FollowUpListViewModel.swift'
    'Goosegrass/Features/FollowUp/FollowUpEditorView.swift'
    'Goosegrass/Features/FollowUp/FollowUpDetailView.swift'
    'Goosegrass/Features/FollowUp/FollowUpView.swift'
)
$testFiles = @(
    'GoosegrassTests/FollowUpScheduleTests.swift'
    'GoosegrassTests/FollowUpRepositoryTests.swift'
    'GoosegrassTests/FollowUpServiceTests.swift'
    'GoosegrassTests/FollowUpViewModelTests.swift'
    'GoosegrassTests/FollowUpFeatureCompositionTests.swift'
    'GoosegrassTests/FollowUpAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Missing Phase 6 file: $relativePath")
    }
}

foreach ($relativePath in $productionFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $content = Get-Content -Raw -LiteralPath $path
    if ($relativePath -notlike 'Goosegrass/Infrastructure/Persistence/*' -and $content.Contains('import SwiftData')) {
        $failures.Add("SwiftData import outside Phase 6 persistence adapter: $relativePath")
    }
    if ($content.Contains('import UserNotifications')) {
        $failures.Add("Phase 6 follow-up code must not import UserNotifications: $relativePath")
    }
}

$schemaV2Path = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
if ((Test-Path -LiteralPath $schemaV2Path) -and -not (Get-Content -Raw -LiteralPath $schemaV2Path).Contains('Schema.Version(2, 0, 0)')) {
    $failures.Add('PersistenceSchemaV2 version changed; Phase 6 must reuse the existing FollowUp record.')
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
if ((Test-Path -LiteralPath $workflowPath) -and -not (Get-Content -Raw -LiteralPath $workflowPath).Contains('./scripts/validate-phase6.ps1')) {
    $failures.Add('macOS workflow does not invoke validate-phase6.ps1.')
}

$testingPath = Join-Path $repositoryRoot 'docs/TESTING.md'
if (Test-Path -LiteralPath $testingPath) {
    $testing = Get-Content -Raw -LiteralPath $testingPath
    if (-not $testing.Contains('Phase 6')) {
        $failures.Add('Testing documentation does not contain a Phase 6 section.')
    }
    if (-not $testing.Contains('Real Mac follow-up dialog, sheet, keyboard/focus behavior, and VoiceOver') -or -not $testing.Contains('**Not Verified**')) {
        $failures.Add('Phase 6 testing documentation does not preserve real-Mac Not Verified boundaries.')
    }
}

$designPath = Join-Path $repositoryRoot 'docs/superpowers/specs/2026-09-16-phase-6-follow-up-design.md'
if ((Test-Path -LiteralPath $designPath) -and -not (Get-Content -Raw -LiteralPath $designPath).Contains('remain **Not Verified**')) {
    $failures.Add('Phase 6 design does not preserve the real-Mac Not Verified boundary.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 6 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 6 static validation passed.'
