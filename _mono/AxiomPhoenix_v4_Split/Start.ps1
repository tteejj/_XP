# ==============================================================================
# Axiom-Phoenix v4.0 - Application Startup (Generated from Split Structure)
# This script loads the framework from its organized file structure.
# ==============================================================================

param(
    [string]$Theme = "Synthwave",
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($env:AXIOM_VERBOSE -eq '1') { 'Continue' } else { 'SilentlyContinue' }
$WarningPreference = $VerbosePreference

try {
    Write-Host "Loading Axiom-Phoenix v4.0 (Split Architecture)..." -ForegroundColor Cyan
    
    $scriptDir = $PSScriptRoot
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }

    # Define the correct loading order for the framework directories
    $loadOrder = @(
        "Base",
        "Models", 
        "Functions",
        "Components",
        "Screens",
        "Services",
        "Runtime"
    )

    # Load all framework files in the correct order
    foreach ($folder in $loadOrder) {
        $folderPath = Join-Path $scriptDir $folder
        if (-not (Test-Path $folderPath)) { 
            Write-Warning "Folder not found: $folder"
            continue 
        }

        Write-Host "Loading $folder..." -ForegroundColor Gray
        $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
        foreach ($file in $files) {
            Write-Verbose "  - Dot-sourcing $($file.Name)"
            try {
                . $file.FullName
            } catch {
                Write-Error "Failed to load $($file.Name): $($_.Exception.Message)"
                throw
            }
        }
    }

    Write-Host "`nFramework loaded successfully!`n" -ForegroundColor Green

    # Service container setup and application startup
    Write-Host "Initializing services..." -ForegroundColor Cyan
    $container = [ServiceContainer]::new()
    
    # Register core services
    Write-Host "  • Registering Logger..." -ForegroundColor Gray
    $container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "axiom-phoenix.log")))
    
    Write-Host "  • Registering EventManager..." -ForegroundColor Gray  
    $container.Register("EventManager", [EventManager]::new())
    
    Write-Host "  • Registering ThemeManager..." -ForegroundColor Gray
    $container.Register("ThemeManager", [ThemeManager]::new())
    
    Write-Host "  • Registering DataManager..." -ForegroundColor Gray
    $container.Register("DataManager", [DataManager]::new((Join-Path $env:TEMP "axiom-data.json"), $container.GetService("EventManager")))
    
    Write-Host "  • Registering ActionService..." -ForegroundColor Gray
    $container.Register("ActionService", [ActionService]::new($container.GetService("EventManager")))
    
    Write-Host "  • Registering KeybindingService..." -ForegroundColor Gray
    $container.Register("KeybindingService", [KeybindingService]::new($container.GetService("ActionService")))
    
    Write-Host "  • Registering NavigationService..." -ForegroundColor Gray
    $container.Register("NavigationService", [NavigationService]::new($container))
    
    Write-Host "  • Registering FocusManager..." -ForegroundColor Gray
    $container.Register("FocusManager", [FocusManager]::new($container.GetService("EventManager")))
    
    Write-Host "  • Registering DialogManager..." -ForegroundColor Gray
    $container.Register("DialogManager", [DialogManager]::new($container.GetService("EventManager"), $container.GetService("FocusManager")))
    
    Write-Host "  • Registering ViewDefinitionService..." -ForegroundColor Gray
    $container.Register("ViewDefinitionService", [ViewDefinitionService]::new())
    
    Write-Host "Services initialized successfully!" -ForegroundColor Green

    # Initialize global state
    $global:TuiState.ServiceContainer = $container
    $global:TuiState.Services = @{
        Logger = $container.GetService("Logger")
        EventManager = $container.GetService("EventManager") 
        ThemeManager = $container.GetService("ThemeManager")
        DataManager = $container.GetService("DataManager")
        ActionService = $container.GetService("ActionService")
        KeybindingService = $container.GetService("KeybindingService")
        NavigationService = $container.GetService("NavigationService")
        FocusManager = $container.GetService("FocusManager")
        DialogManager = $container.GetService("DialogManager")
        ViewDefinitionService = $container.GetService("ViewDefinitionService")
    }
    $global:TuiState.ServiceContainer = $container

    # Apply theme and register default actions
    $themeManager = $container.GetService("ThemeManager")
    if ($themeManager -and $Theme) { 
        $themeManager.LoadTheme($Theme)
        Write-Host "Theme '$Theme' activated!" -ForegroundColor Magenta 
    }
    
    $actionService = $container.GetService("ActionService")
    if ($actionService) { 
        $actionService.RegisterDefaultActions()
        Write-Host "Default actions registered!" -ForegroundColor Green 
    }

    # Create sample data
    Write-Host "Generating sample data..." -ForegroundColor Cyan
    $dataManager = $container.GetService("DataManager")
    
    # Create sample tasks
    $sampleTasks = @()
    
    $task1 = [PmcTask]::new("Review project requirements")
    $task1.Status = [TaskStatus]::Pending
    $task1.Priority = [TaskPriority]::High
    $sampleTasks += $task1
    
    $task2 = [PmcTask]::new("Design system architecture")
    $task2.Status = [TaskStatus]::InProgress
    $task2.Priority = [TaskPriority]::High
    $task2.SetProgress(30)
    $sampleTasks += $task2
    
    $task3 = [PmcTask]::new("Implement core features")
    $task3.Status = [TaskStatus]::InProgress
    $task3.Priority = [TaskPriority]::Medium
    $task3.SetProgress(60)
    $sampleTasks += $task3
    
    $task4 = [PmcTask]::new("Write unit tests")
    $task4.Status = [TaskStatus]::Pending
    $task4.Priority = [TaskPriority]::Medium
    $sampleTasks += $task4
    
    $task5 = [PmcTask]::new("Deploy to staging")
    $task5.Status = [TaskStatus]::Pending
    $task5.Priority = [TaskPriority]::Low
    $sampleTasks += $task5
    
    foreach ($task in $sampleTasks) {
        $dataManager.AddTask($task)
    }
    
    Write-Host "Sample data created!" -ForegroundColor Green

    # Launch the application
    Write-Host "`nStarting Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open command palette, Ctrl+Q to quit" -ForegroundColor Yellow
    Start-Sleep -Seconds 1
    
    $dashboardScreen = [DashboardScreen]::new($container)
    Clear-Host
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen

} catch {
    Write-Host "`nCRITICAL ERROR! Failed to start framework." -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
