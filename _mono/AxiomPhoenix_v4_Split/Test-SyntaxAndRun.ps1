# Direct test to check if deferred actions are working
$ErrorActionPreference = 'Stop'

Write-Host "Checking for syntax errors in engine management..." -ForegroundColor Cyan

# Load just the engine management file and check for errors
try {
    . "$PSScriptRoot\Runtime\ART.002_EngineManagement.ps1"
    Write-Host "✓ Engine management file loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ ERROR loading engine management file:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "At line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "Statement: $($_.InvocationInfo.Line)" -ForegroundColor Yellow
    exit 1
}

# Now try to run the full application
Write-Host "`nStarting full application test..." -ForegroundColor Cyan
Write-Host "When the app loads:" -ForegroundColor Yellow
Write-Host "1. Press '4' to open Command Palette" 
Write-Host "2. Find and select 'test.simple' action"
Write-Host "3. Press Enter - it should show a dialog"
Write-Host ""

# Enable debug logging
$env:AXIOM_LOG_LEVEL = "Debug"

# Start the app
& "$PSScriptRoot\Start.ps1"
