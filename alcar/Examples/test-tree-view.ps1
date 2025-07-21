#!/usr/bin/env pwsh
# Test tree view and edit mode

param(
    [int]$Duration = 10
)

Write-Host "Starting BOLT-AXIOM for $Duration seconds..." -ForegroundColor Cyan
Write-Host "Test:" -ForegroundColor Yellow
Write-Host "- Look for tree view with ▼/▶ indicators" -ForegroundColor Gray
Write-Host "- Press 'e' to enter edit mode (yellow background)" -ForegroundColor Gray
Write-Host "- Press Enter on parent tasks to expand/collapse" -ForegroundColor Gray
Write-Host "- Press 'x' to expand/collapse all" -ForegroundColor Gray
Write-Host ""

# Start bolt.ps1 in background
$process = Start-Process -FilePath "pwsh" -ArgumentList "-File", "./bolt.ps1" -PassThru

# Wait for specified duration
Start-Sleep -Seconds $Duration

# Stop the process
$process | Stop-Process -Force

Write-Host "`nTest completed!" -ForegroundColor Green