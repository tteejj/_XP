#!/usr/bin/env pwsh
# Quick test of navigation

# Set debug mode to see what's happening
$global:TuiDebugMode = $true

# Load framework
. './Start.ps1'

# Wait for startup
Start-Sleep -Seconds 2

Write-Host "Framework started. Testing arrow key navigation..."

# Try to navigate and exit quickly
$downKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)
$upKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)
$enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
$escKey = [System.ConsoleKeyInfo]::new([char]27, [ConsoleKey]::Escape, $false, $false, $false)

# Simulate pressing down arrow a few times
for ($i = 0; $i -lt 3; $i++) {
    [Console]::WriteLine("Sending DownArrow key...")
    if ($global:TuiState -and $global:TuiState.CurrentScreen) {
        $result = $global:TuiState.CurrentScreen.HandleInput($downKey)
        Write-Host "HandleInput result: $result"
    }
    Start-Sleep -Milliseconds 500
}

# Try to press Enter on selected item
Write-Host "Pressing Enter..."
if ($global:TuiState -and $global:TuiState.CurrentScreen) {
    $result = $global:TuiState.CurrentScreen.HandleInput($enterKey)
    Write-Host "Enter result: $result"
}

Start-Sleep -Seconds 2

# Exit gracefully
Write-Host "Exiting..."
$global:TuiState.Running = $false