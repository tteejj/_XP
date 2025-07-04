# _CLASSY-MAIN.ps1 (Corrected and Final)
#
# This script uses the modern 'using module' syntax, which is the correct
# way to load PowerShell modules and their classes in PS 7+.
# The load order has been fixed to resolve all class and function dependencies.
#
#Requires -Version 7.0

# ==============================================================================
# STAGE 1: MODULE LOADING (Handled by PowerShell Engine)
# 'using module' statements MUST be at the very top of the script.
# PowerShell parses these first, ensuring all types are available before
# any script code is executed. The order is critical for dependencies.
# ==============================================================================

# Layer 0: Core Primitives & Models (No internal dependencies)
using module '.\modules\logger\logger.psm1'
using module '.\modules\exceptions\exceptions.psm1'
using module '.\modules\models\models.psm1'
using module '.\components\tui-primitives\tui-primitives.psm1'

# Layer 1: Foundational Systems (Depend on Layer 0)
using module '.\modules\event-system\event-system.psm1'      # Depends on logger, exceptions
#using module '.\components\ui-classes\ui-classes.psm1'       # Depends on primitives, event-system
#using module '.\modules\theme-manager\theme-manager.psm1'     # Depends on logger, event-system

# Layer 2: Layout & Core Components (Depend on Layer 1)
#using module '.\layout\panels-class\panels-class.psm1'             # Depends on ui-classes
#using module '.\components\navigation-class\navigation-class.psm1'     # Depends on ui-classes
#using module '.\components\tui-components\tui-components.psm1'       # Depends on ui-classes

# Layer 3: Advanced Components & Data/Service Classes (Depend on previous layers)
#using module '.\components\advanced-data-components\advanced-data-components.psm1'
#using module '.\components\advanced-input-components\advanced-input-components.psm1'
#using module '.\modules\data-manager-class\data-manager-class.psm1'
#using module '.\services\keybinding-service-class\keybinding-service-class.psm1'
#using module '.\services\navigation-service-class\navigation-service-class.psm1'
#using module '.\modules\dialog-system-class\dialog-system-class.psm1'

# Layer 4: Service Implementation & TUI Engine (Depend on classes and primitives)
#using module '.\modules\data-manager\data-manager.psm1'
#using module '.\services\keybinding-service\keybinding-service.psm1'
#using module '.\services\navigation-service\navigation-service.psm1'
#using module '.\modules\tui-engine\tui-engine.psm1'

# Layer 5: Application Screens (The final layer, depends on all others)
#using module '.\screens\dashboard-screen\dashboard-screen.psm1'
#using module '.\screens\task-list-screen\task-list-screen.psm1'


# ==============================================================================
# STAGE 2: APPLICATION BOOTSTRAP
# All modules are now loaded and all functions/classes are available.
# ==============================================================================
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

# Set execution context
Set-Location $PSScriptRoot
$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n=== PMC Terminal v5 - Starting (Classy Loader) ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    
    # Initialize core services that have no dependencies
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # Create the service container
    $services = @{}
    
    # Initialize services that depend on others, passing the container
    $services.KeybindingService = New-KeybindingService
    $services.DataManager = Initialize-DataManager
    
    # NavigationService needs the $services container to pass to screens
    $services.Navigation = Initialize-NavigationService -Services $services
    
    # Register screen classes with the navigation service
    $services.Navigation.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $services.Navigation.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # Initialize the dialog system
    Initialize-DialogSystem
    
    Write-Host "All services initialized!" -ForegroundColor Green
    
    if (-not $SkipLogo) {
        Write-Host @"
    
    ╔═══════════════════════════════════════╗
    ║      PMC Terminal v5.0                ║
    ║      PowerShell Management Console    ║
    ╚═══════════════════════════════════════╝
    
"@ -ForegroundColor Cyan
    }
    
    # Initialize the TUI Engine which orchestrates the UI
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    
    # Create and initialize the first screen
    $dashboard = [DashboardScreen]::new($services)
    $dashboard.Initialize()
    
    # Push the screen to the engine and start the main loop
    Push-Screen -Screen $dashboard
    Start-TuiLoop
    
} catch {
    Write-Host "`n=== FATAL ERROR ===" -ForegroundColor Red
    Write-Host "An error occurred during application startup."
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor DarkRed
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    if ($Host.UI.RawUI) {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
    exit 1
} finally {
    # Cleanup logic if needed
    Pop-Location -ErrorAction SilentlyContinue
   
}