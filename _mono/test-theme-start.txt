# Test Start.ps1 with Theme Picker
# Load all framework files in correct dependency order

$ErrorActionPreference = "Stop"

Write-Host "Axiom-Phoenix v4.0 Starting..." -ForegroundColor Cyan

# Define root path
$scriptRoot = $PSScriptRoot

# Load files in dependency order
$files = @(
    "AllBaseClasses.ps1",
    "AllModels.ps1", 
    "AllComponents.ps1",
    "AllScreens.ps1",
    "AllFunctions.ps1",
    "AllServices.ps1",
    "AllRuntime.ps1"
)

foreach ($file in $files) {
    $fullPath = Join-Path $scriptRoot $file
    if (Test-Path $fullPath) {
        Write-Host "Loading $file..." -ForegroundColor Gray
        . $fullPath
    } else {
        Write-Error "File not found: $fullPath"
        exit 1
    }
}

# Create Service Container
Write-Host "Creating services..." -ForegroundColor Gray
$serviceContainer = [ServiceContainer]::new()

# Register core services
$eventManager = [EventManager]::new()
$serviceContainer.Register("EventManager", $eventManager)

$logger = [Logger]::new()
$serviceContainer.Register("Logger", $logger)

$themeManager = [ThemeManager]::new()
$serviceContainer.Register("ThemeManager", $themeManager)

$actionService = [ActionService]::new($eventManager)
$actionService.RegisterDefaultActions()
$serviceContainer.Register("ActionService", $actionService)

$keybindingService = [KeybindingService]::new($actionService)
$keybindingService.SetDefaultBindings()
$serviceContainer.Register("KeybindingService", $keybindingService)

$dataManager = [DataManager]::new("./data/appdata.json", $eventManager)
$serviceContainer.Register("DataManager", $dataManager)

$navigationService = [NavigationService]::new(@{ EventManager = $eventManager })
$serviceContainer.Register("NavigationService", $navigationService)

$focusManager = [FocusManager]::new($eventManager)
$serviceContainer.Register("FocusManager", $focusManager)

$dialogManager = [DialogManager]::new($eventManager, $focusManager)
$serviceContainer.Register("DialogManager", $dialogManager)

$tuiFrameworkService = [TuiFrameworkService]::new()
$serviceContainer.Register("TuiFrameworkService", $tuiFrameworkService)

# Store services in global state for easy access
$global:TuiState.Services = @{
    Logger = $logger
    EventManager = $eventManager
    ThemeManager = $themeManager
    ActionService = $actionService
    KeybindingService = $keybindingService
    DataManager = $dataManager
    NavigationService = $navigationService
    FocusManager = $focusManager
    DialogManager = $dialogManager
    TuiFrameworkService = $tuiFrameworkService
}
$global:TuiState.ServiceContainer = $serviceContainer

# Initialize the engine
Initialize-TuiEngine

# Create and navigate directly to ThemePickerScreen for testing
Write-Host "Creating ThemePickerScreen..." -ForegroundColor Yellow
$themeScreen = [ThemePickerScreen]::new($serviceContainer)
$themeScreen.Initialize()
$navigationService.NavigateTo($themeScreen)

# Start the application with error handling
try {
    Write-Host "Starting TUI engine..." -ForegroundColor Green
    Start-TuiEngine
} catch {
    Write-Host "Error in TUI engine: $_" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    
    # Try to save crash info
    $crashInfo = @{
        Error = @{
            Type = $_.Exception.GetType().FullName
            Message = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
            InnerException = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        }
        GlobalState = @{
            OverlayCount = if ($global:TuiState.OverlayStack) { $global:TuiState.OverlayStack.Count } else { 0 }
            Running = $global:TuiState.Running
            BufferSize = "$($global:TuiState.BufferWidth)x$($global:TuiState.BufferHeight)"
            CurrentScreen = if ($global:TuiState.CurrentScreen) { $global:TuiState.CurrentScreen.Name } else { "None" }
        }
        System = @{
            OS = [System.Environment]::OSVersion.ToString()
            Host = "$($Host.Name) v$($Host.Version)"
            PowerShell = $PSVersionTable.PSVersion.ToString()
            Platform = $PSVersionTable.Platform
        }
        Timestamp = (Get-Date).ToString("o")
    }
    
    $crashInfo | ConvertTo-Json -Depth 5 | Out-File "crash_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
} finally {
    # Ensure cleanup
    Stop-TuiEngine -Force
    if ($serviceContainer) {
        $serviceContainer.Cleanup()
    }
}

Write-Host "`nApplication exited." -ForegroundColor Gray
