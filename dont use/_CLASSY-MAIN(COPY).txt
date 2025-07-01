#Requires -Version 7.0

# ALL 'using module' statements MUST be at the top - PowerShell requirement
# Listed in dependency order from core to application layer

# Layer 1: Core (no dependencies on other modules)
using module .\modules\logger.psm1
using module .\modules\exceptions.psm1
using module .\modules\models.psm1
using module .\modules\event-system.psm1

# Layer 2: TUI Foundation (depends on Layer 1)
using module .\components\tui-primitives.psm1
using module .\components\ui-classes.psm1
using module .\layout\panels-class.psm1
using module .\modules\tui-engine.psm1

# Layer 3: Components (depends on Layer 1 & 2)
using module .\components\navigation-class.psm1
using module .\components\tui-components.psm1
using module .\components\advanced-data-components.psm1
using module .\components\advanced-input-components.psm1

# Layer 4: Services & Dialogs (depends on Layer 1, 2 & 3)
using module .\modules\theme-manager.psm1
using module .\modules\data-manager.psm1
using module .\services\keybinding-service.psm1
using module .\modules\dialog-system-class.psm1
using module .\services\navigation-service-class.psm1

# Layer 5: Screens (depends on all layers)
using module .\screens\dashboard\dashboard-screen.psm1
using module .\screens\task-list-screen.psm1

# NOW the regular PowerShell code begins
param(
    [switch]$Debug,
    [switch]$SkipLogo
)

Set-Location $PSScriptRoot
$ErrorActionPreference = 'Stop'

try {
    Write-Host "`n=== PMC Terminal v5 - Starting ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    Write-Host "Platform: $($PSVersionTable.Platform)" -ForegroundColor DarkGray
    
    # All modules are already loaded via 'using module' statements above
    # Now we just need to initialize the services
    
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    
    # Initialize core services
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    
    # Create service container
    $services = @{}
    
    # Initialize KeybindingService (from class)
    $keybindingService = New-KeybindingService
    $services.KeybindingService = $keybindingService
    
    # Initialize DataManager
    $dataManager = Initialize-DataManager
    $services.DataManager = $dataManager
    
    # Initialize NavigationService
    $navigationService = Initialize-NavigationService -Services $services
    $services.Navigation = $navigationService
    
    # Register screen classes with navigation
    $navigationService.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $navigationService.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
    # Initialize Dialog System
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
    
    # Initialize TUI Engine
    Write-Host "Starting TUI Engine..." -ForegroundColor Yellow
    Initialize-TuiEngine
    
    # Create and show dashboard
    $dashboard = [DashboardScreen]::new($services)
    $dashboard.Initialize()
    
    # Start the application
    Push-Screen -Screen $dashboard
    Start-TuiLoop
    
} catch {
    Write-Host "`n=== FATAL ERROR ===" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace:" -ForegroundColor DarkRed
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    
    Write-Host "`nPress any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
} finally {
    Pop-Location -ErrorAction SilentlyContinue
    Clear-Host
}