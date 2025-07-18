#!/usr/bin/env pwsh
# Test script to debug arrow key navigation issue on Dashboard

Write-Host "=== Arrow Key Navigation Debug ===" -ForegroundColor Cyan
Write-Host "Starting minimal test to reproduce the issue..." -ForegroundColor Yellow

# Load only essential components for testing
$scriptDir = $PSScriptRoot
try {
    # Load minimal required files
    . "$scriptDir/Functions/AFU.006a_FileLogger.ps1"
    . "$scriptDir/Runtime/ART.001_GlobalState.ps1"
    . "$scriptDir/Base/ABC.001_TuiAnsiHelper.ps1"
    . "$scriptDir/Base/ABC.002_TuiCell.ps1"
    . "$scriptDir/Base/ABC.003_TuiBuffer.ps1"
    . "$scriptDir/Base/ABC.004_UIElement.ps1"
    . "$scriptDir/Base/ABC.006_Screen.ps1"
    . "$scriptDir/Components/ACO.014_ListBox.ps1"
    . "$scriptDir/Functions/AFU.004_ThemeFunctions.ps1"
    
    Write-Host "Components loaded successfully" -ForegroundColor Green
    
    # Test console input directly
    Write-Host "`nTesting console input directly..." -ForegroundColor Yellow
    Write-Host "Press arrow keys to test input detection. Press 'q' to quit this test." -ForegroundColor Gray
    
    $testCount = 0
    while ($testCount -lt 10) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            Write-Host "Key detected: $($key.Key), Char: '$($key.KeyChar)', Modifiers: $($key.Modifiers)" -ForegroundColor White
            
            if ($key.Key -eq [ConsoleKey]::UpArrow) {
                Write-Host "  -> UP ARROW detected successfully!" -ForegroundColor Green
            } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
                Write-Host "  -> DOWN ARROW detected successfully!" -ForegroundColor Green
            } elseif ($key.KeyChar -eq 'q') {
                Write-Host "Exiting test..." -ForegroundColor Yellow
                break
            }
            
            $testCount++
        }
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "`nTesting ListBox component creation..." -ForegroundColor Yellow
    
    # Create a simple ListBox for testing
    $testListBox = [ListBox]::new("TestList")
    $testListBox.Width = 30
    $testListBox.Height = 10
    $testListBox.IsFocusable = $true
    $testListBox.AddItem("Item 1")
    $testListBox.AddItem("Item 2")
    $testListBox.AddItem("Item 3")
    
    Write-Host "ListBox created with $($testListBox.Items.Count) items" -ForegroundColor Green
    Write-Host "Selected index: $($testListBox.SelectedIndex)" -ForegroundColor Green
    Write-Host "IsFocusable: $($testListBox.IsFocusable)" -ForegroundColor Green
    
    # Test arrow key handling on ListBox
    Write-Host "`nTesting ListBox arrow key handling..." -ForegroundColor Yellow
    
    $upArrowKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::UpArrow, $false, $false, $false)
    $downArrowKey = [System.ConsoleKeyInfo]::new([char]0, [ConsoleKey]::DownArrow, $false, $false, $false)
    
    Write-Host "Initial selected index: $($testListBox.SelectedIndex)" -ForegroundColor White
    
    $handled = $testListBox.HandleInput($downArrowKey)
    Write-Host "After DOWN arrow - Index: $($testListBox.SelectedIndex), Handled: $handled" -ForegroundColor White
    
    $handled = $testListBox.HandleInput($downArrowKey)  
    Write-Host "After DOWN arrow - Index: $($testListBox.SelectedIndex), Handled: $handled" -ForegroundColor White
    
    $handled = $testListBox.HandleInput($upArrowKey)
    Write-Host "After UP arrow - Index: $($testListBox.SelectedIndex), Handled: $handled" -ForegroundColor White
    
    if ($handled) {
        Write-Host "✓ ListBox arrow key handling works correctly!" -ForegroundColor Green
    } else {
        Write-Host "✗ ListBox arrow key handling failed!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "Error during testing: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}

Write-Host "`nTest completed. Check the results above." -ForegroundColor Cyan