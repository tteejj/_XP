# Verify CommandPalette Fixes Are Applied
Write-Host "`nVerifying CommandPalette fixes..." -ForegroundColor Cyan

$issues = @()

# Check 1: CommandPalette Complete override
Write-Host "`nChecking CommandPalette.Complete override..." -ForegroundColor Yellow
$cpFile = Get-Content "$PSScriptRoot\Components\ACO.016_CommandPalette.ps1" -Raw
if ($cpFile -match '\[void\]\s+Complete\s*\(\[object\]\s*\$result\)') {
    Write-Host "✓ CommandPalette.Complete override found" -ForegroundColor Green
} else {
    Write-Host "✗ CommandPalette.Complete override missing" -ForegroundColor Red
    $issues += "CommandPalette.Complete override not found"
}

# Check 2: Dialog visibility fix
Write-Host "`nChecking Dialog.Complete visibility fix..." -ForegroundColor Yellow
$dialogFile = Get-Content "$PSScriptRoot\Components\ACO.014a_Dialog.ps1" -Raw
if ($dialogFile -match '\$this\.Visible\s*=\s*\$false') {
    Write-Host "✓ Dialog visibility fix found" -ForegroundColor Green
} else {
    Write-Host "✗ Dialog visibility fix missing" -ForegroundColor Red
    $issues += "Dialog visibility fix not found"
}

# Check 3: Engine deferred action delay
Write-Host "`nChecking Engine deferred action delay..." -ForegroundColor Yellow
$engineFile = Get-Content "$PSScriptRoot\Runtime\ART.002_EngineManagement.ps1" -Raw
if ($engineFile -match 'DeferredActionDelay') {
    Write-Host "✓ Engine deferred action delay found" -ForegroundColor Green
} else {
    Write-Host "✗ Engine deferred action delay missing" -ForegroundColor Red
    $issues += "Engine deferred action delay not found"
}

# Summary
Write-Host "`n===== Summary =====" -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host "All fixes are properly applied! ✓" -ForegroundColor Green
    Write-Host "`nThe CommandPalette should now:" -ForegroundColor Yellow
    Write-Host "- Close cleanly without visual artifacts" -ForegroundColor Gray
    Write-Host "- Execute selected actions properly" -ForegroundColor Gray
    Write-Host "- Return input control to the main screen" -ForegroundColor Gray
} else {
    Write-Host "Some fixes are missing:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
    Write-Host "`nPlease reapply the fixes or check the COMMANDPALETTE_FIX_SUMMARY.md file" -ForegroundColor Yellow
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
