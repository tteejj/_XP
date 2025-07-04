# run.ps1 - Main entry point for the deconstructed application.
# Synthesized by mushroom.ps1

# --- PARAMETERS & GLOBAL SETTINGS ---
param(


    [switch]$Debug,


    [switch]$SkipLogo


)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- MODULE SOURCING ---
# This block dynamically sources all the decomposed script files in the correct order.
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FileLoadOrder = @(
    'modules\logger\logger.psm1',
    'modules\panic-handler\panic-handler.psm1',
    'modules\exceptions\exceptions.psm1',
    'services\service-container\service-container.psm1',
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

Write-Host "🚀 Loading Axiom-Phoenix modules..."
foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) {
        . $fullPath
    } else {
        Write-Warning "FATAL: Required module not found: $filePath". Aborting."
        exit 1
    }
}
Write-Host "✅ All modules loaded."

# --- MAIN EXECUTION LOGIC ---
# This is the original startup logic from the monolith, now running after all
# functions and classes have been sourced into the session.
try {


    Write-Host "`n=== PMC Terminal v5 - Starting Up ===" -ForegroundColor Cyan


    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray


    


    # 1. Initialize core services that have no dependencies


    Write-Host "`nInitializing services..." -ForegroundColor Yellow


    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })


    Initialize-EventSystem


    Initialize-ThemeManager


    Initialize-DialogSystem


    


    # 2. Create the service container using the new DI system


    Write-Host "Creating service container..." -ForegroundColor Yellow


    $container = New-ServiceContainer


    # For backward compatibility, we'll also maintain the $services hashtable


    $services = @{}


    


    # 3. Register and initialize services in the container


    # Register KeybindingService


    $container.RegisterFactory("KeybindingService", [KeybindingService], {

        param($c)

        return New-KeybindingService

    })


    $services.KeybindingService = $container.Resolve("KeybindingService")


    


    # Register DataManager


    $container.RegisterFactory("DataManager", [DataManager], {

        param($c)

        return Initialize-DataManager

    })


    $services.DataManager = $container.Resolve("DataManager")


    


    # 4. Register NavigationService with proper dependency injection


    $container.RegisterFactory("NavigationService", [NavigationService], {

        param($c)

        # Create a services proxy for the navigation service

        $servicesProxy = @{}

        foreach ($name in $c.GetRegisteredServices()) {

            $servicesProxy[$name] = $c.Resolve($name)

        }

        return Initialize-NavigationService -Services $servicesProxy

    })


    $services.Navigation = $container.Resolve("NavigationService")


    


    # 5. Register the screen classes with the navigation service's factory


    #    This tells the navigation service how to create each screen when requested.


    $services.Navigation.RegisterScreenClass("DashboardScreen", [DashboardScreen])


    $services.Navigation.RegisterScreenClass("TaskListScreen", [TaskListScreen])


    


    # Lock the container to prevent further registrations


    $container.Lock()


    Write-Host "Service container created with $($container.GetRegisteredServices().Count) services!" -ForegroundColor Green


    Write-Host "All services initialized!" -ForegroundColor Green


    


    # 6. Display the application logo (optional)


    if (-not $SkipLogo) {


        Write-Host @"





    ╔═══════════════════════════════════════╗


    ║      PMC Terminal v5.0                ║


    ║      PowerShell Management Console    ║


    ╚═══════════════════════════════════════╝


    


"@ -ForegroundColor Cyan


    }


    


    # 7. Initialize the TUI Engine which orchestrates the UI


    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow


    Initialize-TuiEngine


    Write-Host "TUI Engine initialized successfully" -ForegroundColor Green


    


    # 8. Create the very first screen instance to show.


    Write-Host "Creating initial dashboard screen..." -ForegroundColor Yellow


    $initialScreen = $services.Navigation.ScreenFactory.CreateScreen("DashboardScreen", @{})


    $initialScreen.Initialize()


    Write-Host "Dashboard screen created successfully" -ForegroundColor Green


    


    # 9. Push the initial screen to the engine and start the main loop.


    Write-Host "Starting main application loop..." -ForegroundColor Yellow


    Start-TuiLoop -InitialScreen $initialScreen


    


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


    Write-Host "Application has exited. Cleaning up..."


    Cleanup-TuiEngine


}
