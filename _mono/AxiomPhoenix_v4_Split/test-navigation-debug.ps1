#!/usr/bin/env pwsh
# Test navigation debugging

Write-Host "=== Navigation Debug Test ===" -ForegroundColor Cyan
Write-Host "Starting application and monitoring log for navigation attempts..." -ForegroundColor Yellow

# Start the application in background
$appProcess = Start-Process -FilePath "pwsh" -ArgumentList "-File", "./Start.ps1" -PassThru -NoNewWindow

# Wait for app to start
Start-Sleep -Seconds 3

Write-Host "Application started (PID: $($appProcess.Id))" -ForegroundColor Green
Write-Host "Check the log file for debug messages when you try to navigate to problematic screens" -ForegroundColor Yellow
Write-Host "Log file location: ~/.local/share/AxiomPhoenix/axiom-phoenix.log" -ForegroundColor Gray

# Wait and then kill the process
Start-Sleep -Seconds 15
if (!$appProcess.HasExited) {
    $appProcess.Kill()
    Write-Host "Application terminated." -ForegroundColor Gray
}

# Show recent log entries
$logFile = "~/.local/share/AxiomPhoenix/axiom-phoenix.log"
if (Test-Path $logFile) {
    Write-Host "`nRecent log entries:" -ForegroundColor Yellow
    Get-Content $logFile | Select-Object -Last 20
} else {
    Write-Host "Log file not found at $logFile" -ForegroundColor Red
}