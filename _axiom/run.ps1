# File: run.ps1 (Corrected & Simplified)
# Main entry point for the Axiom-Phoenix application
# FIX: Correctly includes ALL module directories and loads modules in a sane order.

param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# --- PARAMETERS & GLOBAL SETTINGS ---
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- STAGE 1: PRE-FLIGHT CLASS LOADING ---
# This is handled by the launcher before this script is even called.
# We can assume all classes are defined.

# --- STAGE 2: MODULE PATH CONFIG & IMPORT ---
$originalModulePath = $env:PSModulePath

# FIX: Added 'components' and 'layout' to the list of paths to search for modules.
# This is the primary fix for the "command not found" error.
$moduleParentPaths = @(
    (Join-Path $PSScriptRoot 'modules'),
    (Join-Path $PSScriptRoot 'services'),
    (Join-Path $PSScriptRoot 'components'),
    (Join-Path $PSScriptRoot 'layout')
) | ForEach-Object { (Get-Item $_).FullName }

$env:PSModulePath = ($moduleParentPaths -join ';') + ';' + $originalModulePath
Write-Host "Temporarily added project module paths to PSModulePath." -ForegroundColor DarkGray

# FIX: This is the corrected and complete module load order.
# It ensures that modules exporting functions (like tui-primitives) are loaded
# before services or other components try to use them.
$ModuleLoadOrder = @(
    # Foundational Systems (no UI dependencies)
    'modules/logger/logger.psd1',
    'modules/exceptions/exceptions.psd1',
    'modules/theme-manager/theme-manager.psm1',
    'modules/event-system/event-system.psm1',
    'modules/panic-handler/panic-handler.psm1',

    # UI Components (These export the FUNCTIONS that the classes need)
    'components/tui-primitives/tui-primitives.psm1',
    'components/tui-components/tui-components.psm1',
    'components/advanced-data-components/advanced-data-components.psm1',
    'components/advanced-input-components/advanced-input-components.psm1',
    'modules/dialog-system-class/dialog-system-class.psm1',
    'components/command-palette/command-palette.psm1',
    'components/navigation-class/navigation-class.psm1',
    
    # Core Services
    'services/service-container/service-container.psd1',
    'services/action-service/action-service.psd1',
    'services/keybinding-service/keybinding-service.psm1',
    'services/navigation-service/navigation-service.psm1',
    'modules/data-manager/data-manager.psm1',
    'modules/tui-framework/tui-framework.psd1',
    
    # The Engine (loads last as it orchestrates everything)
    'modules/tui-engine/tui-engine.psd1'
)

Write-Host "🚀 Loading Axiom-Phoenix modules..."
foreach ($filePath in $ModuleLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) {
        try {
            Import-Module $fullPath -Force -ErrorAction Stop
        } catch {
            Write-Error "FATAL: Failed to import module '$fullPath'. Error: $($_.Exception.Message)"
            Write-Error $_.ScriptStackTrace
            $env:PSModulePath = $originalModulePath 
            exit 1
        }
    } else {
        Write-Error "FATAL: Required module not found: '$fullPath'. Aborting."
        $env:PSModulePath = $originalModulePath 
        exit 1
    }
}
Write-Host "✅ All modules loaded successfully."

# --- MAIN EXECUTION LOGIC (Unchanged) ---
$container = $null 
try {
    Write-Host "`n=== Axiom-Phoenix v4.0 - Starting Up ===" -ForegroundColor Cyan
    
    # 1. Initialize standalone services
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # 2. Create and configure the service container
    $container = Initialize-ServiceContainer
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService }, $true)
    $container.RegisterFactory("KeybindingService", { param($c) New-KeybindingService }, $true)
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager }, $true)
    $container.RegisterFactory("NavigationService", { param($c) Initialize-NavigationService -Services @{ ServiceContainer = $c } }, $true)
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService }, $true)
    
    # 3. Register screen classes with the Navigation Service
    $navService = $container.GetService("NavigationService")
    $navService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # 4. Initialize the Command Palette system
    Register-CommandPalette -ActionService $container.GetService("ActionService") -KeybindingService $container.GetService("KeybindingService")
    
    Write-Host "Service container configured!" -ForegroundColor Green
    
    # 5. Initialize and start the TUI Engine
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
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
        try {
            $tuiFramework = $container.GetService("TuiFramework")
            if ($tuiFramework) { $tuiFramework.StopAllAsyncJobs() }
            $container.Cleanup()
        } catch {
            Write-Warning "Error during service container cleanup: $($_.Exception.Message)"
        }
    }
    try {
        Cleanup-TuiEngine
    } catch {
        Write-Warning "Error during TUI engine cleanup: $($_.Exception.Message)"
    }
    
    $env:PSModulePath = $originalModulePath
    Write-Host "Restored original PSModulePath." -ForegroundColor DarkGray
}