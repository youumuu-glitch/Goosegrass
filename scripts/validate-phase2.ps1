$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$phase1Validator = Join-Path $PSScriptRoot 'validate-phase1.ps1'
& $phase1Validator

$failures = [System.Collections.Generic.List[string]]::new()
$productionFiles = @(
    'Goosegrass/Application/DTO/CustomerPresentation.swift'
    'Goosegrass/Features/Customers/CustomerEditorDraft.swift'
    'Goosegrass/Features/Customers/CustomerListViewModel.swift'
    'Goosegrass/Features/Customers/CustomersView.swift'
    'Goosegrass/Features/Customers/CustomerEditorView.swift'
    'Goosegrass/Features/Customers/CustomerDetailView.swift'
    'Goosegrass/Features/Customers/DuplicateCustomerView.swift'
    'Goosegrass/Shared/Components/EmptyStateView.swift'
)
$testFiles = @(
    'GoosegrassTests/CustomerServiceTests.swift'
    'GoosegrassTests/CustomerListViewModelTests.swift'
    'GoosegrassTests/CustomerFeatureCompositionTests.swift'
    'GoosegrassTests/CustomerAcceptanceTests.swift'
)
$requiredFiles = $productionFiles + $testFiles

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing Phase 2 file: $relativePath")
    }
}

foreach ($relativePath in @(
    'Goosegrass/Features/Customers/CustomerEditorDraft.swift'
    'Goosegrass/Features/Customers/CustomerListViewModel.swift'
    'Goosegrass/Features/Customers/CustomersView.swift'
    'Goosegrass/Features/Customers/CustomerEditorView.swift'
    'Goosegrass/Features/Customers/CustomerDetailView.swift'
    'Goosegrass/Features/Customers/DuplicateCustomerView.swift'
)) {
    $path = Join-Path $repositoryRoot $relativePath
    if ((Test-Path -LiteralPath $path) -and (Get-Content -Raw -LiteralPath $path).Contains('import SwiftData')) {
        $failures.Add("Feature boundary imports SwiftData: $relativePath")
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
if ((Test-Path -LiteralPath $testingPath) -and -not (Get-Content -Raw -LiteralPath $testingPath).Contains('Phase 2')) {
    $failures.Add('Testing documentation does not contain a Phase 2 verification section.')
}

$designPath = Join-Path $repositoryRoot 'docs/superpowers/specs/2026-09-14-phase-2-customers-design.md'
if ((Test-Path -LiteralPath $designPath) -and -not (Get-Content -Raw -LiteralPath $designPath).Contains('remain **Not Verified**')) {
    $failures.Add('Phase 2 design does not preserve the real Mac Not Verified boundary.')
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 2 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 2 static validation passed.'
