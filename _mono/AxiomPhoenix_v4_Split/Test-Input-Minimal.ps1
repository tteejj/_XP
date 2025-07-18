#!/usr/bin/env pwsh
# Minimal test to find the exact input routing issue

Write-Host "=== MINIMAL INPUT ROUTING TEST ===" -ForegroundColor Cyan

# Load minimal dependencies
. ./Base/ABC.001_TuiAnsiHelper.ps1
. ./Base/ABC.002_TuiCell.ps1
. ./Base/ABC.003_TuiBuffer.ps1
. ./Base/ABC.004_UIElement.ps1
. ./Base/ABC.006_Screen.ps1
. ./Components/ACO.014_ListBox.ps1

# Mock functions
function Get-ThemeColor { param($path, $fallback = "#ffffff"); return $fallback }
function Request-OptimizedRedraw { param($Source, [switch]$Immediate) }
$global:TuiState = @{ IsDirty = $false }

Write-Host "Creating minimal Screen with ListBox..." -ForegroundColor Yellow

# Create a minimal screen class for testing
class TestScreen : Screen {
    hidden [ListBox] $_listBox
    
    TestScreen() : base("TestScreen", $null) {
        $this.Width = 80
        $this.Height = 24
    }
    
    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        # Create ListBox
        $this._listBox = [ListBox]::new("TestList")
        $this._listBox.X = 10
        $this._listBox.Y = 5
        $this._listBox.Width = 30
        $this._listBox.Height = 10
        $this._listBox.IsFocusable = $true
        $this._listBox.TabIndex = 0
        
        # Add items
        $this._listBox.AddItem("Item 1")
        $this._listBox.AddItem("Item 2")
        $this._listBox.AddItem("Item 3")
        
        # Add to screen
        $this.AddChild($this._listBox)
        
        $this._isInitialized = $true
    }
    
    [ListBox] GetListBox() {
        return $this._listBox
    }
}

# Create and initialize test screen
$screen = [TestScreen]::new()
$screen.Initialize()
$screen.OnEnter()  # Set initial focus

$listBox = $screen.GetListBox()

Write-Host "Screen created with ListBox" -ForegroundColor Green
Write-Host "ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor Yellow
Write-Host "ListBox IsFocused: $($listBox.IsFocused)" -ForegroundColor Yellow

# Check focus
$focused = $screen.GetFocusedChild()
Write-Host "Screen focused child: $(if ($focused) { $focused.GetType().Name } else { 'NULL' })" -ForegroundColor Yellow

# Test Screen.HandleInput (the method that should route to ListBox)
Write-Host "`nTesting Screen.HandleInput routing..." -ForegroundColor Cyan

$downArrow = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)

Write-Host "BEFORE - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

# Call the base Screen.HandleInput method directly
$result = ([Screen]$screen).HandleInput($downArrow)

Write-Host "Screen.HandleInput returned: $result" -ForegroundColor Yellow
Write-Host "AFTER - ListBox SelectedIndex: $($listBox.SelectedIndex)" -ForegroundColor White

Write-Host "`n=== MINIMAL TEST COMPLETE ===" -ForegroundColor Cyan