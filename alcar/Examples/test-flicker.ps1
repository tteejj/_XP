#!/usr/bin/env pwsh
# Test script to identify source of flickering

Write-Host "Testing flicker source..." -ForegroundColor Yellow

# Test 1: Basic render loop
Write-Host "`nTest 1: Checking basic render loop (press any key to stop)"
$i = 0
while (-not [Console]::KeyAvailable) {
    [Console]::SetCursorPosition(0, 3)
    Write-Host "Render count: $i" -NoNewline
    $i++
    Start-Sleep -Milliseconds 20
}
[Console]::ReadKey($true) | Out-Null

# Test 2: With clear
Write-Host "`n`nTest 2: With clear screen (press any key to stop)"
$i = 0
while (-not [Console]::KeyAvailable) {
    [Console]::Clear()
    Write-Host "Render count: $i"
    $i++
    Start-Sleep -Milliseconds 20
}
[Console]::ReadKey($true) | Out-Null

# Test 3: With escape sequences
Write-Host "`n`nTest 3: With escape sequence clear (press any key to stop)"
$i = 0
while (-not [Console]::KeyAvailable) {
    [Console]::Write("`e[2J`e[H")
    [Console]::Write("Render count: $i")
    $i++
    Start-Sleep -Milliseconds 20
}
[Console]::ReadKey($true) | Out-Null

# Test 4: With home only
Write-Host "`n`nTest 4: With home only (press any key to stop)"
$i = 0
while (-not [Console]::KeyAvailable) {
    [Console]::Write("`e[H")
    [Console]::Write("Render count: $i          ")  # Spaces to overwrite
    $i++
    Start-Sleep -Milliseconds 20
}
[Console]::ReadKey($true) | Out-Null

Write-Host "`n`nDone. Which test flickered?"