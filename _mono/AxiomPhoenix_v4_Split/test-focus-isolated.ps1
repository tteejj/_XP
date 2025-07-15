#!/usr/bin/env pwsh

# Minimal isolated test of focus system
# This loads only the essential classes needed to test focus

$ErrorActionPreference = "Stop"

Write-Host "=== ISOLATED FOCUS SYSTEM TEST ===" -ForegroundColor Green

# Load minimal required files in dependency order
Write-Host "Loading essential framework files..." -ForegroundColor Yellow

# Core data structures first  
. "$pwd/Models/AMO.001_Enums.ps1"
. "$pwd/Functions/AFU.006_LoggingFunctions.ps1"

# Initialize minimal logging
$global:LoggingEnabled = $true
$global:LogLevel = "Debug"

# Core UI classes
. "$pwd/Base/ABC.001_TuiAnsiHelper.ps1"
. "$pwd/Base/ABC.002_TuiCell.ps1"
. "$pwd/Base/ABC.003_TuiBuffer.ps1"
. "$pwd/Functions/AFU.001_TUIDrawingFunctions.ps1"
. "$pwd/Functions/AFU.002_BorderFunctions.ps1"
. "$pwd/Functions/AFU.004_ThemeFunctions.ps1"

# Initialize minimal theme
$global:ThemeRegistry = @{
    "input.focused.border" = "#0078d4"
    "input.border" = "#404040"
    "button.focused.background" = "#0078d4"
    "button.focused.foreground" = "#ffffff"
    "button.normal.background" = "#404040"
    "button.normal.foreground" = "#d4d4d4"
    "button.border" = "#666666"
    "button.focused.border" = "#00ff88"
    "button.pressed.foreground" = "#d4d4d4"
    "button.pressed.background" = "#4a5568"
    "button.disabled.foreground" = "#6b7280"
    "button.disabled.background" = "#2d2d30"
    "label.foreground" = "#ffffff"
    "status.success" = "#00ff00"
    "status.warning" = "#ffff00"
    "status.error" = "#ff0000"
    "palette.primary" = "#0078d4"
    "panel.background" = "#1e1e1e"
    "foreground" = "#ffffff"
    "background" = "#000000"
    "border" = "#666666"
    "primary.accent" = "#0078d4"
}

# Core UI hierarchy
. "$pwd/Base/ABC.004_UIElement.ps1"
. "$pwd/Base/ABC.005_Component.ps1"
. "$pwd/Base/ABC.006_Screen.ps1"

# Components needed for NewTaskScreen
. "$pwd/Components/ACO.001_LabelComponent.ps1"
. "$pwd/Components/ACO.002_ButtonComponent.ps1"
. "$pwd/Components/ACO.003_TextBoxComponent.ps1"
. "$pwd/Components/ACO.011_Panel.ps1"

# Models needed for NewTaskScreen
. "$pwd/Models/AMO.002_ValidationBase.ps1"
. "$pwd/Models/AMO.003_CoreModelClasses.ps1"

# Load ServiceContainer
. "$pwd/Base/ABC.001a_ServiceContainer.ps1"

# Create minimal service container - just use mock services
$global:AxiomPhoenixContainer = [ServiceContainer]::new()

# Create mock services to prevent null reference errors
$mockNavService = [PSCustomObject]@{}
$mockDataManager = [PSCustomObject]@{}

$global:AxiomPhoenixContainer.Register("NavigationService", $mockNavService)
$global:AxiomPhoenixContainer.Register("DataManager", $mockDataManager)

# Load NewTaskScreen
. "$pwd/Screens/ASC.004_NewTaskScreen.ps1"

Write-Host "Framework loaded. Testing focus system..." -ForegroundColor Yellow

try {
    # Create screen instance
    Write-Host "`n1. Creating NewTaskScreen instance..." -ForegroundColor Cyan
    $screen = [NewTaskScreen]::new($global:AxiomPhoenixContainer)
    $screen.Width = 80
    $screen.Height = 24
    Write-Host "   ✓ Screen created" -ForegroundColor Green
    
    # Initialize screen
    Write-Host "`n2. Initializing screen..." -ForegroundColor Cyan
    $screen.Initialize()
    Write-Host "   ✓ Screen initialized" -ForegroundColor Green
    
    # Check component states
    Write-Host "`n3. Checking component states..." -ForegroundColor Cyan
    $components = @{
        "TitleBox" = $screen._titleBox
        "DescriptionBox" = $screen._descriptionBox  
        "SaveButton" = $screen._saveButton
        "CancelButton" = $screen._cancelButton
    }
    
    foreach ($name in $components.Keys) {
        $comp = $components[$name]
        if ($comp) {
            Write-Host "   $name - IsFocusable: $($comp.IsFocusable), Visible: $($comp.Visible), Enabled: $($comp.Enabled), TabIndex: $($comp.TabIndex)" -ForegroundColor White
        } else {
            Write-Host "   $name - NULL!" -ForegroundColor Red
        }
    }
    
    # Test focus collection
    Write-Host "`n4. Testing focus collection..." -ForegroundColor Cyan
    $focusable = $screen.GetFocusableChildren()
    Write-Host "   Found $($focusable.Count) focusable components:" -ForegroundColor White
    foreach ($comp in $focusable) {
        Write-Host "     - $($comp.Name) (TabIndex: $($comp.TabIndex))" -ForegroundColor Gray
    }
    
    # Test initial focus
    Write-Host "`n5. Testing initial focus (OnEnter)..." -ForegroundColor Cyan
    $screen.OnEnter()
    $focused = $screen.GetFocusedChild()
    if ($focused) {
        Write-Host "   ✓ Initial focus set to: $($focused.Name)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ No initial focus set!" -ForegroundColor Red
    }
    
    # Test manual focus setting
    Write-Host "`n6. Testing manual focus setting..." -ForegroundColor Cyan
    if ($screen._titleBox) {
        $success = $screen.SetChildFocus($screen._titleBox)
        Write-Host "   SetChildFocus(titleBox) returned: $success" -ForegroundColor White
        $focused = $screen.GetFocusedChild()
        if ($focused -eq $screen._titleBox) {
            Write-Host "   ✓ Manual focus successful" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Manual focus failed" -ForegroundColor Red
        }
    }
    
    # Test tab navigation
    Write-Host "`n7. Testing tab navigation..." -ForegroundColor Cyan
    $tabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
    
    for ($i = 0; $i -lt 5; $i++) {
        $beforeFocus = $screen.GetFocusedChild()
        $beforeName = if ($beforeFocus) { $beforeFocus.Name } else { "none" }
        
        $handled = $screen.HandleInput($tabKey)
        
        $afterFocus = $screen.GetFocusedChild()
        $afterName = if ($afterFocus) { $afterFocus.Name } else { "none" }
        
        Write-Host "   Tab $($i+1): $beforeName -> $afterName (handled: $handled)" -ForegroundColor White
    }
    
    # Test button click
    Write-Host "`n8. Testing button click..." -ForegroundColor Cyan
    if ($screen._saveButton) {
        $screen.SetChildFocus($screen._saveButton)
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
        $handled = $screen.HandleInput($enterKey)
        Write-Host "   Enter on SaveButton handled: $handled" -ForegroundColor White
    }
    
    Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
}