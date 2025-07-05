param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# run.ps1 - Main entry point for the Axiom-Phoenix application
# FINAL v3 - Fix for class type resolution

# --- PARAMETERS & GLOBAL SETTINGS ---

Set-StrictMode -Version Latest
# --- STAGE 1: PRE-FLIGHT CLASS LOADING ---
# Dot-source the loader script to define all classes in the global scope.
# This solves all parse-time "Unable to find type" errors before module importing begins.
#. "$PSScriptRoot\class-loader.ps1"
$ErrorActionPreference = 'Stop'

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Make your local modules folder transparently available for `using module`.
# --- AXIOM MODULE PATH CONFIGURATION ---
# The original module path is saved so it can be restored on exit.
$originalModulePath = $env:PSModulePath

# Define the parent directories where our modules live.
$moduleParentPaths = @(
    (Join-Path $PSScriptRoot 'components'),
    (Join-Path $PSScriptRoot 'modules'),
    (Join-Path $PSScriptRoot 'services'),
    (Join-Path $PSScriptRoot 'layout'),
    (Join-Path $PSScriptRoot 'screens')
) | ForEach-Object { (Get-Item $_).FullName }

# Prepend our project's module paths to the system's PSModulePath.
# This allows PowerShell's module loader to automatically discover and resolve
# dependencies listed in the .psd1 manifests (e.g., RequiredModules).
$env:PSModulePath = ($moduleParentPaths -join ';') + ';' + $originalModulePath

Write-Host "Temporarily added project module paths to PSModulePath." -ForegroundColor DarkGray
# --- MODULE SOURCING ---
$FileLoadOrder = @(
    'modules/logger/logger.psd1',
    'modules/exceptions/exceptions.psd1',
    'modules/panic-handler/panic-handler.psd1',
    'modules/event-system/event-system.psd1',
    'modules/models/models.psd1',
    'components/tui-primitives/tui-primitives.psd1',
    'modules/theme-manager/theme-manager.psd1',
    'components/ui-classes/ui-classes.psd1', 
    'layout/panels-class/panels-class.psd1', 
    'services/service-container/service-container.psd1',
    'services/action-service/action-service.psd1',
    'services/keybinding-service-class/keybinding-service-class.psd1',
    'services/keybinding-service/keybinding-service.psm1',
    'services/navigation-service-class/navigation-service-class.psd1',
    'services/navigation-service/navigation-service.psm1',
    'components/tui-components/tui-components.psd1',
    'components/advanced-data-components/advanced-data-components.psd1',
    'components/advanced-input-components/advanced-input-components.psm1',
    'modules/dialog-system-class/dialog-system-class.psm1',
    'components/command-palette/command-palette.psm1',
    'modules/data-manager/data-manager.psm1',
    'screens/dashboard-screen/dashboard-screen.psm1',
    'screens/task-list-screen/task-list-screen.psm1',
    'modules/tui-framework/tui-framework.psd1',
    'modules/tui-engine/tui-engine.psd1'
)

Write-Host "🚀 Loading Axiom-Phoenix modules via Import-Module..."
foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) {
        try {
            # Use -PassThru to get the module object, which can be useful for debugging
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
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService }, $true)
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService }, $true)
    $container.RegisterFactory("KeybindingService", { param($c) New-KeybindingService }, $true)
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager }, $true)
    $container.RegisterFactory("ThemeManager", { 
        param($c) 
        $themeManager = New-Object PSObject
        $themeManager | Add-Member -MemberType ScriptMethod -Name "GetColor" -Value { param($colorName) Get-ThemeColor -ColorName $colorName }
        $themeManager | Add-Member -MemberType ScriptMethod -Name "GetTheme" -Value { Get-TuiTheme }
        return $themeManager
    }, $true)
    $container.RegisterFactory("NavigationService", { 
        param($c)
        Initialize-NavigationService -Services @{ ServiceContainer = $c } 
    }, $true)
    
    # 4. Register screen classes with the Navigation Service
    $navService = $container.GetService("NavigationService")
    
    # FIX: Robustly get the types from the current AppDomain's loaded assemblies.
    Write-Host "Registering screen types..." -ForegroundColor Yellow
    $dashboardScreenType = [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() | Where-Object { $_.Name -eq 'DashboardScreen' } | Select-Object -First 1
    $taskListScreenType = [System.AppDomain]::CurrentDomain.GetAssemblies().GetTypes() | Where-Object { $_.Name -eq 'TaskListScreen' } | Select-Object -First 1

    if (-not $dashboardScreenType) { throw "Could not find the [DashboardScreen] class type after loading modules." }
    if (-not $taskListScreenType) { throw "Could not find the [TaskListScreen] class type after loading modules." }

    $navService.RegisterScreenClass("DashboardScreen", $dashboardScreenType)
    $navService.RegisterScreenClass("TaskListScreen", $taskListScreenType)
    Write-Host "Registered screen types: DashboardScreen, TaskListScreen" -ForegroundColor Green
    
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
    $initialScreen = $navService.ScreenFactory.CreateScreen("DashboardScreen", @{})
    
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