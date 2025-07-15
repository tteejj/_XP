#!/usr/bin/env pwsh

param(
    [string]$Theme = "Synthwave",
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($env:AXIOM_VERBOSE -eq '1') { 'Continue' } else { 'SilentlyContinue' }
$WarningPreference = $VerbosePreference

# Initialize scriptDir FIRST
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = Get-Location
}

Write-Host "Loading framework from: $scriptDir" -ForegroundColor Yellow

# Load framework files in dependency order
$frameworkFiles = @(
    # Core data types first
    "$scriptDir/Models/AMO.001_Enums.ps1",
    
    # Base infrastructure
    "$scriptDir/Functions/AFU.006_LoggingFunctions.ps1",
    "$scriptDir/Functions/AFU.006a_FileLogger.ps1",
    "$scriptDir/Base/ABC.001_TuiAnsiHelper.ps1",
    "$scriptDir/Base/ABC.001a_ServiceContainer.ps1",
    "$scriptDir/Base/ABC.002_TuiCell.ps1",
    "$scriptDir/Base/ABC.003_TuiBuffer.ps1",
    
    # Drawing and utility functions
    "$scriptDir/Functions/AFU.001_TUIDrawingFunctions.ps1",
    "$scriptDir/Functions/AFU.002_BorderFunctions.ps1",
    "$scriptDir/Functions/AFU.004_ThemeFunctions.ps1",
    "$scriptDir/Functions/AFU.005_FocusManagement.ps1",
    "$scriptDir/Functions/AFU.007_EventFunctions.ps1",
    "$scriptDir/Functions/AFU.008_ErrorHandling.ps1",
    "$scriptDir/Functions/AFU.009_InputProcessing.ps1",
    "$scriptDir/Functions/AFU.010_UtilityFunctions.ps1",
    
    # UI hierarchy
    "$scriptDir/Base/ABC.004_UIElement.ps1",
    "$scriptDir/Base/ABC.005_Component.ps1",
    "$scriptDir/Base/ABC.006_Screen.ps1",
    
    # Models
    "$scriptDir/Models/AMO.002_ValidationBase.ps1",
    "$scriptDir/Models/AMO.003_CoreModelClasses.ps1",
    "$scriptDir/Models/AMO.004_ExceptionClasses.ps1",
    "$scriptDir/Models/AMO.005_NavigationClasses.ps1",
    
    # Components
    "$scriptDir/Components/ACO.001_LabelComponent.ps1",
    "$scriptDir/Components/ACO.002_ButtonComponent.ps1",
    "$scriptDir/Components/ACO.003_TextBoxComponent.ps1",
    "$scriptDir/Components/ACO.004_CheckBoxComponent.ps1",
    "$scriptDir/Components/ACO.005_RadioButtonComponent.ps1",
    "$scriptDir/Components/ACO.006_MultilineTextBoxComponent.ps1",
    "$scriptDir/Components/ACO.007_NumericInputComponent.ps1",
    "$scriptDir/Components/ACO.008_DateInputComponent.ps1",
    "$scriptDir/Components/ACO.009_ComboBoxComponent.ps1",
    "$scriptDir/Components/ACO.010_Table.ps1",
    "$scriptDir/Components/ACO.011_Panel.ps1",
    "$scriptDir/Components/ACO.012_ScrollablePanel.ps1",
    "$scriptDir/Components/ACO.013_GroupPanel.ps1",
    "$scriptDir/Components/ACO.014_ListBox.ps1",
    "$scriptDir/Components/ACO.014a_Dialog.ps1",
    "$scriptDir/Components/ACO.015_TextBox.ps1",
    "$scriptDir/Components/ACO.016_CommandPalette.ps1",
    "$scriptDir/Components/ACO.018_AlertDialog.ps1",
    "$scriptDir/Components/ACO.020_InputDialog.ps1",
    "$scriptDir/Components/ACO.021_NavigationMenu.ps1",
    "$scriptDir/Components/ACO.022_DataGridComponent.ps1",
    "$scriptDir/Components/ACO.023_SidebarMenu.ps1",
    "$scriptDir/Components/ACO.025_SimpleTaskDialog.ps1",
    "$scriptDir/Components/ACO.026_ConfirmDialog.ps1",
    "$scriptDir/Components/ACO.100_TextEngine.ps1",
    
    # Services
    "$scriptDir/Services/ASE.001_Logger.ps1",
    "$scriptDir/Services/ASE.002_EventManager.ps1",
    "$scriptDir/Services/ASE.003_ThemeManager.ps1",
    "$scriptDir/Services/ASE.004_ActionService.ps1",
    "$scriptDir/Services/ASE.005_DataManager.ps1",
    "$scriptDir/Services/ASE.007_KeybindingService.ps1",
    "$scriptDir/Services/ASE.008_NavigationService.ps1",
    "$scriptDir/Services/ASE.009_DialogManager.ps1",
    "$scriptDir/Services/ASE.011_ViewDefinitionService.ps1",
    "$scriptDir/Services/ASE.012_AsyncJobService.ps1",
    "$scriptDir/Services/ASE.014_FileSystemService.ps1",
    
    # Screens
    "$scriptDir/Screens/ASC.001_DashboardScreen.ps1",
    "$scriptDir/Screens/ASC.002_TaskListScreen.ps1",
    "$scriptDir/Screens/ASC.003_ThemeScreen.ps1",
    "$scriptDir/Screens/ASC.004_NewTaskScreen.ps1",
    "$scriptDir/Screens/ASC.005_EditTaskScreen.ps1",
    "$scriptDir/Screens/ASC.005_FileCommanderScreen.ps1",
    "$scriptDir/Screens/ASC.006_TextEditorScreen.ps1",
    "$scriptDir/Screens/ASC.006a_ProjectEditDialog.ps1",
    "$scriptDir/Screens/ASC.007_ProjectInfoScreen.ps1",
    "$scriptDir/Screens/ASC.008_ProjectsListScreen.ps1",
    
    # Runtime (load last)
    "$scriptDir/Runtime/ART.001_GlobalState.ps1",
    "$scriptDir/Runtime/ART.002_EngineManagement.ps1",
    "$scriptDir/Runtime/ART.003_RenderingSystem.ps1",
    "$scriptDir/Runtime/ART.004_InputProcessing.ps1",
    "$scriptDir/Runtime/ART.005_ScreenManagement.ps1",
    "$scriptDir/Runtime/ART.006_ErrorHandling.ps1"
)

foreach ($file in $frameworkFiles) {
    Write-Host "Loading: $file" -ForegroundColor Gray
    . $file
}

# Initialize the framework
Write-Host "Initializing framework..." -ForegroundColor Yellow
Initialize-TuiEngine
Initialize-ServiceContainer -ScriptDir $scriptDir

# Initialize theme
Write-Host "Loading theme: $Theme" -ForegroundColor Yellow
$themeManager = $global:AxiomPhoenixContainer.GetService("ThemeManager")
$themeManager.LoadTheme($Theme)

# Test NewTaskScreen specifically
Write-Host "`n=== CREATING NEWTASKSCREEN IN REAL APP ===" -ForegroundColor Green

$screen = [NewTaskScreen]::new($global:AxiomPhoenixContainer)
$screen.Width = 80
$screen.Height = 24
$screen.Initialize()

Write-Host "Components state in real app:" -ForegroundColor Yellow
Write-Host "  TitleBox - IsFocusable: $($screen._titleBox.IsFocusable), Visible: $($screen._titleBox.Visible), Enabled: $($screen._titleBox.Enabled)" -ForegroundColor White
Write-Host "  SaveButton - IsFocusable: $($screen._saveButton.IsFocusable), Visible: $($screen._saveButton.Visible), Enabled: $($screen._saveButton.Enabled)" -ForegroundColor White

Write-Host "`nTesting services in real app:" -ForegroundColor Yellow
$navService = $screen._navService
$dataManager = $screen._dataManager
Write-Host "  NavigationService: $($navService -ne $null) - Type: $($navService.GetType().Name)" -ForegroundColor White
Write-Host "  DataManager: $($dataManager -ne $null) - Type: $($dataManager.GetType().Name)" -ForegroundColor White

Write-Host "`nTesting focus in real app:" -ForegroundColor Yellow
$focusable = $screen.GetFocusableChildren()
Write-Host "  Focusable components: $($focusable.Count)" -ForegroundColor White

$screen.OnEnter()
$focused = $screen.GetFocusedChild()
$focusedName = if ($focused) { $focused.Name } else { 'none' }
Write-Host "  Initial focus: $focusedName" -ForegroundColor White

# Test button click with real services
Write-Host "`nTesting button click with real services:" -ForegroundColor Yellow
$screen.SetChildFocus($screen._saveButton)
$enterKey = [System.ConsoleKeyInfo]::new([char]13, [ConsoleKey]::Enter, $false, $false, $false)
Write-Host "  Button OnClick handler exists: $($screen._saveButton.OnClick -ne $null)" -ForegroundColor White

try {
    $handled = $screen.HandleInput($enterKey)
    Write-Host "  Enter key handled: $handled" -ForegroundColor Green
} catch {
    Write-Host "  Enter key ERROR: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=== REAL APP TEST COMPLETE ===" -ForegroundColor Green
