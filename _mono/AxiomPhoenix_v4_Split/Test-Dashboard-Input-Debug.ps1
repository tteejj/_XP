#!/usr/bin/env pwsh
# Test dashboard input routing specifically

Write-Host "=== DASHBOARD INPUT ROUTING TEST ===" -ForegroundColor Cyan

# Start app but intercept before TUI engine starts
$ErrorActionPreference = 'Stop'

# Load the framework
. ./Start.ps1 -Debug

# Get the dashboard screen
$dashboardScreen = $global:TuiState.Services.NavigationService.CurrentScreen
$listBox = $dashboardScreen._menuListBox

Write-Host "`nDashboard Screen Type: $($dashboardScreen.GetType().Name)" -ForegroundColor Yellow
Write-Host "ListBox Type: $($listBox.GetType().Name)" -ForegroundColor Yellow
Write-Host "ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor Yellow
Write-Host "ListBox IsFocused: $($listBox.IsFocused)" -ForegroundColor Yellow
Write-Host "ListBox IsFocusable: $($listBox.IsFocusable)" -ForegroundColor Yellow

# Check which component has focus
$focusedChild = $dashboardScreen.GetFocusedChild()
Write-Host "Dashboard focused child: $(if ($focusedChild) { $focusedChild.GetType().Name } else { 'NULL' })" -ForegroundColor Yellow

# Test dashboard input handling directly
Write-Host "`nTesting DashboardScreen.HandleInput with DOWN arrow..." -ForegroundColor Cyan

$downArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)

Write-Host "BEFORE - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

# Call dashboard HandleInput
$result = $dashboardScreen.HandleInput($downArrow)

Write-Host "DashboardScreen.HandleInput returned: $result" -ForegroundColor Yellow
Write-Host "AFTER - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

# Test if the issue is focus-related
Write-Host "`nTesting focus management..." -ForegroundColor Cyan
$dashboardScreen.SetChildFocus($listBox)
$focusedAfter = $dashboardScreen.GetFocusedChild()
Write-Host "After SetChildFocus - focused child: $(if ($focusedAfter) { $focusedAfter.GetType().Name } else { 'NULL' })" -ForegroundColor Yellow
Write-Host "ListBox IsFocused after SetChildFocus: $($listBox.IsFocused)" -ForegroundColor Yellow

# Test again after explicit focus
Write-Host "`nRetesting after explicit focus..." -ForegroundColor Cyan
$result2 = $dashboardScreen.HandleInput($downArrow)
Write-Host "DashboardScreen.HandleInput returned: $result2" -ForegroundColor Yellow
Write-Host "FINAL - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

Write-Host "`n=== INPUT ROUTING TEST COMPLETE ===" -ForegroundColor Cyan

# Stop the engine to clean up
$global:TuiState.Running = $false