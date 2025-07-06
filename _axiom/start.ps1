# File: launcher.ps1 (Consolidated - Replaces both launcher.ps1 and run.ps1)
# This script is dot-sourced by start.ps1. It loads all classes and then runs the application.

param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# --- GLOBAL SETTINGS ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- STAGE 1: PRE-FLIGHT CLASS LOADING ---
# Dot-source the single file containing ALL class definitions.
# This makes all classes available to the parser because this entire script
# is being run in the top-level scope.
Write-Host "🚀 Axiom-Phoenix: Stage 1 - Loading Type Definitions..." -ForegroundColor DarkCyan
. "$PSScriptRoot\all-classes.ps1"
Write-Host "✅ All types loaded successfully."

# --- STAGE 2: MODULE PATH CONFIG & IMPORT ---
Write-Host "🚀 Axiom-Phoenix: Stage 2 - Loading Modules..." -ForegroundColor DarkCyan
$originalModulePath = $env:PSModulePath
$moduleParentPaths = @(
    (Join-Path $PSScriptRoot 'modules'),
    (Join-Path $PSScriptRoot 'services'),
    (Join-Path $PSScriptRoot 'components'),
    (Join-Path $PSScriptRoot 'layout')
) | ForEach-Object { (Get-Item $_).FullName }
$env:PSModulePath = ($moduleParentPaths -join ';') + ';' + $originalModulePath

$ModuleLoadOrder = @(
    'modules/logger/logger.psd1',
    'modules/exceptions/exceptions.psd1',
    'modules/theme-manager/theme-manager.psm1',
    'modules/event-system/event-system.psm1',
    'modules/panic-handler/panic-handler.psm1',
    'components/tui-primitives/tui-primitives.psm1',
    'components/tui-components/tui-components.psm1',
    'components/advanced-data-components/advanced-data-components.psm1',
    'components/advanced-input-components/advanced-input-components.psm1',
    'modules/dialog-system-class/dialog-system-class.psm1',
    'components/command-palette/command-palette.psm1',
    'components/navigation-class/navigation-class.psm1',
    'services/service-container/service-container.psd1',
    'services/action-service/action-service.psd1',
    'services/keybinding-service/keybinding-service.psm1',
    'services/navigation-service/navigation-service.psm1',
    'modules/data-manager/data-manager.psm1',
    'modules/tui-framework/tui-framework.psd1',
    'modules/tui-engine/tui-engine.psd1'
)

foreach ($filePath in $ModuleLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    Import-Module $fullPath -Force -ErrorAction Stop
}
Write-Host "✅ All modules loaded successfully."

# --- STAGE 3: MAIN EXECUTION LOGIC ---
$container = $null 
try {
    Write-Host "`n=== Axiom-Phoenix v4.0 - Starting Up ===" -ForegroundColor Cyan
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    $container = Initialize-ServiceContainer
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService }, $true)
    $container.RegisterFactory("KeybindingService", { param($c) New-KeybindingService }, $true)
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager }, $true)
    $container.RegisterFactory("NavigationService", { param($c) Initialize-NavigationService -Services @{ ServiceContainer = $c } }, $true)
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService }, $true)
    
    $navService = $container.GetService("NavigationService")
    $navService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    Register-CommandPalette -ActionService $container.GetService("ActionService") -KeybindingService $container.GetService("KeybindingService")
    
    Initialize-TuiEngine
    $initialScreen = $navService.ScreenFactory.CreateScreen("DashboardScreen", @{})
    Start-TuiLoop -InitialScreen $initialScreen
    
} catch {
    Write-Host "`n=== FATAL STARTUP ERROR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    if ($Host.Name -eq 'ConsoleHost' -and $Host.UI.RawUI) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    exit 1
} finally {
    Write-Host "`nApplication has exited. Cleaning up..."
    if ($container) {
        $tuiFramework = $container.GetService("TuiFramework")
        if ($tuiFramework) { $tuiFramework.StopAllAsyncJobs() }
        $container.Cleanup()
    }
    Cleanup-TuiEngine
    
    $env:PSModulePath = $originalModulePath
    Write-Host "Restored original PSModulePath." -ForegroundColor DarkGray
}