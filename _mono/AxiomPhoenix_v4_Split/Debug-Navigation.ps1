# Debug Navigation Issues
# This script helps diagnose navigation problems

param(
    [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
if ($Verbose) {
    $VerbosePreference = 'Continue'
}

Write-Host "Navigation Debug Script" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan
Write-Host ""

# Load just the framework without starting the UI
Write-Host "Loading framework files..." -ForegroundColor Yellow

$scriptDir = $PSScriptRoot
$loadOrder = @(
    "Base",
    "Models", 
    "Functions",
    "Components",
    "Screens",
    "Services",
    "Runtime"
)

foreach ($folder in $loadOrder) {
    $folderPath = Join-Path $scriptDir $folder
    if (-not (Test-Path $folderPath)) { 
        Write-Warning "Folder not found: $folder"
        continue 
    }

    Write-Host "Loading $folder..." -ForegroundColor Gray
    $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
    foreach ($file in $files) {
        Write-Verbose "  - Loading $($file.Name)"
        try {
            . $file.FullName
        } catch {
            Write-Error "Failed to load $($file.Name): $($_.Exception.Message)"
            throw
        }
    }
}

Write-Host "`nFramework loaded!" -ForegroundColor Green

# Create service container
Write-Host "`nSetting up services..." -ForegroundColor Yellow
$container = [ServiceContainer]::new()

# Register services
$container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "axiom-debug.log")))
$container.Register("EventManager", [EventManager]::new())
$container.Register("ThemeManager", [ThemeManager]::new())
$container.Register("DataManager", [DataManager]::new((Join-Path $env:TEMP "axiom-data.json"), $container.GetService("EventManager")))
$container.Register("ActionService", [ActionService]::new($container.GetService("EventManager")))
$container.Register("KeybindingService", [KeybindingService]::new($container.GetService("ActionService")))
$container.Register("NavigationService", [NavigationService]::new($container))
$container.Register("FocusManager", [FocusManager]::new($container.GetService("EventManager")))
$container.Register("DialogManager", [DialogManager]::new($container))
$container.Register("ViewDefinitionService", [ViewDefinitionService]::new())

# Initialize global state
$global:TuiState = @{
    Running = $false
    BufferWidth = 120
    BufferHeight = 30
    CompositorBuffer = $null
    PreviousCompositorBuffer = $null
    ScreenStack = [System.Collections.Stack]::new()
    CurrentScreen = $null
    IsDirty = $true
    FocusedComponent = $null
    CommandPalette = $null
    Services = @{}
    ServiceContainer = $container
}

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

# Register default actions
$actionService = $container.GetService("ActionService")
$actionService.RegisterDefaultActions()

Write-Host "Services initialized!" -ForegroundColor Green

# Test navigation functions
Write-Host "`nTesting Navigation..." -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

# Check if classes exist
Write-Host "`nChecking screen classes:" -ForegroundColor Yellow
$screenClasses = @(
    "DashboardScreen",
    "TaskListScreen", 
    "ThemeScreen"
)

foreach ($className in $screenClasses) {
    try {
        $type = [Type]::GetType($className)
        if ($null -ne $type -or (Get-Command -Name "[$className]" -ErrorAction SilentlyContinue)) {
            Write-Host "  ✓ $className found" -ForegroundColor Green
        } else {
            # Try alternative check
            $testObj = New-Object -TypeName $className -ArgumentList $container -ErrorAction Stop
            Write-Host "  ✓ $className found (instantiation test)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ✗ $className NOT FOUND or cannot instantiate" -ForegroundColor Red
        Write-Host "    Error: $_" -ForegroundColor Yellow
    }
}

# Check registered actions
Write-Host "`nChecking registered actions:" -ForegroundColor Yellow
$navActions = @(
    "navigation.dashboard",
    "navigation.taskList",
    "navigation.newTask",
    "navigation.themeScreen",
    "task.list",
    "task.new",
    "ui.theme.picker"
)

foreach ($actionName in $navActions) {
    $action = $actionService.GetAction($actionName)
    if ($action) {
        Write-Host "  ✓ $actionName - $($action.Description)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $actionName NOT REGISTERED" -ForegroundColor Red
    }
}

# Test navigation to each screen
Write-Host "`nTesting screen navigation:" -ForegroundColor Yellow
$navService = $container.GetService("NavigationService")

# Test Dashboard
Write-Host "`n1. Testing DashboardScreen..." -ForegroundColor Cyan
try {
    $dashboard = [DashboardScreen]::new($container)
    $dashboard.Initialize()
    Write-Host "  ✓ DashboardScreen created and initialized" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create DashboardScreen: $_" -ForegroundColor Red
}

# Test TaskListScreen
Write-Host "`n2. Testing TaskListScreen..." -ForegroundColor Cyan
try {
    $taskList = [TaskListScreen]::new($container)
    $taskList.Initialize()
    Write-Host "  ✓ TaskListScreen created and initialized" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create TaskListScreen: $_" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

# Test ThemeScreen
Write-Host "`n3. Testing ThemeScreen..." -ForegroundColor Cyan
try {
    $themeScreen = [ThemeScreen]::new($container)
    $themeScreen.Initialize()
    Write-Host "  ✓ ThemeScreen created and initialized" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Failed to create ThemeScreen: $_" -ForegroundColor Red
}

# Test action execution
Write-Host "`nTesting action execution:" -ForegroundColor Yellow

Write-Host "`n1. Testing navigation.taskList action..." -ForegroundColor Cyan
try {
    # Reset navigation state
    $global:TuiState.ScreenStack.Clear()
    $global:TuiState.CurrentScreen = $null
    
    # Execute action
    $actionService.ExecuteAction("navigation.taskList", @{})
    
    # Check result
    if ($navService.CurrentScreen -is [TaskListScreen]) {
        Write-Host "  ✓ Successfully navigated to TaskListScreen" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Navigation failed - current screen is: $($navService.CurrentScreen.GetType().Name)" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Action execution failed: $_" -ForegroundColor Red
    Write-Host "  Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

Write-Host "`n2. Testing ui.theme.picker action..." -ForegroundColor Cyan
try {
    # Reset navigation state
    $global:TuiState.ScreenStack.Clear()
    $global:TuiState.CurrentScreen = $null
    
    # Execute action
    $actionService.ExecuteAction("ui.theme.picker", @{})
    
    # Check result
    if ($navService.CurrentScreen -is [ThemeScreen]) {
        Write-Host "  ✓ Successfully navigated to ThemeScreen" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Navigation failed - current screen is: $($navService.CurrentScreen?.GetType().Name)" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Action execution failed: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n===================" -ForegroundColor Cyan
Write-Host "Debug Summary" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

$issues = @()

# Check for common issues
if (-not (Get-Command -Name "[TaskListScreen]" -ErrorAction SilentlyContinue)) {
    $issues += "TaskListScreen class may not be properly loaded"
}

if (-not $actionService.GetAction("navigation.taskList")) {
    $issues += "navigation.taskList action not registered"
}

if ($issues.Count -eq 0) {
    Write-Host "`n✓ All navigation components appear to be working correctly!" -ForegroundColor Green
    Write-Host "`nIf navigation still fails in the running app, the issue may be:" -ForegroundColor Yellow
    Write-Host "  - Input handling in the command palette" -ForegroundColor White
    Write-Host "  - Event timing issues" -ForegroundColor White
    Write-Host "  - Focus management conflicts" -ForegroundColor White
} else {
    Write-Host "`n✗ Found $($issues.Count) potential issue(s):" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Yellow
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
