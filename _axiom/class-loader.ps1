# File: class-loader.ps1 (Corrected)
#
# Axiom-Phoenix Type Loader

[CmdletBinding()]
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "🚀 Axiom-Phoenix: Stage 1 - Loading Type Definitions..." -ForegroundColor DarkCyan

# --- The Golden Order of Class Definitions ---
$ClassFileLoadOrder = @(
    # ... (your existing load order remains the same)
    'modules/models/models.psm1',
    'components/tui-primitives/tui-primitives.psm1',
    'modules/theme-manager/theme-manager.psm1',
    'components/ui-classes/ui-classes.psm1',
    'modules/logger/logger.psm1',
    'modules/exceptions/exceptions.psm1',
    'modules/event-system/event-system.psm1',
    'layout/panels-class/panels-class.psm1',
    'components/tui-components/tui-components.psm1',
    'components/advanced-data-components/advanced-data-components.psm1',
    'components/advanced-input-components/advanced-input-components.psm1',
    'modules/dialog-system-class/dialog-system-class.psm1',
    'services/service-container/service-container.psm1',
    'services/action-service/action-service.psm1',
    'services/keybinding-service-class/keybinding-service-class.psm1',
    'services/navigation-service-class/navigation-service-class.psm1',
    'modules/data-manager/data-manager.psm1',
    'modules/panic-handler/panic-handler.psm1',
    'modules/tui-framework/tui-framework.psm1',
    'components/command-palette/command-palette.psm1',
    'components/navigation-class/navigation-class.psm1',
    'screens/dashboard-screen/dashboard-screen.psm1',
    'screens/task-list-screen/task-list-screen.psm1'
)

foreach ($relativePath in $ClassFileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $relativePath
    if (Test-Path $fullPath) {
        try {
            Write-Host "  -> Loading types from: $relativePath" -ForegroundColor DarkGray
            . $fullPath
        } catch {
            throw "Failed to load types from '$fullPath'. Error: $($_.Exception.Message)"
        }
    }
}

Write-Host "✅ All types loaded successfully." -ForegroundColor Green
Write-Host "🚀 Axiom-Phoenix: Stage 2 - Handing off to Application Runner..." -ForegroundColor DarkCyan

# --- Handoff to Stage 2 ---
$runScriptPath = Join-Path $PSScriptRoot "run.ps1"
if (-not (Test-Path $runScriptPath)) {
    throw "Critical boot file 'run.ps1' not found. The application cannot continue."
}

# --- FIX: Sanitize arguments before splatting ---
# Apply the same fix as in start.ps1
$passthroughArgs = $PSBoundParameters.Clone()
$commonParamsToRemove = @('Debug', 'Verbose', 'WhatIf', 'Confirm', 'ErrorAction', 'WarningAction')
foreach ($param in $commonParamsToRemove) {
    if ($passthroughArgs.ContainsKey($param)) {
        $passthroughArgs.Remove($param)
    }
}

# Use the sanitized arguments for the call to run.ps1
& $runScriptPath @passthroughArgs