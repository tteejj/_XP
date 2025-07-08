Write-Host "Testing stability fixes..." -ForegroundColor Cyan

# Test for ConsoleColor usage
$content = Get-Content ".\AllComponents.ps1" -Raw
$colorProperties = Select-String -InputObject $content -Pattern '\[\s*ConsoleColor\s*\]\s*\$\w+' -AllMatches

if ($colorProperties.Matches.Count -eq 0) {
    Write-Host "✓ No ConsoleColor properties found - GOOD!" -ForegroundColor Green
} else {
    Write-Host "✗ Still found $($colorProperties.Matches.Count) ConsoleColor properties!" -ForegroundColor Red
    $colorProperties.Matches | Select-Object -First 5 | ForEach-Object {
        Write-Host "  - $($_.Value)" -ForegroundColor Yellow
    }
}

# Test for ExecuteAction fix
if ($content -match 'ExecuteAction\s*\(\s*\$selectedAction\.Name\s*,\s*@\{\}\s*\)') {
    Write-Host "✓ ExecuteAction correctly called with empty hashtable - GOOD!" -ForegroundColor Green
} else {
    Write-Host "✗ ExecuteAction not fixed!" -ForegroundColor Red
}

# Test for borderColor variable conflicts
$borderColorConflicts = Select-String -InputObject $content -Pattern '\$borderColor\s*=' -AllMatches
Write-Host "`nChecking for borderColor variable conflicts..."
if ($borderColorConflicts.Matches.Count -eq 0) {
    Write-Host "✓ No borderColor variable conflicts - GOOD!" -ForegroundColor Green
} else {
    Write-Host "⚠ Found $($borderColorConflicts.Matches.Count) potential borderColor variable assignments" -ForegroundColor Yellow
}

Write-Host "`nTrying to run Start.ps1..." -ForegroundColor Cyan
