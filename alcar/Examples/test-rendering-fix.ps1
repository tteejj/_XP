#!/usr/bin/env pwsh
# Test the rendering fixes

Write-Host "Testing BOLT-AXIOM rendering fixes..." -ForegroundColor Cyan
Write-Host "This will launch the main menu. Check for:" -ForegroundColor Yellow
Write-Host "  1. No flicker when navigating" -ForegroundColor White
Write-Host "  2. Proper box alignment for selected items" -ForegroundColor White
Write-Host "  3. Description text inside the selection box" -ForegroundColor White
Write-Host "  4. Smooth transitions between screens" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Green
[Console]::ReadKey($true) | Out-Null

# Launch the application
& "$PSScriptRoot/bolt.ps1"