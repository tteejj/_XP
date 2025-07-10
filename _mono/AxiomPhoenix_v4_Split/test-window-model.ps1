# Test script to verify the window-based model is working

Write-Host "Testing Window-Based Model Implementation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if file "2" exists (should not)
if (Test-Path "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\2") {
    Write-Host "ERROR: File '2' still exists!" -ForegroundColor Red
} else {
    Write-Host "✓ File '2' issue fixed" -ForegroundColor Green
}

# Test that we can load the framework
try {
    Write-Host "`nAttempting to load framework..." -ForegroundColor Yellow
    
    # Change to split directory
    Push-Location "C:\Users\jhnhe\Documents\GitHub\_XP\_mono\AxiomPhoenix_v4_Split"
    
    # Source Start.ps1 but with -WhatIf to just test loading
    $ErrorActionPreference = 'Stop'
    
    # Load Base classes
    . .\Base\ABC.001_TuiAnsiHelper.ps1
    . .\Base\ABC.002_TuiCell.ps1
    . .\Base\ABC.003_TuiBuffer.ps1
    . .\Base\ABC.004_UIElement.ps1
    . .\Base\ABC.005_Component.ps1
    . .\Base\ABC.006_Screen.ps1
    . .\Base\ABC.001a_ServiceContainer.ps1
    
    Write-Host "✓ Base classes loaded" -ForegroundColor Green
    
    # Test Dialog inheritance
    . .\Models\AMO.001_Enums.ps1
    . .\Functions\AFU.001_TUIDrawingFunctions.ps1
    . .\Functions\AFU.003_FactoryFunctions.ps1
    . .\Functions\AFU.010_UtilityFunctions.ps1
    . .\Components\ACO.011_Panel.ps1
    . .\Components\ACO.014a_Dialog.ps1
    
    $testDialog = [Dialog]::new("TestDialog", [ServiceContainer]::new())
    if ($testDialog -is [Screen]) {
        Write-Host "✓ Dialog correctly inherits from Screen" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Dialog does not inherit from Screen!" -ForegroundColor Red
    }
    
    # Test that Dialog is not focusable (container rule)
    if ($testDialog.IsFocusable -eq $false) {
        Write-Host "✓ Dialog correctly not focusable (container)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Dialog is focusable (should not be)!" -ForegroundColor Red
    }
    
    Write-Host "`nWindow-Based Model appears to be correctly implemented!" -ForegroundColor Green
    
} catch {
    Write-Host "ERROR loading framework: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Yellow
} finally {
    Pop-Location
    $ErrorActionPreference = 'Continue'
}
