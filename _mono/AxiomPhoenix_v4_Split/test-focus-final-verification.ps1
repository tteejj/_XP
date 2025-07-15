#!/usr/bin/env pwsh

# Final verification that focus is working correctly

$ErrorActionPreference = "Stop"

Write-Host "=== FINAL FOCUS VERIFICATION TEST ===" -ForegroundColor Green

# Minimal setup for testing
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

# Set up global state
$global:TuiState = [PSCustomObject]@{
    FocusedComponent = $null
    IsDirty = $false
    BufferWidth = 120
    BufferHeight = 30
}

$container = [ServiceContainer]::new()
$mockNav = [PSCustomObject]@{}
$mockData = [PSCustomObject]@{}
$container.Register("NavigationService", $mockNav)
$container.Register("DataManager", $mockData)

. "$pwd/Components/ACO.025_SimpleTaskDialog.ps1"

Write-Host "`nCreating SimpleTaskDialog..." -ForegroundColor Yellow
$dialog = [SimpleTaskDialog]::new($container, $null)
$dialog.Width = 120
$dialog.Height = 30
$dialog.Initialize()

Write-Host "`nTesting focus sequence..." -ForegroundColor Yellow

Write-Host "`n1. Before OnEnter():" -ForegroundColor Cyan
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Screen focus: $focusName" -ForegroundColor White
Write-Host "   Global focus: $($global:TuiState.FocusedComponent)" -ForegroundColor White

Write-Host "`n2. After OnEnter():" -ForegroundColor Cyan
$dialog.OnEnter()
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Screen focus: $focusName" -ForegroundColor White
Write-Host "   Global focus: $($global:TuiState.FocusedComponent)" -ForegroundColor White

if ($focused) {
    Write-Host "   TitleBox.IsFocused: $($dialog._titleBox.IsFocused)" -ForegroundColor White
    Write-Host "   TitleBox.IsFocusable: $($dialog._titleBox.IsFocusable)" -ForegroundColor White
}

Write-Host "`n3. Testing Tab navigation:" -ForegroundColor Cyan
$tabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
$handled = $dialog.HandleInput($tabKey)
Write-Host "   Tab handled: $handled" -ForegroundColor White

$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus after Tab: $focusName" -ForegroundColor White

Write-Host "`n4. Testing Enter key on Save button:" -ForegroundColor Cyan
# Tab to Save button (should be at TabIndex 2)
$dialog.SetChildFocus($dialog._saveButton)
$focused = $dialog.GetFocusedChild()
$focusName = if ($focused) { $focused.Name } else { 'NONE' }
Write-Host "   Focus on Save button: $focusName" -ForegroundColor White

$enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
$handled = $dialog.HandleInput($enterKey)
Write-Host "   Enter handled: $handled" -ForegroundColor White

Write-Host "`n=== FOCUS SYSTEM VERIFICATION COMPLETE ===" -ForegroundColor Green

if ($focused -and $global:TuiState.FocusedComponent) {
    Write-Host "✓ Focus system is working correctly!" -ForegroundColor Green
} else {
    Write-Host "✗ Focus system still has issues" -ForegroundColor Red
}