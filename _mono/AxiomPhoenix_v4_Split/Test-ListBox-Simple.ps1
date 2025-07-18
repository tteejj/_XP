#!/usr/bin/env pwsh
# Simple ListBox test without any dependencies

Write-Host "=== SIMPLE LISTBOX TEST ===" -ForegroundColor Cyan

# Mock the Request-OptimizedRedraw function
function Request-OptimizedRedraw {
    param([string]$Source, [switch]$Immediate)
    Write-Host "MOCK: Request-OptimizedRedraw called with Source=$Source Immediate=$($Immediate.IsPresent)" -ForegroundColor Green
}

# Initialize global state
$global:TuiState = @{ IsDirty = $false }

# Load classes
. ./Base/ABC.001_TuiAnsiHelper.ps1
. ./Base/ABC.002_TuiCell.ps1  
. ./Base/ABC.003_TuiBuffer.ps1
. ./Base/ABC.004_UIElement.ps1
. ./Components/ACO.014_ListBox.ps1

Write-Host "Creating test ListBox..." -ForegroundColor Yellow

# Create a simple ListBox for testing
$listBox = [ListBox]::new("TestList")
$listBox.AddItem("Item 1")
$listBox.AddItem("Item 2") 
$listBox.AddItem("Item 3")
$listBox.SelectedIndex = 0
$listBox.IsFocused = $true

Write-Host "ListBox created with $($listBox.Items.Count) items" -ForegroundColor Green
Write-Host "Initial SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor Green

# Test arrow key handling directly
Write-Host "`nTesting DOWN ARROW key handling..." -ForegroundColor Yellow

# Create ConsoleKeyInfo for DOWN arrow
$downArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)

Write-Host "Before DOWN arrow - SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

# Test the HandleInput method directly
$result = $listBox.HandleInput($downArrow)

Write-Host "HandleInput returned: $result" -ForegroundColor Yellow
Write-Host "After DOWN arrow - SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

# Test UP arrow
Write-Host "`nTesting UP ARROW key handling..." -ForegroundColor Yellow
$upArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)

Write-Host "Before UP arrow - SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White
$result = $listBox.HandleInput($upArrow)
Write-Host "HandleInput returned: $result" -ForegroundColor Yellow
Write-Host "After UP arrow - SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

Write-Host "`n=== LISTBOX CORE LOGIC TEST COMPLETE ===" -ForegroundColor Cyan