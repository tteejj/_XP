Write-Host "Running FINAL JSON FIX..." -ForegroundColor Cyan

# Change to the correct directory
Set-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono"

# Run the comprehensive fix
. ".\FINAL-JSON-FIX.ps1"

Write-Host "`nPress any key to continue..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
