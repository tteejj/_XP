#!/usr/bin/env pwsh
# Test the enhanced V3 screen with command system

Write-Host "Testing ProjectContextScreenV3_Enhanced..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Features to test:" -ForegroundColor Yellow
Write-Host "1. Improved command line with visual feedback" -ForegroundColor Green
Write-Host "2. Command suggestions and autocomplete" -ForegroundColor Green
Write-Host "3. Command history (↑↓ arrows)" -ForegroundColor Green
Write-Host "4. Context-aware commands" -ForegroundColor Green
Write-Host "5. Command palette (Ctrl+P)" -ForegroundColor Green
Write-Host "6. Three-pane view mode (V key)" -ForegroundColor Green
Write-Host "7. Better alignment and layout" -ForegroundColor Green
Write-Host ""
Write-Host "Command examples:" -ForegroundColor Yellow
Write-Host "  / new task        - Create a new task" -ForegroundColor White
Write-Host "  / edit task login - Edit task with 'login' in title" -ForegroundColor White
Write-Host "  / goto files      - Navigate to files tab" -ForegroundColor White
Write-Host "  / open project web - Open project with 'web' in name" -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to launch..." -ForegroundColor Cyan
Read-Host

& "$PSScriptRoot/bolt.ps1"