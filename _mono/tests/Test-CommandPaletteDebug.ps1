# Simple test to verify CommandPalette execution with debug output
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "=== COMMANDPALETTE DEBUG TEST ===" -ForegroundColor Cyan
Write-Host ""

# Enable debug logging
$env:AXIOM_LOG_LEVEL = "Debug"

# Add a hook to trace when Start-TuiEngine is called
$global:DebugTrace = @{
    StartTuiEngineCalled = $false
    DeferredActionsCreated = $false
    HandlerRegistered = $false
}

Write-Host "Starting application with debug tracing..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. When app loads, check the console for 'Engine: Setting up DeferredAction handler'" -ForegroundColor Yellow
Write-Host "2. Press '4' to open Command Palette" -ForegroundColor Yellow
Write-Host "3. Find and select 'test.simple' action" -ForegroundColor Yellow
Write-Host "4. Press Enter" -ForegroundColor Yellow
Write-Host "5. Should see 'TEST ACTION EXECUTED' in logs" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Run the app
& .\Start.ps1
