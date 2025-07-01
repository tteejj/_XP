# debug.ps1
# 'using' statements MUST be the very first thing in the file.
using module '.\components\tui-primitives.psm1'
using module '.\components\ui-classes.psm1'

# --------------------------------------------------------------------
# If the script reaches this point, the two modules above loaded and parsed correctly.
# Any code below here is just for verification.
$ErrorActionPreference = 'Stop'

Write-Host "SUCCESS: Loaded foundational modules." -ForegroundColor Green
Write-Host "Verifying types are accessible..."

try {
    $null = [TuiCell]::new()
    Write-Host "[TuiCell]... OK" -ForegroundColor Green
    
    $null = [UIElement]::new("Test")
    Write-Host "[UIElement]... OK" -ForegroundColor Green

    Write-Host "`nFoundation is SOLID. The problem is in a module loaded after these." -ForegroundColor Cyan
} catch {
    Write-Host "`nVERIFICATION FAILED. This should not happen if the script got this far." -ForegroundColor Red
    $_
}