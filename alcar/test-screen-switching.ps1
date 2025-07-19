#!/usr/bin/env pwsh
# Test script to verify screen switching works without overlap

Write-Host "Testing screen switching and flicker fixes..." -ForegroundColor Green
Write-Host ""
Write-Host "Navigation:" -ForegroundColor Yellow
Write-Host "  - Use arrow keys to navigate menus"
Write-Host "  - Press 't' for Tasks, 'p' for Projects, 'd' for Dashboard"
Write-Host "  - Press 'q' or Escape to go back"
Write-Host "  - Press Ctrl+Q to quit entirely"
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Cyan
[Console]::ReadKey($true) | Out-Null

# Run the application
& "$PSScriptRoot/bolt.ps1"