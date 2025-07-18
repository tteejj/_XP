#!/usr/bin/env pwsh
# Direct test of arrow key functionality in the dashboard

# Test the actual input pipeline
Write-Host "=== DIRECT ARROW KEY TEST ===" -ForegroundColor Cyan
Write-Host "Starting application and testing arrow keys directly..." -ForegroundColor Yellow

# Load framework first
. ./Start.ps1 -Debug

# Override the dashboard HandleInput to add comprehensive debugging
$dashboardScreen = $global:TuiState.Services.NavigationService.CurrentScreen

# Add direct input testing
Write-Host "`nTesting arrow key detection..." -ForegroundColor Yellow

# Test Console.ReadKey directly
Write-Host "Press UP ARROW now (5 second timeout):" -ForegroundColor Green
$timeout = 5
$startTime = Get-Date

while (((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        Write-Host "DETECTED KEY: $($key.Key) Char='$($key.KeyChar)' Modifiers=$($key.Modifiers)" -ForegroundColor Green
        
        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            Write-Host "SUCCESS: UP ARROW DETECTED!" -ForegroundColor Green
            
            # Test dashboard input handling
            Write-Host "Testing DashboardScreen.HandleInput..." -ForegroundColor Yellow
            $result = $dashboardScreen.HandleInput($key)
            Write-Host "DashboardScreen.HandleInput returned: $result" -ForegroundColor Yellow
            
            # Check ListBox state
            $listBox = $dashboardScreen._menuListBox
            if ($listBox) {
                Write-Host "ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor Yellow
                Write-Host "ListBox IsFocused: $($listBox.IsFocused)" -ForegroundColor Yellow
                Write-Host "ListBox Items.Count: $($listBox.Items.Count)" -ForegroundColor Yellow
            } else {
                Write-Host "ERROR: ListBox is NULL!" -ForegroundColor Red
            }
            break
        }
    }
    Start-Sleep -Milliseconds 100
}

Write-Host "`nPress any key to exit..." -ForegroundColor Gray
[Console]::ReadKey($true) | Out-Null