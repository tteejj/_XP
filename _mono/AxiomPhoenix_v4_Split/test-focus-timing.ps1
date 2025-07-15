#!/usr/bin/env pwsh

# Test timing of focus during render cycle

$ErrorActionPreference = "Stop"

Write-Host "=== TESTING FOCUS TIMING DURING RENDER ===" -ForegroundColor Green

# Minimal setup
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

$dialog = [SimpleTaskDialog]::new($container, $null)
$dialog.Width = 80
$dialog.Height = 24
$dialog.Initialize()

Write-Host "`nTesting focus at different stages:" -ForegroundColor Yellow

Write-Host "`n1. After Initialize():" -ForegroundColor Cyan
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus: $focusName" -ForegroundColor White

Write-Host "`n2. After OnEnter():" -ForegroundColor Cyan
$dialog.OnEnter()
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus: $focusName" -ForegroundColor White

Write-Host "`n3. After RequestRedraw():" -ForegroundColor Cyan
$dialog.RequestRedraw()
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus: $focusName" -ForegroundColor White

Write-Host "`n4. After OnRender() call:" -ForegroundColor Cyan
try {
    $dialog.OnRender()
    $focused = $dialog.GetFocusedChild()
    $focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus: $focusName" -ForegroundColor White
} catch {
    Write-Host "   OnRender() failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n5. Testing TitleBox focus directly:" -ForegroundColor Cyan
$titleBox = $dialog._titleBox
Write-Host "   TitleBox.IsFocused: $($titleBox.IsFocused)" -ForegroundColor White
Write-Host "   TitleBox.IsFocusable: $($titleBox.IsFocusable)" -ForegroundColor White
Write-Host "   TitleBox.Visible: $($titleBox.Visible)" -ForegroundColor White
Write-Host "   TitleBox.Enabled: $($titleBox.Enabled)" -ForegroundColor White

Write-Host "`n6. Manual focus test:" -ForegroundColor Cyan
$result = $dialog.SetChildFocus($titleBox)
Write-Host "   SetChildFocus result: $result" -ForegroundColor White
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus after manual set: $focusName" -ForegroundColor White
Write-Host "   TitleBox.IsFocused after manual: $($titleBox.IsFocused)" -ForegroundColor White