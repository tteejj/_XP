# Quick test to see if CommandPalette executes actions
# Run this to test the execution flow

$ErrorActionPreference = 'Stop'

# Change to the script directory
Set-Location $PSScriptRoot

# Set debug logging
$env:AXIOM_LOG_LEVEL = "Debug"

Write-Host "Starting CommandPalette execution test..." -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Press '4' to open Command Palette"
Write-Host "2. Type 'test' to find the test action"
Write-Host "3. Press Enter to execute it"
Write-Host "4. Watch for 'TEST ACTION EXECUTED' message"
Write-Host ""

# Start the application
& .\Start.ps1
