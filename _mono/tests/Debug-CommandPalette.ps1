# ==============================================================================
# Debug Script for CommandPalette Action Execution
# Tests why actions aren't executing when Enter is pressed
# ==============================================================================

param(
    [switch]$Debug
)

# Set error action preference
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing CommandPalette Action Execution..." -ForegroundColor Cyan
    
    # Load the framework (don't start the full app)
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    
    # Load all framework files
    $loadOrder = @("Base", "Models", "Functions", "Components", "Screens", "Services", "Runtime")
    foreach ($folder in $loadOrder) {
        $folderPath = Join-Path $scriptDir $folder
        if (Test-Path $folderPath) {
            $files = Get-ChildItem -Path $folderPath -Filter "*.ps1" | Sort-Object Name
            foreach ($file in $files) {
                . $file.FullName
            }
        }
    }
    
    # Setup minimal services
    $container = [ServiceContainer]::new()
    $container.Register("Logger", [Logger]::new((Join-Path $env:TEMP "axiom-debug.log")))
    $container.Register("EventManager", [EventManager]::new())
    $container.Register("ThemeManager", [ThemeManager]::new())
    $container.Register("ActionService", [ActionService]::new($container.GetService("EventManager")))
    $container.Register("NavigationService", [NavigationService]::new($container))
    $container.Register("FocusManager", [FocusManager]::new($container.GetService("EventManager")))
    
    # Initialize global state
    $global:TuiState.ServiceContainer = $container
    $global:TuiState.Services = @{
        Logger = $container.GetService("Logger")
        EventManager = $container.GetService("EventManager")
        ActionService = $container.GetService("ActionService")
        NavigationService = $container.GetService("NavigationService")
        FocusManager = $container.GetService("FocusManager")
    }
    
    # Register test actions
    $actionService = $container.GetService("ActionService")
    $actionService.RegisterAction("test.action1", {
        Write-Host "TEST ACTION 1 EXECUTED!" -ForegroundColor Green
    }, @{ Category = "Test"; Description = "First test action" })
    
    $actionService.RegisterAction("test.action2", {
        Write-Host "TEST ACTION 2 EXECUTED!" -ForegroundColor Yellow
    }, @{ Category = "Test"; Description = "Second test action" })
    
    # Test 1: Direct action execution
    Write-Host "`nTest 1: Direct Action Execution" -ForegroundColor Yellow
    $actionService.ExecuteAction("test.action1", @{})
    Write-Host "  Direct execution works!" -ForegroundColor Green
    
    # Test 2: Create CommandPalette manually
    Write-Host "`nTest 2: CommandPalette Setup" -ForegroundColor Yellow
    $palette = [CommandPalette]::new("TestPalette", $container)
    
    # Set actions
    $allActions = @()
    foreach ($actionName in $actionService.ActionRegistry.Keys) {
        $actionData = $actionService.ActionRegistry[$actionName]
        $allActions += @{
            Name = $actionName
            Category = $actionData.Category
            Description = $actionData.Description
        }
    }
    $palette.SetActions($allActions)
    Write-Host "  Actions set: $($palette._filteredActions.Count) actions available" -ForegroundColor Green
    
    # Test 3: Test Complete method
    Write-Host "`nTest 3: Complete Method" -ForegroundColor Yellow
    
    # Set up event listener for DeferredAction
    $deferredCalled = $false
    $eventManager = $container.GetService("EventManager")
    $eventManager.Subscribe("DeferredAction", {
        param($sender, $data)
        Write-Host "  DeferredAction event received! ActionName: $($data.ActionName)" -ForegroundColor Cyan
        $script:deferredCalled = $true
    })
    
    # Set OnClose callback
    $palette.OnClose = {
        param($result)
        Write-Host "  OnClose callback triggered! Result: $($result | ConvertTo-Json -Compress)" -ForegroundColor Magenta
        if ($result) {
            Write-Host "  Publishing DeferredAction for: $($result.Name)" -ForegroundColor Magenta
            $eventManager = $global:TuiState.Services.EventManager
            if ($eventManager) {
                $eventManager.Publish("DeferredAction", @{
                    ActionName = $result.Name
                })
            }
        }
    }
    
    # Simulate selecting an action
    $testAction = $palette._filteredActions[0]
    Write-Host "  Calling Complete with action: $($testAction.Name)" -ForegroundColor Yellow
    
    # Call Complete (this should trigger OnClose)
    $palette.Complete($testAction)
    
    Write-Host "  Complete called. Result set to: $($palette.Result | ConvertTo-Json -Compress)" -ForegroundColor Green
    Write-Host "  DeferredAction event published: $deferredCalled" -ForegroundColor $(if ($deferredCalled) { 'Green' } else { 'Red' })
    
    # Test 4: Test the full app.commandPalette action
    Write-Host "`nTest 4: Full app.commandPalette Action" -ForegroundColor Yellow
    
    # Register the full action as in the real app
    $actionService.RegisterAction("app.commandPalette", {
        Write-Host "  app.commandPalette action triggered" -ForegroundColor Cyan
        
        $navService = $global:TuiState.Services.NavigationService
        $container = $global:TuiState.ServiceContainer
        $actionService = $global:TuiState.Services.ActionService
        
        # Create CommandPalette dialog
        $palette = [CommandPalette]::new("CommandPalette", $container)
        
        # Get all registered actions
        $allActions = @()
        foreach ($actionName in $actionService.ActionRegistry.Keys) {
            $actionData = $actionService.ActionRegistry[$actionName]
            $allActions += @{
                Name = $actionName
                Category = $actionData.Category
                Description = $actionData.Description
            }
        }
        
        Write-Host "  Setting $($allActions.Count) actions" -ForegroundColor Cyan
        $palette.SetActions($allActions)
        
        # Set callback to execute selected action
        $palette.OnClose = {
            param($result)
            Write-Host "  OnClose in app.commandPalette! Result: $(if ($result) { $result.Name } else { 'null' })" -ForegroundColor Green
            if ($result) {
                Write-Host "  Publishing DeferredAction..." -ForegroundColor Green
                $eventManager = $global:TuiState.Services.EventManager
                if ($eventManager) {
                    $eventManager.Publish("DeferredAction", @{
                        ActionName = $result.Name
                    })
                }
            }
        }
        
        Write-Host "  CommandPalette created and configured" -ForegroundColor Cyan
        
        # Instead of navigating (which would require full UI), test directly
        # Simulate user selecting first action
        if ($palette._filteredActions.Count -gt 0) {
            $selectedAction = $palette._filteredActions[0]
            Write-Host "  Simulating selection of: $($selectedAction.Name)" -ForegroundColor Yellow
            $palette.Complete($selectedAction)
        }
    }, @{ Category = "Application"; Description = "Show command palette" })
    
    # Execute the action
    $actionService.ExecuteAction("app.commandPalette", @{})
    
    Write-Host "`nAll tests completed!" -ForegroundColor Green
    
} catch {
    Write-Host "`nTest failed!" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
