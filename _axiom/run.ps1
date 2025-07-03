# run.ps1 - Main entry point for the deconstructed application.
# Synthesized by mushroom.

param(
    [switch]$Debug,
    [switch]$SkipLogo
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load order derived directly from the original monolith's structure to ensure correctness.
# CRITICAL: To add a new file, add its path to this array in the correct dependency order.
$FileLoadOrder = @(
    'modules\logger\logger.psm1',
    'modules\exceptions\exceptions.psm1',
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

Write-Host "Loading application modules..." -ForegroundColor Cyan
$PSScriptRoot = Get-Location
foreach ($filePath in $FileLoadOrder) {
    $fullPath = Join-Path $PSScriptRoot $filePath
    if (Test-Path $fullPath) { . $fullPath }
    else { Write-Warning "Module not found: $filePath" }
}

Write-Host "All modules loaded. Starting application..." -ForegroundColor Green

# --- MAIN EXECUTION LOGIC ---
# --- START OF ORIGINAL FILE: modules\tui-framework\tui-framework.psm1 ---
# TUI Framework Integration Module
# Contains utility functions for interacting with the TUI engine and components.
# AI: FIX - Added all missing dependencies.




$script:TuiAsyncJobs = @()

function Invoke-TuiMethod {
    <# .SYNOPSIS Safely invokes a method on a TUI component. #>
    param(
        [Parameter(Mandatory)] [hashtable]$Component,
        [Parameter(Mandatory)] [string]$MethodName,
        [Parameter()] [hashtable]$Arguments = @{}
    )
    if (-not $Component) { return }
    $method = $Component[$MethodName]
    if (-not ($method -is [scriptblock])) { return }

    $Arguments['self'] = $Component
    Invoke-WithErrorHandling -Component "$($Component.Name ?? $Component.Type).$MethodName" -Context "Invoking component method" -ScriptBlock { & $method @Arguments }
}

function Initialize-TuiFramework {
    Invoke-WithErrorHandling -Component "TuiFramework.Initialize" -Context "Initializing framework" -ScriptBlock {
        if (-not $global:TuiState) { throw "TUI Engine must be initialized before the TUI Framework." }
        Write-Log -Level Info -Message "TUI Framework initialized."
    }
}

function Invoke-TuiAsync {
    <# .SYNOPSIS Executes a script block asynchronously with job management. #>
    param(
        [Parameter(Mandatory)] [scriptblock]$ScriptBlock,
        [string]$JobName = "TuiAsyncJob_$(Get-Random)",
        [hashtable]$ArgumentList = @{}
    )
    Invoke-WithErrorHandling -Component "TuiFramework.Async" -Context "Starting async job: $JobName" -ScriptBlock {
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -Name $JobName
        $script:TuiAsyncJobs += $job
        Write-Log -Level Debug -Message "Started async job: $JobName" -Data @{ JobId = $job.Id }
        return $job
    }
}

function Get-TuiAsyncResults {
    <# .SYNOPSIS Checks for completed async jobs and returns their results. #>
    param([switch]$RemoveCompleted = $true)
    Invoke-WithErrorHandling -Component "TuiFramework.AsyncResults" -Context "Checking async job results" -ScriptBlock {
        $results = @()
        $completedJobs = $script:TuiAsyncJobs | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }
        
        foreach ($job in $completedJobs) {
            $results += @{
                JobId = $job.Id; JobName = $job.Name; State = $job.State
                Output = if ($job.State -eq 'Completed') { Receive-Job -Job $job } else { $null }
                Error = if ($job.State -eq 'Failed') { $job.ChildJobs[0].JobStateInfo.Reason } else { $null }
            }
            Write-Log -Level Debug -Message "Async job completed: $($job.Name)" -Data @{ JobId = $job.Id; State = $job.State }
        }
        
        if ($RemoveCompleted -and $completedJobs.Count -gt 0) {
            foreach ($job in $completedJobs) {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                $script:TuiAsyncJobs = $script:TuiAsyncJobs | Where-Object { $_.Id -ne $job.Id }
            }
        }
        return $results
    }
}

function Stop-AllTuiAsyncJobs {
    Invoke-WithErrorHandling -Component "TuiFramework.StopAsync" -Context "Stopping all async jobs" -ScriptBlock {
        foreach ($job in $script:TuiAsyncJobs) {
            try {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                Write-Log -Level Debug -Message "Stopped async job: $($job.Name)"
            } catch {
                Write-Log -Level Warning -Message "Failed to stop job $($job.Name): $_"
            }
        }
        $script:TuiAsyncJobs = @()
        Write-Log -Level Info -Message "All TUI async jobs stopped."
    }
}



function Get-TuiState { return $global:TuiState }

function Test-TuiState {
    param([switch]$ThrowOnError)
    $isValid = $global:TuiState -and $global:TuiState.Running -and $global:TuiState.CurrentScreen
    if (-not $isValid -and $ThrowOnError) { throw "TUI state is not properly initialized. Call Initialize-TuiEngine first." }
    return $isValid
}

try {
    Write-Host "`n=== PMC Terminal v5 - Starting Up ===" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
    
    # 1. Initialize core services that have no dependencies
    Write-Host "`nInitializing services..." -ForegroundColor Yellow
    Initialize-Logger -Level $(if ($Debug) { "Debug" } else { "Info" })
    Initialize-EventSystem
    Initialize-ThemeManager
    Initialize-DialogSystem
    
    # 2. Create the service container
    $services = @{}
    
    # 3. Initialize services that depend on others, passing the container
    $services.KeybindingService = New-KeybindingService
    $services.DataManager = Initialize-DataManager
    
    # 4. NavigationService needs the $services container to pass to screens
    $services.Navigation = Initialize-NavigationService -Services $services
    
    # 5. Register the screen classes with the navigation service's factory
    #    This tells the navigation service how to create each screen when requested.
    $services.Navigation.RegisterScreenClass("DashboardScreen", [DashboardScreen])
    $services.Navigation.RegisterScreenClass("TaskListScreen", [TaskListScreen])
    
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
