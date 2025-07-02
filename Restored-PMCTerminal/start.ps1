# start.ps1 (CORRECTED)

param(
    [switch]$Debug,
    [switch]$SkipLogo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$PSScriptRoot = Get-Location
$MainScriptPath = Join-Path $PSScriptRoot '_CLASSY-MAIN.ps1'

# This is the verified load order, taken from the original build script.
$FileLoadOrder = @(
    'modules\logger\logger.psm1',
    'modules\exceptions\exceptions.psm1',
    'modules\models\models.psm1',
    'components\tui-primitives\tui-primitives.psm1',
    'modules\event-system\event-system.psm1',
    'modules\theme-manager\theme-manager.psm1',
    'components\ui-classes\ui-classes.psm1',
    'layout\panels-class\panels-class.psm1',
    'components\navigation-class\navigation-class.psm1',
    'components\tui-components\tui-components.psm1',
    'components\advanced-data-components\advanced-data-components.psm1',
    'components\advanced-input-components\advanced-input-components.psm1',
    'modules\data-manager-class\data-manager-class.psm1',
    'services\keybinding-service-class\keybinding-service-class.psm1',
    'modules\dialog-system-class\dialog-system-class.psm1',
    'screens\dashboard-screen\dashboard-screen.psm1',
    'screens\task-list-screen\task-list-screen.psm1',
    'services\navigation-service-class\navigation-service-class.psm1',
    'modules\data-manager\data-manager.psm1',
    'services\keybinding-service\keybinding-service.psm1',
    'services\navigation-service\navigation-service.psm1',
    'modules\tui-engine\tui-engine.psm1',
    'modules\tui-framework\tui-framework.psm1'
)

Write-Host "Loading application modules..." -ForegroundColor Cyan

# Use dot-sourcing to load all functions and classes into the current scope.
foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) {
        Write-Host "  -> Loading $filePath"
        # THIS IS THE CRITICAL LINE
        . $fullPath
    } else {
        Write-Warning "Module file not found, skipping: $filePath"
    }
}

Write-Host "All modules loaded. Starting application..." -ForegroundColor Green

# Pass the parameters from this script down to the main logic script.
& $MainScriptPath @PSBoundParameters