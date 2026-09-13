$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$phase0Validator = Join-Path $PSScriptRoot 'validate-phase0.ps1'
& $phase0Validator

$failures = [System.Collections.Generic.List[string]]::new()
$requiredFiles = @(
    'Goosegrass/Application/Repositories/CustomerRepository.swift'
    'Goosegrass/Application/Repositories/AppointmentRepository.swift'
    'Goosegrass/Application/Services/CustomerService.swift'
    'Goosegrass/Application/Services/AppointmentService.swift'
    'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV1.swift'
    'Goosegrass/Infrastructure/Persistence/GoosegrassMigrationPlan.swift'
    'Goosegrass/Infrastructure/Persistence/PersistenceMapper.swift'
    'Goosegrass/Infrastructure/Persistence/LocalCustomerRepository.swift'
    'Goosegrass/Infrastructure/Persistence/LocalAppointmentRepository.swift'
    'Goosegrass/Infrastructure/Persistence/PersistenceController.swift'
    'GoosegrassTests/PersistenceSchemaTests.swift'
    'GoosegrassTests/PersistenceRepositoryTests.swift'
    'GoosegrassTests/PersistenceLifecycleTests.swift'
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $repositoryRoot $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing Phase 1 file: $relativePath")
    }
}

$schemaPath = Join-Path $repositoryRoot 'Goosegrass/Infrastructure/Persistence/PersistenceSchemaV1.swift'
if (Test-Path -LiteralPath $schemaPath) {
    $schema = Get-Content -Raw -LiteralPath $schemaPath
    foreach ($requiredText in @(
        'import SwiftData'
        'enum PersistenceSchemaV1: VersionedSchema'
        '@Model'
        'CustomerRecord.self'
        'AppointmentRecord.self'
        'ActivityRecord.self'
        'FollowUpRecord.self'
        'LeadSourceRecord.self'
        'TagRecord.self'
        'ReminderRecord.self'
    )) {
        if (-not $schema.Contains($requiredText)) {
            $failures.Add("Persistence schema is missing: $requiredText")
        }
    }
}

$appPath = Join-Path $repositoryRoot 'Goosegrass/App/GoosegrassApp.swift'
if (Test-Path -LiteralPath $appPath) {
    $app = Get-Content -Raw -LiteralPath $appPath
    if (-not $app.Contains('.modelContainer(persistenceController.container)')) {
        $failures.Add('App does not inject the application-owned model container.')
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

if ($failures.Count -gt 0) {
    Write-Error ("Phase 1 static validation failed:`n- " + ($failures -join "`n- "))
    exit 1
}

Write-Output 'Phase 1 static validation passed.'
