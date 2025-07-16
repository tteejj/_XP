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
            
            $category = "General"
            if ($metadata.ContainsKey('Category')) { $category = $metadata.Category }
            
            $description = ""
            if ($metadata.ContainsKey('Description')) { $description = $metadata.Description }
            
            $hotkey = ""
            if ($metadata.ContainsKey('Hotkey')) { $hotkey = $metadata.Hotkey }
            
            $actionData = @{
                Name = $actionName
                Action = $action
                Category = $category
                Description = $description
                Hotkey = $hotkey
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
        return @($this.ActionRegistry.Values.Where({$_.Category -eq $category}))
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
            
            $commandScreen = New-Object CommandPaletteScreen -ArgumentList $container
            $commandScreen.Initialize()
            $navService.NavigateTo($commandScreen)
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
            $dashboardScreen = New-Object DashboardScreen -ArgumentList $container
            $dashboardScreen.Initialize()
            $navService.NavigateTo($dashboardScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Dashboard"
        })

        $this.RegisterAction("navigation.taskList", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $taskListScreen = New-Object TaskListScreen -ArgumentList $container
            $taskListScreen.Initialize()
            $navService.NavigateTo($taskListScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Task List"
        })

        $this.RegisterAction("navigation.projects", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $projectsScreen = New-Object ProjectsListScreen -ArgumentList $container
            $projectsScreen.Initialize()
            $navService.NavigateTo($projectsScreen)
        }, @{
            Category = "Navigation"
            Description = "Go to Projects List"
        })

        $this.RegisterAction("tools.fileCommander", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $fileCommander = New-Object FileBrowserScreen -ArgumentList $container
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
            $editor = New-Object TextEditScreen -ArgumentList $container
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
            $themeScreen = New-Object ThemeScreen -ArgumentList $container
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

        # Component navigation actions - work with current screen
        $this.RegisterAction("navigation.nextComponent", {
            $navService = $global:TuiState.Services.NavigationService
            if ($navService -and $navService.CurrentScreen) {
                Write-Log -Level Debug -Message "navigation.nextComponent: Calling FocusNextChild on $($navService.CurrentScreen.Name)"
                $focusable = $navService.CurrentScreen.GetFocusableChildren()
                Write-Log -Level Debug -Message "navigation.nextComponent: Found $($focusable.Count) focusable components"
                if ($focusable.Count -gt 0) {
                    foreach ($comp in $focusable) {
                        Write-Log -Level Debug -Message "  - Focusable: $($comp.Name) (TabIndex: $($comp.TabIndex), IsFocusable: $($comp.IsFocusable), Visible: $($comp.Visible), Enabled: $($comp.Enabled))"
                    }
                }
                $currentFocus = $navService.CurrentScreen.GetFocusedChild()
                $currentFocusName = "none"
                if ($currentFocus) { $currentFocusName = $currentFocus.Name }
                Write-Log -Level Debug -Message "navigation.nextComponent: Current focus: $currentFocusName"
                $navService.CurrentScreen.FocusNextChild()
                $newFocus = $navService.CurrentScreen.GetFocusedChild()
                $newFocusName = "none"
                if ($newFocus) { $newFocusName = $newFocus.Name }
                Write-Log -Level Debug -Message "navigation.nextComponent: New focus: $newFocusName"
            }
        }, @{
            Category = "Navigation"
            Description = "Focus Next Component"
            Hotkey = "Tab"
        })

        $this.RegisterAction("navigation.previousComponent", {
            $navService = $global:TuiState.Services.NavigationService
            if ($navService -and $navService.CurrentScreen) {
                Write-Log -Level Debug -Message "navigation.previousComponent: Calling FocusPreviousChild on $($navService.CurrentScreen.Name)"
                $navService.CurrentScreen.FocusPreviousChild()
                $newFocus = $navService.CurrentScreen.GetFocusedChild()
                $newFocusName = "none"
                if ($newFocus) { $newFocusName = $newFocus.Name }
                Write-Log -Level Debug -Message "navigation.previousComponent: New focus: $newFocusName"
            }
        }, @{
            Category = "Navigation"
            Description = "Focus Previous Component"
            Hotkey = "Shift+Tab"
        })

        # Task management actions
        $this.RegisterAction("navigation.newTask", {
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $newTaskScreen = New-Object NewTaskScreen -ArgumentList $container
            $newTaskScreen.Initialize()
            $navService.NavigateTo($newTaskScreen)
        }, @{
            Category = "Tasks"
            Description = "Create New Task"
        })

        $this.RegisterAction("navigation.editTask", {
            param([string]$TaskId)
            $navService = $global:TuiState.Services.NavigationService
            $container = $global:TuiState.ServiceContainer
            $dataManager = $container.GetService("DataManager")
            
            if ($TaskId -and $dataManager) {
                $task = $dataManager.GetTask($TaskId)
                if ($task) {
                    $editTaskScreen = New-Object EditTaskScreen -ArgumentList $container, $task
                    $editTaskScreen.Initialize()
                    $navService.NavigateTo($editTaskScreen)
                }
            }
        }, @{
            Category = "Tasks"
            Description = "Edit Task"
        })

        $this.RegisterAction("tasks.delete", {
            param([string]$TaskId)
            $container = $global:TuiState.ServiceContainer
            $dataManager = $container.GetService("DataManager")
            $dialogManager = $container.GetService("DialogManager")
            
            if ($TaskId -and $dataManager) {
                $task = $dataManager.GetTask($TaskId)
                if ($task) {
                    # Show confirmation dialog
                    $result = $dialogManager.ShowConfirmation(
                        "Delete Task",
                        "Are you sure you want to delete the task '$($task.Title)'?"
                    )
                    
                    if ($result) {
                        $success = $dataManager.DeleteTask($TaskId)
                        if ($success) {
                            Write-Log -Level Info -Message "Task deleted: $($task.Title)"
                        } else {
                            Write-Log -Level Error -Message "Failed to delete task: $($task.Title)"
                        }
                        return $success
                    }
                }
            }
            return $false
        }, @{
            Category = "Tasks"
            Description = "Delete Task"
        })
    }
}

#endregion