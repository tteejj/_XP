#!/usr/bin/env pwsh
# Test script to debug focus issues

# Start the application with additional focus logging
$env:AXIOM_DEBUG_FOCUS = "true"

# Set strict mode to catch errors
Set-StrictMode -Version Latest

# Start with detailed logging
Write-Host "Starting Axiom Phoenix with focus debugging enabled..." -ForegroundColor Yellow
Write-Host "Instructions:" -ForegroundColor Cyan
Write-Host "1. Navigate to 'New Task' screen" -ForegroundColor White
Write-Host "2. Note if focus starts on the title text box" -ForegroundColor White
Write-Host "3. Press Tab and count how many times needed to reach description box" -ForegroundColor White
Write-Host "4. Try pressing Enter on Save/Cancel buttons" -ForegroundColor White
Write-Host "5. Check the debug log for focus-related messages" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Start the application
& "$PSScriptRoot/Start.ps1"