$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$phase2Validator = Join-Path $PSScriptRoot 'validate-phase2.ps1'
& $phase2Validator

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Domain/Rules/AppointmentLifecycle.swift'
    'Goosegrass/Application/DTO/AppointmentPresentation.swift'
    'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV2.swift'
    'Goosegrass/Features/Appointments/AppointmentEditorDraft.swift'
    'Goosegrass/Features/Appointments/AppointmentListViewModel.swift'
    'Goosegrass/Features/Appointments/AppointmentsView.swift'
    'Goosegrass/Features/Appointments/AppointmentEditorView.swift'
    'Goosegrass/Features/Appointments/AppointmentDetailView.swift'
)
$testFiles = @(
    'GoosegrassTests/AppointmentLifecycleTests.swift'
    'GoosegrassTests/AppointmentServiceLifecycleTests.swift'
    'GoosegrassTests/AppointmentRepositoryAggregateTests.swift'
    'GoosegrassTests/AppointmentMigrationTests.swift'
    'GoosegrassTests/AppointmentListViewModelTests.swift'
    'GoosegrassTests/AppointmentFeatureCompositionTests.swift'
    'GoosegrassTests/AppointmentAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing Phase 3 file: $relativePath")
    }
}

foreach ($relativePath in $productionFiles | Where-Object { $_ -like 'Goosegrass/Features/Appointments/*' }) {
    $path = Join-Path $repositoryRoot $relativePath
    if ((Test-Path -LiteralPath $path) -and (Get-Content -Raw -LiteralPath $path).Contains('import SwiftData')) {
        $failures.Add("Feature boundary imports SwiftData: $relativePath")
    }
}

$schemaV1Path = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV1.swift'
if (Test-Path -LiteralPath $schemaV1Path) {
    $schemaV1 = Get-Content -Raw -LiteralPath $schemaV1Path
    if (-not $schemaV1.Contains('Schema.Version(1, 0, 0)')) {
        $failures.Add('PersistenceSchemaV1 version identifier changed; Phase 3 must add a new schema version.')
    }
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

$testingPath = Join-Path $repositoryRoot 'docs/TESTING.md'
if ((Test-Path -LiteralPath $testingPath) -and -not (Get-Content -Raw -LiteralPath $testingPath).Contains('Phase 3')) {
    $failures.Add('Testing documentation does not contain a Phase 3 verification section.')
}

$designPath = Join-Path $repositoryRoot 'docs/superpowers/specs/2026-09-15-phase-3-appointments-design.md'
if ((Test-Path -LiteralPath $designPath) -and -not (Get-Content -Raw -LiteralPath $designPath).Contains('remain **Not Verified**')) {
    $failures.Add('Phase 3 design does not preserve the real Mac Not Verified boundary.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 3 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 3 static validation passed.'
