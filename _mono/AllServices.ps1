# ==============================================================================
# Axiom-Phoenix v4.0 - All Services (Load After Components)
# Core application services: action, navigation, data, theming, logging, events
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
        Write-Verbose "ActionService: Initialized with empty registry"
    }
    
    ActionService([object]$eventManager) {
        $this.EventManager = $eventManager
        Write-Verbose "ActionService: Initialized with EventManager integration"
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
                Category = $metadata.Category ?? "General"
                Description = $metadata.Description ?? ""
                Hotkey = $metadata.Hotkey ?? ""
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
            
            Write-Verbose "ActionService: Registered action '$actionName' in category '$($actionData.Category)'"
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
            
            Write-Verbose "ActionService: Unregistered action '$actionName'"
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
            
            Write-Verbose "ActionService: Executing action '$actionName' with $($parameters.Count) parameters"
            
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
    
    [hashtable[]] GetAllActions() {
        return $this.ActionRegistry.Values | ForEach-Object { $_ }
    }
    
    [hashtable[]] GetActionsByCategory([string]$category) {
        return $this.ActionRegistry.Values | Where-Object { $_.Category -eq $category }
    }
    
    [void] RegisterDefaultActions() {
        # Register built-in actions
        $this.RegisterAction("app.exit", {
            Write-Verbose "Executing app.exit action"
            $global:TuiState.Running = $false
        }, @{
            Category = "Application"
            Description = "Exit the application"
            Hotkey = "Ctrl+Q"
        })
        
        $this.RegisterAction("app.help", {
            Write-Verbose "Executing app.help action"
            # Would show help screen
        }, @{
            Category = "Application"
            Description = "Show help"
            Hotkey = "F1"
        })
        
        Write-Verbose "ActionService: Registered default actions"
    }
}

# ===== CLASS: KeybindingService =====
# Module: keybinding-service (from axiom)
# Dependencies: ActionService (optional)
# Purpose: Global keyboard shortcut management
class KeybindingService {
    [hashtable]$KeyMap = @{}
    [hashtable]$GlobalHandlers = @{}
    [System.Collections.Generic.Stack[hashtable]]$ContextStack
    [ActionService]$ActionService
    [bool]$EnableChords = $false
    
    KeybindingService() {
        $this.ContextStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this._InitializeDefaultBindings()
    }
    
    KeybindingService([ActionService]$actionService) {
        $this.ActionService = $actionService
        $this.ContextStack = [System.Collections.Generic.Stack[hashtable]]::new()
        $this._InitializeDefaultBindings()
    }
    
    hidden [void] _InitializeDefaultBindings() {
        # Default global bindings
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Navigation bindings
        $this.SetBinding("Tab", "navigation.nextComponent", "Global")
        $this.SetBinding("Shift+Tab", "navigation.previousComponent", "Global")
        
        # Arrow keys
        $this.SetBinding("UpArrow", "navigation.up", "Global")
        $this.SetBinding("DownArrow", "navigation.down", "Global")
        $this.SetBinding("LeftArrow", "navigation.left", "Global")
        $this.SetBinding("RightArrow", "navigation.right", "Global")
        
        Write-Verbose "KeybindingService: Initialized default keybindings"
    }
    
    [void] SetBinding([string]$keyPattern, [string]$actionName, [string]$context = "Global") {
        if (-not $this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context] = @{}
        }
        
        $this.KeyMap[$context][$keyPattern] = $actionName
        Write-Verbose "KeybindingService: Bound '$keyPattern' to '$actionName' in context '$context'"
    }
    
    [void] RemoveBinding([string]$keyPattern, [string]$context = "Global") {
        if ($this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context].Remove($keyPattern)
            Write-Verbose "KeybindingService: Removed binding for '$keyPattern' in context '$context'"
        }
    }
    
    [bool] IsAction([System.ConsoleKeyInfo]$keyInfo, [string]$actionName) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        
        # Check current context stack
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern) -and $context[$keyPattern] -eq $actionName) {
                return $true
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and 
            $this.KeyMap["Global"].ContainsKey($keyPattern) -and
            $this.KeyMap["Global"][$keyPattern] -eq $actionName) {
            return $true
        }
        
        return $false
    }
    
    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        
        # Check current context stack (most recent first)
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern)) {
                return $context[$keyPattern]
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and $this.KeyMap["Global"].ContainsKey($keyPattern)) {
            return $this.KeyMap["Global"][$keyPattern]
        }
        
        return $null
    }
    
    [string] GetBindingDescription([System.ConsoleKeyInfo]$keyInfo) {
        $action = $this.GetAction($keyInfo)
        if ($action -and $this.ActionService) {
            $actionData = $this.ActionService.GetAction($action)
            if ($actionData) {
                return $actionData.Description
            }
        }
        return $null
    }
    
    hidden [string] _GetKeyPattern([System.ConsoleKeyInfo]$keyInfo) {
        $parts = @()
        
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) {
            $parts += "Ctrl"
        }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) {
            $parts += "Alt"
        }
        if ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) {
            $parts += "Shift"
        }
        
        $parts += $keyInfo.Key.ToString()
        
        return $parts -join "+"
    }
    
    [void] PushContext([hashtable]$contextBindings) {
        $this.ContextStack.Push($contextBindings)
        Write-Verbose "KeybindingService: Pushed new context with $($contextBindings.Count) bindings"
    }
    
    [void] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $removed = $this.ContextStack.Pop()
            Write-Verbose "KeybindingService: Popped context with $($removed.Count) bindings"
        }
    }
    
    [void] RegisterGlobalHandler([string]$handlerId, [scriptblock]$handler) {
        $this.GlobalHandlers[$handlerId] = $handler
        Write-Verbose "KeybindingService: Registered global handler '$handlerId'"
    }
    
    [void] UnregisterGlobalHandler([string]$handlerId) {
        $this.GlobalHandlers.Remove($handlerId)
        Write-Verbose "KeybindingService: Unregistered global handler '$handlerId'"
    }
}

# ===== CLASS: DataManager =====
# Module: data-manager (from axiom)
# Dependencies: EventManager (optional), PmcTask, PmcProject
# Purpose: High-performance data management with transactions
class DataManager {
    [hashtable]$Tasks = @{}
    [hashtable]$Projects = @{}
    [hashtable]$TasksByProject = @{}
    [string]$DataPath
    [EventManager]$EventManager
    [bool]$IsDirty = $false
    [bool]$AutoSave = $true
    [int]$BatchUpdateCount = 0
    [datetime]$LastSave = [datetime]::Now
    [hashtable]$Metadata = @{}
    [int]$MaxBackups = 5
    
    DataManager() {
        $this.DataPath = Join-Path $env:APPDATA "AxiomPhoenix\data.json"
        $this._Initialize()
    }
    
    DataManager([string]$dataPath) {
        $this.DataPath = $dataPath
        $this._Initialize()
    }
    
    DataManager([string]$dataPath, [EventManager]$eventManager) {
        $this.DataPath = $dataPath
        $this.EventManager = $eventManager
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        $dataDir = Split-Path -Parent $this.DataPath
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        Write-Verbose "DataManager: Initialized with data path: $($this.DataPath)"
    }
    
    [void] LoadData() {
        try {
            if (Test-Path $this.DataPath) {
                $jsonContent = Get-Content -Path $this.DataPath -Raw
                $data = $jsonContent | ConvertFrom-Json -AsHashtable
                
                # Load tasks
                $this.Tasks.Clear()
                $this.TasksByProject.Clear()
                
                if ($data.ContainsKey('Tasks')) {
                    foreach ($taskData in $data.Tasks) {
                        $task = [PmcTask]::new()
                        # Map properties
                        $taskData.GetEnumerator() | ForEach-Object {
                            if ($task.PSObject.Properties.Match($_.Name)) {
                                $task.($_.Name) = $_.Value
                            }
                        }
                        
                        $this.Tasks[$task.Id] = $task
                        
                        # Update project index
                        if (-not $this.TasksByProject.ContainsKey($task.ProjectKey)) {
                            $this.TasksByProject[$task.ProjectKey] = @()
                        }
                        $this.TasksByProject[$task.ProjectKey] += $task.Id
                    }
                }
                
                # Load projects
                $this.Projects.Clear()
                if ($data.ContainsKey('Projects')) {
                    foreach ($projectData in $data.Projects) {
                        $project = [PmcProject]::new()
                        # Map properties
                        $projectData.GetEnumerator() | ForEach-Object {
                            if ($project.PSObject.Properties.Match($_.Name)) {
                                $project.($_.Name) = $_.Value
                            }
                        }
                        
                        $this.Projects[$project.Key] = $project
                    }
                }
                
                # Load metadata
                if ($data.ContainsKey('Metadata')) {
                    $this.Metadata = $data.Metadata
                }
                
                $this.IsDirty = $false
                Write-Verbose "DataManager: Loaded $($this.Tasks.Count) tasks and $($this.Projects.Count) projects"
                
                if ($this.EventManager) {
                    $this.EventManager.Publish("Data.Loaded", @{
                        TaskCount = $this.Tasks.Count
                        ProjectCount = $this.Projects.Count
                    })
                }
            }
            else {
                Write-Verbose "DataManager: No data file found at $($this.DataPath)"
            }
        }
        catch {
            Write-Error "Failed to load data: $_"
            throw [DataLoadException]::new("Failed to load data from $($this.DataPath)", "DataManager", @{}, $_)
        }
    }
    
    [void] SaveData() {
        try {
            if ($this.BatchUpdateCount -gt 0) {
                Write-Verbose "DataManager: Save deferred - batch update in progress"
                return
            }
            
            # Create backup if file exists
            if (Test-Path $this.DataPath) {
                $this._CreateBackup()
            }
            
            $data = @{
                Tasks = $this.Tasks.Values | ForEach-Object {
                    @{
                        Id = $_.Id
                        Title = $_.Title
                        Description = $_.Description
                        Status = $_.Status.ToString()
                        Priority = $_.Priority.ToString()
                        ProjectKey = $_.ProjectKey
                        Category = $_.Category
                        CreatedAt = $_.CreatedAt
                        UpdatedAt = $_.UpdatedAt
                        DueDate = $_.DueDate
                        Tags = $_.Tags
                        Progress = $_.Progress
                        Completed = $_.Completed
                    }
                }
                Projects = $this.Projects.Values | ForEach-Object {
                    @{
                        Key = $_.Key
                        Name = $_.Name
                        Description = $_.Description
                        CreatedAt = $_.CreatedAt
                        UpdatedAt = $_.UpdatedAt
                        Owner = $_.Owner
                        Tags = $_.Tags
                        Metadata = $_.Metadata
                        IsActive = $_.IsActive
                    }
                }
                Metadata = $this.Metadata
                SavedAt = [datetime]::Now
            }
            
            $jsonContent = $data | ConvertTo-Json -Depth 10
            Set-Content -Path $this.DataPath -Value $jsonContent -Force
            
            $this.IsDirty = $false
            $this.LastSave = [datetime]::Now
            
            Write-Verbose "DataManager: Saved $($this.Tasks.Count) tasks and $($this.Projects.Count) projects"
            
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.Saved", @{
                    TaskCount = $this.Tasks.Count
                    ProjectCount = $this.Projects.Count
                })
            }
        }
        catch {
            Write-Error "Failed to save data: $_"
            throw
        }
    }
    
    hidden [void] _CreateBackup() {
        try {
            $backupDir = Join-Path (Split-Path -Parent $this.DataPath) "backups"
            if (-not (Test-Path $backupDir)) {
                New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            }
            
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupPath = Join-Path $backupDir "data_$timestamp.json"
            
            Copy-Item -Path $this.DataPath -Destination $backupPath -Force
            
            # Clean old backups
            $backups = Get-ChildItem -Path $backupDir -Filter "data_*.json" | 
                       Sort-Object -Property LastWriteTime -Descending
            
            if ($backups.Count -gt $this.MaxBackups) {
                $backups | Select-Object -Skip $this.MaxBackups | Remove-Item -Force
            }
            
            Write-Verbose "DataManager: Created backup at $backupPath"
        }
        catch {
            Write-Warning "Failed to create backup: $_"
        }
    }
    
    # Task operations
    [PmcTask[]] GetTasks() {
        return $this.Tasks.Values | ForEach-Object { $_ }
    }
    
    [PmcTask] GetTask([string]$id) {
        return $this.Tasks[$id]
    }
    
    [PmcTask[]] GetTasksByProject([string]$projectKey) {
        if ($this.TasksByProject.ContainsKey($projectKey)) {
            return $this.TasksByProject[$projectKey] | ForEach-Object { $this.Tasks[$_] } | Where-Object { $_ }
        }
        return @()
    }
    
    [void] AddTask([PmcTask]$task) {
        if (-not $task) {
            throw [ArgumentNullException]::new("task")
        }
        
        $this.Tasks[$task.Id] = $task
        
        # Update project index
        if (-not $this.TasksByProject.ContainsKey($task.ProjectKey)) {
            $this.TasksByProject[$task.ProjectKey] = @()
        }
        $this.TasksByProject[$task.ProjectKey] += $task.Id
        
        $this.IsDirty = $true
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Data.TaskAdded", @{ Task = $task })
        }
        
        if ($this.AutoSave -and $this.BatchUpdateCount -eq 0) {
            $this.SaveData()
        }
        
        Write-Verbose "DataManager: Added task '$($task.Title)' with ID: $($task.Id)"
    }
    
    [void] UpdateTask([PmcTask]$task) {
        if (-not $task) {
            throw [ArgumentNullException]::new("task")
        }
        
        if (-not $this.Tasks.ContainsKey($task.Id)) {
            throw "Task with ID '$($task.Id)' not found"
        }
        
        $oldTask = $this.Tasks[$task.Id]
        
        # Update project index if project changed
        if ($oldTask.ProjectKey -ne $task.ProjectKey) {
            # Remove from old project
            if ($this.TasksByProject.ContainsKey($oldTask.ProjectKey)) {
                $this.TasksByProject[$oldTask.ProjectKey] = 
                    $this.TasksByProject[$oldTask.ProjectKey] | Where-Object { $_ -ne $task.Id }
            }
            
            # Add to new project
            if (-not $this.TasksByProject.ContainsKey($task.ProjectKey)) {
                $this.TasksByProject[$task.ProjectKey] = @()
            }
            $this.TasksByProject[$task.ProjectKey] += $task.Id
        }
        
        $this.Tasks[$task.Id] = $task
        $this.IsDirty = $true
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Data.TaskUpdated", @{ 
                Task = $task
                OldTask = $oldTask
            })
        }
        
        if ($this.AutoSave -and $this.BatchUpdateCount -eq 0) {
            $this.SaveData()
        }
        
        Write-Verbose "DataManager: Updated task '$($task.Title)'"
    }
    
    [void] RemoveTask([string]$id) {
        if ($this.Tasks.ContainsKey($id)) {
            $task = $this.Tasks[$id]
            
            # Remove from project index
            if ($this.TasksByProject.ContainsKey($task.ProjectKey)) {
                $this.TasksByProject[$task.ProjectKey] = 
                    $this.TasksByProject[$task.ProjectKey] | Where-Object { $_ -ne $id }
            }
            
            $this.Tasks.Remove($id)
            $this.IsDirty = $true
            
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.TaskRemoved", @{ TaskId = $id })
            }
            
            if ($this.AutoSave -and $this.BatchUpdateCount -eq 0) {
                $this.SaveData()
            }
            
            Write-Verbose "DataManager: Removed task with ID: $id"
        }
    }
    
    # Project operations
    [PmcProject[]] GetProjects() {
        return $this.Projects.Values | ForEach-Object { $_ }
    }
    
    [PmcProject] GetProject([string]$key) {
        return $this.Projects[$key]
    }
    
    [void] AddProject([PmcProject]$project) {
        if (-not $project) {
            throw [ArgumentNullException]::new("project")
        }
        
        $this.Projects[$project.Key] = $project
        $this.IsDirty = $true
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Data.ProjectAdded", @{ Project = $project })
        }
        
        if ($this.AutoSave -and $this.BatchUpdateCount -eq 0) {
            $this.SaveData()
        }
        
        Write-Verbose "DataManager: Added project '$($project.Name)' with key: $($project.Key)"
    }
    
    [void] UpdateProject([PmcProject]$project) {
        if (-not $project) {
            throw [ArgumentNullException]::new("project")
        }
        
        if (-not $this.Projects.ContainsKey($project.Key)) {
            throw "Project with key '$($project.Key)' not found"
        }
        
        $oldProject = $this.Projects[$project.Key]
        $this.Projects[$project.Key] = $project
        $this.IsDirty = $true
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Data.ProjectUpdated", @{ 
                Project = $project
                OldProject = $oldProject
            })
        }
        
        if ($this.AutoSave -and $this.BatchUpdateCount -eq 0) {
            $this.SaveData()
        }
        
        Write-Verbose "DataManager: Updated project '$($project.Name)'"
    }
    
    # Transaction support
    [void] BeginUpdate() {
        $this.BatchUpdateCount++
        Write-Verbose "DataManager: Began batch update (level: $($this.BatchUpdateCount))"
    }
    
    [void] EndUpdate() {
        $this.BatchUpdateCount--
        if ($this.BatchUpdateCount -eq 0 -and $this.IsDirty -and $this.AutoSave) {
            $this.SaveData()
        }
        Write-Verbose "DataManager: Ended batch update (level: $($this.BatchUpdateCount))"
    }
}

# ===== CLASS: NavigationService =====
# Module: navigation-service (from axiom)
# Dependencies: EventManager (optional)
# Purpose: Screen navigation and history management
class NavigationService {
    [System.Collections.Generic.Stack[Screen]]$NavigationStack
    [Screen]$CurrentScreen
    [EventManager]$EventManager
    [hashtable]$ScreenRegistry = @{}
    [int]$MaxStackSize = 10
    
    NavigationService() {
        $this.NavigationStack = [System.Collections.Generic.Stack[Screen]]::new()
    }
    
    NavigationService([EventManager]$eventManager) {
        $this.NavigationStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this.EventManager = $eventManager
    }
    
    [void] RegisterScreen([string]$name, [Screen]$screen) {
        $this.ScreenRegistry[$name] = $screen
        Write-Verbose "NavigationService: Registered screen '$name'"
    }
    
    [void] NavigateTo([Screen]$screen) {
        if (-not $screen) {
            throw [ArgumentNullException]::new("screen")
        }
        
        try {
            # Exit current screen
            if ($this.CurrentScreen) {
                Write-Verbose "NavigationService: Exiting screen '$($this.CurrentScreen.Name)'"
                $this.CurrentScreen.OnExit()
                $this.NavigationStack.Push($this.CurrentScreen)
                
                # Limit stack size
                if ($this.NavigationStack.Count -gt $this.MaxStackSize) {
                    $tempStack = [System.Collections.Generic.Stack[Screen]]::new()
                    for ($i = 0; $i -lt $this.MaxStackSize - 1; $i++) {
                        $tempStack.Push($this.NavigationStack.Pop())
                    }
                    $this.NavigationStack.Clear()
                    while ($tempStack.Count -gt 0) {
                        $this.NavigationStack.Push($tempStack.Pop())
                    }
                }
            }
            
            # Enter new screen
            $this.CurrentScreen = $screen
            Write-Verbose "NavigationService: Entering screen '$($screen.Name)'"
            
            if (-not $screen._isInitialized) {
                $screen.Initialize()
                $screen._isInitialized = $true
            }
            
            $screen.OnEnter()
            
            # Publish navigation event
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.ScreenChanged", @{
                    Screen = $screen
                    ScreenName = $screen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # Update global state
            $global:TuiState.CurrentScreen = $screen
            $global:TuiState.IsDirty = $true
        }
        catch {
            Write-Error "NavigationService: Failed to navigate to screen '$($screen.Name)': $_"
            throw [NavigationException]::new(
                "Failed to navigate to screen '$($screen.Name)'",
                "NavigationService",
                @{ ScreenName = $screen.Name },
                $_
            )
        }
    }
    
    [void] NavigateToByName([string]$screenName) {
        if (-not $this.ScreenRegistry.ContainsKey($screenName)) {
            throw "Screen '$screenName' not found in registry"
        }
        
        $this.NavigateTo($this.ScreenRegistry[$screenName])
    }
    
    [bool] CanGoBack() {
        return $this.NavigationStack.Count -gt 0
    }
    
    [void] GoBack() {
        if (-not $this.CanGoBack()) {
            Write-Warning "NavigationService: Cannot go back - navigation stack is empty"
            return
        }
        
        try {
            # Exit current screen
            if ($this.CurrentScreen) {
                Write-Verbose "NavigationService: Exiting screen '$($this.CurrentScreen.Name)' (going back)"
                $this.CurrentScreen.OnExit()
            }
            
            # Pop and resume previous screen
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            
            Write-Verbose "NavigationService: Resuming screen '$($previousScreen.Name)'"
            $previousScreen.OnResume()
            
            # Publish navigation event
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.BackNavigation", @{
                    Screen = $previousScreen
                    ScreenName = $previousScreen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # Update global state
            $global:TuiState.CurrentScreen = $previousScreen
            $global:TuiState.IsDirty = $true
        }
        catch {
            Write-Error "NavigationService: Failed to go back: $_"
            throw [NavigationException]::new(
                "Failed to navigate back",
                "NavigationService",
                @{ StackDepth = $this.NavigationStack.Count },
                $_
            )
        }
    }
    
    [void] Reset() {
        # Clean up all screens in stack
        while ($this.NavigationStack.Count -gt 0) {
            $screen = $this.NavigationStack.Pop()
            try {
                $screen.Cleanup()
            }
            catch {
                Write-Warning "NavigationService: Error cleaning up screen '$($screen.Name)': $_"
            }
        }
        
        # Clean up current screen
        if ($this.CurrentScreen) {
            try {
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup()
            }
            catch {
                Write-Warning "NavigationService: Error cleaning up current screen: $_"
            }
            $this.CurrentScreen = $null
        }
        
        Write-Verbose "NavigationService: Reset complete"
    }
}

# ===== CLASS: ThemeManager =====
# Module: theme-manager (from axiom)
# Dependencies: None
# Purpose: Visual theming system with hot-swapping
class ThemeManager {
    [hashtable]$CurrentTheme = @{}
    [string]$ThemeName = "Default"
    [hashtable]$ThemeRegistry = @{}
    [string]$ThemePath
    
    ThemeManager() {
        $this.ThemePath = Join-Path $env:APPDATA "AxiomPhoenix\themes"
        $this._Initialize()
    }
    
    ThemeManager([string]$themePath) {
        $this.ThemePath = $themePath
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        if (-not (Test-Path $this.ThemePath)) {
            New-Item -ItemType Directory -Path $this.ThemePath -Force | Out-Null
        }
        
        $this.LoadDefaultTheme()
        Write-Verbose "ThemeManager: Initialized with theme path: $($this.ThemePath)"
    }
    
    [void] LoadDefaultTheme() {
        $this.CurrentTheme = @{
            # Base colors
            'Foreground' = [ConsoleColor]::White
            'Background' = [ConsoleColor]::Black
            'Accent' = [ConsoleColor]::Cyan
            'Header' = [ConsoleColor]::Cyan
            'Subtle' = [ConsoleColor]::DarkGray
            'Highlight' = [ConsoleColor]::Yellow
            'Border' = [ConsoleColor]::Gray
            'Selection' = [ConsoleColor]::DarkBlue
            'Error' = [ConsoleColor]::Red
            'Warning' = [ConsoleColor]::Yellow
            'Success' = [ConsoleColor]::Green
            'Info' = [ConsoleColor]::Cyan
            
            # Component-specific colors
            'button.normal.background' = [ConsoleColor]::Black
            'button.normal.foreground' = [ConsoleColor]::White
            'button.normal.border' = [ConsoleColor]::Gray
            'button.focus.background' = [ConsoleColor]::Black
            'button.focus.foreground' = [ConsoleColor]::White
            'button.focus.border' = [ConsoleColor]::Cyan
            'button.pressed.background' = [ConsoleColor]::DarkGray
            'button.pressed.foreground' = [ConsoleColor]::Black
            'button.pressed.border' = [ConsoleColor]::Cyan
            
            'textbox.normal.background' = [ConsoleColor]::Black
            'textbox.normal.foreground' = [ConsoleColor]::White
            'textbox.normal.border' = [ConsoleColor]::Gray
            'textbox.focus.background' = [ConsoleColor]::Black
            'textbox.focus.foreground' = [ConsoleColor]::White
            'textbox.focus.border' = [ConsoleColor]::Cyan
            'textbox.placeholder' = [ConsoleColor]::DarkGray
            
            'checkbox.normal.foreground' = [ConsoleColor]::White
            'checkbox.checked.foreground' = [ConsoleColor]::Green
            'checkbox.focus.foreground' = [ConsoleColor]::Cyan
            
            'panel.background' = [ConsoleColor]::Black
            'panel.foreground' = [ConsoleColor]::White
            'panel.border' = [ConsoleColor]::Gray
            'panel.title' = [ConsoleColor]::Cyan
            
            'list.item.normal' = [ConsoleColor]::White
            'list.item.selected' = [ConsoleColor]::Black
            'list.item.selected.background' = [ConsoleColor]::Cyan
            'list.scrollbar' = [ConsoleColor]::DarkGray
            
            'dialog.background' = [ConsoleColor]::Black
            'dialog.foreground' = [ConsoleColor]::White
            'dialog.border' = [ConsoleColor]::Yellow
            'dialog.title' = [ConsoleColor]::Yellow
            'dialog.shadow' = [ConsoleColor]::DarkGray
        }
        
        $this.ThemeName = "Default"
        Write-Verbose "ThemeManager: Loaded default theme"
    }
    
    [object] GetColor([string]$colorName) {
        if ($this.CurrentTheme.ContainsKey($colorName)) {
            return $this.CurrentTheme[$colorName]
        }
        
        # Fallback to base color
        if ($colorName -match '\.') {
            $baseColor = $colorName.Split('.')[0]
            if ($this.CurrentTheme.ContainsKey($baseColor)) {
                return $this.CurrentTheme[$baseColor]
            }
        }
        
        Write-Warning "ThemeManager: Color '$colorName' not found in theme, using White"
        return [ConsoleColor]::White
    }
    
    [void] SetColor([string]$colorName, [object]$color) {
        $this.CurrentTheme[$colorName] = $color
        Write-Verbose "ThemeManager: Set color '$colorName' to '$color'"
    }
    
    [void] LoadTheme([string]$themeName) {
        $themePath = Join-Path $this.ThemePath "$themeName.json"
        
        if (-not (Test-Path $themePath)) {
            throw "Theme file not found: $themePath"
        }
        
        try {
            $themeData = Get-Content -Path $themePath -Raw | ConvertFrom-Json -AsHashtable
            
            # Convert color values
            $this.CurrentTheme.Clear()
            foreach ($key in $themeData.Keys) {
                $value = $themeData[$key]
                
                # Handle ConsoleColor enum values
                if ($value -is [string] -and [Enum]::TryParse([ConsoleColor], $value, [ref]$null)) {
                    $this.CurrentTheme[$key] = [Enum]::Parse([ConsoleColor], $value)
                }
                # Handle hex colors
                elseif ($value -is [string] -and $value -match '^#[0-9A-Fa-f]{6}$') {
                    $this.CurrentTheme[$key] = $value
                }
                else {
                    $this.CurrentTheme[$key] = $value
                }
            }
            
            $this.ThemeName = $themeName
            Write-Verbose "ThemeManager: Loaded theme '$themeName' from file"
        }
        catch {
            Write-Error "Failed to load theme '$themeName': $_"
            throw
        }
    }
    
    [void] SaveTheme([string]$themeName) {
        $themePath = Join-Path $this.ThemePath "$themeName.json"
        
        try {
            # Convert ConsoleColor enums to strings for JSON
            $themeData = @{}
            foreach ($key in $this.CurrentTheme.Keys) {
                $value = $this.CurrentTheme[$key]
                if ($value -is [ConsoleColor]) {
                    $themeData[$key] = $value.ToString()
                }
                else {
                    $themeData[$key] = $value
                }
            }
            
            $jsonContent = $themeData | ConvertTo-Json -Depth 10
            Set-Content -Path $themePath -Value $jsonContent -Force
            
            Write-Verbose "ThemeManager: Saved theme '$themeName' to file"
        }
        catch {
            Write-Error "Failed to save theme '$themeName': $_"
            throw
        }
    }
    
    [hashtable] CreateTheme([string]$themeName, [hashtable]$baseTheme = @{}) {
        $newTheme = if ($baseTheme.Count -gt 0) { 
            $baseTheme.Clone() 
        } else { 
            $this.CurrentTheme.Clone() 
        }
        
        $this.ThemeRegistry[$themeName] = $newTheme
        Write-Verbose "ThemeManager: Created theme '$themeName'"
        
        return $newTheme
    }
    
    [void] ApplyTheme([string]$themeName) {
        if ($this.ThemeRegistry.ContainsKey($themeName)) {
            $this.CurrentTheme = $this.ThemeRegistry[$themeName].Clone()
            $this.ThemeName = $themeName
            Write-Verbose "ThemeManager: Applied theme '$themeName' from registry"
        }
        else {
            $this.LoadTheme($themeName)
        }
    }
}

# ===== CLASS: Logger =====
# Module: logger (from axiom)
# Dependencies: None
# Purpose: Application-wide logging with multiple outputs
class Logger {
    [string]$LogPath
    [System.Collections.Queue]$LogQueue
    [int]$MaxQueueSize = 1000
    [bool]$EnableFileLogging = $true
    [bool]$EnableConsoleLogging = $false
    [string]$MinimumLevel = "Info"
    [hashtable]$LevelPriority = @{
        'Trace' = 0
        'Debug' = 1
        'Info' = 2
        'Warning' = 3
        'Error' = 4
        'Fatal' = 5
    }
    
    Logger() {
        $this.LogPath = Join-Path $env:APPDATA "AxiomPhoenix\app.log"
        $this._Initialize()
    }
    
    Logger([string]$logPath) {
        $this.LogPath = $logPath
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        $this.LogQueue = [System.Collections.Queue]::new()
        
        $logDir = Split-Path -Parent $this.LogPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        Write-Verbose "Logger: Initialized with log path: $($this.LogPath)"
    }
    
    [void] Log([string]$message, [string]$level = "Info") {
        # Check if we should log this level
        if ($this.LevelPriority[$level] -lt $this.LevelPriority[$this.MinimumLevel]) {
            return
        }
        
        $logEntry = @{
            Timestamp = [DateTime]::Now
            Level = $level
            Message = $message
            ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        }
        
        # Add to queue
        $this.LogQueue.Enqueue($logEntry)
        
        # Flush if queue is getting large
        if ($this.LogQueue.Count -ge $this.MaxQueueSize) {
            $this.Flush()
        }
        
        # Console logging if enabled
        if ($this.EnableConsoleLogging) {
            $this._WriteToConsole($logEntry)
        }
    }
    
    [void] LogException([Exception]$exception, [string]$message = "") {
        $exceptionDetails = @{
            Message = if ($message) { $message } else { "Exception occurred" }
            ExceptionType = $exception.GetType().FullName
            ExceptionMessage = $exception.Message
            StackTrace = $exception.StackTrace
            InnerException = if ($exception.InnerException) { 
                $exception.InnerException.Message 
            } else { 
                $null 
            }
        }
        
        $detailsJson = $exceptionDetails | ConvertTo-Json -Compress
        $this.Log($detailsJson, "Error")
    }
    
    [void] Flush() {
        if ($this.LogQueue.Count -eq 0 -or -not $this.EnableFileLogging) {
            return
        }
        
        try {
            $logContent = [System.Text.StringBuilder]::new()
            
            while ($this.LogQueue.Count -gt 0) {
                $entry = $this.LogQueue.Dequeue()
                $logLine = "$($entry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')) [$($entry.Level.ToUpper().PadRight(7))] [Thread:$($entry.ThreadId)] $($entry.Message)"
                [void]$logContent.AppendLine($logLine)
            }
            
            if ($logContent.Length -gt 0) {
                Add-Content -Path $this.LogPath -Value $logContent.ToString() -NoNewline
            }
        }
        catch {
            Write-Warning "Logger: Failed to flush logs: $_"
        }
    }
    
    hidden [void] _WriteToConsole([hashtable]$logEntry) {
        $color = switch ($logEntry.Level) {
            'Trace' { [ConsoleColor]::DarkGray }
            'Debug' { [ConsoleColor]::Gray }
            'Info' { [ConsoleColor]::White }
            'Warning' { [ConsoleColor]::Yellow }
            'Error' { [ConsoleColor]::Red }
            'Fatal' { [ConsoleColor]::Magenta }
            default { [ConsoleColor]::White }
        }
        
        $timestamp = $logEntry.Timestamp.ToString('HH:mm:ss')
        $prefix = "[$timestamp] [$($logEntry.Level.ToUpper())]"
        
        Write-Host $prefix -ForegroundColor $color -NoNewline
        Write-Host " $($logEntry.Message)" -ForegroundColor White
    }
    
    [void] Cleanup() {
        $this.Flush()
        Write-Verbose "Logger: Cleanup complete"
    }
}

# ===== CLASS: EventManager =====
# Module: event-system (from axiom)
# Dependencies: None
# Purpose: Pub/sub event system for decoupled communication
class EventManager {
    [hashtable]$EventHandlers = @{}
    [int]$NextHandlerId = 1
    [System.Collections.Generic.List[hashtable]]$EventHistory
    [int]$MaxHistorySize = 100
    [bool]$EnableHistory = $true
    
    EventManager() {
        $this.EventHistory = [System.Collections.Generic.List[hashtable]]::new()
        Write-Verbose "EventManager: Initialized"
    }
    
    [string] Subscribe([string]$eventName, [scriptblock]$handler) {
        if ([string]::IsNullOrWhiteSpace($eventName)) {
            throw [ArgumentException]::new("Event name cannot be null or empty")
        }
        if (-not $handler) {
            throw [ArgumentNullException]::new("handler")
        }
        
        if (-not $this.EventHandlers.ContainsKey($eventName)) {
            $this.EventHandlers[$eventName] = @{}
        }
        
        $handlerId = "handler_$($this.NextHandlerId)"
        $this.NextHandlerId++
        
        $this.EventHandlers[$eventName][$handlerId] = @{
            Handler = $handler
            SubscribedAt = [DateTime]::Now
            ExecutionCount = 0
        }
        
        Write-Verbose "EventManager: Subscribed handler '$handlerId' to event '$eventName'"
        return $handlerId
    }
    
    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            if ($this.EventHandlers[$eventName].ContainsKey($handlerId)) {
                $this.EventHandlers[$eventName].Remove($handlerId)
                Write-Verbose "EventManager: Unsubscribed handler '$handlerId' from event '$eventName'"
                
                # Clean up empty event entries
                if ($this.EventHandlers[$eventName].Count -eq 0) {
                    $this.EventHandlers.Remove($eventName)
                }
            }
        }
    }
    
    [void] UnsubscribeAll([string]$eventName) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlerCount = $this.EventHandlers[$eventName].Count
            $this.EventHandlers.Remove($eventName)
            Write-Verbose "EventManager: Unsubscribed all $handlerCount handlers from event '$eventName'"
        }
    }
    
    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        Write-Verbose "EventManager: Publishing event '$eventName'"
        
        # Add to history if enabled
        if ($this.EnableHistory) {
            $historyEntry = @{
                EventName = $eventName
                EventData = $eventData.Clone()
                Timestamp = [DateTime]::Now
                HandlerCount = 0
            }
            
            $this.EventHistory.Add($historyEntry)
            
            # Trim history if needed
            if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
                $this.EventHistory.RemoveAt(0)
            }
        }
        
        # Execute handlers
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
            $handlerCount = $handlers.Count
            
            if ($this.EnableHistory) {
                $this.EventHistory[-1].HandlerCount = $handlerCount
            }
            
            foreach ($entry in $handlers) {
                try {
                    $handlerData = $entry.Value
                    $handlerData.ExecutionCount++
                    
                    Write-Verbose "EventManager: Executing handler '$($entry.Key)' for event '$eventName'"
                    & $handlerData.Handler $eventData
                }
                catch {
                    Write-Error "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $_"
                }
            }
            
            Write-Verbose "EventManager: Published event '$eventName' to $handlerCount handlers"
        }
        else {
            Write-Verbose "EventManager: No handlers registered for event '$eventName'"
        }
    }
    
    [hashtable[]] GetEventHistory([string]$eventName = $null) {
        if ($eventName) {
            return $this.EventHistory | Where-Object { $_.EventName -eq $eventName }
        }
        return $this.EventHistory | ForEach-Object { $_ }
    }
    
    [void] ClearHistory() {
        $this.EventHistory.Clear()
        Write-Verbose "EventManager: Cleared event history"
    }
    
    [hashtable] GetEventInfo() {
        $info = @{
            RegisteredEvents = @{}
            TotalHandlers = 0
        }
        
        foreach ($eventName in $this.EventHandlers.Keys) {
            $handlers = $this.EventHandlers[$eventName]
            $info.RegisteredEvents[$eventName] = @{
                HandlerCount = $handlers.Count
                Handlers = $handlers.Keys | ForEach-Object { $_ }
            }
            $info.TotalHandlers += $handlers.Count
        }
        
        return $info
    }
}

# ===== CLASS: TuiFrameworkService =====
# Module: tui-framework (from axiom)
# Dependencies: None
# Purpose: Framework utilities and async operations
class TuiFrameworkService {
    [hashtable]$AsyncJobs = @{}
    [int]$NextJobId = 1
    [bool]$IsRunning = $false
    
    TuiFrameworkService() {
        Write-Verbose "TuiFrameworkService: Initialized"
    }
    
    [hashtable] StartAsync([scriptblock]$work, [string]$name = "") {
        try {
            $jobId = $this.NextJobId++
            $jobName = if ($name) { $name } else { "AsyncJob_$jobId" }
            
            # Use ThreadJob for lightweight async operations
            $job = Start-ThreadJob -ScriptBlock $work -Name $jobName
            
            $jobInfo = @{
                Id = $jobId
                Name = $jobName
                Job = $job
                StartedAt = [DateTime]::Now
                Status = "Running"
            }
            
            $this.AsyncJobs[$jobId] = $jobInfo
            
            Write-Verbose "TuiFrameworkService: Started async job '$jobName' with ID $jobId"
            return $jobInfo
        }
        catch {
            Write-Error "Failed to start async job: $_"
            throw
        }
    }
    
    [object] GetAsyncResults([int]$jobId, [bool]$wait = $false) {
        if (-not $this.AsyncJobs.ContainsKey($jobId)) {
            throw "Async job with ID $jobId not found"
        }
        
        $jobInfo = $this.AsyncJobs[$jobId]
        $job = $jobInfo.Job
        
        if ($wait) {
            Write-Verbose "TuiFrameworkService: Waiting for job $jobId to complete"
            Wait-Job -Job $job | Out-Null
        }
        
        if ($job.State -eq "Completed") {
            $result = Receive-Job -Job $job -Keep
            $jobInfo.Status = "Completed"
            return $result
        }
        elseif ($job.State -eq "Failed") {
            $jobInfo.Status = "Failed"
            $error = Receive-Job -Job $job -Keep
            throw "Async job $jobId failed: $error"
        }
        else {
            return $null
        }
    }
    
    [void] StopAllAsyncJobs() {
        Write-Verbose "TuiFrameworkService: Stopping all async jobs"
        
        foreach ($jobInfo in $this.AsyncJobs.Values) {
            try {
                if ($jobInfo.Job.State -eq "Running") {
                    Stop-Job -Job $jobInfo.Job
                    Remove-Job -Job $jobInfo.Job -Force
                }
            }
            catch {
                Write-Warning "Failed to stop job $($jobInfo.Id): $_"
            }
        }
        
        $this.AsyncJobs.Clear()
    }
    
    [hashtable] GetState() {
        return @{
            IsRunning = $this.IsRunning
            AsyncJobCount = $this.AsyncJobs.Count
            ActiveJobs = $this.AsyncJobs.Values | Where-Object { $_.Status -eq "Running" } | Measure-Object | Select-Object -ExpandProperty Count
        }
    }
    
    [bool] IsRunning() {
        return $this.IsRunning
    }
    
    [void] Start() {
        $this.IsRunning = $true
        Write-Verbose "TuiFrameworkService: Started"
    }
    
    [void] Stop() {
        $this.StopAllAsyncJobs()
        $this.IsRunning = $false
        Write-Verbose "TuiFrameworkService: Stopped"
    }
    
    [void] Cleanup() {
        $this.Stop()
    }
}

#endregion
