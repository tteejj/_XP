#!/usr/bin/env pwsh
# Debug wrapper for Start.ps1
$ErrorActionPreference = 'Continue'
Write-Host "=== DEBUG START ===" -ForegroundColor Cyan

try {
    Write-Host "Loading Start.ps1..." -ForegroundColor Yellow
    & "./Start.ps1" -ErrorAction Continue 2>&1 | Tee-Object -FilePath "startup-debug.log"
    Write-Host "Start.ps1 completed" -ForegroundColor Green
} catch {
    Write-Host "ERROR CAUGHT:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
    $_ | Out-File -FilePath "startup-error.log" -Append
}

Write-Host "=== DEBUG END ===" -ForegroundColor Cyan
Read-Host "Press Enter to continue..."