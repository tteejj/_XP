# Verify All Fixes Are In Place
# =============================

Clear-Host
Write-Host "VERIFYING ALL FIXES..." -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

$issues = @()

# Check 1: Theme name
Write-Host "1. Checking theme name..." -ForegroundColor Yellow
$startContent = Get-Content "$PSScriptRoot\Start.ps1" -Raw
if ($startContent -match '\[string\]\$Theme = "Synthwave"') {
    Write-Host "   ✓ Theme name is correct: 'Synthwave'" -ForegroundColor Green
} else {
    Write-Host "   ✗ Theme name is WRONG!" -ForegroundColor Red
    $issues += "Theme name not 'Synthwave'"
}

# Check 2: Engine input
Write-Host "`n2. Checking engine input loop..." -ForegroundColor Yellow
$enginePath = "$PSScriptRoot\Runtime\ART.002_EngineManagement.ps1"
if (Test-Path $enginePath) {
    $engineContent = Get-Content $enginePath -Raw
    if ($engineContent -match 'if \(\[Console\]::KeyAvailable\)') {
        Write-Host "   ✓ Has KeyAvailable check" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Missing KeyAvailable check!" -ForegroundColor Red
        $issues += "Missing KeyAvailable in engine"
    }
    
    if ($engineContent -match '\$keyInfo = \[Console\]::ReadKey\(\$true\)') {
        Write-Host "   ✓ Has ReadKey call" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Missing ReadKey call!" -ForegroundColor Red
        $issues += "Missing ReadKey in engine"
    }
    
    if ($engineContent -match 'Process-TuiInput -KeyInfo \$keyInfo') {
        Write-Host "   ✓ Passes KeyInfo to Process-TuiInput" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Not passing KeyInfo parameter!" -ForegroundColor Red
        $issues += "Not passing KeyInfo to Process-TuiInput"
    }
} else {
    Write-Host "   ✗ Engine file not found!" -ForegroundColor Red
    $issues += "Engine file missing"
}

# Check 3: FocusManager service
Write-Host "`n3. Checking FocusManager service..." -ForegroundColor Yellow
$focusPath = "$PSScriptRoot\Services\ASE.006_FocusManager.ps1"
if (Test-Path $focusPath) {
    Write-Host "   ✓ FocusManager.ps1 exists" -ForegroundColor Green
} else {
    Write-Host "   ✗ FocusManager.ps1 MISSING!" -ForegroundColor Red
    Write-Host "     Only .bak files found" -ForegroundColor Red
    $issues += "FocusManager.ps1 missing"
}

# Check 4: No duplicate services
Write-Host "`n4. Checking for duplicate services..." -ForegroundColor Yellow
$themeManagers = Get-ChildItem "$PSScriptRoot\Services" -Filter "*ThemeManager.ps1"
if ($themeManagers.Count -eq 1) {
    Write-Host "   ✓ Only one ThemeManager.ps1" -ForegroundColor Green
} else {
    Write-Host "   ✗ Multiple ThemeManager files!" -ForegroundColor Red
    $themeManagers | ForEach-Object { Write-Host "     - $($_.Name)" -ForegroundColor Red }
    $issues += "Multiple ThemeManager files"
}

# Check 5: Console settings
Write-Host "`n5. Checking console settings in engine..." -ForegroundColor Yellow
if ($engineContent -match 'TreatControlCAsInput = \$true') {
    Write-Host "   ✓ Has TreatControlCAsInput setting" -ForegroundColor Green
} else {
    Write-Host "   ~ Missing TreatControlCAsInput (optional)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
if ($issues.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED! ✓" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host "The input system should work now." -ForegroundColor Green
} else {
    Write-Host "FOUND $($issues.Count) ISSUES! ✗" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host "" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    Write-Host "`nThese issues MUST be fixed for input to work!" -ForegroundColor Yellow
}
Write-Host ("=" * 60) -ForegroundColor Cyan

Write-Host "`nPress Enter to continue..." -ForegroundColor Gray
Read-Host
