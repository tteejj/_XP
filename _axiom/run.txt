# run.ps1 - Main entry point for the Axiom-Phoenix application
# This version fully integrates the Service Container and Command Palette.

# --- PARAMETERS & GLOBAL SETTINGS ---
param(
    [switch]$Debug,
    [switch]$SkipLogo
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- MODULE SOURCING ---
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Corrected and finalized load order.
$FileLoadOrder = @(
    'modules/logger/logger.psm1',
    'modules/panic-handler/panic-handler.psm1',
    'modules/exceptions/exceptions.psm1',
    'services/service-container/service-container.psm1',
    'services/action-service/action-service.psm1',
    'modules/models/models.psm1',
    'components/tui-primitives/tui-primitives.psm1',
    'modules/event-system/event-system.psm1',
    'modules/theme-manager/theme-manager.psm1',
    'components/ui-classes/ui-classes.psm1',
    'layout/panels-class/panels-class.psm1',
    'services/keybinding-service/keybinding-service.psm1',
    'components/command-palette/command-palette.psm1',
    'modules/dialog-system-class/dialog-system-class.psm1',
    'components/tui-components/tui-components.psm1',
    'components/advanced-data-components/advanced-data-components.psm1',
    'components/advanced-input-components/advanced-input-components.psm1',
    'modules/data-manager/data-manager.psm1',
    'services/navigation-service/navigation-service.psm1',
    'screens/dashboard-screen/dashboard-screen.psm1',
    'screens/task-list-screen/task-list-screen.psm1',
    'modules/tui-framework/tui-framework.psm1',
    'modules/tui-engine/tui-engine.psm1'
)

Write-Host "🚀 Loading Axiom-Phoenix modules..."
foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) { . $fullPath } 
    else { Write-Warning "FATAL: Required module not found: '$filePath'. Aborting."; exit 1 }
}
Write-Host "✅ All modules loaded."

# --- MAIN EXECUTION LOGIC ---
$container = $null # Define in outer scope for finally block
try {
    Write-Host "`n=== Axiom-Phoenix v4.0 - Starting Up ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    
    # 1. Initialize standalone services
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-DialogSystem
    
    # 2. Create the service container
    Write-Host "Creating service container..." -ForegroundColor Yellow
    # Use the correct factory function from the service-container module
    $container = Initialize-ServiceContainer
    
    # 3. Register all services with the container using factories
    # The container is now the single source of truth for services.
    $container.RegisterFactory("TuiFramework", { param($c) Initialize-TuiFrameworkService })
    $container.RegisterFactory("ActionService", { param($c) Initialize-ActionService })
    $container.RegisterFactory("KeybindingService", { param($c) Initialize-KeybindingService })
    $container.RegisterFactory("DataManager", { param($c) Initialize-DataManager })
    
    # Register NavigationService with true Dependency Injection
    $container.RegisterFactory("NavigationService", {
        param($c)
        # The NavigationService constructor accepts the container directly
        # to resolve its own dependencies internally.
        Initialize-NavigationService -ServiceContainer $c
    })
    
    # 4. Register screen classes with the Navigation Service
    $navService = $container.GetService("NavigationService")
    $navService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # 5. Initialize the Command Palette system
    # This crucial step creates the palette and registers its global hotkey.
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
    # The screen's constructor receives the container to get its dependencies
    $initialScreen = $navService.ScreenFactory.CreateScreen("DashboardScreen", $container, @{})
    $initialScreen.Initialize()
    
    # 9. Start the main application loop
    Write-Host "Starting main application loop... Press Ctrl+P to open the Command Palette." -ForegroundColor Yellow
    Start-TuiLoop -InitialScreen $initialScreen
    
} catch {
    # The Panic Handler should now catch most errors, making this a final safeguard.
    Write-Host "`n=== FATAL STARTUP ERROR ===" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($Host.UI.RawUI) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
    exit 1
} finally {
    Write-Host "Application has exited. Cleaning up..."
    # Ensure all disposable services and the TUI engine are cleaned up.
    if ($container) {
        # Explicitly stop framework async jobs before other services are cleaned up.
        $container.GetService("TuiFramework")?.StopAllAsyncJobs()
        $container.Cleanup()
    }
    Cleanup-TuiEngine
}