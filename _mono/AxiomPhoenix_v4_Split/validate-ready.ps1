# Validation script to check if the application is ready to run
$ErrorActionPreference = 'Stop'

Write-Host "Validating Axiom-Phoenix v4.0 readiness..." -ForegroundColor Cyan

$issues = @()

# Check 1: Verify ProjectEditDialog loads before screens that use it
Write-Host "Checking screen loading order..." -ForegroundColor Gray
$screenFiles = Get-ChildItem -Path ".\Screens" -Filter "*.ps1" | Sort-Object Name

$projectEditDialogIndex = -1
$projectInfoScreenIndex = -1
$projectsListScreenIndex = -1

for ($i = 0; $i -lt $screenFiles.Count; $i++) {
    if ($screenFiles[$i].Name -match "ProjectEditDialog") { $projectEditDialogIndex = $i }
    if ($screenFiles[$i].Name -match "ProjectInfoScreen") { $projectInfoScreenIndex = $i }
    if ($screenFiles[$i].Name -match "ProjectsListScreen") { $projectsListScreenIndex = $i }
}

if ($projectEditDialogIndex -gt $projectInfoScreenIndex -or $projectEditDialogIndex -gt $projectsListScreenIndex) {
    $issues += "ProjectEditDialog loads after screens that use it"
} else {
    Write-Host "  ✓ ProjectEditDialog loads before dependent screens" -ForegroundColor Green
}

# Check 2: Verify no critical services are trying to use FocusManager
Write-Host "Checking for FocusManager dependencies..." -ForegroundColor Gray
$focusManagerUsage = Get-ChildItem -Path ".\Runtime", ".\Base" -Filter "*.ps1" -Recurse | 
    Select-String -Pattern "GetService.*FocusManager" -SimpleMatch

if ($focusManagerUsage) {
    $issues += "Critical components still trying to use FocusManager service"
    $focusManagerUsage | ForEach-Object { Write-Host "  ! Found in: $($_.Path)" -ForegroundColor Red }
} else {
    Write-Host "  ✓ No critical FocusManager dependencies found" -ForegroundColor Green
}

# Check 3: Verify all required services are registered
Write-Host "Checking service registrations..." -ForegroundColor Gray
$startScript = Get-Content ".\Start.ps1" -Raw
$requiredServices = @(
    "Logger", "EventManager", "ThemeManager", "DataManager", 
    "ActionService", "KeybindingService", "NavigationService", 
    "DialogManager", "ViewDefinitionService", "FileSystemService"
)

foreach ($service in $requiredServices) {
    if ($startScript -notmatch "Register.*$service") {
        $issues += "Service '$service' not registered in Start.ps1"
    }
}

if ($issues.Count -eq 0) {
    Write-Host "  ✓ All required services are registered" -ForegroundColor Green
}

# Check 4: Look for undefined dialog classes
Write-Host "Checking for undefined dialog classes..." -ForegroundColor Gray
$dialogReferences = Get-ChildItem -Path ".\Screens" -Filter "*.ps1" | 
    Select-String -Pattern '\[(.*Dialog)\]::new' -AllMatches

$definedDialogs = @()
Get-ChildItem -Path ".\Screens", ".\Components" -Filter "*.ps1" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'class\s+(\w+Dialog)\s*:') {
        $definedDialogs += $matches[1]
    }
}

foreach ($ref in $dialogReferences) {
    foreach ($match in $ref.Matches) {
        $dialogClass = $match.Groups[1].Value
        if ($dialogClass -notin $definedDialogs -and $dialogClass -ne "SimpleTaskDialog" -and $dialogClass -ne "ConfirmDialog") {
            $issues += "Undefined dialog class '$dialogClass' referenced in $($ref.Filename)"
        }
    }
}

if ($issues.Count -eq 0) {
    Write-Host "  ✓ All dialog classes are defined" -ForegroundColor Green
}

# Summary
Write-Host "`n" -NoNewline
if ($issues.Count -eq 0) {
    Write-Host "✅ All checks passed! The application should run." -ForegroundColor Green
    Write-Host "`nYou can now run: .\Start.ps1" -ForegroundColor Yellow
} else {
    Write-Host "❌ Found $($issues.Count) issue(s):" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
    Write-Host "`nPlease fix these issues before running the application." -ForegroundColor Red
}
