param(
    [switch]$Debug,
    [switch]$SkipLogo
)# Point PSModulePath at your modules folder, not the repo root:
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$env:PSModulePath = "$PSScriptRoot\modules;$env:PSModulePath"

# run.ps1 - Main entry point for the Axiom-Phoenix application
# FINAL v2 - With PSModulePath fix for dependency resolution

# --- PARAMETERS & GLOBAL SETTINGS ---

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Make your local modules folder transparently available for `using module`.
$env:PSModulePath = "$PSScriptRoot\modules;$env:PSModulePath"

# --- CRITICAL FIX: Add project root to the PSModulePath ---
# This allows PowerShell's module loader to find local dependencies (RequiredModules).
# We prepend it so our project's modules are found first.
$originalModulePath = $env:PSModulePath
$env:PSModulePath = "$PSScriptRoot;$originalModulePath"
Write-Host "Temporarily added '$PSScriptRoot' to PSModulePath." -ForegroundColor DarkGray

# --- MODULE SOURCING ---
# The load order should still respect class inheritance dependencies.
$FileLoadOrder = @(
    'modules/logger/logger.psd1',
    'modules/exceptions/exceptions.psd1',
    'modules/panic-handler/panic-handler.psd1',
    'modules/event-system/event-system.psd1',
    'modules/models/models.psd1',
    'components/tui-primitives/tui-primitives.psd1',
    'modules/theme-manager/theme-manager.psd1',
    'components/ui-classes/ui-classes.psd1',
    'layout/panels-class/panels-class.psd1', # This will now find its dependencies
    'services/service-container/service-container.psd1',
    'services/action-service/action-service.psd1',
    'services/keybinding-service-class/keybinding-service-class.psd1',
    'services/keybinding-service/keybinding-service.psd1',
    'services/navigation-service-class/navigation-service-class.psd1',
    'services/navigation-service/navigation-service.psd1',
    'components/command-palette/command-palette.psd1',
    'modules/dialog-system-class/dialog-system-class.psd1',
    'components/tui-components/tui-components.psd1',
    'components/advanced-data-components/advanced-data-components.psd1',
    'components/advanced-input-components/advanced-input-components.psd1',
    'modules/data-manager/data-manager.psd1',
    'screens/dashboard-screen/dashboard-screen.psd1',
    'screens/task-list-screen/task-list-screen.psd1',
    'modules/tui-framework/tui-framework.psd1',
    'modules/tui-engine/tui-engine.psd1'
)

Write-Host "🚀 Loading Axiom-Phoenix modules via Import-Module..."
foreach ($filePath in $FileLoadOrder) {
    # Since the root is now in PSModulePath, we can use simpler names,
    # but using the full path is more explicit and safer.
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) {
        try {
            Import-Module $fullPath -Force -ErrorAction Stop
        } catch {
            Write-Error "FATAL: Failed to import module '$fullPath'. Error: $($_.Exception.Message)"
            Write-Error $_.ScriptStackTrace
            $env:PSModulePath = $originalModulePath # Restore path on failure
            exit 1
        }
    } else {
        Write-Error "FATAL: Required module not found: '$fullPath'. Aborting."
        $env:PSModulePath = $originalModulePath # Restore path on failure
        exit 1
    }
}
Write-Host "✅ All modules loaded successfully."

# --- MAIN EXECUTION LOGIC ---
$container = $null 
try {
    Write-Host "`n=== Axiom-Phoenix v4.0 - Starting Up ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    
    # 1. Initialize standalone services
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # 2. Create the service container
    Write-Host "Creating service container..." -ForegroundColor Yellow
    $container = Initialize-ServiceContainer
    
    # 3. Register all services with the container using factories
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService })
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService })
    $container.RegisterFactory("KeybindingService", { param($c) New-KeybindingService })
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager })
    $container.RegisterFactory("NavigationService", { 
        param($c)
        Initialize-NavigationService -Services @{ ServiceContainer = $c } 
    })
    
    # 4. Register screen classes with the Navigation Service
    $navService = $container.GetService("NavigationService")
    $navService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # 5. Initialize the Command Palette system
    Register-CommandPalette -ActionService $container.GetService("ActionService") -KeybindingService $container.GetService("KeybindingService")
    
    Write-Host "Service container configured with $($container.GetAllRegisteredServices().Count) services!" -ForegroundColor Green
    
    # 6. Display application logo
    if (-not $SkipLogo) {
        Write-Host @"

    ╔═══════════════════════════════════════╗
    ║      Axiom-Phoenix v4.0               ║
    ║      PowerShell Management Console    ║
    ╚═══════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
    }
    
    # 7. Initialize the TUI Engine
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    
    # 8. Create the initial screen
    Write-Host "Creating initial dashboard screen..." -ForegroundColor Yellow
    $initialScreen = [DashboardScreen]::new($container)
    
    # 9. Start the main application loop
    Write-Host "Starting main application loop... Press Ctrl+P to open the Command Palette." -ForegroundColor Yellow
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
    
    # Restore the original module path when the script exits
    $env:PSModulePath = $originalModulePath
    Write-Host "Restored original PSModulePath." -ForegroundColor DarkGray
}