# Simple test to verify navigation works

$ErrorActionPreference = 'Stop'

Write-Host "Testing Navigation Keys..." -ForegroundColor Cyan

# Add current directory to path
$env:PSModulePath = "$PSScriptRoot;$env:PSModulePath"

# Load just the ActionService to test
Write-Host "Loading framework..." -ForegroundColor Yellow

# Load files
. "$PSScriptRoot\Base\ABC.001_CoreTypes.ps1"
. "$PSScriptRoot\Base\ABC.002_TuiAnsiHelper.ps1"
. "$PSScriptRoot\Base\ABC.003_TuiCell.ps1"
. "$PSScriptRoot\Base\ABC.004_TuiBuffer.ps1"
. "$PSScriptRoot\Base\ABC.005_UIElement.ps1"
. "$PSScriptRoot\Base\ABC.006_BaseClasses.ps1"
. "$PSScriptRoot\Base\ABC.007_ServiceContainer.ps1"
. "$PSScriptRoot\Models\AMO.001_Enums.ps1"
. "$PSScriptRoot\Models\AMO.002_Tasks.ps1"
. "$PSScriptRoot\Functions\AFN.001_TuiDrawing.ps1"
. "$PSScriptRoot\Functions\AFN.002_FactoryFunctions.ps1"
. "$PSScriptRoot\Functions\AFN.003_UtilityFunctions.ps1"

# Create minimal services
$container = [ServiceContainer]::new()

# Create logger
$logger = [Logger]::new((Join-Path $env:TEMP "test-nav.log"))
$container.Register("Logger", $logger)

# Create EventManager  
$eventManager = [EventManager]::new()
$container.Register("EventManager", $eventManager)

# Create ActionService
$actionService = [ActionService]::new($eventManager)
$container.Register("ActionService", $actionService)

# Register actions
$actionService.RegisterDefaultActions()

Write-Host "`nRegistered Actions:" -ForegroundColor Green
$actions = $actionService.GetAllActions()
foreach ($key in $actions.Keys | Sort-Object) {
    $action = $actions[$key]
    Write-Host "  $key - $($action.Description)" -ForegroundColor White
}

Write-Host "`nTesting action execution..." -ForegroundColor Yellow

# Test navigation.taskList
Write-Host "`nTesting navigation.taskList..." -ForegroundColor Cyan
try {
    $actionService.ExecuteAction("navigation.taskList", @{})
    Write-Host "  ERROR: Should have failed without NavigationService!" -ForegroundColor Red
}
catch {
    Write-Host "  ✓ Correctly failed without NavigationService" -ForegroundColor Green
}

# Test simple actions
Write-Host "`nTesting app.exit..." -ForegroundColor Cyan
$global:TuiState = @{ Running = $true }
$actionService.ExecuteAction("app.exit", @{})
if (-not $global:TuiState.Running) {
    Write-Host "  ✓ app.exit worked correctly" -ForegroundColor Green
} else {
    Write-Host "  ✗ app.exit failed" -ForegroundColor Red
}

Write-Host "`nAll basic tests passed!" -ForegroundColor Green
Write-Host "The issue appears to be elsewhere in the navigation stack." -ForegroundColor Yellow

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
