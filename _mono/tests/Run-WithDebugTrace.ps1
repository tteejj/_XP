# Run the app with debug tracing for CommandPalette
$ErrorActionPreference = 'Stop'

Clear-Host
Write-Host "=== COMMANDPALETTE EXECUTION TRACE ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting app with debug output enabled..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Watch for these debug messages:" -ForegroundColor Green
Write-Host "1. [DEBUG] Setting up DeferredActions queue..." -ForegroundColor Gray
Write-Host "2. [DEBUG] CommandPalette calling Complete()..." -ForegroundColor Gray
Write-Host "3. [DEBUG] Dialog.Complete called..." -ForegroundColor Gray
Write-Host "4. [DEBUG] CommandPalette OnClose called..." -ForegroundColor Gray
Write-Host "5. [DEBUG] DeferredAction received..." -ForegroundColor Gray
Write-Host "6. [DEBUG] Processing deferred action..." -ForegroundColor Gray
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Press '4' to open Command Palette"
Write-Host "2. Select 'test.simple' action (or any action)"
Write-Host "3. Press Enter"
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Enable debug logging
$env:AXIOM_LOG_LEVEL = "Debug"

# Run the app
& "$PSScriptRoot\Start.ps1"
