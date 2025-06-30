# ==============================================================================
# PMC Terminal v5 "Helios" - Modern PowerShell 7 Main Entry Point
# ==============================================================================

# --- Declarative Module Loading ---
# PowerShell 7+ loads all necessary modules and their classes/functions here.
# Order is important: dependencies must be loaded before dependents.

# Core Services (no dependencies)
using module '.\modules\exceptions.psm1'
using module '.\modules\logger.psm1'
using module '.\modules\event-system.psm1'
using module '.\modules\theme-manager.psm1'

# Base Classes
using module '.\modules\models.psm1'
using module '.\components\ui-classes.psm1'

# Components (depend on base classes)
using module '.\layout\panels-class.psm1'
using module '.\components\navigation-class.psm1'
using module '.\components\advanced-data-components.psm1'
using module '.\components\advanced-input-components.psm1'
using module '.\components\tui-components.psm1'

# Framework & Services (depend on core services and models)
using module '.\modules\data-manager.psm1'
using module '.\services\keybinding-service.psm1'
using module '.\services\navigation-service-class.psm1'
using module '.\modules\dialog-system-class.psm1'
using module '.\modules\tui-framework.psm1'

# Screens (depend on services and components) - LOAD BEFORE TUI ENGINE
using module '.\screens\dashboard\dashboard-screen.psm1'
using module '.\screens\task-list-screen.psm1'

# Engine (loaded last, depends on many utilities)
using module '.\modules\tui-engine.psm1'

# --- Script Configuration ---
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Main Application Logic ---
function Start-PMCTerminal {
    [CmdletBinding()]
    param()
    
    Invoke-WithErrorHandling -Component "Main" -Context "Main startup sequence" -ScriptBlock {
        # --- 1. Initialize Core Systems ---
        Write-Host "Initializing core systems..." -ForegroundColor Cyan
        Initialize-Logger
        Write-Log -Level Info -Message "PMC Terminal v5 'Helios' startup initiated."
        
        Initialize-EventSystem
        Initialize-ThemeManager
        Initialize-DialogSystem
        
        # --- 2. Initialize and Assemble Services ---
        Write-Host "Initializing services..." -ForegroundColor Cyan
        $services = @{
            DataManager = Initialize-DataManager
            Keybindings = New-KeybindingService  # AI: Using factory function for better compatibility
        }
        $services.Navigation = Initialize-NavigationService -Services $services  # AI: Using factory function
        
        # --- 3. CRITICAL FIX - Register Screen Classes ---
        Write-Host "Registering screen classes..." -ForegroundColor Cyan
        try {
            $services.Navigation.RegisterScreenClass("DashboardScreen", [DashboardScreen])
            Write-Host "✓ DashboardScreen registered" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Failed to register DashboardScreen: $_" -ForegroundColor Red
            throw
        }
        
        try {
            $services.Navigation.RegisterScreenClass("TaskListScreen", [TaskListScreen])
            Write-Host "✓ TaskListScreen registered" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ TaskListScreen not available: $_" -ForegroundColor Yellow
        }
        
        # Debug output
        $services.Navigation.ListRegisteredScreens()
        $services.Navigation.ListAvailableRoutes()
        
        $global:Services = $services
        Write-Log -Level Info -Message "All services initialized and assembled."
        
        # --- 4. Initialize TUI Engine and Navigate ---
        Write-Host "Starting TUI Engine..." -ForegroundColor Green
        Clear-Host
        
        Initialize-TuiEngine
        
        # AI: FIX - Verify TUI state before proceeding
        if (-not $global:TuiState) {
            throw "TUI Engine failed to initialize - global state is null"
        }
        Write-Host "✓ TUI Engine initialized: $($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)" -ForegroundColor Green
        
        $startPath = if ($args -contains "-start" -and ($args.IndexOf("-start") + 1) -lt $args.Count) {
            $args[$args.IndexOf("-start") + 1]
        } else {
            "/dashboard"
        }
        
        if (-not $services.Navigation.IsValidRoute($startPath)) {
            Write-Log -Level Warning -Message "Startup path '$startPath' is not valid. Defaulting to /dashboard."
            $startPath = "/dashboard"
        }
        
        Write-Host "Navigating to: $startPath" -ForegroundColor Cyan
        $services.Navigation.GoTo($startPath, @{})
        
        # AI: FIX - Verify screen was created and pushed
        if (-not $global:TuiState.CurrentScreen) {
            throw "Failed to navigate to $startPath - no current screen set"
        }
        Write-Host "✓ Successfully navigated to: $startPath" -ForegroundColor Green
        Write-Host "✓ Current screen: $($global:TuiState.CurrentScreen.Name)" -ForegroundColor Green
        
        # --- 5. Start the Main Loop ---
        Write-Host "Starting main TUI loop... (Press ESC to exit)" -ForegroundColor Yellow
        Start-TuiLoop
        
        Write-Log -Level Info -Message "PMC Terminal exited gracefully."
    }
}

# --- Main Execution Block ---
try {
    Start-PMCTerminal
}
catch {
    $errorMessage = "A fatal, unhandled exception occurred: $($_.Exception.Message)"
    Write-Host "`n$errorMessage" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Level Fatal -Message $errorMessage -Data @{ Exception = $_.Exception; Stack = $_.ScriptStackTrace } -Force
    }
    
    Read-Host "Press Enter to exit"
    exit 1
}
finally {
    if ($global:Services -and $global:Services.DataManager) {
        try {
            $global:Services.DataManager.SaveData()
            if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
                Write-Log -Level Info -Message "Data saved on exit." -Force
            }
        }
        catch {
            Write-Warning "Failed to save data on exit: $_"
        }
    }
    if (Get-Command Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Level Info -Message "Application shutdown complete." -Force
    }
}