#!/usr/bin/env pwsh
# Test edit mode visual feedback

Write-Host "Starting BOLT-AXIOM..." -ForegroundColor Cyan
Write-Host "Instructions:" -ForegroundColor Yellow
Write-Host "1. Press 'e' to edit a task - look for YELLOW bar at bottom" -ForegroundColor Gray
Write-Host "2. Press 's' to add subtask - status bar should say 'EDITING SUBTASK'" -ForegroundColor Gray
Write-Host "3. Press 'd' to delete - should see RED confirmation dialog" -ForegroundColor Gray
Write-Host "4. Press 'E' (shift+e) for detail edit screen" -ForegroundColor Gray
Write-Host ""
Write-Host "Press any key to start..." -ForegroundColor Green
[Console]::ReadKey($true) | Out-Null

# Start the app
. ./bolt.ps1