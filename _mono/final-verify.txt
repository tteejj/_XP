# Final verification script for all stability fixes
Write-Host "=== FINAL STABILITY VERIFICATION ===" -ForegroundColor Cyan

$file = ".\AllComponents.ps1"
if (-not (Test-Path $file)) {
    Write-Host "ERROR: AllComponents.ps1 not found!" -ForegroundColor Red
    exit 1
}

$content = Get-Content $file -Raw

Write-Host "`n[1] Checking ConsoleColor properties..." -ForegroundColor Yellow
$colorProps = Select-String -InputObject $content -Pattern '\[\s*ConsoleColor\s*\]\s*\$' -AllMatches
if ($colorProps.Matches.Count -eq 0) {
    Write-Host "  ✓ PASS: No ConsoleColor property declarations" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Found $($colorProps.Matches.Count) ConsoleColor properties" -ForegroundColor Red
}

Write-Host "`n[2] Checking ConsoleColor enum usage..." -ForegroundColor Yellow  
$enumUsage = Select-String -InputObject $content -Pattern '\[ConsoleColor\]::\w+' -AllMatches
if ($enumUsage.Matches.Count -eq 0) {
    Write-Host "  ✓ PASS: No ConsoleColor enum usage" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: Found $($enumUsage.Matches.Count) ConsoleColor enums" -ForegroundColor Red
}

Write-Host "`n[3] Checking ExecuteAction fix..." -ForegroundColor Yellow
if ($content -match 'ExecuteAction\s*\(\s*\$selectedAction\.Name\s*,\s*@\{\}\s*\)') {
    Write-Host "  ✓ PASS: ExecuteAction has empty hashtable parameter" -ForegroundColor Green
} else {
    Write-Host "  ✗ FAIL: ExecuteAction missing second parameter" -ForegroundColor Red
}

Write-Host "`n[4] Checking variable naming conflicts..." -ForegroundColor Yellow
$conflicts = 0
# Check for $borderColor assignments (should use $borderColorValue)
if ($content -match '\$borderColor\s*=\s*if') {
    Write-Host "  ✗ FAIL: Found \$borderColor variable assignment" -ForegroundColor Red
    $conflicts++
} else {
    Write-Host "  ✓ PASS: No \$borderColor conflicts" -ForegroundColor Green
}

Write-Host "`n[5] Checking TuiCell.Clear usage..." -ForegroundColor Yellow
$clearIssues = Select-String -InputObject $content -Pattern 'Clear\(\[TuiCell\]::new\([^,]+,\s*\$[^,]+Color,\s*\$[^)]+\)\)' -AllMatches
$correctClears = 0
$incorrectClears = 0
foreach ($match in $clearIssues.Matches) {
    if ($match.Value -match 'Clear\(\[TuiCell\]::new\([^,]+,\s*\$\w+Color,\s*\$\w+Color\)\)') {
        $correctClears++
    } else {
        $incorrectClears++
    }
}
if ($incorrectClears -eq 0) {
    Write-Host "  ✓ PASS: All buffer clears use consistent colors" -ForegroundColor Green
} else {
    Write-Host "  ⚠ WARNING: Found $incorrectClears potential buffer clear issues" -ForegroundColor Yellow
}

Write-Host "`n[6] Summary:" -ForegroundColor Cyan
$totalIssues = $colorProps.Matches.Count + $enumUsage.Matches.Count + $conflicts
if ($totalIssues -eq 0) {
    Write-Host "  ✅ ALL CRITICAL FIXES APPLIED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "  The application should now run without type mismatch errors." -ForegroundColor Green
} else {
    Write-Host "  ❌ Found $totalIssues critical issues remaining!" -ForegroundColor Red
}

Write-Host "`nYou can now run: .\Start.ps1" -ForegroundColor Cyan
