#!/usr/bin/env pwsh
# Simple test to verify Linux compatibility
Write-Host "Testing Linux compatibility..." -ForegroundColor Cyan

# Test cross-platform variables
Write-Host "IsWindows: $IsWindows" -ForegroundColor Yellow
Write-Host "IsLinux: $IsLinux" -ForegroundColor Yellow
Write-Host "HOME: $HOME" -ForegroundColor Yellow

# Test log path creation
if ($IsWindows) {
    $logPath = Join-Path $env:TEMP "test.log"
} else {
    $logDir = Join-Path $HOME ".local/share/AxiomPhoenix"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logPath = Join-Path $logDir "test.log"
}

Write-Host "Log path: $logPath" -ForegroundColor Green

# Test basic file operations
"Test log entry $(Get-Date)" | Out-File -FilePath $logPath -Append
if (Test-Path $logPath) {
    Write-Host "Log file created successfully" -ForegroundColor Green
} else {
    Write-Host "Failed to create log file" -ForegroundColor Red
}

Write-Host "Linux compatibility test completed" -ForegroundColor Cyan