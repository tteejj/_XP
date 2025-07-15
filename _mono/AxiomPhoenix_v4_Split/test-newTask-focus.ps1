#!/usr/bin/env pwsh

# Test NewTaskScreen focus behavior specifically
# This test will load the NewTaskScreen and check if components are properly focusable

$ErrorActionPreference = "Stop"

# Add the current directory to the path to allow module loading
$env:PSModulePath = "$pwd;$env:PSModulePath"

# Load all required modules
. "$pwd/Runtime/ART.001_GlobalState.ps1"
. "$pwd/Runtime/ART.002_EngineManagement.ps1"

try {
    Write-Host "=== Testing NewTaskScreen Focus System ===" -ForegroundColor Green
    
    # Initialize like Start.ps1 does
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }
    
    # Load all the framework files  
    . "$scriptDir/Runtime/ART.001_GlobalState.ps1"
    . "$scriptDir/Runtime/ART.002_EngineManagement.ps1"
    
    # Initialize the engine
    Initialize-AxiomPhoenix -ScriptDir $scriptDir -LogLevel Debug
    
    # Create NewTaskScreen instance
    $screen = [NewTaskScreen]::new($global:AxiomPhoenixContainer)
    $screen.Width = 80
    $screen.Height = 24
    $screen.Initialize()
    
    Write-Host "`nChecking components after Initialize():" -ForegroundColor Yellow
    
    # Check if title box is focusable
    Write-Host "TitleBox - IsFocusable: $($screen._titleBox.IsFocusable), Enabled: $($screen._titleBox.Enabled), Visible: $($screen._titleBox.Visible), TabIndex: $($screen._titleBox.TabIndex)" -ForegroundColor Cyan
    
    # Check if description box is focusable
    Write-Host "DescriptionBox - IsFocusable: $($screen._descriptionBox.IsFocusable), Enabled: $($screen._descriptionBox.Enabled), Visible: $($screen._descriptionBox.Visible), TabIndex: $($screen._descriptionBox.TabIndex)" -ForegroundColor Cyan
    
    # Check if save button is focusable
    Write-Host "SaveButton - IsFocusable: $($screen._saveButton.IsFocusable), Enabled: $($screen._saveButton.Enabled), Visible: $($screen._saveButton.Visible), TabIndex: $($screen._saveButton.TabIndex)" -ForegroundColor Cyan
    
    # Check if cancel button is focusable
    Write-Host "CancelButton - IsFocusable: $($screen._cancelButton.IsFocusable), Enabled: $($screen._cancelButton.Enabled), Visible: $($screen._cancelButton.Visible), TabIndex: $($screen._cancelButton.TabIndex)" -ForegroundColor Cyan
    
    # Get focusable children
    $focusable = $screen.GetFocusableChildren()
    Write-Host "`nFocusable components found: $($focusable.Count)" -ForegroundColor Yellow
    foreach ($comp in $focusable) {
        Write-Host "  - $($comp.Name) (TabIndex: $($comp.TabIndex))" -ForegroundColor White
    }
    
    # Test OnEnter
    Write-Host "`nTesting OnEnter()..." -ForegroundColor Yellow
    $screen.OnEnter()
    
    # Check what has focus
    $focused = $screen.GetFocusedChild()
    if ($focused) {
        Write-Host "Current focus: $($focused.Name)" -ForegroundColor Green
    } else {
        Write-Host "No component has focus!" -ForegroundColor Red
    }
    
    # Test tab navigation
    Write-Host "`nTesting tab navigation..." -ForegroundColor Yellow
    $tabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
    
    for ($i = 0; $i -lt 5; $i++) {
        $screen.HandleInput($tabKey)
        $focused = $screen.GetFocusedChild()
        if ($focused) {
            Write-Host "Tab $($i+1): Focus on $($focused.Name)" -ForegroundColor White
        } else {
            Write-Host "Tab $($i+1): No focus" -ForegroundColor Red
        }
    }
    
    Write-Host "`n=== Test Complete ===" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}