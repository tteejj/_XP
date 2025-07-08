# Test script to verify command palette works without JSON warnings

Write-Host "=== Testing Command Palette Fix ===" -ForegroundColor Cyan

# First apply the fixes
Write-Host "`nApplying fixes..." -ForegroundColor Yellow
& ".\fix-all-json-issues.ps1"

Write-Host "`n`nStarting application to test..." -ForegroundColor Yellow
Write-Host "Press Ctrl+P to open the Command Palette" -ForegroundColor Cyan
Write-Host "If no JSON warnings appear, the fix was successful!" -ForegroundColor Green
Write-Host "Press Ctrl+Q to exit the application" -ForegroundColor Gray

# Small delay to read messages
Start-Sleep -Seconds 2

# Run the application
& ".\Start.ps1"
