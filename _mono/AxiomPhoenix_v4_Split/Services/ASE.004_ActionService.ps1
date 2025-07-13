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
            $global:TuiState.Running = $false
        }, @{
            Category = "Application"
            Description = "Exit the application"
            Hotkey = "Ctrl+Q"
        })
        
        $this.RegisterAction("app.exit.ctrlc", {
            $global:TuiState.Running = $false
        }, @{
            Category = "Application"
            Description = "Exit the application (Ctrl+C)"
            Hotkey = "Ctrl+C"
        })
        
        $this.RegisterAction("app.help", {
            # Placeholder for help screen
        }, @{
            Category = "Application"
            Description = "Show help"
            Hotkey = "F1"
        })
        
        # FIXED: Use CommandPalette dialog correctly
        $this.RegisterAction("app.commandPalette", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $actionService = $global:TuiState.Services.ActionService
            
            if (-not ($navService -and $container -and $actionService)) {
                Write-Log -Level Error -Message "CommandPalette: Required services not found"
                return
            }
            
            $palette = [CommandPalette]::new("CommandPalette", $container)
            
            $allActions = @($actionService.GetAllActions().Values | ForEach-Object {
                @{
                    Name = $_.Name
                    Category = $_.Category
                    Description = $_.Description
                    Hotkey = $_.Hotkey
                }
            })
            
            $palette.SetActions($allActions)
            
            # FIXED: Use OnClose with DeferredAction for robust execution
            $palette.OnClose = {
                param($result)
                if ($result -and $result.Name) {
                    $evtMgr = $global:TuiState.Services.EventManager
                    if ($evtMgr) {
                        $evtMgr.Publish("DeferredAction", @{ ActionName = $result.Name })
                    }
                }
            }.GetNewClosure()
            
            $navService.NavigateTo($palette)
        }, @{
            Category = "Application"
            Description = "Show command palette"
            Hotkey = "Ctrl+P"
        })
        
        # FIXED: All navigation actions now defer screen creation until execution time
        # This breaks the circular dependency at parse time.
        
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

        $this.RegisterAction("navigation.taskList", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $taskListScreen = [TaskListScreen]::new($container)
            $taskListScreen.Initialize()
            $navService.NavigateTo($taskListScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Task List"
        })

        $this.RegisterAction("navigation.projects", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $projectsScreen = [ProjectsListScreen]::new($container)
            $projectsScreen.Initialize()
            $navService.NavigateTo($projectsScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Projects List"
        })

        $this.RegisterAction("tools.fileCommander", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $fileCommander = [FileCommanderScreen]::new($container)
            $fileCommander.Initialize()
            $navService.NavigateTo($fileCommander)
        }, @{
            Category = "Tools"
            Description = "File Browser"
            Hotkey = "F9"
        })

        $this.RegisterAction("tools.textEditor", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $editor = [TextEditorScreen]::new($container)
            $editor.Initialize()
            $navService.NavigateTo($editor)
        }, @{
            Category = "Tools"
            Description = "Text Editor"
            Hotkey = "Ctrl+E"
        })

        $this.RegisterAction("navigation.themePicker", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $themeScreen = [ThemeScreen]::new($container)
            $themeScreen.Initialize()
            $navService.NavigateTo($themeScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Theme Selection"
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
    }
}

#endregion