# TUI Scope Fix Verification Script
# This script verifies that the scope fixes have been applied correctly

Write-Host "TUI Scope Fix Verification" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan

$baseDir = "C:\Users\jhnhe\Documents\GitHub\_XP\"
$hasErrors = $false

# Check 1: Verify engine uses global:TuiState
Write-Host "`nChecking TUI Engine..." -ForegroundColor Yellow
$enginePath = Join-Path $baseDir "modules\tui-engine-v2.psm1"
$engineContent = Get-Content $enginePath -Raw

$scriptStateCount = ([regex]::Matches($engineContent, '\$script:TuiState')).Count
$globalStateCount = ([regex]::Matches($engineContent, '\$global:TuiState')).Count

if ($scriptStateCount -gt 0) {
    Write-Host "  ERROR: Found $scriptStateCount instances of `$script:TuiState" -ForegroundColor Red
    $hasErrors = $true
} else {
    Write-Host "  OK: No `$script:TuiState found" -ForegroundColor Green
}

Write-Host "  INFO: Found $globalStateCount instances of `$global:TuiState" -ForegroundColor Cyan

# Check 2: Verify no global: function definitions
Write-Host "`nChecking Component Functions..." -ForegroundColor Yellow
$componentPaths = @(
    "components\advanced-data-components.psm1",
    "components\advanced-input-components.psm1", 
    "components\tui-components.psm1",
    "layout\panels.psm1",
    "modules\dialog-system.psm1",
    "modules\event-system.psm1",
    "modules\state-manager.psm1",
    "modules\text-resources.psm1",
    "modules\theme-manager.psm1",
    "services\keybindings.psm1",
    "services\navigation.psm1",
    "services\task-services.psm1",
    "utilities\focus-manager.psm1",
    "utilities\layout-manager.psm1",
    "utilities\positioning-helper.psm1"
)

$totalGlobalFunctions = 0
foreach ($relativePath in $componentPaths) {
    $fullPath = Join-Path $baseDir $relativePath
    if (Test-Path $fullPath) {
        $content = Get-Content $fullPath -Raw
        $matches = [regex]::Matches($content, 'function\s+global:(\w+)')
        if ($matches.Count -gt 0) {
            Write-Host "  ERROR in $relativePath : Found $($matches.Count) global: functions" -ForegroundColor Red
            $hasErrors = $true
            $totalGlobalFunctions += $matches.Count
        }
    }
}

if ($totalGlobalFunctions -eq 0) {
    Write-Host "  OK: No global: function definitions found" -ForegroundColor Green
}

# Check 3: Verify main.ps1 uses Import-Module -Global
Write-Host "`nChecking main.ps1 module loading..." -ForegroundColor Yellow
$mainPath = Join-Path $baseDir "main.ps1"
if (Test-Path $mainPath) {
    $mainContent = Get-Content $mainPath -Raw
    if ($mainContent -match 'Import-Module.*-Global') {
        Write-Host "  OK: main.ps1 uses Import-Module -Global" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: main.ps1 may not be using Import-Module -Global" -ForegroundColor Yellow
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
if ($hasErrors) {
    Write-Host "VERIFICATION FAILED: Issues found!" -ForegroundColor Red
    Write-Host "Run the fix scripts before proceeding." -ForegroundColor Yellow
} else {
    Write-Host "VERIFICATION PASSED: All checks successful!" -ForegroundColor Green
    Write-Host "The TUI should now render correctly." -ForegroundColor Green
}
