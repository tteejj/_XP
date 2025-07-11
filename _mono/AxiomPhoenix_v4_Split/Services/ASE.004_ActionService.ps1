# ==============================================================================
# Axiom-Phoenix v4.0 - ActionService
# Central command registry and execution service
# ==============================================================================

class ActionService {
    [hashtable]$ActionRegistry = @{}
    [hashtable]$EventSubscriptions = @{}
    [object]$EventManager = $null
    
    ActionService() {
        # Write-Verbose "ActionService: Initialized with empty registry"
    }
    
    ActionService([object]$eventManager) {
        $this.EventManager = $eventManager
        # Write-Verbose "ActionService: Initialized with EventManager integration"
    }
    
    [void] RegisterAction([string]$actionName, [scriptblock]$action, [hashtable]$metadata = @{}) {
        try {
            if ([string]::IsNullOrWhiteSpace($actionName)) {
                throw "Action name cannot be null or empty"
            }
            if (-not $action) {
                throw "Action scriptblock cannot be null"
            }
            
            $actionData = @{
                Name = $actionName
                Action = $action
                Category = if ($metadata.ContainsKey('Category')) { $metadata.Category } else { "General" }
                Description = if ($metadata.ContainsKey('Description')) { $metadata.Description } else { "" }
                Hotkey = if ($metadata.ContainsKey('Hotkey')) { $metadata.Hotkey } else { "" }
                RegisteredAt = [datetime]::Now
                ExecutionCount = 0
                LastExecuted = $null
                Metadata = $metadata
            }
            
            $this.ActionRegistry[$actionName] = $actionData
            
            # Publish event if EventManager available
            if ($this.EventManager) {
                $this.EventManager.Publish("Action.Registered", @{
                    ActionName = $actionName
                    Category = $actionData.Category
                })
            }
            
            # Write-Verbose "ActionService: Registered action '$actionName' in category '$($actionData.Category)'"
        }
        catch {
            Write-Error "Failed to register action '$actionName': $_"
            throw
        }
    }
    
    [void] UnregisterAction([string]$actionName) {
        if ($this.ActionRegistry.ContainsKey($actionName)) {
            $this.ActionRegistry.Remove($actionName)
            
            if ($this.EventManager) {
                $this.EventManager.Publish("Action.Unregistered", @{
                    ActionName = $actionName
                })
            }
            
            # Write-Verbose "ActionService: Unregistered action '$actionName'"
        }
    }
    
    [object] ExecuteAction([string]$actionName, [hashtable]$parameters = @{}) {
        try {
            if (-not $this.ActionRegistry.ContainsKey($actionName)) {
                throw "Action '$actionName' not found in registry"
            }
            
            $actionData = $this.ActionRegistry[$actionName]
            
            # Update execution metadata
            $actionData.ExecutionCount++
            $actionData.LastExecuted = [datetime]::Now
            
            # Write-Verbose "ActionService: Executing action '$actionName' with $($parameters.Count) parameters"
            
            # Execute the action
            $result = & $actionData.Action @parameters
            
            # Publish execution event
            if ($this.EventManager) {
                $this.EventManager.Publish("Action.Executed", @{
                    ActionName = $actionName
                    Parameters = $parameters
                    Success = $true
                })
            }
            
            return $result
        }
        catch {
            Write-Error "Failed to execute action '$actionName': $_"
            
            if ($this.EventManager) {
                $this.EventManager.Publish("Action.Executed", @{
                    ActionName = $actionName
                    Parameters = $parameters
                    Success = $false
                    Error = $_.ToString()
                })
            }
            
            throw
        }
    }
    
    [hashtable] GetAction([string]$actionName) {
        return $this.ActionRegistry[$actionName]
    }
    
    [hashtable] GetAllActions() {
        return $this.ActionRegistry
    }
    
    [hashtable[]] GetActionsByCategory([string]$category) {
        return @($this.ActionRegistry.Values | Where-Object { $_.Category -eq $category })
    }
    
    [void] RegisterDefaultActions() {
        # Register built-in actions
        $this.RegisterAction("app.exit", {
            # Write-Verbose "Executing app.exit action"
            $global:TuiState.Running = $false
        }, @{
            Category = "Application"
            Description = "Exit the application"
            Hotkey = "Ctrl+Q"
        })
        
        $this.RegisterAction("app.help", {
            # Write-Verbose "Executing app.help action"
            # Would show help screen
        }, @{
            Category = "Application"
            Description = "Show help"
            Hotkey = "F1"
        })
        
        # Use CommandPalette dialog directly (it inherits from Dialog/Screen)
        $this.RegisterAction("app.commandPalette", {
            Write-Log -Level Debug -Message "app.commandPalette action triggered"
            
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $actionService = $global:TuiState.Services.ActionService
            
            if (-not $navService -or -not $container -or -not $actionService) {
                Write-Log -Level Error -Message "Required services not found"
                return
            }
            
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
                    Hotkey = $actionData.Hotkey
                }
            }
            
            # Set actions and show
            $palette.SetActions($allActions)
            
            # Set callback to execute selected action
            $palette.OnClose = {
                param($result)
                Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] CommandPalette OnClose called!"
                if ($result -and $result.Name) {
                    Write-Log -Level Debug -Message "CommandPalette OnClose: Selected action: $($result.Name)"
                    Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] Selected action: $($result.Name)"
                    
                    # Defer execution to avoid re-entrance issues in window-based model
                    # Actions should execute AFTER the dialog closes and navigation completes
                    $evtMgr = $global:TuiState.Services.EventManager
                    if ($evtMgr) {
                        Write-Log -Level Debug -Message "CommandPalette OnClose: Publishing DeferredAction event for: $($result.Name)"
                        Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] Publishing DeferredAction event..."
                        $evtMgr.Publish("DeferredAction", @{
                            ActionName = $result.Name
                        })
                        Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] DeferredAction event published!"
                    } else {
                        Write-Log -Level Error -Message "CommandPalette OnClose: EventManager not found!"
                        Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] ERROR: EventManager not found!"
                    }
                } else {
                    Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] No action selected (result was null or had no Name)"
                }
            }
            
            # Navigate to the palette (it will handle its own lifecycle)
            $navService.NavigateTo($palette)
        }, @{
            Category = "Application"
            Description = "Show command palette"
            Hotkey = "Ctrl+P"
        })
        
        # Theme picker action
        $this.RegisterAction("ui.themePicker", {
            Write-Log -Level Info -Message "Opening Theme Selection screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    $themeScreen = [ThemeScreen]::new($container)
                    $themeScreen.Initialize()
                    $navService.NavigateTo($themeScreen)
                    Write-Log -Level Info -Message "Successfully navigated to ThemeScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to ThemeScreen: $_"
                }
            }
        }, @{
            Category = "UI"
            Description = "Change Theme"
        })
        
        # Task list action
        $this.RegisterAction("task.list", {
            Write-Log -Level Info -Message "Navigating to Task List screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    # Create and navigate to TaskListScreen
                    $taskListScreen = [TaskListScreen]::new($container)
                    $taskListScreen.Initialize()
                    $navService.NavigateTo($taskListScreen)
                    Write-Log -Level Info -Message "Successfully navigated to TaskListScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to TaskListScreen: $_"
                    Write-Log -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
                }
            }
        }, @{
            Category = "Tasks"
            Description = "View All Tasks"
        })
        
        # File browser action
        $this.RegisterAction("tools.fileCommander", {
            Write-Log -Level Info -Message "Navigating to File Commander screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    $fileCommander = [FileCommanderScreen]::new($container)
                    $fileCommander.Initialize()
                    $navService.NavigateTo($fileCommander)
                    Write-Log -Level Info -Message "Successfully navigated to FileCommanderScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to FileCommanderScreen: $_"
                }
            }
        }, @{
            Category = "Tools"
            Description = "File Browser"
            Hotkey = "F9"
        })
        
        # Text editor action
        $this.RegisterAction("tools.textEditor", {
            Write-Log -Level Info -Message "Navigating to Text Editor screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    $editor = [TextEditorScreen]::new($container)
                    $editor.Initialize()
                    $navService.NavigateTo($editor)
                    Write-Log -Level Info -Message "Successfully navigated to TextEditorScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to TextEditorScreen: $_"
                }
            }
        }, @{
            Category = "Tools"
            Description = "Text Editor"
            Hotkey = "Ctrl+E"
        })
        
        # Navigation actions
        $this.RegisterAction("navigation.taskList", {
            Write-Log -Level Info -Message "Navigating to Task List screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    # Create and navigate to TaskListScreen
                    $taskListScreen = [TaskListScreen]::new($container)
                    $taskListScreen.Initialize()
                    $navService.NavigateTo($taskListScreen)
                    Write-Log -Level Info -Message "Successfully navigated to TaskListScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to TaskListScreen: $_"
                    Write-Log -Level Error -Message "Stack trace: $($_.ScriptStackTrace)"
                }
            }
        }, @{
            Category = "Navigation"
            Description = "Go to Task List"
        })
        
        $this.RegisterAction("navigation.dashboard", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $dashboardScreen = [DashboardScreen]::new($container)
            $dashboardScreen.Initialize()
            $navService.NavigateTo($dashboardScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Dashboard"
        })
        
        $this.RegisterAction("navigation.themePicker", {
            Write-Log -Level Info -Message "Navigating to Theme Selection screen"
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                try {
                    $themeScreen = [ThemeScreen]::new($container)
                    $themeScreen.Initialize()
                    $navService.NavigateTo($themeScreen)
                    Write-Log -Level Info -Message "Successfully navigated to ThemeScreen"
                }
                catch {
                    Write-Log -Level Error -Message "Failed to navigate to ThemeScreen: $_"
                }
            }
        }, @{
            Category = "Navigation"
            Description = "Go to Theme Selection"
        })
        
        # Add navigation.commandPalette for menu option
        $this.RegisterAction("navigation.commandPalette", {
            $this.ExecuteAction("app.commandPalette", @{})
        }, @{
            Category = "Navigation"
            Description = "Open Command Palette"
        })
        
        $this.RegisterAction("navigation.back", {
            $navService = $global:TuiState.Services.NavigationService
            if ($navService.CanGoBack()) {
                $navService.GoBack()
            }
        }, @{
            Category = "Navigation"
            Description = "Go Back"
        })
        
        # Task CRUD actions (placeholders for now)
        $this.RegisterAction("task.edit.selected", {
            Write-Log -Level Info -Message "Edit task not implemented yet"
        }, @{
            Category = "Tasks"
            Description = "Edit Selected Task"
        })
        
        $this.RegisterAction("task.delete.selected", {
            Write-Log -Level Info -Message "Delete task not implemented yet"
        }, @{
            Category = "Tasks"
            Description = "Delete Selected Task"
        })
        
        $this.RegisterAction("task.complete.selected", {
            Write-Log -Level Info -Message "Complete task not implemented yet"
        }, @{
            Category = "Tasks"
            Description = "Complete Selected Task"
        })
        
        # Simple test action that returns to dashboard
        $this.RegisterAction("test.simple", {
            Write-Log -Level Info -Message "TEST ACTION EXECUTED: Showing test dialog"
            Add-Content -Path "$PSScriptRoot\..\debug-trace.log" -Value "[$(Get-Date -Format 'HH:mm:ss.fff')] >>> TEST ACTION EXECUTED! <<<"
            
            $dialogManager = $global:TuiState.Services.DialogManager
            if ($dialogManager) {
                # Show a simple message dialog
                $dialogManager.ShowMessage(
                    "Test Action Executed!", 
                    "This confirms that command palette actions are working correctly.`n`nPress any key to continue.", 
                    "Info"
                )
            }
            
            # Navigate back to dashboard
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            if ($navService -and $container) {
                $dashboardScreen = [DashboardScreen]::new($container)
                $dashboardScreen.Initialize()
                $navService.NavigateTo($dashboardScreen)
                Write-Log -Level Info -Message "Test complete - navigated to dashboard"
            }
        }, @{
            Category = "Test"
            Description = "Simple test - show dialog and refresh"
        })
        
        # Write-Verbose "ActionService: Registered default actions"
    }
}

#endregion
