# ==============================================================================
# Axiom-Phoenix v4.0 - Application Entry Point
# Loads all framework files and starts the application
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: STA.###" to find specific sections.
# Each section ends with "END_PAGE: STA.###"
# ==============================================================================

#<!-- PAGE: STA.001 - Script Configuration -->
#region Script Configuration

# Clean session by removing any existing types
if ($global:TuiState) {
    Write-Host "Cleaning previous session..." -ForegroundColor Yellow
    try {
        if ($global:TuiState.Running) {
            $global:TuiState.Running = $false
        }
        Remove-Variable -Name TuiState -Scope Global -Force -ErrorAction SilentlyContinue
    } catch {}
}

# Remove any loaded types from previous runs
$typesToRemove = @(
    'TuiAnsiHelper', 'TuiCell', 'TuiBuffer', 'UIElement', 'Component', 'Screen', 'ServiceContainer',
    'ValidationBase', 'PmcTask', 'PmcProject', 'TimeEntry', 'NavigationItem',
    'LabelComponent', 'ButtonComponent', 'TextBoxComponent', 'CheckBoxComponent', 'RadioButtonComponent',
    'Panel', 'ScrollablePanel', 'GroupPanel', 'ListBox', 'TextBox', 'CommandPalette',
    'ActionService', 'KeybindingService', 'DataManager', 'NavigationService', 'ThemeManager', 'Logger', 'EventManager'
)

foreach ($typeName in $typesToRemove) {
    try {
        [System.Management.Automation.PSObject].Assembly.GetTypes() | 
            Where-Object { $_.Name -eq $typeName } | 
            ForEach-Object { 
                Remove-TypeData -TypeName $_.FullName -ErrorAction SilentlyContinue 
            }
    } catch {}
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'  # Change to 'Continue' for debug output

#endregion
#<!-- END_PAGE: STA.001 -->

#<!-- PAGE: STA.002 - Framework Loading & Service Initialization -->
#region Load Framework Files

try {
    Write-Host "Loading Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    
    $scriptRoot = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    
    # Define files in dependency order (CRITICAL: Do not change order!)
    $filesToLoad = @(
        'AllBaseClasses.ps1'   # Foundation types with zero dependencies
        'AllModels.ps1'        # Data models, depends on base classes
        'AllFunctions.ps1'     # Helper functions, must be loaded BEFORE components use them
        'AllComponents.ps1'    # UI components, depends on base + models + functions
        'AllScreens.ps1'       # Screens, depends on all above
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
    
    # Initialize global state BEFORE creating services
    if (-not $global:TuiState) {
        $global:TuiState = @{
            Services = @{}
        }
    }
    
    # Create service container
    $container = [ServiceContainer]::new()
    
    # Store ServiceContainer reference in TuiState for global access
    $global:TuiState.ServiceContainer = $container
    
    # Register core services
    # First register Logger and immediately add to global state
    $logger = [Logger]::new()
    $container.Register("Logger", $logger)
    $global:TuiState.Services['Logger'] = $logger
    Write-Verbose "Registered Logger service"
    
    # Register EventManager
    $eventManager = [EventManager]::new()
    $container.Register("EventManager", $eventManager)
    Write-Verbose "Registered EventManager service"
    
    # Register ThemeManager
    $themeManager = [ThemeManager]::new()
    $container.Register("ThemeManager", $themeManager)
    $themeManager.LoadDefaultTheme()
    Write-Verbose "Registered ThemeManager service"
    
    # Register ActionService
    $actionService = [ActionService]::new($eventManager)
    $container.Register("ActionService", $actionService)
    Write-Verbose "Registered ActionService"
    
    # Register DataManager
    $dataPath = Join-Path $env:APPDATA "AxiomPhoenix\data.json"
    $dataManager = [DataManager]::new($dataPath, $eventManager)
    $container.Register("DataManager", $dataManager)
    Write-Verbose "Registered DataManager"
    
    # Register NavigationService
    $navigationService = [NavigationService]::new(@{ EventManager = $eventManager })
    $container.Register("NavigationService", $navigationService)
    Write-Verbose "Registered NavigationService"
    
    # Register FocusManager
    $focusManager = [FocusManager]::new($eventManager)
    $container.Register("FocusManager", $focusManager)
    Write-Verbose "Registered FocusManager"
    
    # Register KeybindingService (depends on ActionService)
    $keybindingService = [KeybindingService]::new($actionService)
    $container.Register("KeybindingService", $keybindingService)
    Write-Verbose "Registered KeybindingService"
    
    # Register DialogManager (depends on EventManager and FocusManager)
    $dialogManager = [DialogManager]::new($eventManager, $focusManager)
    $container.Register("DialogManager", $dialogManager)
    Write-Verbose "Registered DialogManager"
    
    # Initialize default actions
    $actionService.RegisterDefaultActions()
    Write-Verbose "Registered default actions"
    
    # Initialize default keybindings
    $keybindingService.SetDefaultBindings()
    Write-Verbose "Set default keybindings"
    
    # Register navigation actions
    $actionService.RegisterAction("navigation.dashboard", {
        $dashboard = [DashboardScreen]::new($container)
        $navigationService.NavigateTo($dashboard)
    }, @{
        Category = "Navigation"
        Description = "Go to Dashboard"
    })
    
    $actionService.RegisterAction("navigation.taskList", {
        $taskList = [TaskListScreen]::new($container)
        $navigationService.NavigateTo($taskList)
    }, @{
        Category = "Navigation"
        Description = "Go to Task List"
    })
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green
}
catch {
    Write-Host "Failed to initialize services!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion
#<!-- END_PAGE: STA.002 -->

#<!-- PAGE: STA.003 - Data Loading & Application Startup -->
#region Load Sample Data

try {
    Write-Host "Loading sample data..." -ForegroundColor Cyan
    
    # Try to load existing data first
    try {
        $dataManager.LoadData()
        
        if ($dataManager.GetTasks().Count -eq 0) {
            throw "No existing data found"
        }
        
        Write-Host "Loaded $($dataManager.GetTasks().Count) tasks from storage" -ForegroundColor Green
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
#<!-- END_PAGE: STA.003 -->
