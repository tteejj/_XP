#!/usr/bin/env pwsh
# Test edit mode functionality

# Load the framework
. ./bolt.ps1 -Debug

Write-Host "`nPress 'e' to enter edit mode on a task" -ForegroundColor Yellow
Write-Host "Look for yellow background and cursor block" -ForegroundColor Yellow
Write-Host "Press Ctrl+C to exit`n" -ForegroundColor Gray