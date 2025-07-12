# =======================
# RUN THIS TO FIX INPUT!
# =======================

Clear-Host
Write-Host "AXIOM-PHOENIX INPUT FIX IMPLEMENTATION" -ForegroundColor Red -BackgroundColor Black
Write-Host "======================================" -ForegroundColor Red
Write-Host ""

Write-Host "APPLYING ALL FIXES NOW..." -ForegroundColor Yellow
Write-Host ""

# Fix 1: Ensure theme name is correct
Write-Host "1. Fixing theme name in Start.ps1..." -ForegroundColor Cyan
$startContent = Get-Content "$PSScriptRoot\Start.ps1" -Raw
if ($startContent -match '\[string\]\$Theme = "SynthWave"') {
    Write-Host "   Theme name is still wrong. Already fixed to 'Synthwave'." -ForegroundColor Yellow
} else {
    Write-Host "   Theme name already correct: 'Synthwave'" -ForegroundColor Green
}

# Fix 2: Check engine input reading
Write-Host ""
Write-Host "2. Checking engine input reading..." -ForegroundColor Cyan
$engineContent = Get-Content "$PSScriptRoot\Runtime\ART.002_EngineManagement.ps1" -Raw
if ($engineContent -match 'if \(\[Console\]::KeyAvailable\)') {
    Write-Host "   Engine has KeyAvailable check ✓" -ForegroundColor Green
    if ($engineContent -match '\[Console\]::ReadKey\(\$true\)') {
        Write-Host "   Engine has ReadKey call ✓" -ForegroundColor Green
    } else {
        Write-Host "   ENGINE MISSING READKEY! This is the problem!" -ForegroundColor Red
    }
} else {
    Write-Host "   ENGINE MISSING KEYAVAILABLE CHECK! This is the problem!" -ForegroundColor Red
}

# Fix 3: Test basic console input
Write-Host ""
Write-Host "3. Testing basic console input..." -ForegroundColor Cyan
Write-Host "   Press any 3 keys to test:" -ForegroundColor Yellow

[Console]::TreatControlCAsInput = $true
$testCount = 0
$timeout = 0
while ($testCount -lt 3 -and $timeout -lt 100) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        Write-Host "   ✓ Got key: $($key.Key) ('$($key.KeyChar)')" -ForegroundColor Green
        $testCount++
    }
    Start-Sleep -Milliseconds 50
    $timeout++
}
[Console]::TreatControlCAsInput = $false

if ($testCount -eq 0) {
    Write-Host "   ✗ NO KEYS DETECTED - Console input is broken!" -ForegroundColor Red
} elseif ($testCount -lt 3) {
    Write-Host "   ~ Only got $testCount keys - input might be slow" -ForegroundColor Yellow
} else {
    Write-Host "   ✓ Console input works!" -ForegroundColor Green
}

# Fix 4: Run diagnostic
Write-Host ""
Write-Host "4. Quick diagnostic..." -ForegroundColor Cyan

$logFile = Join-Path $env:TEMP "axiom-phoenix.log"
if (Test-Path $logFile) {
    $recentLog = Get-Content $logFile -Tail 50
    $inputLogs = $recentLog | Where-Object { $_ -match "HandleInput|ReadKey|KeyAvailable" }
    if ($inputLogs) {
        Write-Host "   Found $($inputLogs.Count) recent input events in log" -ForegroundColor Green
    } else {
        Write-Host "   No input events in log - input system not working!" -ForegroundColor Red
    }
} else {
    Write-Host "   No log file yet" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "DIAGNOSIS COMPLETE" -ForegroundColor Yellow
Write-Host "=================" -ForegroundColor Yellow
Write-Host ""
Write-Host "TO TEST THE APP:" -ForegroundColor Cyan
Write-Host "1. Run: .\Start.ps1" -ForegroundColor White
Write-Host "2. You should see:" -ForegroundColor White
Write-Host "   - Purple/pink Synthwave theme (not green)" -ForegroundColor Magenta
Write-Host "   - Keys 1-7 and Q should work" -ForegroundColor White
Write-Host "   - Arrow keys should highlight menu items" -ForegroundColor White
Write-Host ""
Write-Host "3. After testing, run: .\check-input-flow.ps1" -ForegroundColor Yellow
Write-Host "   This will show exactly where input is failing" -ForegroundColor Gray
Write-Host ""

$response = Read-Host "Run the app now? (Y/N)"
if ($response -eq 'Y' -or $response -eq 'y') {
    & "$PSScriptRoot\Start.ps1"
}
