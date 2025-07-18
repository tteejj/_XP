#!/usr/bin/env pwsh
# Test dashboard input without starting the engine

Write-Host "=== DASHBOARD ONLY TEST ===" -ForegroundColor Cyan

$ErrorActionPreference = 'Stop'

# Load only what we need
. ./Base/ABC.001_TuiAnsiHelper.ps1
. ./Base/ABC.002_TuiCell.ps1
. ./Base/ABC.003_TuiBuffer.ps1
. ./Base/ABC.004_UIElement.ps1
. ./Base/ABC.006_Screen.ps1
. ./Components/ACO.011_Panel.ps1
. ./Components/ACO.014_ListBox.ps1
. ./Screens/ASC.001_DashboardScreen.ps1
. ./Services/ASE.001_Logger.ps1
. ./Services/ASE.002_EventManager.ps1
. ./Services/ASE.003_ThemeManager.ps1
. ./Base/ABC.001a_ServiceContainer.ps1

# Mock global functions
function Get-ThemeColor { 
    param([string]$path, [string]$fallback = "#ffffff")
    return $fallback
}
function Request-OptimizedRedraw {
    param([string]$Source, [switch]$Immediate)
    Write-Host "MOCK: Request-OptimizedRedraw $Source" -ForegroundColor Green
}

# Initialize minimal state
$global:TuiState = @{ IsDirty = $false }

# Create minimal service container
$container = [ServiceContainer]::new()
$eventManager = [EventManager]::new()
$themeManager = [ThemeManager]::new()
$container.Register("EventManager", $eventManager)  
$container.Register("ThemeManager", $themeManager)

Write-Host "Creating DashboardScreen..." -ForegroundColor Yellow

# Create dashboard
$dashboard = [DashboardScreen]::new($container)
$dashboard.Width = 80
$dashboard.Height = 24
$dashboard.Initialize()

Write-Host "Dashboard created and initialized" -ForegroundColor Green

# Check the ListBox
$listBox = $dashboard._menuListBox
Write-Host "ListBox found: $(if ($listBox) { 'YES' } else { 'NO' })" -ForegroundColor Yellow

if ($listBox) {
    Write-Host "ListBox Type: $($listBox.GetType().Name)" -ForegroundColor Yellow
    Write-Host "ListBox Items Count: $($listBox.Items.Count)" -ForegroundColor Yellow
    Write-Host "ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor Yellow
    Write-Host "ListBox IsFocusable: $($listBox.IsFocusable)" -ForegroundColor Yellow
    Write-Host "ListBox IsFocused: $($listBox.IsFocused)" -ForegroundColor Yellow
    
    # Check focus management
    Write-Host "`nTesting focus management..." -ForegroundColor Cyan
    $dashboard.OnEnter()  # This should set initial focus
    
    $focusedChild = $dashboard.GetFocusedChild()
    Write-Host "Focused child after OnEnter: $(if ($focusedChild) { $focusedChild.GetType().Name } else { 'NULL' })" -ForegroundColor Yellow
    Write-Host "ListBox IsFocused after OnEnter: $($listBox.IsFocused)" -ForegroundColor Yellow
    
    # Test input routing
    Write-Host "`nTesting input routing..." -ForegroundColor Cyan
    $downArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)
    
    Write-Host "BEFORE DOWN - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White
    
    # Test dashboard HandleInput
    $result = $dashboard.HandleInput($downArrow)
    
    Write-Host "Dashboard.HandleInput returned: $result" -ForegroundColor Yellow
    Write-Host "AFTER DOWN - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White
    
    # Test direct ListBox input if dashboard didn't handle it
    if (-not $result) {
        Write-Host "`nDashboard didn't handle input, testing ListBox directly..." -ForegroundColor Cyan
        $listBoxResult = $listBox.HandleInput($downArrow)
        Write-Host "ListBox.HandleInput returned: $listBoxResult" -ForegroundColor Yellow
        Write-Host "AFTER ListBox direct - SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White
    }
}

Write-Host "`n=== DASHBOARD TEST COMPLETE ===" -ForegroundColor Cyan