$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate-phase6.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Application/DTO/CalendarPresentation.swift'
    'Goosegrass/Application/Services/CalendarService.swift'
    'Goosegrass/Features/Calendar/CalendarViewModel.swift'
    'Goosegrass/Features/Calendar/CalendarView.swift'
)
$testFiles = @(
    'GoosegrassTests/CalendarServiceTests.swift'
    'GoosegrassTests/CalendarViewModelTests.swift'
    'GoosegrassTests/CalendarFeatureCompositionTests.swift'
    'GoosegrassTests/CalendarAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing Phase 7 file: $relativePath")
        continue
    }
    $content = Get-Content -Raw -LiteralPath $path
    if ($content.Contains('import SwiftData') -or $content.Contains('import UserNotifications')) {
        $failures.Add("Phase 7 calendar code must use application boundaries: $relativePath")
    }
}

$schemaPath = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
if (-not (Get-Content -Raw -LiteralPath $schemaPath).Contains('Schema.Version(2, 0, 0)')) {
    $failures.Add('Schema V2 changed; Phase 7 must not alter persistence schema.')
}

$project = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Goosegrass.xcodeproj/project.pbxproj')
foreach ($relativePath in $requiredFiles) {
    $fileName = Split-Path -Leaf $relativePath
    if (-not $project.Contains("$fileName in Sources")) {
        $failures.Add("Xcode target membership is missing: $fileName")
    }
}

$workflow = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot '.github/workflows/macos-build.yml')
if (-not $workflow.Contains('./scripts/validate-phase7.ps1')) {
    $failures.Add('macOS workflow does not invoke validate-phase7.ps1.')
}

$testing = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/TESTING.md')
if (-not $testing.Contains('Phase 7 gates') -or -not $testing.Contains('Real Mac Calendar') -or -not $testing.Contains('**Not Verified**')) {
    $failures.Add('Phase 7 testing documentation must preserve real-Mac Not Verified boundaries.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 7 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 7 static validation passed.'
