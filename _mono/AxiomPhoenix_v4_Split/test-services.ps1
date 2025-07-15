# Load minimal framework like isolated test
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
    "input.focused.border" = "#0078d4"
    "input.border" = "#404040"
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

# Test different scenarios
Write-Host "Testing scenario: SimpleTaskDialog with different initialization" -ForegroundColor Cyan

# Create real service container like the app does
$container = [ServiceContainer]::new()

# Load and register actual NavigationService
. "$pwd/Services/ASE.008_NavigationService.ps1"
$navService = [NavigationService]::new($container)
$container.Register("NavigationService", $navService)

# Load and register actual DataManager  
. "$pwd/Services/ASE.005_DataManager.ps1"
$dataManager = [DataManager]::new($container)
$container.Register("DataManager", $dataManager)

# Now test SimpleTaskDialog with REAL services
. "$pwd/Components/ACO.025_SimpleTaskDialog.ps1"

$dialog = [SimpleTaskDialog]::new($container, $null)
$dialog.Width = 80
$dialog.Height = 24
$dialog.Initialize()

Write-Host "With REAL services:" -ForegroundColor White
$focusable = $dialog.GetFocusableChildren()
Write-Host "  Focusable count: $($focusable.Count)" -ForegroundColor White

$dialog.OnEnter()
$focused = $dialog.GetFocusedChild()
if ($focused) {
    Write-Host "  Initial focus: $($focused.Name)" -ForegroundColor Green
} else {
    Write-Host "  NO INITIAL FOCUS - SAME AS REAL APP!" -ForegroundColor Red
}
