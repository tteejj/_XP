#!/usr/bin/env pwsh
# Test the focus issue by navigating to SimpleTaskDialog

# Clear any existing debug log
if (Test-Path "/tmp/focus-debug.log") {
    Remove-Item "/tmp/focus-debug.log" -Force
}

Write-Host "Starting app in background and navigating to SimpleTaskDialog..." -ForegroundColor Green

# Start the app in background
$job = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    pwsh Start.ps1
}

# Wait for app to start
Start-Sleep 3

# Try to send inputs to navigate to task dialog
# This is tricky with PowerShell jobs, so let's just check if we can access the dialog class directly
Write-Host "Testing SimpleTaskDialog creation..." -ForegroundColor Yellow

try {
    # Load the framework
    . "./Runtime/ART.001_GlobalState.ps1"
    . "./Base/ABC.001_TuiAnsiHelper.ps1"
    . "./Base/ABC.001a_ServiceContainer.ps1"
    . "./Base/ABC.002_TuiCell.ps1"
    . "./Base/ABC.003_TuiBuffer.ps1"
    . "./Base/ABC.004_UIElement.ps1"
    . "./Base/ABC.005_Component.ps1"
    . "./Base/ABC.006_Screen.ps1"
    . "./Components/ACO.003_TextBoxComponent.ps1"
    . "./Components/ACO.002_ButtonComponent.ps1"
    . "./Components/ACO.011_Panel.ps1"
    . "./Components/ACO.025_SimpleTaskDialog.ps1"
    . "./Models/AMO.003_CoreModelClasses.ps1"
    
    # Create minimal service container
    $container = [ServiceContainer]::new()
    
    # Create and initialize dialog
    Write-Host "Creating SimpleTaskDialog..." -ForegroundColor Cyan
    $dialog = [SimpleTaskDialog]::new($container, $null)
    
    Write-Host "Initializing dialog..." -ForegroundColor Cyan
    $dialog.Initialize()
    
    Write-Host "Calling OnEnter..." -ForegroundColor Cyan
    $dialog.OnEnter()
    
    Write-Host "Dialog test completed. Check /tmp/focus-debug.log" -ForegroundColor Green
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}

# Clean up job
if ($job) {
    Stop-Job $job -Force
    Remove-Job $job -Force
}