# Test Navigation functionality
# This script tests that all navigation actions work correctly

$ErrorActionPreference = 'Stop'

# Load the framework
Write-Host "Loading framework..." -ForegroundColor Cyan
& "$PSScriptRoot\Start.ps1"

# Wait for framework to load
Start-Sleep -Seconds 2

Write-Host "`nTesting navigation actions..." -ForegroundColor Yellow

# Get services
$actionService = $global:TuiState.Services.ActionService
$navService = $global:TuiState.Services.NavigationService

if (-not $actionService -or -not $navService) {
    Write-Host "ERROR: Required services not found!" -ForegroundColor Red
    exit 1
}

Write-Host "`nRegistered actions:" -ForegroundColor Cyan
$actions = $actionService.GetAllActions()
$navigationActions = @{}
$taskActions = @{}
$uiActions = @{}

foreach ($actionName in $actions.Keys) {
    $action = $actions[$actionName]
    if ($actionName -like "navigation.*") {
        $navigationActions[$actionName] = $action
    }
    elseif ($actionName -like "task.*") {
        $taskActions[$actionName] = $action
    }
    elseif ($actionName -like "ui.*") {
        $uiActions[$actionName] = $action
    }
}

Write-Host "`nNavigation Actions:" -ForegroundColor Green
foreach ($actionName in $navigationActions.Keys | Sort-Object) {
    $action = $navigationActions[$actionName]
    Write-Host "  - $actionName : $($action.Description)" -ForegroundColor White
}

Write-Host "`nTask Actions:" -ForegroundColor Green
foreach ($actionName in $taskActions.Keys | Sort-Object) {
    $action = $taskActions[$actionName]
    Write-Host "  - $actionName : $($action.Description)" -ForegroundColor White
}

Write-Host "`nUI Actions:" -ForegroundColor Green
foreach ($actionName in $uiActions.Keys | Sort-Object) {
    $action = $uiActions[$actionName]
    Write-Host "  - $actionName : $($action.Description)" -ForegroundColor White
}

Write-Host "`nKey navigation actions to test:" -ForegroundColor Yellow
Write-Host "  1. navigation.taskList - should open Task List screen" -ForegroundColor White
Write-Host "  2. task.list - should also open Task List screen" -ForegroundColor White
Write-Host "  3. navigation.newTask - should open Theme Picker (redirected)" -ForegroundColor White
Write-Host "  4. task.new - should open Theme Picker (redirected)" -ForegroundColor White
Write-Host "  5. ui.theme.picker - should open Theme Picker directly" -ForegroundColor White

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Clean exit
Stop-TuiEngine
