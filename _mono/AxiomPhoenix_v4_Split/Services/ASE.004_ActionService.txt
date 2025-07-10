# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASE.###" to find specific sections.
# Each section ends with "END_PAGE: ASE.###"
# ==============================================================================

#region Service Classes

# ===== CLASS: ActionService =====
# Module: action-service (from axiom)
# Dependencies: EventManager (optional)
# Purpose: Central command registry and execution service
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
        
        $this.RegisterAction("app.commandPalette", {
            # Write-Verbose "Executing app.commandPalette action"
            # Get required services from global state
            $dialogManager = $global:TuiState.Services.DialogManager
            $actionService = $global:TuiState.Services.ActionService
            
            if (-not $dialogManager -or -not $actionService) {
                Write-Log -Level Error -Message "Required services not available for command palette"
                return
            }
            
            # 1. Create the CommandPalette
            $palette = [CommandPalette]::new("CommandPaletteDialog")
            $palette.Width = 60
            $palette.Height = 20
            
            # 2. Configure - Populate with actions and set OnClose handler
            $allActions = $actionService.GetAllActions()
            $actionList = @()
            foreach ($actionEntry in $allActions.GetEnumerator()) {
                $actionData = $actionEntry.Value
                $actionList += [PSCustomObject]@{
                    Name = $actionEntry.Key
                    Description = $actionData.Description
                    Category = $actionData.Category
                    Hotkey = $actionData.Hotkey
                }
            }
            
            # Set the actions data
            $palette.SetActions($actionList)
            
            # Configure what happens when the dialog closes with a result
            $palette.OnClose = {
                param($result)
                if ($result -and $result.Name) {
                    # Execute the selected action after the dialog has closed
                    try {
                        $actionService.ExecuteAction($result.Name)
                    }
                    catch {
                        Write-Log -Level Error -Message "Failed to execute action '$($result.Name)': $($_.Exception.Message)"
                    }
                }
            }.GetNewClosure()
            
            # 3. Show - Let DialogManager handle everything
            $dialogManager.ShowDialog($palette)
            
        }, @{
            Category = "Application"
            Description = "Show command palette"
            Hotkey = "Ctrl+P"
        })
        
        # Theme picker action
        $this.RegisterAction("ui.theme.picker", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $themeScreen = [ThemePickerScreen]::new($container)
            $themeScreen.Initialize()
            $navService.NavigateTo($themeScreen)
        }, @{
            Category = "UI"
            Description = "Change Theme"
        })
        
        # Task management actions
        $this.RegisterAction("task.new", {
            $navService = $global:TuiState.Services.NavigationService
            $currentScreen = $navService?.CurrentScreen
            if ($currentScreen -is [TaskListScreen]) {
                $currentScreen._newButton.OnClick.Invoke()
            }
        }, @{
            Category = "Tasks"
            Description = "New Task"
        })
        
        $this.RegisterAction("task.list", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $taskScreen = [TaskListScreen]::new($container)
            $taskScreen.Initialize()
            $navService.NavigateTo($taskScreen)
        }, @{
            Category = "Tasks"
            Description = "View All Tasks"
        })
        
        # Add navigation.taskList action for consistency
        $this.RegisterAction("navigation.taskList", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $taskScreen = [TaskListScreen]::new($container)
            $taskScreen.Initialize()
            $navService.NavigateTo($taskScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Task List"
        })
        
        # Add navigation.dashboard action
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
        
        # Add navigation.newTask action
        $this.RegisterAction("navigation.newTask", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $newTaskScreen = [NewTaskScreen]::new($container)
            $newTaskScreen.Initialize()
            $navService.NavigateTo($newTaskScreen)
        }, @{
            Category = "Navigation"
            Description = "Create New Task"
        })
        
        # Add navigation.back action
        $this.RegisterAction("navigation.back", {
            $navService = $global:TuiState.Services.NavigationService
            if ($navService.CanGoBack()) {
                $navService.GoBack()
            }
        }, @{
            Category = "Navigation"
            Description = "Go Back"
        })
        
        # Task CRUD actions
        $this.RegisterAction("task.edit.selected", {
            $navService = $global:TuiState.Services.NavigationService
            $currentScreen = $navService?.CurrentScreen
            if ($currentScreen -is [TaskListScreen] -and $currentScreen._selectedTask) {
                $container = $global:TuiState.ServiceContainer
                $editScreen = [EditTaskScreen]::new($container, $currentScreen._selectedTask)
                $editScreen.Initialize()
                $navService.NavigateTo($editScreen)
            }
        }, @{
            Category = "Tasks"
            Description = "Edit Selected Task"
        })
        
        $this.RegisterAction("task.delete.selected", {
            $navService = $global:TuiState.Services.NavigationService
            $currentScreen = $navService?.CurrentScreen
            if ($currentScreen -is [TaskListScreen] -and $currentScreen._selectedTask) {
                $dataManager = $global:TuiState.Services.DataManager
                $dataManager.DeleteTask($currentScreen._selectedTask.Id)
                $currentScreen._RefreshTasks()
                $currentScreen._UpdateDisplay()
            }
        }, @{
            Category = "Tasks"
            Description = "Delete Selected Task"
        })
        
        $this.RegisterAction("task.complete.selected", {
            $navService = $global:TuiState.Services.NavigationService
            $currentScreen = $navService?.CurrentScreen
            if ($currentScreen -is [TaskListScreen] -and $currentScreen._selectedTask) {
                $currentScreen._selectedTask.Complete()
                $dataManager = $global:TuiState.Services.DataManager
                $dataManager.UpdateTask($currentScreen._selectedTask)
                $currentScreen._RefreshTasks()
                $currentScreen._UpdateDisplay()
            }
        }, @{
            Category = "Tasks"
            Description = "Complete Selected Task"
        })
        
        # Write-Verbose "ActionService: Registered default actions"
    }
}

#endregion
#<!-- END_PAGE: ASE.001 -->
