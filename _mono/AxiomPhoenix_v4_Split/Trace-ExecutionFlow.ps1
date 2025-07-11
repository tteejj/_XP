# Final comprehensive test - manually trace the entire execution flow
param(
    [switch]$AutoRun
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host "=== COMMANDPALETTE EXECUTION TRACE ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Load framework files manually to check for syntax errors
Write-Host "TEST 1: Loading framework..." -ForegroundColor Yellow
$loadErrors = @()
try {
    # Load files in correct order
    $loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")
    foreach ($folder in $loadOrder) {
        $files = Get-ChildItem -Path "$PSScriptRoot\$folder" -Filter "*.ps1" | Sort-Object Name
        foreach ($file in $files) {
            . $file.FullName
        }
    }
    Write-Host "✓ Framework loaded successfully" -ForegroundColor Green
    
    # Initialize services manually
    Write-Host "Initializing services..." -ForegroundColor Gray
    $container = [ServiceContainer]::new()
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("ActionService", [ActionService]::new($container.GetService("EventManager")))
    $container.Register("NavigationService", [NavigationService]::new($container))
    $container.Register("FocusManager", [FocusManager]::new($container.GetService("EventManager")))
    
    # Set global state
    $global:TuiState.ServiceContainer = $container
    $global:TuiState.Services = @{
        EventManager = $container.GetService("EventManager")
        ActionService = $container.GetService("ActionService")
        NavigationService = $container.GetService("NavigationService")
        FocusManager = $container.GetService("FocusManager")
    }
    
    # Initialize engine (this should set up DeferredActions)
    Initialize-TuiEngine
    
} catch {
    Write-Host "✗ Framework load FAILED: $_" -ForegroundColor Red
    Write-Host "  At line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host "  File: $($_.InvocationInfo.ScriptName)" -ForegroundColor Yellow
    exit 1
}

# Test 2: Check critical services
Write-Host "`nTEST 2: Checking services..." -ForegroundColor Yellow
$services = @(
    "EventManager",
    "ActionService", 
    "NavigationService",
    "FocusManager"
)

foreach ($svc in $services) {
    if ($global:TuiState.Services.$svc) {
        Write-Host "✓ $svc exists" -ForegroundColor Green
    } else {
        Write-Host "✗ $svc MISSING" -ForegroundColor Red
    }
}

# Test 3: Check DeferredActions setup
Write-Host "`nTEST 3: Checking deferred actions..." -ForegroundColor Yellow
if ($global:TuiState.DeferredActions) {
    Write-Host "✓ DeferredActions queue exists" -ForegroundColor Green
    Write-Host "  Type: $($global:TuiState.DeferredActions.GetType().Name)" -ForegroundColor Gray
} else {
    Write-Host "✗ DeferredActions queue MISSING" -ForegroundColor Red
}

# Test 4: Check event handler registration
Write-Host "`nTEST 4: Checking event handlers..." -ForegroundColor Yellow
$em = $global:TuiState.Services.EventManager
if ($em -and $em.EventHandlers.ContainsKey("DeferredAction")) {
    $count = $em.EventHandlers["DeferredAction"].Count
    Write-Host "✓ DeferredAction handlers registered: $count" -ForegroundColor Green
} else {
    Write-Host "✗ DeferredAction handler NOT registered" -ForegroundColor Red
}

# Test 5: Manually test the action flow
Write-Host "`nTEST 5: Testing action execution flow..." -ForegroundColor Yellow

# Create a test action
$actionService = $global:TuiState.Services.ActionService
$actionService.RegisterAction("test.trace", {
    Write-Host ">>> TEST ACTION EXECUTED! <<<" -ForegroundColor Magenta
}, @{
    Category = "Test"
    Description = "Trace test action"
})

# Simulate what CommandPalette does
Write-Host "  Simulating CommandPalette flow..." -ForegroundColor Cyan

# 1. Create action result (what Complete() receives)
$selectedAction = @{
    Name = "test.trace"
    Category = "Test"
    Description = "Trace test action"
}

# 2. Simulate OnClose callback
Write-Host "  Publishing DeferredAction event..." -ForegroundColor Gray
$em.Publish("DeferredAction", @{ActionName = $selectedAction.Name})

# 3. Check if it was enqueued
Start-Sleep -Milliseconds 100
$queueCount = $global:TuiState.DeferredActions.Count
Write-Host "  Queue count after publish: $queueCount" -ForegroundColor $(if ($queueCount -gt 0) {"Green"} else {"Red"})

# 4. Manually process the queue (what engine does)
if ($queueCount -gt 0) {
    Write-Host "  Processing deferred action..." -ForegroundColor Gray
    $deferredAction = $null
    if ($global:TuiState.DeferredActions.TryDequeue([ref]$deferredAction)) {
        Write-Host "  Dequeued action: $($deferredAction.ActionName)" -ForegroundColor Gray
        try {
            $actionService.ExecuteAction($deferredAction.ActionName, @{})
            Write-Host "✓ Action executed successfully!" -ForegroundColor Green
        } catch {
            Write-Host "✗ Action execution FAILED: $_" -ForegroundColor Red
        }
    }
} else {
    Write-Host "✗ No action in queue to process!" -ForegroundColor Red
}

# Test 6: Run the actual app if requested
if ($AutoRun) {
    Write-Host "`nTEST 6: Starting application..." -ForegroundColor Yellow
    Write-Host "Instructions:" -ForegroundColor Cyan
    Write-Host "1. Press '4' to open Command Palette"
    Write-Host "2. Find 'test.trace' or 'test.simple'"
    Write-Host "3. Press Enter"
    Write-Host "4. Watch the logs for execution"
    Write-Host ""
    
    $env:AXIOM_LOG_LEVEL = "Debug"
    Start-AxiomPhoenix
} else {
    Write-Host "`nTo run the full app test, use: .\$($MyInvocation.MyCommand.Name) -AutoRun" -ForegroundColor Gray
}
