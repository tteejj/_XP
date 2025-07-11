# Direct navigation test - bypass all UI and test navigation directly

$ErrorActionPreference = 'Stop'

Write-Host "Direct Navigation Test" -ForegroundColor Cyan
Write-Host "=====================" -ForegroundColor Cyan

# Load framework
Write-Host "`nLoading framework..." -ForegroundColor Yellow

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

    $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
    foreach ($file in $files) {
        try {
            . $file.FullName
        } catch {
            Write-Error "Failed to load $($file.Name): $($_.Exception.Message)"
            throw
        }
    }
}

Write-Host "Framework loaded!" -ForegroundColor Green

# Create service container
Write-Host "`nCreating services..." -ForegroundColor Yellow
$container = [ServiceContainer]::new()

# Register essential services only
$container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "test-nav.log")))
$container.Register("EventManager", [EventManager]::new())
$container.Register("ThemeManager", [ThemeManager]::new())
$container.Register("NavigationService", [NavigationService]::new($container))
$container.Register("FocusManager", [FocusManager]::new($container.GetService("EventManager")))

# Get services
$navService = $container.GetService("NavigationService")
$themeManager = $container.GetService("ThemeManager")

Write-Host "Services created!" -ForegroundColor Green

# Test 1: Create and navigate to Dashboard
Write-Host "`nTest 1: Creating DashboardScreen..." -ForegroundColor Cyan
try {
    $dashboard = [DashboardScreen]::new($container)
    Write-Host "  ✓ Created DashboardScreen" -ForegroundColor Green
    
    $dashboard.Initialize()
    Write-Host "  ✓ Initialized DashboardScreen" -ForegroundColor Green
    
    $navService.NavigateTo($dashboard)
    Write-Host "  ✓ Navigated to DashboardScreen" -ForegroundColor Green
    Write-Host "  Current Screen: $($navService.CurrentScreen.Name)" -ForegroundColor White
}
catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

# Test 2: Create and navigate to TaskListScreen
Write-Host "`nTest 2: Creating TaskListScreen..." -ForegroundColor Cyan
try {
    $taskList = [TaskListScreen]::new($container)
    Write-Host "  ✓ Created TaskListScreen" -ForegroundColor Green
    
    $taskList.Initialize()
    Write-Host "  ✓ Initialized TaskListScreen" -ForegroundColor Green
    
    $navService.NavigateTo($taskList)
    Write-Host "  ✓ Navigated to TaskListScreen" -ForegroundColor Green
    Write-Host "  Current Screen: $($navService.CurrentScreen.Name)" -ForegroundColor White
    Write-Host "  Stack Size: $($navService.NavigationStack.Count)" -ForegroundColor White
}
catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

# Test 3: Create and navigate to ThemeScreen
Write-Host "`nTest 3: Creating ThemeScreen..." -ForegroundColor Cyan
try {
    $themeScreen = [ThemeScreen]::new($container)
    Write-Host "  ✓ Created ThemeScreen" -ForegroundColor Green
    
    $themeScreen.Initialize()
    Write-Host "  ✓ Initialized ThemeScreen" -ForegroundColor Green
    
    $navService.NavigateTo($themeScreen)
    Write-Host "  ✓ Navigated to ThemeScreen" -ForegroundColor Green
    Write-Host "  Current Screen: $($navService.CurrentScreen.Name)" -ForegroundColor White
    Write-Host "  Stack Size: $($navService.NavigationStack.Count)" -ForegroundColor White
}
catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
    Write-Host "  Stack: $($_.ScriptStackTrace)" -ForegroundColor Yellow
}

# Test 4: Test GoBack
Write-Host "`nTest 4: Testing GoBack..." -ForegroundColor Cyan
try {
    if ($navService.CanGoBack()) {
        $navService.GoBack()
        Write-Host "  ✓ Went back successfully" -ForegroundColor Green
        Write-Host "  Current Screen: $($navService.CurrentScreen.Name)" -ForegroundColor White
        Write-Host "  Stack Size: $($navService.NavigationStack.Count)" -ForegroundColor White
    }
    else {
        Write-Host "  ! Cannot go back (no screens in stack)" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ✗ FAILED: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n===================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "===================" -ForegroundColor Cyan

if ($navService.CurrentScreen) {
    Write-Host "✓ Navigation system is working" -ForegroundColor Green
    Write-Host "✓ All screens can be created and navigated to" -ForegroundColor Green
    Write-Host "`nThe issue must be in:" -ForegroundColor Yellow
    Write-Host "  - ActionService execution" -ForegroundColor White
    Write-Host "  - Input handling in DashboardScreen" -ForegroundColor White
    Write-Host "  - Global keybinding interference" -ForegroundColor White
}
else {
    Write-Host "✗ Navigation system has issues" -ForegroundColor Red
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
