# ==============================================================================
# Axiom-Phoenix v4.0 - Startup Script
# Loads all classes and functions then RUNS THE APPLICATION
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$LoadOnly
)

# Set script root
$script:ProjectRoot = $PSScriptRoot

# Verbose output is controlled by -Verbose common parameter from CmdletBinding()

Write-Host "Loading Axiom-Phoenix v4.0 Framework..." -ForegroundColor Cyan

try {
    # Load in strict dependency order
    Write-Host "Loading base classes..." -ForegroundColor Gray
    . "$ProjectRoot\AllBaseClasses.ps1"
    
    Write-Host "Loading models..." -ForegroundColor Gray
    . "$ProjectRoot\AllModels.ps1"
    
    Write-Host "Loading components..." -ForegroundColor Gray
    . "$ProjectRoot\AllComponents.ps1"
    
    Write-Host "Loading screens..." -ForegroundColor Gray
    . "$ProjectRoot\AllScreens.ps1"
    
    Write-Host "Loading functions..." -ForegroundColor Gray
    . "$ProjectRoot\AllFunctions.ps1"
    
    Write-Host "Loading services..." -ForegroundColor Gray
    . "$ProjectRoot\AllServices.ps1"
    
    Write-Host "Loading runtime..." -ForegroundColor Gray
    . "$ProjectRoot\AllRuntime.ps1"
    
    Write-Host "Axiom-Phoenix loaded successfully!" -ForegroundColor Green
    Write-Host ""
    
    if ($LoadOnly) {
        Write-Host "Load only mode - not starting application" -ForegroundColor Yellow
        return
    }
    
    # ACTUALLY RUN THE APPLICATION
    Write-Host "Initializing services..." -ForegroundColor Cyan
    
    $container = [ServiceContainer]::new()
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("Logger", [Logger]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    $container.Register("ActionService", [ActionService]::new())
    $container.Register("KeybindingService", [KeybindingService]::new())
    $container.Register("NavigationService", [NavigationService]::new())
    $container.Register("DataManager", [DataManager]::new())
    
    Write-Host "Loading sample data..." -ForegroundColor Cyan
    
    $dm = $container.GetService("DataManager")
    $dm.AddTask([PmcTask]::new("Complete project documentation", "Write comprehensive docs for v4.0", [TaskPriority]::High, "PROJ-001"))
    $dm.AddTask([PmcTask]::new("Review pull requests", "Check and merge pending PRs", [TaskPriority]::Medium, "PROJ-001"))
    $dm.AddTask([PmcTask]::new("Update dependencies", "Update all npm packages to latest", [TaskPriority]::Low, "PROJ-002"))
    $dm.AddTask([PmcTask]::new("Fix bug #1234", "Users report crash on startup", [TaskPriority]::High, "PROJ-002"))
    $dm.AddTask([PmcTask]::new("Implement dark mode", "Add theme switching support", [TaskPriority]::Medium, "PROJ-003"))
    
    # Mark some as in progress
    $task = $dm.GetTasks()[0]
    $task.SetProgress(45)
    $dm.UpdateTask($task)
    
    $task2 = $dm.GetTasks()[3]
    $task2.SetProgress(80)
    $dm.UpdateTask($task2)
    
    Write-Host ""
    Write-Host "Starting application..." -ForegroundColor Green
    Write-Host "Controls: Ctrl+P = Command Palette | Ctrl+C = Exit" -ForegroundColor DarkGray
    Write-Host ""
    
    # START THE APPLICATION
    Start-AxiomPhoenix -ServiceContainer $container
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkRed
    throw
}
