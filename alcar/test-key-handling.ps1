#!/usr/bin/env pwsh
# Test script to verify key handling in TaskScreen

Write-Host "Key Handling Test for TaskScreen" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Test ConsoleKeyInfo behavior
Write-Host "Testing ConsoleKeyInfo behavior:" -ForegroundColor Yellow

# Test lowercase 'e'
$lowerE = [System.ConsoleKeyInfo]::new('e', [System.ConsoleKey]::E, $false, $false, $false)
Write-Host "Lowercase 'e': KeyChar='$($lowerE.KeyChar)' (ASCII: $([int][char]$lowerE.KeyChar))"

# Test uppercase 'E' 
$upperE = [System.ConsoleKeyInfo]::new('E', [System.ConsoleKey]::E, $true, $false, $false)
Write-Host "Uppercase 'E': KeyChar='$($upperE.KeyChar)' (ASCII: $([int][char]$upperE.KeyChar))"

# Test case-sensitive comparison
Write-Host "`nCase-sensitive comparison test:" -ForegroundColor Yellow
Write-Host "'e' -eq 'e': $('e' -eq 'e')"
Write-Host "'e' -eq 'E': $('e' -eq 'E')"
Write-Host "'E' -eq 'E': $('E' -eq 'E')"

# Simulate menu items
$menuItems = @(
    @{Key='e'; Label='edit'; Action='Edit'},
    @{Key='E'; Label='details'; Action='EditDetails'}
)

Write-Host "`nMenu matching simulation:" -ForegroundColor Yellow

# Test with lowercase e
Write-Host "`nTesting with lowercase 'e':"
foreach ($item in $menuItems) {
    if ($lowerE.KeyChar -eq $item.Key) {
        Write-Host "  MATCH: $($item.Key) -> $($item.Action)" -ForegroundColor Green
    } else {
        Write-Host "  no match: $($item.Key)" -ForegroundColor DarkGray
    }
}

# Test with uppercase E
Write-Host "`nTesting with uppercase 'E':"
foreach ($item in $menuItems) {
    if ($upperE.KeyChar -eq $item.Key) {
        Write-Host "  MATCH: $($item.Key) -> $($item.Action)" -ForegroundColor Green
    } else {
        Write-Host "  no match: $($item.Key)" -ForegroundColor DarkGray
    }
}

Write-Host "`nPress any key to test actual keyboard input..."
Write-Host "Try pressing: e, E (shift+e), d, a" -ForegroundColor Yellow
Write-Host "Press 'q' to quit" -ForegroundColor Yellow
Write-Host ""

# Real keyboard test
while ($true) {
    $key = [Console]::ReadKey($true)
    
    Write-Host "Key pressed: " -NoNewline
    Write-Host "KeyChar='$($key.KeyChar)'" -NoNewline -ForegroundColor Cyan
    Write-Host " ASCII=$([int][char]$key.KeyChar)" -NoNewline -ForegroundColor DarkCyan
    Write-Host " Key=$($key.Key)" -NoNewline -ForegroundColor DarkCyan
    Write-Host " Shift=$($key.Modifiers -band [ConsoleModifiers]::Shift)" -ForegroundColor DarkCyan
    
    # Test against menu items
    foreach ($item in $menuItems) {
        if ($key.KeyChar -eq $item.Key) {
            Write-Host "  -> Would trigger: $($item.Action)" -ForegroundColor Green
        }
    }
    
    if ($key.KeyChar -eq 'q') {
        break
    }
}

Write-Host "`nTest complete!" -ForegroundColor Green