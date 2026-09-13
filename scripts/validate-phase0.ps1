$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

$requiredFiles = @(
    '.github/workflows/macos-build.yml'
    '.gitignore'
    'README.md'
    'docs/ARCHITECTURE.md'
    'docs/CHANGELOG.md'
    'docs/CODING_CONVENTIONS.md'
    'docs/DATA_MODEL.md'
    'docs/GOOSEGRASS_MASTER_SPEC.md'
    'docs/PRODUCT.md'
    'docs/ROADMAP.md'
    'docs/TESTING.md'
    'docs/UX.md'
    'docs/WINDOWS_MACOS_WORKFLOW.md'
    'Goosegrass.xcodeproj/project.pbxproj'
    'Goosegrass.xcodeproj/xcshareddata/xcschemes/Goosegrass.xcscheme'
    'Goosegrass/App/ContentView.swift'
    'Goosegrass/App/GoosegrassApp.swift'
    'Goosegrass/Domain/Enums/DomainEnums.swift'
    'Goosegrass/Domain/Models/DomainModels.swift'
    'Goosegrass/Domain/Rules/AppointmentValidator.swift'
    'Goosegrass/Domain/Rules/PhoneNormalizer.swift'
    'GoosegrassTests/DomainModelTests.swift'
    'GoosegrassTests/DomainRulesTests.swift'
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing required file: $relativePath")
    }
}

$sourceSpec = Join-Path $repositoryRoot 'Goosegrass_Product_Architecture_and_Codex_Execution_Spec.md'
$masterSpec = Join-Path $repositoryRoot 'docs/GOOSEGRASS_MASTER_SPEC.md'
if ((Test-Path -LiteralPath $sourceSpec) -and (Test-Path -LiteralPath $masterSpec)) {
    $sourceHash = (Get-FileHash -LiteralPath $sourceSpec -Algorithm SHA256).Hash
    $masterHash = (Get-FileHash -LiteralPath $masterSpec -Algorithm SHA256).Hash
    if ($sourceHash -ne $masterHash) {
        $failures.Add('docs/GOOSEGRASS_MASTER_SPEC.md differs from the supplied specification.')
    }
}

$projectFile = Join-Path $repositoryRoot 'Goosegrass.xcodeproj/project.pbxproj'
if (Test-Path -LiteralPath $projectFile) {
    $project = Get-Content -Raw -LiteralPath $projectFile
    $requiredProjectSettings = @(
        'MACOSX_DEPLOYMENT_TARGET = 14.0;'
        'PRODUCT_BUNDLE_IDENTIFIER = com.gravityedge.goosegrass;'
        'PRODUCT_BUNDLE_IDENTIFIER = com.gravityedge.goosegrassTests;'
        'GENERATE_INFOPLIST_FILE = YES;'
        'SWIFT_VERSION = 5.0;'
        'ENABLE_TESTABILITY = YES;'
        'MARKETING_VERSION = 0.1.0;'
    )

    foreach ($setting in $requiredProjectSettings) {
        if (-not $project.Contains($setting)) {
            $failures.Add("Missing Xcode setting: $setting")
        }
    }

    if ($project -match '(?m)^\s*DEVELOPMENT_TEAM\s*=') {
        $failures.Add('Xcode project must not assign DEVELOPMENT_TEAM in Phase 0.')
    }

    if ($project -match '(?m)^\s*PROVISIONING_PROFILE(?:_SPECIFIER)?\s*=') {
        $failures.Add('Xcode project must not assign a provisioning profile in Phase 0.')
    }
}

$workflowFile = Join-Path $repositoryRoot '.github/workflows/macos-build.yml'
if (Test-Path -LiteralPath $workflowFile) {
    $workflow = Get-Content -Raw -LiteralPath $workflowFile
    foreach ($requiredText in @('macos-latest', 'xcodebuild build', 'xcodebuild test', 'CODE_SIGNING_ALLOWED=NO')) {
        if (-not $workflow.Contains($requiredText)) {
            $failures.Add("macOS workflow is missing: $requiredText")
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Error ("Phase 0 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 0 static validation passed.'
