#!/usr/bin/env pwsh

# Test if IsOverlay property is breaking focus

$ErrorActionPreference = "Stop"

Write-Host "=== TESTING OVERLAY BEHAVIOR ===" -ForegroundColor Green

# Load minimal framework
. "$pwd/Models/AMO.001_Enums.ps1"
. "$pwd/Functions/AFU.006_LoggingFunctions.ps1"
$global:LoggingEnabled = $true
$global:LogLevel = "Debug"

. "$pwd/Base/ABC.001_TuiAnsiHelper.ps1"
. "$pwd/Base/ABC.002_TuiCell.ps1"
. "$pwd/Base/ABC.003_TuiBuffer.ps1"
. "$pwd/Functions/AFU.001_TUIDrawingFunctions.ps1"
. "$pwd/Functions/AFU.002_BorderFunctions.ps1"
. "$pwd/Functions/AFU.004_ThemeFunctions.ps1"

$global:ThemeRegistry = @{
    "palette.primary" = "#0078d4"
    "palette.border" = "#404040"
    "palette.error" = "#ff0000"
    "button.focused.background" = "#0e7490"
    "button.normal.background" = "#007acc"
}

. "$pwd/Base/ABC.004_UIElement.ps1"
. "$pwd/Base/ABC.005_Component.ps1"
. "$pwd/Base/ABC.006_Screen.ps1"
. "$pwd/Components/ACO.001_LabelComponent.ps1"
. "$pwd/Components/ACO.002_ButtonComponent.ps1"
. "$pwd/Components/ACO.003_TextBoxComponent.ps1"
. "$pwd/Components/ACO.011_Panel.ps1"
. "$pwd/Models/AMO.002_ValidationBase.ps1"
. "$pwd/Models/AMO.003_CoreModelClasses.ps1"
. "$pwd/Base/ABC.001a_ServiceContainer.ps1"

$container = [ServiceContainer]::new()
$mockNav = [PSCustomObject]@{}
$mockData = [PSCustomObject]@{}
$container.Register("NavigationService", $mockNav)
$container.Register("DataManager", $mockData)

. "$pwd/Components/ACO.025_SimpleTaskDialog.ps1"

Write-Host "`nTest 1: SimpleTaskDialog WITH IsOverlay=true (original)" -ForegroundColor Yellow
$dialog1 = [SimpleTaskDialog]::new($container, $null)
$dialog1.Width = 80
$dialog1.Height = 24
$dialog1.Initialize()
Write-Host "IsOverlay: $($dialog1.IsOverlay)" -ForegroundColor White

$focusable1 = $dialog1.GetFocusableChildren()
Write-Host "Focusable count: $($focusable1.Count)" -ForegroundColor White

$dialog1.OnEnter()
$focused1 = $dialog1.GetFocusedChild()
if ($focused1) {
    Write-Host "Focus result: $($focused1.Name)" -ForegroundColor Green
} else {
    Write-Host "Focus result: NONE" -ForegroundColor Red
}

Write-Host "`nTest 2: SimpleTaskDialog with IsOverlay=false" -ForegroundColor Yellow
$dialog2 = [SimpleTaskDialog]::new($container, $null)
$dialog2.IsOverlay = $false  # CHANGE THIS
$dialog2.Width = 80
$dialog2.Height = 24
$dialog2.Initialize()
Write-Host "IsOverlay: $($dialog2.IsOverlay)" -ForegroundColor White

$focusable2 = $dialog2.GetFocusableChildren()
Write-Host "Focusable count: $($focusable2.Count)" -ForegroundColor White

$dialog2.OnEnter()
$focused2 = $dialog2.GetFocusedChild()
if ($focused2) {
    Write-Host "Focus result: $($focused2.Name)" -ForegroundColor Green
} else {
    Write-Host "Focus result: NONE" -ForegroundColor Red
}

Write-Host "`nCOMPARISON:" -ForegroundColor Cyan
$result1 = if ($focused1) { $focused1.Name } else { 'NONE' }
$result2 = if ($focused2) { $focused2.Name } else { 'NONE' }
Write-Host "IsOverlay=true : $result1" -ForegroundColor White
Write-Host "IsOverlay=false: $result2" -ForegroundColor White