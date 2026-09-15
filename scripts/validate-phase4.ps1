$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'validate-phase3.ps1')

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Application/DTO/TodayPresentation.swift'
    'Goosegrass/Application/Services/TodayService.swift'
    'Goosegrass/Features/Today/TodayViewModel.swift'
    'Goosegrass/Features/Today/TodayView.swift'
    'Goosegrass/Features/Today/TodaySummaryCard.swift'
)
$testFiles = @(
    'GoosegrassTests/TodayAggregationTests.swift'
    'GoosegrassTests/TodayViewModelTests.swift'
    'GoosegrassTests/TodayFeatureCompositionTests.swift'
    'GoosegrassTests/TodayAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Missing Phase 4 file: $relativePath")
    }
}

foreach ($relativePath in $productionFiles | Where-Object { $_ -like 'Goosegrass/Features/Today/*' }) {
    $path = Join-Path $repositoryRoot $relativePath
    if (Test-Path -LiteralPath $path) {
        $content = Get-Content -Raw -LiteralPath $path
        foreach ($forbiddenImport in @('import SwiftData', 'import UserNotifications')) {
            if ($content.Contains($forbiddenImport)) {
                $failures.Add("Today feature boundary contains forbidden import '$forbiddenImport': $relativePath")
            }
        }
    }
}

$schemaV2Path = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
if ((Test-Path -LiteralPath $schemaV2Path) -and -not (Get-Content -Raw -LiteralPath $schemaV2Path).Contains('Schema.Version(2, 0, 0)')) {
    $failures.Add('PersistenceSchemaV2 version identifier changed; Phase 4 must not add storage state.')
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
if ((Test-Path -LiteralPath $workflowPath) -and -not (Get-Content -Raw -LiteralPath $workflowPath).Contains('./scripts/validate-phase4.ps1')) {
    $failures.Add('macOS workflow does not invoke validate-phase4.ps1.')
}

$testingPath = Join-Path $repositoryRoot 'docs/TESTING.md'
if (Test-Path -LiteralPath $testingPath) {
    $testing = Get-Content -Raw -LiteralPath $testingPath
    if (-not $testing.Contains('Phase 4')) {
        $failures.Add('Testing documentation does not contain a Phase 4 verification section.')
    }
    if (-not $testing.Contains('Real Mac Today UI appearance, keyboard/focus behavior, VoiceOver, notification delivery') -or -not $testing.Contains('**Not Verified**')) {
        $failures.Add('Phase 4 testing documentation does not preserve the real-Mac Not Verified boundary.')
    }
}

$designPath = Join-Path $repositoryRoot 'docs/superpowers/specs/2026-09-15-phase-4-today-design.md'
if ((Test-Path -LiteralPath $designPath) -and -not (Get-Content -Raw -LiteralPath $designPath).Contains('remain **Not Verified**')) {
    $failures.Add('Phase 4 design does not preserve the real-Mac Not Verified boundary.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 4 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 4 static validation passed.'
