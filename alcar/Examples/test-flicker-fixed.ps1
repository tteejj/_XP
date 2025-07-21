#!/usr/bin/env pwsh
# Test script to verify flicker fixes

Write-Host "Starting ALCAR with flicker fixes applied..." -ForegroundColor Green
Write-Host "Press Ctrl+Q to quit the application" -ForegroundColor Yellow
Write-Host ""
Start-Sleep -Seconds 2

# Run the application
& "$PSScriptRoot/bolt.ps1"