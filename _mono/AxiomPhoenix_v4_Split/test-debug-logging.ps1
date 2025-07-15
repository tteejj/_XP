#!/usr/bin/env pwsh

# Test if debug logging is working
$ErrorActionPreference = "Stop"

Write-Host "=== TESTING DEBUG LOGGING ===`n" -ForegroundColor Green

# Test basic file write
try {
    "Test message $(Get-Date)" | Out-File "/tmp/debug-test.log" -Append -Force
    Write-Host "✓ Basic file write successful" -ForegroundColor Green
    
    # Check if file was created
    if (Test-Path "/tmp/debug-test.log") {
        Write-Host "✓ File exists at /tmp/debug-test.log" -ForegroundColor Green
        $content = Get-Content "/tmp/debug-test.log"
        Write-Host "✓ File content: $content" -ForegroundColor Green
    } else {
        Write-Host "✗ File does not exist" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ File write failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test the exact debug code from SimpleTaskDialog
try {
    Write-Host "`nTesting exact debug code from SimpleTaskDialog..." -ForegroundColor Yellow
    "=== REAL APP DEBUG START $(Get-Date) ===" | Out-File "/tmp/simpleTaskDialog-debug.log" -Append -Force
    "Test from debug script" | Out-File "/tmp/simpleTaskDialog-debug.log" -Append -Force
    
    if (Test-Path "/tmp/simpleTaskDialog-debug.log") {
        Write-Host "✓ SimpleTaskDialog debug log created" -ForegroundColor Green
        $content = Get-Content "/tmp/simpleTaskDialog-debug.log"
        Write-Host "✓ Debug log content:" -ForegroundColor Green
        $content | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    } else {
        Write-Host "✗ SimpleTaskDialog debug log not created" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ SimpleTaskDialog debug test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nDebug logging test complete.`n" -ForegroundColor Green