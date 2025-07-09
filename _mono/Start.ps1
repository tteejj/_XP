# ==============================================================================
# Axiom-Phoenix v4.0 - Application Startup
# ==============================================================================

param(
    [string]$Theme = "Synthwave",
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Disable verbose output to prevent JSON serialization warnings
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'

# Only enable verbose output if explicitly requested
if ($env:AXIOM_VERBOSE -eq '1') {
    $VerbosePreference = 'Continue'
    $WarningPreference = 'Continue'
}

# Main startup sequence
try {
    
    Write-Host "Loading Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host ""
    
    # Verify PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "ERROR: PowerShell 7.0 or higher is required!" -ForegroundColor Red
        Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
        Write-Host "Download from: https://github.com/PowerShell/PowerShell" -ForegroundColor Cyan
        exit 1
    }
    
    # Get script directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($scriptDir)) {
        $scriptDir = Get-Location
    }
    
    # Load framework files in order with progress indication
    $files = @(
        @{ File = "AllBaseClasses.ps1"; Description = "Core Framework" },
        @{ File = "AllModels.ps1"; Description = "Data Models" },
        @{ File = "AllComponents.ps1"; Description = "UI Components" },
        @{ File = "AllScreens.ps1"; Description = "Application Screens" },
        @{ File = "AllFunctions.ps1"; Description = "Utility Functions" },
        @{ File = "AllServices.ps1"; Description = "Business Services" },
        @{ File = "AllRuntime.ps1"; Description = "Runtime Engine" }
    )
    
    foreach ($fileInfo in $files) {
        Write-Host "Loading $($fileInfo.Description)... " -NoNewline -ForegroundColor Gray
        
        $filePath = Join-Path $scriptDir $fileInfo.File
        if (Test-Path $filePath) {
            . $filePath
            Write-Host "✓" -ForegroundColor Green
        } else {
            Write-Host "✗" -ForegroundColor Red
            throw "File not found: $filePath"
        }
    }
    
    Write-Host ""
    Write-Host "All framework files loaded successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Create service container
    Write-Host "Initializing services..." -ForegroundColor Cyan
    $container = [ServiceContainer]::new()
    
    # Register services
    $services = @(
        @{ Type = "Logger" },
        @{ Type = "EventManager" },
        @{ Type = "ThemeManager" },
        @{ Type = "DataManager" },
        @{ Type = "ActionService" },
        @{ Type = "KeybindingService" },
        @{ Type = "NavigationService" },
        @{ Type = "FocusManager" },
        @{ Type = "DialogManager" },
        @{ Type = "TuiFrameworkService" },
        @{ Type = "CommandPaletteManager" }
    )
    
    # Create a hashtable to store services as we register them
    $servicesHashtable = @{}
    
    foreach ($service in $services) {
        Write-Host "  • Initializing $($service.Type)... " -NoNewline -ForegroundColor Gray
        
        $instance = switch ($service.Type) {
            "Logger" { 
                $logger = [Logger]::new((Join-Path $env:TEMP "axiom-phoenix.log"))
                $logger.MinimumLevel = "Info"  # Only log Info, Warning, Error, Fatal
                $logger.EnableConsoleLogging = $false  # Disable console logging by default
                $logger
            }
            "EventManager" { 
                $eventManager = [EventManager]::new()
                $eventManager.EnableHistory = $false  # Disable event history to prevent any serialization
                $eventManager
            }
            "ThemeManager" { [ThemeManager]::new() }
            "DataManager" { [DataManager]::new((Join-Path $env:TEMP "axiom-data.json")) }
            "ActionService" { [ActionService]::new() }
            "KeybindingService" { [KeybindingService]::new() }
            "NavigationService" { 
                # NavigationService requires a hashtable of services
                [NavigationService]::new($servicesHashtable) 
            }
            "FocusManager" { 
                # FocusManager requires EventManager
                $eventManager = $servicesHashtable.EventManager
                if ($eventManager) {
                    [FocusManager]::new($eventManager)
                } else {
                    [FocusManager]::new($null)
                }
            }
            "DialogManager" { 
                # DialogManager requires EventManager and FocusManager
                $eventManager = $servicesHashtable.EventManager
                $focusManager = $servicesHashtable.FocusManager
                if ($eventManager -and $focusManager) {
                    [DialogManager]::new($eventManager, $focusManager)
                } else {
                    # Create with nulls if dependencies not available
                    [DialogManager]::new($null, $null)
                }
            }
            "TuiFrameworkService" { [TuiFrameworkService]::new() }
            "CommandPaletteManager" { 
                # Create the SINGLE command palette instance
                $actionService = $servicesHashtable.ActionService
                if (-not $actionService) {
                    throw "CommandPaletteManager requires ActionService to be registered first"
                }
                $globalPalette = [CommandPalette]::new("GlobalCommandPalette", $actionService)
                
                # Create and return the manager
                $focusManager = $servicesHashtable.FocusManager
                $frameworkService = $servicesHashtable.TuiFrameworkService
                if (-not $focusManager -or -not $frameworkService) {
                    throw "CommandPaletteManager requires FocusManager and TuiFrameworkService to be registered first"
                }
                [CommandPaletteManager]::new($globalPalette, $focusManager, $frameworkService)
            }
        }
        
        # Store service in hashtable for dependencies
        $servicesHashtable[$service.Type] = $instance
        
        $container.Register($service.Type, $instance)
        Write-Host "✓" -ForegroundColor Green
    }
    
    # Set the selected theme
    $themeManager = $container.GetService("ThemeManager")
    if ($themeManager -and $Theme) {
        $themeManager.LoadTheme($Theme)
        Write-Host ""
        Write-Host "Theme '$Theme' activated!" -ForegroundColor Magenta
    }
    
    # Register default actions
    $actionService = $container.GetService("ActionService")
    if ($actionService) {
        $actionService.RegisterDefaultActions()
        Write-Host "Default actions registered!" -ForegroundColor Green
    }
    
    # Create sample data with enhanced items
    Write-Host ""
    Write-Host "Generating sample data..." -ForegroundColor Cyan
    $dataManager = $container.GetService("DataManager")
    
    # Sample tasks
    $sampleTasks = @(
        @{
            Title = "Implement User Authentication"
            Description = "Add secure login functionality to the application"
            Priority = "High"
            Progress = 75
        },
        @{
            Title = "Update Documentation"
            Description = "Update API documentation with latest changes"
            Priority = "Medium"
            Progress = 45
        },
        @{
            Title = "Fix Memory Leak"
            Description = "Investigate and fix memory leak in data processing module"
            Priority = "High"
            Progress = 90
        },
        @{
            Title = "Design New UI Components"
            Description = "Create mockups for new dashboard components"
            Priority = "Low"
            Progress = 20
        },
        @{
            Title = "Optimize Database Queries"
            Description = "Improve performance of slow database queries"
            Priority = "Medium"
            Progress = 60
        }
    )
    
    foreach ($taskData in $sampleTasks) {
        $task = [PmcTask]::new()
        $task.Title = $taskData.Title
        $task.Description = $taskData.Description
        $task.Priority = [TaskPriority]::$($taskData.Priority)
        $task.SetProgress($taskData.Progress)
        $task.ProjectKey = "PHOENIX"
        [void]$dataManager.AddTask($task)
    }
    
    Write-Host "Sample data created!" -ForegroundColor Green
    
    # Test command palette before starting
    Write-Host ""
    Write-Host "Testing services..." -ForegroundColor Cyan
    $actionService = $container.GetService("ActionService")
    if ($actionService) {
        Write-Host "✓ ActionService available with $($actionService.ActionRegistry.Count) actions" -ForegroundColor Green
    } else {
        Write-Host "✗ ActionService not available!" -ForegroundColor Red
    }
    
    # Start application
    Write-Host ""
    Write-Host "Starting Axiom-Phoenix v4.0..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+P to open command palette, Ctrl+Q to quit" -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    # Create initial screen
    $dashboardScreen = [DashboardScreen]::new($container)
    
    # Launch the application
    Clear-Host
    Start-AxiomPhoenix -ServiceContainer $container -InitialScreen $dashboardScreen
}
catch {
    Write-Host ""
    Write-Host "CRITICAL ERROR!" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host "Failed to load framework files!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Yellow
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    
    if ($Debug) {
        Write-Host ""
        Write-Host "Full Exception:" -ForegroundColor Yellow
        Write-Host $_ -ForegroundColor DarkGray
    }
    
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}
