#!/usr/bin/env pwsh
# Test JUST the input routing from Screen to ListBox

Write-Host "=== JUST ROUTING TEST ===" -ForegroundColor Cyan

# Start the full app but pause before engine starts
$ErrorActionPreference = 'Continue'

# Just load everything through Start.ps1 until we get to the engine
Write-Host "Loading framework..." -ForegroundColor Yellow

# Modify Start.ps1 to load everything but stop before Start-AxiomPhoenix
$scriptDir = $PSScriptRoot

# Load the framework
$loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")

foreach ($folder in $loadOrder) {
    $folderPath = Join-Path $scriptDir $folder
    if (Test-Path $folderPath) {
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
        foreach ($file in $files) {
            . $file.FullName
        }
    }
}

Write-Host "Creating services..." -ForegroundColor Yellow
$container = [ServiceContainer]::new()
$container.Register("EventManager", [EventManager]::new())
$container.Register("ThemeManager", [ThemeManager]::new())

# Mock navigation service
class MockNavigationService {
    [void] NavigateTo([object]$screen) { Write-Host "MOCK: Navigate to $($screen.GetType().Name)" }
}
$container.Register("NavigationService", [MockNavigationService]::new())

$global:TuiState = @{ 
    IsDirty = $false
    ServiceContainer = $container
    Services = @{
        EventManager = $container.GetService("EventManager")
        ThemeManager = $container.GetService("ThemeManager")
        NavigationService = $container.GetService("NavigationService")
    }
}

Write-Host "Creating DashboardScreen..." -ForegroundColor Yellow
$dashboard = [DashboardScreen]::new($container)
$dashboard.Width = 80
$dashboard.Height = 24
$dashboard.Initialize()
$dashboard.OnEnter()

Write-Host "Testing routing..." -ForegroundColor Cyan
$listBox = $dashboard._menuListBox

Write-Host "ListBox SelectedIndex BEFORE: $($listBox.SelectedIndex)" -ForegroundColor White
Write-Host "ListBox IsFocused: $($listBox.IsFocused)" -ForegroundColor Yellow

$focused = $dashboard.GetFocusedChild()
Write-Host "Dashboard focused child: $(if ($focused) { $focused.GetType().Name } else { 'NULL' })" -ForegroundColor Yellow

# Test with DOWN arrow
$downArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)

Write-Host "`nCalling Dashboard.HandleInput..." -ForegroundColor Cyan
$result = $dashboard.HandleInput($downArrow)

Write-Host "Dashboard.HandleInput returned: $result" -ForegroundColor Yellow
Write-Host "ListBox SelectedIndex AFTER: $($listBox.SelectedIndex)" -ForegroundColor White

Write-Host "`n=== ROUTING TEST COMPLETE ===" -ForegroundColor Cyan