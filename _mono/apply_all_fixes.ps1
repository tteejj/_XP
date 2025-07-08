# Master Fix Script for Axiom-Phoenix v4.0
# This script applies all fixes in the correct order

Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║     Axiom-Phoenix v4.0 - Comprehensive Fix Application      ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "`nThis script will apply all fixes to make the framework fully functional." -ForegroundColor Yellow
Write-Host "Fixes include:" -ForegroundColor Yellow
Write-Host "  • Data model enhancements (TimeEntry, enhanced PmcProject)" -ForegroundColor White
Write-Host "  • TaskListScreen CRUD operations with dialogs" -ForegroundColor White
Write-Host "  • Panel alignment and layout fixes" -ForegroundColor White
Write-Host "  • Command palette performance optimization" -ForegroundColor White
Write-Host "  • Text filtering implementation" -ForegroundColor White
Write-Host "  • Unicode support for better UI rendering" -ForegroundColor White
Write-Host "  • Multiple built-in themes (Synthwave, HighContrastLight, Paper)" -ForegroundColor White
Write-Host "  • Theme picker screen" -ForegroundColor White
Write-Host "  • DashboardScreen rendering fixes" -ForegroundColor White

Write-Host "`nPress any key to continue or Ctrl+C to cancel..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Check if fix scripts exist
$scripts = @(
    "comprehensive_fixes.ps1",
    "enhanced_theming.ps1",
    "implement_crud_dialogs.ps1"
)

$missingScripts = @()
foreach ($script in $scripts) {
    if (-not (Test-Path $script)) {
        $missingScripts += $script
    }
}

if ($missingScripts.Count -gt 0) {
    Write-Host "`nError: The following fix scripts are missing:" -ForegroundColor Red
    foreach ($missing in $missingScripts) {
        Write-Host "  - $missing" -ForegroundColor Red
    }
    Write-Host "`nPlease ensure all fix scripts are in the current directory." -ForegroundColor Red
    exit 1
}

# Create backups
Write-Host "`nCreating backups..." -ForegroundColor Cyan
$backupDir = "backups_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

$filesToBackup = @(
    "AllModels.ps1",
    "AllComponents.ps1",
    "AllScreens.ps1",
    "AllServices.ps1",
    "AllRuntime.ps1"
)

foreach ($file in $filesToBackup) {
    if (Test-Path $file) {
        Copy-Item $file "$backupDir\$file" -Force
        Write-Host "  Backed up: $file" -ForegroundColor Green
    }
}

# Apply fixes in order
try {
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "STEP 1: Applying comprehensive fixes..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    & .\comprehensive_fixes.ps1
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "STEP 2: Applying enhanced theming..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    & .\enhanced_theming.ps1
    
    Write-Host "`n═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "STEP 3: Implementing CRUD dialogs..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    & .\implement_crud_dialogs.ps1
    
    Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              ALL FIXES APPLIED SUCCESSFULLY!                 ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    
    Write-Host "`nWhat's new:" -ForegroundColor Cyan
    Write-Host "  ✓ TaskListScreen now has functional CRUD buttons" -ForegroundColor Green
    Write-Host "  ✓ Text filtering works - type in the filter box" -ForegroundColor Green
    Write-Host "  ✓ Command palette is optimized with debouncing" -ForegroundColor Green
    Write-Host "  ✓ Unicode support enabled - better UI characters" -ForegroundColor Green
    Write-Host "  ✓ 4 themes available: Default, Synthwave, HighContrastLight, Paper" -ForegroundColor Green
    Write-Host "  ✓ Theme picker accessible via Ctrl+P -> 'Change Theme'" -ForegroundColor Green
    Write-Host "  ✓ Time tracking support with TimeEntry class" -ForegroundColor Green
    Write-Host "  ✓ Enhanced project model with additional fields" -ForegroundColor Green
    
    Write-Host "`nKeyboard shortcuts in TaskListScreen:" -ForegroundColor Yellow
    Write-Host "  [N] - Create new task" -ForegroundColor White
    Write-Host "  [E] - Edit selected task" -ForegroundColor White
    Write-Host "  [D] - Delete selected task" -ForegroundColor White
    Write-Host "  [C] - Mark task as complete" -ForegroundColor White
    Write-Host "  ↑↓  - Navigate tasks" -ForegroundColor White
    Write-Host "  Enter - Edit task (alternative)" -ForegroundColor White
    
    Write-Host "`nRun .\Start.ps1 to launch the improved application!" -ForegroundColor Cyan
    
} catch {
    Write-Host "`nError applying fixes:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nBackups are available in: $backupDir" -ForegroundColor Yellow
    exit 1
}

# Optional: Launch the application
Write-Host "`nWould you like to launch the application now? (Y/N)" -ForegroundColor Yellow
$response = Read-Host
if ($response -eq 'Y' -or $response -eq 'y') {
    Write-Host "`nLaunching Axiom-Phoenix..." -ForegroundColor Cyan
    & .\Start.ps1
}
