#!/usr/bin/env pwsh

Write-Host "Testing simple console output"

# Test basic console state
Write-Host "Console size: $([Console]::WindowWidth)x$([Console]::WindowHeight)"

# Test console configuration
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::CursorVisible = $false

Write-Host "Console configured"

# Test manual clear
Write-Host "About to clear screen..."
[Console]::Clear()
Write-Host "Screen cleared"

# Test cursor positioning
[Console]::SetCursorPosition(0, 0)
Write-Host "Cursor positioned"

# Test simple output
for ($i = 0; $i -lt 10; $i++) {
    [Console]::SetCursorPosition(0, $i)
    Write-Host "Line $i"
}

Write-Host "Test completed"