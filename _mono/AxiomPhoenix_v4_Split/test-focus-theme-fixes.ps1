#!/usr/bin/env pwsh

# Quick test to verify theme and focus fixes
Write-Host "Testing Theme Manager Service Access and Focus System Fixes..." -ForegroundColor Yellow

try {
    # Start the application
    ./Start.ps1
} catch {
    Write-Host "Error during application start: $_" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}