#!/usr/bin/env pwsh

# Test SimpleTaskDialog focus behavior - the ACTUAL component causing issues

$ErrorActionPreference = "Stop"

Write-Host "=== TESTING SIMPLETASKDIALOG FOCUS SYSTEM ===" -ForegroundColor Green

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
    "palette.primary" = "#0078d4"
    "palette.border" = "#404040"
    "palette.error" = "#ff0000"
    "button.focused.background" = "#0e7490"
    "button.normal.background" = "#007acc"
    "input.focused.border" = "#0078d4"
    "input.border" = "#404040"
    "button.focused.border" = "#00ff88"
    "button.border" = "#666666"
    "foreground" = "#ffffff"
    "background" = "#000000"
}

# Core UI hierarchy
. "$pwd/Base/ABC.004_UIElement.ps1"
. "$pwd/Base/ABC.005_Component.ps1"
. "$pwd/Base/ABC.006_Screen.ps1"

# Components needed for SimpleTaskDialog
. "$pwd/Components/ACO.001_LabelComponent.ps1"
. "$pwd/Components/ACO.002_ButtonComponent.ps1"
. "$pwd/Components/ACO.003_TextBoxComponent.ps1"
. "$pwd/Components/ACO.011_Panel.ps1"

# Models needed
. "$pwd/Models/AMO.002_ValidationBase.ps1"
. "$pwd/Models/AMO.003_CoreModelClasses.ps1"

# Load ServiceContainer
. "$pwd/Base/ABC.001a_ServiceContainer.ps1"

# Create minimal service container
$global:AxiomPhoenixContainer = [ServiceContainer]::new()

# Create mock services
$mockNavService = [PSCustomObject]@{}
$mockDataManager = [PSCustomObject]@{}

$global:AxiomPhoenixContainer.Register("NavigationService", $mockNavService)
$global:AxiomPhoenixContainer.Register("DataManager", $mockDataManager)

# Load SimpleTaskDialog
. "$pwd/Components/ACO.025_SimpleTaskDialog.ps1"

Write-Host "Framework loaded. Testing SimpleTaskDialog..." -ForegroundColor Yellow

try {
    # Create dialog instance for NEW task (this is what user experiences)
    Write-Host "`n1. Creating SimpleTaskDialog instance (new task)..." -ForegroundColor Cyan
    $dialog = [SimpleTaskDialog]::new($global:AxiomPhoenixContainer, $null)
    $dialog.Width = 80
    $dialog.Height = 24
    Write-Host "   ✓ Dialog created (IsOverlay: $($dialog.IsOverlay))" -ForegroundColor Green
    
    # Initialize dialog
    Write-Host "`n2. Initializing dialog..." -ForegroundColor Cyan
    $dialog.Initialize()
    Write-Host "   ✓ Dialog initialized" -ForegroundColor Green
    
    # Check component states
    Write-Host "`n3. Checking component states..." -ForegroundColor Cyan
    $components = @{
        "TitleBox" = $dialog._titleBox
        "DescriptionBox" = $dialog._descriptionBox  
        "SaveButton" = $dialog._saveButton
        "CancelButton" = $dialog._cancelButton
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
    $focusable = $dialog.GetFocusableChildren()
    Write-Host "   Found $($focusable.Count) focusable components:" -ForegroundColor White
    foreach ($comp in $focusable) {
        Write-Host "     - $($comp.Name) (TabIndex: $($comp.TabIndex))" -ForegroundColor Gray
    }
    
    # Test initial focus (OnEnter) - this is where user sees the problem
    Write-Host "`n5. Testing initial focus (OnEnter) - WHERE USER SEES PROBLEM..." -ForegroundColor Cyan
    $dialog.OnEnter()
    $focused = $dialog.GetFocusedChild()
    if ($focused) {
        Write-Host "   ✓ Initial focus set to: $($focused.Name)" -ForegroundColor Green
    } else {
        Write-Host "   ✗ NO INITIAL FOCUS SET! - THIS IS THE PROBLEM" -ForegroundColor Red
    }
    
    # Test manual focus setting
    Write-Host "`n6. Testing manual focus setting..." -ForegroundColor Cyan
    if ($dialog._titleBox) {
        $success = $dialog.SetChildFocus($dialog._titleBox)
        Write-Host "   SetChildFocus(titleBox) returned: $success" -ForegroundColor White
        $focused = $dialog.GetFocusedChild()
        if ($focused -eq $dialog._titleBox) {
            Write-Host "   ✓ Manual focus successful" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Manual focus failed" -ForegroundColor Red
        }
    }
    
    # Test tab navigation - user says needs multiple presses
    Write-Host "`n7. Testing tab navigation (user reports multiple presses needed)..." -ForegroundColor Cyan
    $tabKey = [System.ConsoleKeyInfo]::new([char]9, [ConsoleKey]::Tab, $false, $false, $false)
    
    for ($i = 0; $i -lt 8; $i++) {
        $beforeFocus = $dialog.GetFocusedChild()
        $beforeName = if ($beforeFocus) { $beforeFocus.Name } else { "none" }
        
        $handled = $dialog.HandleInput($tabKey)
        
        $afterFocus = $dialog.GetFocusedChild()
        $afterName = if ($afterFocus) { $afterFocus.Name } else { "none" }
        
        Write-Host "   Tab $($i+1): $beforeName -> $afterName (handled: $handled)" -ForegroundColor White
        
        if ($beforeName -eq $afterName -and $beforeName -ne "none") {
            Write-Host "   ⚠️ Focus didn't change - THIS COULD BE THE MULTIPLE TAB ISSUE" -ForegroundColor Yellow
        }
    }
    
    # Test Enter key on save button - user says doesn't work
    Write-Host "`n8. Testing Enter key on save button (user reports not working)..." -ForegroundColor Cyan
    if ($dialog._saveButton) {
        $dialog.SetChildFocus($dialog._saveButton)
        $focused = $dialog.GetFocusedChild()
        Write-Host "   Save button focused: $($focused -eq $dialog._saveButton)" -ForegroundColor White
        Write-Host "   Save button OnClick handler: $($dialog._saveButton.OnClick -ne $null)" -ForegroundColor White
        
        $enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
        
        # First test: Does dialog HandleInput process Enter?
        $dialogHandled = $dialog.HandleInput($enterKey)
        Write-Host "   Dialog HandleInput processed Enter: $dialogHandled" -ForegroundColor White
        
        # Second test: Does button HandleInput process Enter?
        $dialog.SetChildFocus($dialog._saveButton)
        $buttonHandled = $dialog._saveButton.HandleInput($enterKey)
        Write-Host "   Button HandleInput processed Enter: $buttonHandled" -ForegroundColor White
        
        # Third test: Test with empty title (should show validation error)
        $dialog._titleBox.Text = ""
        Write-Host "   Testing save with empty title..." -ForegroundColor White
        try {
            $dialog._SaveTask()
            Write-Host "   ✓ _SaveTask() executed without error" -ForegroundColor Green
        } catch {
            Write-Host "   ✗ _SaveTask() failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Test typing performance
    Write-Host "`n9. Testing typing performance (user reports slow)..." -ForegroundColor Cyan
    if ($dialog._titleBox) {
        $dialog.SetChildFocus($dialog._titleBox)
        $dialog._titleBox.Text = ""
        
        $testText = "Hello World"
        $startTime = Get-Date
        
        foreach ($char in $testText.ToCharArray()) {
            $keyInfo = [System.ConsoleKeyInfo]::new($char, [ConsoleKey]::A, $false, $false, $false)
            $dialog._titleBox.HandleInput($keyInfo)
        }
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        Write-Host "   Typed '$testText' in $duration ms" -ForegroundColor White
        Write-Host "   Final text: '$($dialog._titleBox.Text)'" -ForegroundColor White
        Write-Host "   Average per character: $([Math]::Round($duration / $testText.Length, 2)) ms" -ForegroundColor White
        
        if ($duration -gt 500) {
            Write-Host "   ⚠️ SLOW TYPING DETECTED - Over 500ms for $($testText.Length) characters" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n=== SIMPLETASKDIALOG TEST COMPLETE ===" -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "At: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
}