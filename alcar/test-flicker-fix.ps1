#!/usr/bin/env pwsh
# Direct test for flicker issues

Write-Host "Testing flicker fixes..." -ForegroundColor Cyan
Write-Host "Watch for:" -ForegroundColor Yellow
Write-Host "  1. Smooth initial load (no multiple clears)" -ForegroundColor White
Write-Host "  2. Clean transitions when pressing 't' for Tasks" -ForegroundColor White  
Write-Host "  3. No flicker when navigating with arrow keys" -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to start test..." -ForegroundColor Green
Read-Host

# Run with debug to see loading order
& "$PSScriptRoot/bolt.ps1" -Debug