# ==============================================================================
# Axiom-Phoenix v4.0 - Application Entry Point
# Loads all framework files and starts the application
# ==============================================================================

#region Script Configuration

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'  # Change to 'Continue' for debug output

#endregion

#region Load Framework Files

try {
    Write-Host "Loading Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    
    $scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    
    # Define files in dependency order (CRITICAL: Do not change order!)
    $filesToLoad = @(
        'AllBaseClasses.ps1'   # Foundation types with zero dependencies
        'AllModels.ps1'        # Data models, depends on base classes
        'AllComponents.ps1'    # UI components, depends on base + models
        'AllScreens.ps1'       # Screens, depends on all above
        'AllFunctions.ps1'     # Helper functions, can reference all classes
        'AllServices.ps1'      # Services, can use everything
        'AllRuntime.ps1'       # Engine and runtime, orchestrates everything
    )
    
    # Load each file
    foreach ($file in $filesToLoad) {
        $filePath = Join-Path $scriptRoot $file
        
        if (-not (Test-Path $filePath)) {
            throw "Required file not found: $filePath"
        }
        
        Write-Verbose "Loading: $file"
        . $filePath
    }
    
    Write-Host "Framework loaded successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to load framework files!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

#endregion

#region Initialize Services

try {
    Write-Host "Initializing services..." -ForegroundColor Cyan
    
    # Create service container
    $container = [ServiceContainer]::new()
    
    # Register core services
    $container.Register("Logger", [Logger]::new())
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    
    # Register services that depend on EventManager
    $eventManager = $container.GetService("EventManager")
    $container.Register("ActionService", [ActionService]::new($eventManager))
    $container.Register("DataManager", [DataManager]::new((Join-Path $env:APPDATA "AxiomPhoenix\data.json"), $eventManager))
    $container.Register("NavigationService", [NavigationService]::new($eventManager))
    
    # Register services that depend on ActionService
    $actionService = $container.GetService("ActionService")
    $container.Register("KeybindingService", [KeybindingService]::new($actionService))
    
    # Register framework service
    $container.Register("TuiFrameworkService", [TuiFrameworkService]::new())
    
    # Initialize default actions
    $actionService.RegisterDefaultActions()
    
    # Register navigation actions
    $navService = $container.GetService("NavigationService")
    
    $actionService.RegisterAction("navigation.dashboard", {
        $dashboard = [DashboardScreen]::new($container)
        $navService.NavigateTo($dashboard)
    }, @{
        Category = "Navigation"
        Description = "Go to Dashboard"
    })
    
    $actionService.RegisterAction("navigation.taskList", {
        $taskList = [TaskListScreen]::new($container)
        $navService.NavigateTo($taskList)
    }, @{
        Category = "Navigation"
        Description = "Go to Task List"
    })
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to initialize services!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

#endregion

#region Load Sample Data

try {
    Write-Host "Loading sample data..." -ForegroundColor Cyan
    
    $dataManager = $container.GetService("DataManager")
    
    # Try to load existing data first
    try {
        $dataManager.LoadData()
        
        if ($dataManager.Tasks.Count -eq 0) {
            throw "No existing data found"
        }
        
        Write-Host "Loaded $($dataManager.Tasks.Count) tasks from storage" -ForegroundColor Green
    }
    catch {
        Write-Host "Creating sample data..." -ForegroundColor Yellow
        
        # Create sample project
        $project = [PmcProject]::new("DEMO", "Demo Project", "Sample project for demonstration", "Admin")
        $dataManager.AddProject($project)
        
        # Create sample tasks
        $sampleTasks = @(
            @{
                Title = "Complete TUI Framework Migration"
                Description = "Migrate all axiom components to mono structure"
                Priority = [TaskPriority]::High
                Status = [TaskStatus]::InProgress
                Progress = 75
            },
            @{
                Title = "Write Documentation"
                Description = "Create comprehensive documentation for the framework"
                Priority = [TaskPriority]::Medium
                Status = [TaskStatus]::Pending
                Progress = 0
            },
            @{
                Title = "Add Unit Tests"
                Description = "Implement unit tests for core components"
                Priority = [TaskPriority]::Medium
                Status = [TaskStatus]::Pending
                Progress = 0
            },
            @{
                Title = "Optimize Rendering Performance"
                Description = "Profile and optimize the differential rendering system"
                Priority = [TaskPriority]::Low
                Status = [TaskStatus]::InProgress
                Progress = 30
            },
            @{
                Title = "Create Theme Editor"
                Description = "Build a visual theme editor screen"
                Priority = [TaskPriority]::Low
                Status = [TaskStatus]::Pending
                Progress = 0
            }
        )
        
        foreach ($taskData in $sampleTasks) {
            $task = [PmcTask]::new($taskData.Title, $taskData.Description, $taskData.Priority, "DEMO")
            $task.Status = $taskData.Status
            $task.Progress = $taskData.Progress
            
            if ($taskData.Progress -eq 100) {
                $task.Complete()
            }
            
            $dataManager.AddTask($task)
        }
        
        Write-Host "Created $($sampleTasks.Count) sample tasks" -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to load sample data: $($_.Exception.Message)"
    # Continue anyway - app can run without data
}

#endregion

#region Start Application

try {
    Write-Host "`nStarting Axiom-Phoenix..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open the Command Palette" -ForegroundColor Yellow
    Write-Host "Press Ctrl+Q to exit`n" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 2
    
    # Create initial screen
    $dashboardScreen = [DashboardScreen]::new($container)
    
    # Start the application
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen
}
catch {
    Write-Host "`nApplication error!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    
    Write-Host "`nPress any key to exit..." -ForegroundColor White
    [Console]::ReadKey($true) | Out-Null
    exit 1
}
finally {
    # Ensure console is restored
    try {
        [Console]::CursorVisible = $true
        [Console]::Clear()
    }
    catch {}
}

#endregion
