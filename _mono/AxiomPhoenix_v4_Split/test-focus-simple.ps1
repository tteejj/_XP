#!/usr/bin/env pwsh
# Simple test to create SimpleTaskDialog and trigger focus debug

# Clear debug log
Remove-Item "/tmp/focus-debug.log" -Force -ErrorAction SilentlyContinue

# Navigate to Task List and create new task
Write-Host "Navigate to Task List (press 2), then press 'n' to create new task" -ForegroundColor Yellow
Write-Host "After dialog opens, press Escape to close and check debug log" -ForegroundColor Yellow
Write-Host "Press any key to start..." -ForegroundColor Green
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

pwsh Start.ps1