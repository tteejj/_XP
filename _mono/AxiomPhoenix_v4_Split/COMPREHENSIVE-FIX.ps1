# AXIOM-PHOENIX COMPREHENSIVE INPUT FIX
# =====================================

Clear-Host
Write-Host @"
╔═══════════════════════════════════════════════════════════════╗
║              AXIOM-PHOENIX INPUT SYSTEM FIX                   ║
╚═══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Red

Write-Host "`nCRITICAL FIXES APPLIED:" -ForegroundColor Yellow
Write-Host "=======================" -ForegroundColor Yellow

Write-Host "`n1. FIXED MISSING SERVICE FILE" -ForegroundColor Green
Write-Host "   - Restored ASE.006_FocusManager.ps1 from .bak file" -ForegroundColor White
Write-Host "   - Removed duplicate ASE.008_ThemeManager.ps1" -ForegroundColor White

Write-Host "`n2. FIXED THEME NAME" -ForegroundColor Green
Write-Host "   - Changed 'SynthWave' to 'Synthwave' (case sensitive)" -ForegroundColor White

Write-Host "`n3. FIXED ENGINE INPUT LOOP" -ForegroundColor Green
Write-Host "   - Added Console.KeyAvailable check" -ForegroundColor White
Write-Host "   - Added Console.ReadKey($true) call" -ForegroundColor White
Write-Host "   - Added TreatControlCAsInput = true" -ForegroundColor White

Write-Host "`n4. ADDED DEBUG LOGGING" -ForegroundColor Green
Write-Host "   - Engine logs when keys are read" -ForegroundColor White
Write-Host "   - NavigationService logs CurrentScreen changes" -ForegroundColor White
Write-Host "   - DashboardScreen logs HandleInput calls" -ForegroundColor White

Write-Host "`n`nIMPORTANT TESTS TO RUN:" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan

Write-Host "`n1. TEST BASIC CONSOLE INPUT:" -ForegroundColor Yellow
Write-Host "   .\test-console-input.ps1" -ForegroundColor White
Write-Host "   - This verifies PowerShell can read keys at all" -ForegroundColor Gray

Write-Host "`n2. TEST ENGINE SIMULATION:" -ForegroundColor Yellow
Write-Host "   .\simulate-engine-input.ps1" -ForegroundColor White
Write-Host "   - This simulates the exact engine input loop" -ForegroundColor Gray

Write-Host "`n3. RUN THE ACTUAL APP:" -ForegroundColor Yellow
Write-Host "   .\Start.ps1" -ForegroundColor White
Write-Host "   - Should show Synthwave theme (purple/pink)" -ForegroundColor Gray
Write-Host "   - Press keys: 1, 2, 3, Q, arrows" -ForegroundColor Gray

Write-Host "`n4. CHECK THE INPUT FLOW:" -ForegroundColor Yellow
Write-Host "   .\check-input-flow.ps1" -ForegroundColor White
Write-Host "   - Shows exactly where input chain breaks" -ForegroundColor Gray

Write-Host "`n`nQUICK TEST NOW?" -ForegroundColor Cyan
Write-Host "===============" -ForegroundColor Cyan
Write-Host "Let's do a quick console input test right here..." -ForegroundColor White
Write-Host "Press any 3 keys:" -ForegroundColor Yellow

# Quick test
[Console]::TreatControlCAsInput = $true
[Console]::CursorVisible = $false
$testKeys = @()
$timeout = 0

while ($testKeys.Count -lt 3 -and $timeout -lt 200) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        $testKeys += $key
        Write-Host "  ✓ Got: $($key.Key) ('$($key.KeyChar)')" -ForegroundColor Green
    }
    Start-Sleep -Milliseconds 25
    $timeout++
}

[Console]::TreatControlCAsInput = $false
[Console]::CursorVisible = $true

if ($testKeys.Count -eq 0) {
    Write-Host "`n  ✗ NO KEYS DETECTED!" -ForegroundColor Red
    Write-Host "  Console input is NOT working in this PowerShell session!" -ForegroundColor Red
    Write-Host "  Try:" -ForegroundColor Yellow
    Write-Host "  - Running PowerShell as Administrator" -ForegroundColor White
    Write-Host "  - Using Windows Terminal instead of ISE" -ForegroundColor White
    Write-Host "  - Checking if antivirus is blocking console input" -ForegroundColor White
} else {
    Write-Host "`n  ✓ Console input WORKS! Got $($testKeys.Count) keys" -ForegroundColor Green
    Write-Host "  The app should work now!" -ForegroundColor Green
}

Write-Host "`n`nPress Enter to launch the app..." -ForegroundColor Yellow
Read-Host

# Clear log before starting
$logFile = Join-Path $env:TEMP "axiom-phoenix.log"
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
    Write-Host "Cleared old log file" -ForegroundColor Gray
}

# Launch app
& "$PSScriptRoot\Start.ps1"
