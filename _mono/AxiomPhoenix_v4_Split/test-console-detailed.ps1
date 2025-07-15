#!/usr/bin/env pwsh
# Test each console operation individually
Write-Host "=== DETAILED CONSOLE TEST ===" -ForegroundColor Cyan

$operations = @(
    @{ Name = "Get CursorVisible"; Code = { [Console]::CursorVisible } },
    @{ Name = "Set CursorVisible False"; Code = { [Console]::CursorVisible = $false } },
    @{ Name = "Set CursorVisible True"; Code = { [Console]::CursorVisible = $true } },
    @{ Name = "Get WindowWidth"; Code = { [Console]::WindowWidth } },
    @{ Name = "Get WindowHeight"; Code = { [Console]::WindowHeight } },
    @{ Name = "Set OutputEncoding UTF8"; Code = { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } },
    @{ Name = "Set InputEncoding UTF8"; Code = { [Console]::InputEncoding = [System.Text.Encoding]::UTF8 } },
    @{ Name = "Set TreatControlCAsInput"; Code = { [Console]::TreatControlCAsInput = $true } },
    @{ Name = "KeyAvailable"; Code = { [Console]::KeyAvailable } },
    @{ Name = "SetCursorPosition"; Code = { [Console]::SetCursorPosition(0, 0) } },
    @{ Name = "Clear"; Code = { [Console]::Clear() } },
    @{ Name = "Host UI WindowTitle Get"; Code = { $Host.UI.RawUI.WindowTitle } },
    @{ Name = "Host UI WindowTitle Set"; Code = { $Host.UI.RawUI.WindowTitle = "Test" } },
    @{ Name = "Host UI WindowSize"; Code = { $Host.UI.RawUI.WindowSize } },
    @{ Name = "Host UI BufferSize"; Code = { $Host.UI.RawUI.BufferSize } }
)

foreach ($op in $operations) {
    try {
        Write-Host -NoNewline "Testing $($op.Name): " -ForegroundColor Yellow
        $result = & $op.Code
        Write-Host "✓ SUCCESS" -ForegroundColor Green
        if ($result -ne $null) {
            Write-Host "  Result: $result" -ForegroundColor Gray
        }
    } catch {
        Write-Host "✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== ALTERNATIVE APPROACHES ===" -ForegroundColor Cyan

# Test ANSI escape sequences
try {
    Write-Host -NoNewline "Testing ANSI cursor hide: " -ForegroundColor Yellow
    Write-Host -NoNewline "`e[?25l"  # Hide cursor
    Write-Host "✓ SUCCESS" -ForegroundColor Green
    
    Write-Host -NoNewline "Testing ANSI cursor show: " -ForegroundColor Yellow  
    Write-Host -NoNewline "`e[?25h"  # Show cursor
    Write-Host "✓ SUCCESS" -ForegroundColor Green
    
    Write-Host -NoNewline "Testing ANSI clear screen: " -ForegroundColor Yellow
    # Don't actually clear, just test the sequence
    # Write-Host -NoNewline "`e[2J`e[H"  
    Write-Host "✓ SUCCESS (not executed)" -ForegroundColor Green
    
} catch {
    Write-Host "✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== ENVIRONMENT INFO ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor Gray
Write-Host "OS: $($PSVersionTable.OS)" -ForegroundColor Gray
Write-Host "Terminal: $env:TERM" -ForegroundColor Gray
Write-Host "Terminal Program: $env:TERM_PROGRAM" -ForegroundColor Gray