#!/usr/bin/env pwsh

# Quick test to verify debug logging works
Write-Host "Testing debug logging..." -ForegroundColor Yellow

# Load just the logger to test
. ./Functions/AFU.006a_FileLogger.ps1

# Initialize basic logger
Initialize-FileLogger -LogPath "./test-debug.log"

Write-Log -Level Debug -Message "TEST: This is a debug message"
Write-Log -Level Info -Message "TEST: This is an info message"

Start-Sleep -Seconds 1

Write-Host "Check test-debug.log for debug messages" -ForegroundColor Green