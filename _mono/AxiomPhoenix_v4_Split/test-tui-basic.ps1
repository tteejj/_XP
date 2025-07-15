#!/usr/bin/env pwsh
# Simple test to isolate TUI startup issues
Write-Host "=== TUI STARTUP TEST ===" -ForegroundColor Cyan

try {
    Write-Host "Terminal size: $([Console]::WindowWidth) x $([Console]::WindowHeight)" -ForegroundColor Yellow
    
    Write-Host "Testing basic PowerShell TUI functions..." -ForegroundColor Yellow
    
    # Test console access
    Write-Host "Console cursor position: $([Console]::CursorLeft), $([Console]::CursorTop)" -ForegroundColor Green
    
    # Test if we can capture key input (this might reveal the issue)
    Write-Host "Testing key input availability..." -ForegroundColor Yellow
    
    if ($Host.UI.RawUI.KeyAvailable) {
        Write-Host "Key input system is available" -ForegroundColor Green
    } else {
        Write-Host "Key input system not available - this could be the issue!" -ForegroundColor Red
    }
    
    # Test if console supports required operations
    Write-Host "Testing console manipulation..." -ForegroundColor Yellow
    
    # Try to set cursor position
    [Console]::SetCursorPosition(0, [Console]::CursorTop)
    Write-Host "Console manipulation works" -ForegroundColor Green
    
    # Test if we're in an interactive session
    if ($Host.UI.SupportsVirtualTerminal) {
        Write-Host "Virtual terminal sequences supported" -ForegroundColor Green
    } else {
        Write-Host "Virtual terminal sequences NOT supported" -ForegroundColor Red
    }
    
    Write-Host "=== TEST COMPLETED ===" -ForegroundColor Cyan
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "This might explain why TUI exits immediately" -ForegroundColor Yellow
}