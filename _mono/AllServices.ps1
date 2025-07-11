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

#<!-- PAGE: ASE.001 - ActionService Class -->
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
            
            # Create and configure the CommandPalette component
            $palette = [CommandPalette]::new("CommandPalette")
            $palette.Width = 60
            $palette.Height = 20
            
            # Get all available actions and populate the palette
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
            
            # Set the actions data (Data Down)
            $palette.SetActions($actionList)
            
            # Define what happens when user selects a command (Events Up)
            $palette.OnExecute = {
                param($sender, $selectedAction)
                try {
                    # Hide the palette first
                    $dialogManager.HideDialog($palette)
                    
                    # Execute the selected action
                    if ($selectedAction -and $selectedAction.Name) {
                        $actionService.ExecuteAction($selectedAction.Name)
                    }
                }
                catch {
                    Write-Log -Level Error -Message "Failed to execute command palette action: $($_.Exception.Message)"
                }
            }.GetNewClosure()
            
            # Define cancel behavior
            $palette.OnCancel = {
                $dialogManager.HideDialog($palette)
            }.GetNewClosure()
            
            # Show the palette using the standard overlay mechanism
            $dialogManager.ShowDialog($palette)
            
            # Set initial focus directly without sleep
            if ($palette._searchBox) {
                $focusManager = $global:TuiState.Services.FocusManager
                if ($focusManager) {
                    # Make sure the search box is ready
                    $palette._searchBox.IsFocusable = $true
                    $palette._searchBox.Enabled = $true
                    $palette._searchBox.Visible = $true
                    
                    # Set focus and update global state
                    $focusManager.SetFocus($palette._searchBox)
                    $global:TuiState.FocusedComponent = $palette._searchBox
                    
                    # Force a redraw
                    $palette._searchBox.RequestRedraw()
                    $global:TuiState.IsDirty = $true
                }
            }
            
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
        
        # Write-Verbose "ActionService: Registered default actions"
    }
}

#endregion
#<!-- END_PAGE: ASE.001 -->

#<!-- PAGE: ASE.002 - KeybindingService Class -->
#region KeybindingService Class

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
        
        # Write-Verbose "KeybindingService: Initialized default keybindings"
    }
    
    [void] SetBinding([string]$keyPattern, [string]$actionName, [string]$context = "Global") {
        if (-not $this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context] = @{}
        }
        
        $this.KeyMap[$context][$keyPattern] = $actionName
        # Write-Verbose "KeybindingService: Bound '$keyPattern' to '$actionName' in context '$context'"
    }
    
    [void] RemoveBinding([string]$keyPattern, [string]$context = "Global") {
        if ($this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context].Remove($keyPattern)
            # Write-Verbose "KeybindingService: Removed binding for '$keyPattern' in context '$context'"
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
        
        # Log key pattern for debugging
        if ($keyPattern -match "Ctrl") {
            Write-Log -Level Debug -Message "KeybindingService: Key pattern detected: $keyPattern"
        }
        
        # Check current context stack (most recent first)
        foreach ($context in $this.ContextStack) {
            if ($context.ContainsKey($keyPattern)) {
                Write-Log -Level Debug -Message "KeybindingService: Found action in context: $($context[$keyPattern])"
                return $context[$keyPattern]
            }
        }
        
        # Check global context
        if ($this.KeyMap.ContainsKey("Global") -and $this.KeyMap["Global"].ContainsKey($keyPattern)) {
            Write-Log -Level Debug -Message "KeybindingService: Found action in global context: $($this.KeyMap["Global"][$keyPattern])"
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
        # Write-Verbose "KeybindingService: Pushed new context with $($contextBindings.Count) bindings"
    }
    
    [void] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $removed = $this.ContextStack.Pop()
            # Write-Verbose "KeybindingService: Popped context with $($removed.Count) bindings"
        }
    }
    
    [void] RegisterGlobalHandler([string]$handlerId, [scriptblock]$handler) {
        $this.GlobalHandlers[$handlerId] = $handler
        # Write-Verbose "KeybindingService: Registered global handler '$handlerId'"
    }
    
    [void] UnregisterGlobalHandler([string]$handlerId) {
        $this.GlobalHandlers.Remove($handlerId)
        # Write-Verbose "KeybindingService: Unregistered global handler '$handlerId'"
    }
    
    [void] SetDefaultBindings() {
        # Application control
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("Escape", "app.cancel", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        
        # Navigation
        $this.SetBinding("Tab", "nav.nextField", "Global")
        $this.SetBinding("Shift+Tab", "nav.previousField", "Global")
        $this.SetBinding("Enter", "nav.select", "Global")
        $this.SetBinding("Space", "nav.toggle", "Global")
        
        # Movement
        $this.SetBinding("UpArrow", "nav.up", "Global")
        $this.SetBinding("DownArrow", "nav.down", "Global")
        $this.SetBinding("LeftArrow", "nav.left", "Global")
        $this.SetBinding("RightArrow", "nav.right", "Global")
        $this.SetBinding("PageUp", "nav.pageUp", "Global")
        $this.SetBinding("PageDown", "nav.pageDown", "Global")
        $this.SetBinding("Home", "nav.home", "Global")
        $this.SetBinding("End", "nav.end", "Global")
        
        # Screen navigation
        $this.SetBinding("Ctrl+N", "screen.new", "Global")
        $this.SetBinding("Ctrl+D", "screen.dashboard", "Global")
        $this.SetBinding("Ctrl+T", "screen.tasks", "Global")
        $this.SetBinding("Ctrl+B", "nav.back", "Global")
    }
    
    [void] Cleanup() {
        $this.KeyMap.Clear()
        $this.GlobalHandlers.Clear()
        $this.ContextStack.Clear()
    }
}

#endregion
#<!-- END_PAGE: ASE.002 -->

#<!-- PAGE: ASE.003 - DataManager Class -->
#region DataManager Class

# ===== CLASS: DataManager =====
# Module: data-manager (from axiom)
# Dependencies: EventManager (optional), PmcTask, PmcProject
# Purpose: High-performance data management with transactions, backups, and robust serialization
class DataManager : System.IDisposable {
    # Private fields for high-performance indexes
    hidden [System.Collections.Generic.Dictionary[string, PmcTask]]$_taskIndex
    hidden [System.Collections.Generic.Dictionary[string, PmcProject]]$_projectIndex
    hidden [string]$_dataFilePath
    hidden [string]$_backupPath
    hidden [datetime]$_lastSaveTime
    hidden [bool]$_dataModified = $false
    hidden [int]$_updateTransactionCount = 0
    
    # Public properties
    [hashtable]$Metadata = @{}
    [bool]$AutoSave = $true
    [int]$BackupCount = 5
    [EventManager]$EventManager = $null
    
    DataManager([string]$dataPath) {
        $this._dataFilePath = $dataPath
        $this._Initialize()
    }
    
    DataManager([string]$dataPath, [EventManager]$eventManager) {
        $this._dataFilePath = $dataPath
        $this.EventManager = $eventManager
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        # Initialize indexes
        $this._taskIndex = [System.Collections.Generic.Dictionary[string, PmcTask]]::new()
        $this._projectIndex = [System.Collections.Generic.Dictionary[string, PmcProject]]::new()
        
        # Set up directories
        $baseDir = Split-Path -Path $this._dataFilePath -Parent
        $this._backupPath = Join-Path $baseDir "backups"
        
        # Ensure directories exist
        if (-not (Test-Path $baseDir)) {
            New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
        }
        if (-not (Test-Path $this._backupPath)) {
            New-Item -ItemType Directory -Path $this._backupPath -Force | Out-Null
        }
        
        # Write-Verbose "DataManager: Initialized with path '$($this._dataFilePath)'"
    }
    
    [void] LoadData() {
        try {
            if (-not (Test-Path $this._dataFilePath)) {
                # Write-Verbose "DataManager: No existing data file found at '$($this._dataFilePath)'"
                return
            }
            
            $jsonContent = Get-Content -Path $this._dataFilePath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($jsonContent)) {
                # Write-Verbose "DataManager: Data file is empty"
                return
            }
            
            $data = $jsonContent | ConvertFrom-Json -AsHashtable
            
            # Clear existing data
            $this._taskIndex.Clear()
            $this._projectIndex.Clear()
            
            # Load tasks using FromLegacyFormat
            if ($data.ContainsKey('Tasks')) {
                foreach ($taskData in $data.Tasks) {
                    try {
                        $task = [PmcTask]::FromLegacyFormat($taskData)
                        $this._taskIndex[$task.Id] = $task
                    }
                    catch {
                        Write-Warning "DataManager: Failed to load task: $($_.Exception.Message)"
                    }
                }
            }
            
            # Load projects using FromLegacyFormat
            if ($data.ContainsKey('Projects')) {
                foreach ($projectData in $data.Projects) {
                    try {
                        $project = [PmcProject]::FromLegacyFormat($projectData)
                        $this._projectIndex[$project.Key] = $project
                    }
                    catch {
                        Write-Warning "DataManager: Failed to load project: $($_.Exception.Message)"
                    }
                }
            }
            
            # Load metadata
            if ($data.ContainsKey('Metadata')) {
                $this.Metadata = $data.Metadata.Clone()
            }
            
            $this._lastSaveTime = [datetime]::Now
            $this._dataModified = $false
            
            # Write-Verbose "DataManager: Loaded $($this._taskIndex.Count) tasks and $($this._projectIndex.Count) projects"
            
            # Publish event
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.Loaded", @{
                    TaskCount = $this._taskIndex.Count
                    ProjectCount = $this._projectIndex.Count
                    Source = $this._dataFilePath
                })
            }
        }
        catch {
            Write-Error "DataManager: Failed to load data from '$($this._dataFilePath)': $($_.Exception.Message)"
            throw
        }
    }
    
    [void] SaveData() {
        if ($this._updateTransactionCount -gt 0) {
            # Write-Verbose "DataManager: SaveData deferred - inside update transaction (level $($this._updateTransactionCount))"
            return
        }
        
        try {
            $this.CreateBackup()
            
            $saveData = @{
                Tasks = @()
                Projects = @()
                Metadata = $this.Metadata.Clone()
                SavedAt = [datetime]::Now
                Version = "4.0"
            }
            
            # Convert tasks to legacy format for serialization
            foreach ($task in $this._taskIndex.Values) {
                $saveData.Tasks += $task.ToLegacyFormat()
            }
            
            # Convert projects to legacy format for serialization
            foreach ($project in $this._projectIndex.Values) {
                $saveData.Projects += $project.ToLegacyFormat()
            }
            
            $saveData | ConvertTo-Json -Depth 10 -WarningAction SilentlyContinue | Set-Content -Path $this._dataFilePath -Encoding UTF8 -Force
            $this._lastSaveTime = [datetime]::Now
            $this._dataModified = $false
            
            # Write-Verbose "DataManager: Data saved to '$($this._dataFilePath)'"
            
            # Publish event
            if ($this.EventManager) {
                $this.EventManager.Publish("Data.Saved", @{
                    TaskCount = $saveData.Tasks.Count
                    ProjectCount = $saveData.Projects.Count
                    Destination = $this._dataFilePath
                })
            }
        }
        catch {
            Write-Error "DataManager: Failed to save data: $($_.Exception.Message)"
            throw
        }
    }
    
    hidden [void] CreateBackup() {
        try {
            if (Test-Path $this._dataFilePath) {
                $timestamp = (Get-Date).ToString("yyyyMMdd-HHmmss")
                $backupFileName = "data-backup-$timestamp.json"
                $backupFilePath = Join-Path $this._backupPath $backupFileName
                
                Copy-Item -Path $this._dataFilePath -Destination $backupFilePath -Force
                
                # Manage backup rotation
                if ($this.BackupCount -gt 0) {
                    $backups = Get-ChildItem -Path $this._backupPath -Filter "data-backup-*.json" | 
                               Sort-Object LastWriteTime -Descending
                    
                    if ($backups.Count -gt $this.BackupCount) {
                        $backupsToDelete = $backups | Select-Object -Skip $this.BackupCount
                        foreach ($backup in $backupsToDelete) {
                            Remove-Item -Path $backup.FullName -Force
                            # Write-Verbose "DataManager: Removed old backup '$($backup.Name)'"
                        }
                    }
                }
                
                # Write-Verbose "DataManager: Created backup '$backupFileName'"
            }
        }
        catch {
            Write-Warning "DataManager: Failed to create backup: $($_.Exception.Message)"
        }
    }
    
    # Transactional update methods
    [void] BeginUpdate() {
        $this._updateTransactionCount++
        # Write-Verbose "DataManager: Began update transaction. Depth: $($this._updateTransactionCount)"
    }
    
    [void] EndUpdate() {
        $this.EndUpdate($false)
    }
    
    [void] EndUpdate([bool]$forceSave) {
        if ($this._updateTransactionCount -gt 0) {
            $this._updateTransactionCount--
        }
        
        # Write-Verbose "DataManager: Ended update transaction. Depth: $($this._updateTransactionCount)"
        
        if ($this._updateTransactionCount -eq 0 -and ($this._dataModified -or $forceSave)) {
            if ($this.AutoSave -or $forceSave) {
                $this.SaveData()
            }
        }
    }
    
    # Task management methods
    [PmcTask[]] GetTasks() {
        return @($this._taskIndex.Values)
    }
    
    [PmcTask] GetTask([string]$taskId) {
        if ($this._taskIndex.ContainsKey($taskId)) {
            return $this._taskIndex[$taskId]
        }
        return $null
    }
    
    [PmcTask[]] GetTasksByProject([string]$projectKey) {
        return @($this._taskIndex.Values | Where-Object { $_.ProjectKey -eq $projectKey })
    }
    
    [PmcTask] AddTask([PmcTask]$task) {
        if ($null -eq $task) {
            throw [System.ArgumentNullException]::new("task", "Task cannot be null")
        }
        
        if ([string]::IsNullOrEmpty($task.Id)) {
            $task.Id = [guid]::NewGuid().ToString()
        }
        
        if ($this._taskIndex.ContainsKey($task.Id)) {
            throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' already exists")
        }
        
        $this._taskIndex[$task.Id] = $task
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Created"; Task = $task })
        }
        
        # Write-Verbose "DataManager: Added task '$($task.Title)' with ID '$($task.Id)'"
        return $task
    }
    
    [PmcTask] UpdateTask([PmcTask]$task) {
        if ($null -eq $task) {
            throw [System.ArgumentNullException]::new("task", "Task cannot be null")
        }
        
        if (-not $this._taskIndex.ContainsKey($task.Id)) {
            throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' not found")
        }
        
        $task.UpdatedAt = [datetime]::Now
        $this._taskIndex[$task.Id] = $task
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Updated"; Task = $task })
        }
        
        # Write-Verbose "DataManager: Updated task '$($task.Title)' with ID '$($task.Id)'"
        return $task
    }
    
    [bool] DeleteTask([string]$taskId) {
        if (-not $this._taskIndex.ContainsKey($taskId)) {
            # Write-Verbose "DataManager: Task '$taskId' not found for deletion"
            return $false
        }
        
        $task = $this._taskIndex[$taskId]
        $this._taskIndex.Remove($taskId) | Out-Null
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Tasks.Changed", @{ Action = "Deleted"; TaskId = $taskId })
        }
        
        # Write-Verbose "DataManager: Deleted task with ID '$taskId'"
        return $true
    }
    
    # Project management methods
    [PmcProject[]] GetProjects() {
        return @($this._projectIndex.Values)
    }
    
    [PmcProject] GetProject([string]$projectKey) {
        if ($this._projectIndex.ContainsKey($projectKey)) {
            return $this._projectIndex[$projectKey]
        }
        return $null
    }
    
    [PmcProject] AddProject([PmcProject]$project) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project cannot be null")
        }
        
        if ([string]::IsNullOrEmpty($project.Key)) {
            throw [System.ArgumentException]::new("Project Key is required")
        }
        
        if ($this._projectIndex.ContainsKey($project.Key)) {
            throw [System.InvalidOperationException]::new("Project with Key '$($project.Key)' already exists")
        }
        
        $this._projectIndex[$project.Key] = $project
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ Action = "Created"; Project = $project })
        }
        
        # Write-Verbose "DataManager: Added project '$($project.Name)' with Key '$($project.Key)'"
        return $project
    }
    
    [PmcProject] UpdateProject([PmcProject]$project) {
        if ($null -eq $project) {
            throw [System.ArgumentNullException]::new("project", "Project cannot be null")
        }
        
        if (-not $this._projectIndex.ContainsKey($project.Key)) {
            throw [System.InvalidOperationException]::new("Project with Key '$($project.Key)' not found")
        }
        
        $project.UpdatedAt = [datetime]::Now
        $this._projectIndex[$project.Key] = $project
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ Action = "Updated"; Project = $project })
        }
        
        # Write-Verbose "DataManager: Updated project '$($project.Name)' with Key '$($project.Key)'"
        return $project
    }
    
    [bool] DeleteProject([string]$projectKey) {
        if (-not $this._projectIndex.ContainsKey($projectKey)) {
            # Write-Verbose "DataManager: Project '$projectKey' not found for deletion"
            return $false
        }
        
        # Delete all tasks associated with this project
        $tasksToDelete = @($this._taskIndex.Values | Where-Object { $_.ProjectKey -eq $projectKey })
        foreach ($task in $tasksToDelete) {
            $this.DeleteTask($task.Id) | Out-Null
        }
        
        $project = $this._projectIndex[$projectKey]
        $this._projectIndex.Remove($projectKey) | Out-Null
        $this._dataModified = $true
        
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) {
            $this.SaveData()
        }
        
        if ($this.EventManager) {
            $this.EventManager.Publish("Projects.Changed", @{ 
                Action = "Deleted"
                ProjectKey = $projectKey
                DeletedTaskCount = $tasksToDelete.Count
            })
        }
        
        # Write-Verbose "DataManager: Deleted project '$projectKey' and $($tasksToDelete.Count) associated tasks"
        return $true
    }
    
    # Utility methods
    [datetime] GetLastSaveTime() {
        return $this._lastSaveTime
    }
    
    [void] ForceSave() {
        $originalTransactionCount = $this._updateTransactionCount
        $this._updateTransactionCount = 0
        try {
            $this.SaveData()
        }
        finally {
            $this._updateTransactionCount = $originalTransactionCount
        }
    }
    
    # IDisposable implementation
    [void] Dispose() {
        # Write-Verbose "DataManager: Disposing - checking for unsaved data"
        
        if ($this._dataModified) {
            $originalTransactionCount = $this._updateTransactionCount
            $this._updateTransactionCount = 0
            try {
                $this.SaveData()
                # Write-Verbose "DataManager: Performed final save during dispose"
            }
            catch {
                Write-Warning "DataManager: Failed to save data during dispose: $($_.Exception.Message)"
            }
            finally {
                $this._updateTransactionCount = $originalTransactionCount
            }
        }
    }
    
    # Cleanup method (alias for Dispose)
    [void] Cleanup() {
        $this.Dispose()
    }
}

#endregion
#<!-- END_PAGE: ASE.003 -->

#<!-- PAGE: ASE.004 - NavigationService Class -->
#region NavigationService Class

# ===== CLASS: NavigationService =====
# Module: navigation-service (from axiom)
# Dependencies: EventManager (optional)
# Purpose: Screen navigation and history management
class NavigationService {
    [System.Collections.Generic.Stack[Screen]]$NavigationStack = [System.Collections.Generic.Stack[Screen]]::new() # Explicitly initialize
    [Screen]$CurrentScreen
    [EventManager]$EventManager
    [hashtable]$ScreenRegistry = @{}
    [int]$MaxStackSize = 10
    [hashtable]$Services # Added to store access to all services (for creating screens)

    # Add constructor that takes ServiceContainer (or hashtable of services)
    NavigationService([hashtable]$services) {
        $this.Services = $services
        $this.EventManager = $services.EventManager # Get EventManager if present
    }

    # IMPORTANT: Update NavigateTo method
    [void] NavigateTo([Screen]$screen) {
        if ($null -eq $screen) { throw [System.ArgumentNullException]::new("screen", "Cannot navigate to a null screen.") }
        
        try {
            # Exit current screen if one exists
            if ($this.CurrentScreen) {
                # Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($this.CurrentScreen.Name)'"
                $this.CurrentScreen.OnExit()
                $this.NavigationStack.Push($this.CurrentScreen)
                
                # Limit stack size (optional, complex to trim from bottom of Stack)
                # If MaxStackSize is critical, consider switching NavigationStack to List<Screen> and managing explicitly.
            }
            
            # Enter new screen
            $this.CurrentScreen = $screen
            # Write-Log -Level Debug -Message "NavigationService: Entering screen '$($screen.Name)'"
            
            # Initialize if not already (screens passed via registry should be initialized via factory)
            if (-not $screen._isInitialized) {
                # Write-Log -Level Debug -Message "NavigationService: Initializing screen '$($screen.Name)'"
                $screen.Initialize()
                $screen._isInitialized = $true
            }
            
            # Resize screen to match current console dimensions
            $width = [Math]::Max(80, $global:TuiState.BufferWidth)
            $height = [Math]::Max(24, $global:TuiState.BufferHeight)
            $screen.Resize($width, $height)
            
            $screen.OnEnter() # Call lifecycle method
            
            # Publish navigation event
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.ScreenChanged", @{
                    Screen = $screen
                    ScreenName = $screen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # Update global TUI state (CRITICAL FIX)
            $global:TuiState.CurrentScreen = $screen
            $global:TuiState.IsDirty = $true # Force redraw
            $global:TuiState.FocusedComponent = $null # Clear focus, screen OnEnter should set new focus

        }
        catch {
            Write-Error "NavigationService: Failed to navigate to screen '$($screen.Name)': $_"
            throw
        }
    }

    [void] NavigateToByName([string]$screenName) {
        if (-not $this.ScreenRegistry.ContainsKey($screenName)) {
            throw [System.ArgumentException]::new("Screen '$screenName' not found in registry. Registered: $($this.ScreenRegistry.Keys -join ', ').", "screenName")
        }
        
        $this.NavigateTo($this.ScreenRegistry[$screenName])
    }
    
    [bool] CanGoBack() {
        return $this.NavigationStack.Count -gt 0
    }
    
    # IMPORTANT: Update GoBack method
    [void] GoBack() {
        if (-not $this.CanGoBack()) {
            # Write-Log -Level Warning -Message "NavigationService: Cannot go back - navigation stack is empty"
            return
        }
        
        try {
            # Exit current screen
            if ($this.CurrentScreen) {
                # Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($this.CurrentScreen.Name)' (going back)"
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup() # Clean up the screen being exited/popped
            }
            
            # Pop and resume previous screen
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            
            # Write-Log -Level Debug -Message "NavigationService: Resuming screen '$($previousScreen.Name)'"
            
            # Resize screen to match current console dimensions
            $previousScreen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)

            $previousScreen.OnResume() # Call lifecycle method
            
            # Publish navigation event
            if ($this.EventManager) {
                $this.EventManager.Publish("Navigation.BackNavigation", @{
                    Screen = $previousScreen
                    ScreenName = $previousScreen.Name
                    StackDepth = $this.NavigationStack.Count
                })
            }
            
            # Update global TUI state (CRITICAL FIX)
            $global:TuiState.CurrentScreen = $previousScreen
            $global:TuiState.IsDirty = $true # Force redraw
            $global:TuiState.FocusedComponent = $null # Clear focus, screen OnResume should set new focus

        }
        catch {
            Write-Error "NavigationService: Failed to go back: $_"
            throw
        }
    }
    
    [void] Reset() {
        # Cleanup all screens in stack and current screen
        while ($this.NavigationStack.Count -gt 0) {
            $screen = $this.NavigationStack.Pop()
            try { $screen.Cleanup() } catch { # Write-Log -Level Warning -Message "NavigationService: Error cleaning up stacked screen '$($screen.Name)': $($_.Exception.Message)" }
            }
        }
        
        if ($this.CurrentScreen) {
            try { 
                $this.CurrentScreen.OnExit()
                $this.CurrentScreen.Cleanup() 
            } catch { # Write-Log -Level Warning -Message "NavigationService: Error cleaning up current screen '$($this.CurrentScreen.Name)': $($_.Exception.Message)" }
            }
            $this.CurrentScreen = $null
        }
        # Write-Log -Level Debug -Message "NavigationService: Reset complete, all screens cleaned up."
    }
}

#endregion
#<!-- END_PAGE: ASE.004 -->

#<!-- PAGE: ASE.005 - ThemeManager Class -->
#region ThemeManager Class

# ===== CLASS: ThemeManager =====
# Module: theme-manager (from axiom)
# Dependencies: None
# Purpose: Visual theming system with consistent hex color output
class ThemeManager {
    [hashtable]$CurrentTheme = @{}
    [string]$ThemeName = "Synthwave"
    [hashtable]$Themes = @{}
    
    ThemeManager() {
        $this.InitializeThemes()
        $this.LoadTheme($this.ThemeName)
    }
    
    [void] InitializeThemes() {
        # Synthwave Theme - Neon cyberpunk aesthetic
        $this.Themes["Synthwave"] = @{
            # Base colors
            "Background" = "#0a0e27"
            "Foreground" = "#f92aad"
            "Subtle" = "#72f1b8"
            "Primary" = "#ff6ac1"
            "Accent" = "#ffcc00"
            "Secondary" = "#5a189a"
            "Error" = "#ff006e"
            "Warning" = "#ffbe0b"
            "Success" = "#3bf4fb"
            "Info" = "#8338ec"
            
            # Component specific
            "component.background" = "#0a0e27"
            "component.border" = "#f92aad"
            "component.title" = "#ffcc00"
            
            # Input
            "input.background" = "#1a1e3a"
            "input.foreground" = "#f92aad"
            "input.placeholder" = "#72f1b8"
            
            # Button states
            "button.normal.fg" = "#0a0e27"
            "button.normal.bg" = "#f92aad"
            "button.focused.fg" = "#0a0e27"
            "button.focused.bg" = "#ff6ac1"
            "button.pressed.fg" = "#0a0e27"
            "button.pressed.bg" = "#ffcc00"
            "button.disabled.fg" = "#555555"
            "button.disabled.bg" = "#2a2e4a"
            
            # List/Table
            "list.header.fg" = "#ffcc00"
            "list.header.bg" = "#1a1e3a"
            "list.item.normal" = "#f92aad"
            "list.item.selected" = "#0a0e27"
            "list.item.selected.background" = "#ff6ac1"
            "list.scrollbar" = "#72f1b8"
        }
        
        # Aurora Theme - Northern lights inspired
        $this.Themes["Aurora"] = @{
            # Base colors
            "Background" = "#011627"
            "Foreground" = "#d6deeb"
            "Subtle" = "#7fdbca"
            "Primary" = "#82aaff"
            "Accent" = "#21c7a8"
            "Secondary" = "#c792ea"
            "Error" = "#ef5350"
            "Warning" = "#ffeb95"
            "Success" = "#22da6e"
            "Info" = "#82aaff"
            
            # Component specific
            "component.background" = "#011627"
            "component.border" = "#5f7e97"
            "component.title" = "#21c7a8"
            
            # Input
            "input.background" = "#0e293f"
            "input.foreground" = "#d6deeb"
            "input.placeholder" = "#637777"
            
            # Button states
            "button.normal.fg" = "#011627"
            "button.normal.bg" = "#82aaff"
            "button.focused.fg" = "#011627"
            "button.focused.bg" = "#21c7a8"
            "button.pressed.fg" = "#011627"
            "button.pressed.bg" = "#c792ea"
            "button.disabled.fg" = "#444444"
            "button.disabled.bg" = "#1d3b53"
            
            # List/Table
            "list.header.fg" = "#21c7a8"
            "list.header.bg" = "#0e293f"
            "list.item.normal" = "#d6deeb"
            "list.item.selected" = "#011627"
            "list.item.selected.background" = "#82aaff"
            "list.scrollbar" = "#5f7e97"
        }
        
        # Ocean Theme - Deep sea aesthetics
        $this.Themes["Ocean"] = @{
            # Base colors
            "Background" = "#0f111a"
            "Foreground" = "#8f93a2"
            "Subtle" = "#4b526d"
            "Primary" = "#00bcd4"
            "Accent" = "#00e676"
            "Secondary" = "#536dfe"
            "Error" = "#ff5252"
            "Warning" = "#ffb74d"
            "Success" = "#00e676"
            "Info" = "#448aff"
            
            # Component specific
            "component.background" = "#0f111a"
            "component.border" = "#1f2937"
            "component.title" = "#00bcd4"
            
            # Input
            "input.background" = "#1a1f2e"
            "input.foreground" = "#8f93a2"
            "input.placeholder" = "#4b526d"
            
            # Button states
            "button.normal.fg" = "#0f111a"
            "button.normal.bg" = "#00bcd4"
            "button.focused.fg" = "#0f111a"
            "button.focused.bg" = "#00e676"
            "button.pressed.fg" = "#0f111a"
            "button.pressed.bg" = "#536dfe"
            "button.disabled.fg" = "#333333"
            "button.disabled.bg" = "#1a1f2e"
            
            # List/Table
            "list.header.fg" = "#00e676"
            "list.header.bg" = "#1a1f2e"
            "list.item.normal" = "#8f93a2"
            "list.item.selected" = "#0f111a"
            "list.item.selected.background" = "#00bcd4"
            "list.scrollbar" = "#4b526d"
        }
        
        # Forest Theme - Nature inspired
        $this.Themes["Forest"] = @{
            # Base colors
            "Background" = "#0d1117"
            "Foreground" = "#c9d1d9"
            "Subtle" = "#8b949e"
            "Primary" = "#58a6ff"
            "Accent" = "#56d364"
            "Secondary" = "#d29922"
            "Error" = "#f85149"
            "Warning" = "#f0883e"
            "Success" = "#56d364"
            "Info" = "#58a6ff"
            
            # Component specific
            "component.background" = "#0d1117"
            "component.border" = "#30363d"
            "component.title" = "#56d364"
            
            # Input
            "input.background" = "#161b22"
            "input.foreground" = "#c9d1d9"
            "input.placeholder" = "#484f58"
            
            # Button states
            "button.normal.fg" = "#0d1117"
            "button.normal.bg" = "#58a6ff"
            "button.focused.fg" = "#0d1117"
            "button.focused.bg" = "#56d364"
            "button.pressed.fg" = "#0d1117"
            "button.pressed.bg" = "#d29922"
            "button.disabled.fg" = "#484f58"
            "button.disabled.bg" = "#21262d"
            
            # List/Table
            "list.header.fg" = "#56d364"
            "list.header.bg" = "#161b22"
            "list.item.normal" = "#c9d1d9"
            "list.item.selected" = "#0d1117"
            "list.item.selected.background" = "#58a6ff"
            "list.scrollbar" = "#8b949e"
        }
        
        # Green Console Theme - Classic terminal green
        $this.Themes["Green Console"] = @{
            # Base colors
            "Background" = "#000000"
            "Foreground" = "#00FF00"
            "Subtle" = "#008000"
            "Primary" = "#00FF00"
            "Accent" = "#00FFFF"
            "Secondary" = "#00AA00"
            "Error" = "#FF0000"
            "Warning" = "#FFFF00"
            "Success" = "#00FF00"
            "Info" = "#00FFFF"
            
            # Component specific
            "component.background" = "#000000"
            "component.border" = "#00FF00"
            "component.title" = "#00FFFF"
            
            # Input
            "input.background" = "#001100"
            "input.foreground" = "#00FF00"
            "input.placeholder" = "#008000"
            
            # Button states
            "button.normal.fg" = "#000000"
            "button.normal.bg" = "#00FF00"
            "button.focused.fg" = "#000000"
            "button.focused.bg" = "#00FFFF"
            "button.pressed.fg" = "#000000"
            "button.pressed.bg" = "#FFFF00"
            "button.disabled.fg" = "#005500"
            "button.disabled.bg" = "#001100"
            
            # List/Table
            "list.header.fg" = "#00FFFF"
            "list.header.bg" = "#001100"
            "list.item.normal" = "#00FF00"
            "list.item.selected" = "#000000"
            "list.item.selected.background" = "#00FF00"
            "list.scrollbar" = "#008000"
        }
        
        # Amber Console Theme - Classic amber terminal
        $this.Themes["Amber Console"] = @{
            # Base colors
            "Background" = "#000000"
            "Foreground" = "#FFB000"
            "Subtle" = "#AA7700"
            "Primary" = "#FFB000"
            "Accent" = "#FFFF00"
            "Secondary" = "#FF8800"
            "Error" = "#FF0000"
            "Warning" = "#FFFF00"
            "Success" = "#00FF00"
            "Info" = "#00FFFF"
            
            # Component specific
            "component.background" = "#000000"
            "component.border" = "#FFB000"
            "component.title" = "#FFFF00"
            
            # Input
            "input.background" = "#110800"
            "input.foreground" = "#FFB000"
            "input.placeholder" = "#AA7700"
            
            # Button states
            "button.normal.fg" = "#000000"
            "button.normal.bg" = "#FFB000"
            "button.focused.fg" = "#000000"
            "button.focused.bg" = "#FFFF00"
            "button.pressed.fg" = "#000000"
            "button.pressed.bg" = "#FF8800"
            "button.disabled.fg" = "#553300"
            "button.disabled.bg" = "#110800"
            
            # List/Table
            "list.header.fg" = "#FFFF00"
            "list.header.bg" = "#110800"
            "list.item.normal" = "#FFB000"
            "list.item.selected" = "#000000"
            "list.item.selected.background" = "#FFB000"
            "list.scrollbar" = "#AA7700"
        }
        
        # Notepad Theme - Light theme like Windows Notepad
        $this.Themes["Notepad"] = @{
            # Base colors
            "Background" = "#FFFFFF"
            "Foreground" = "#000000"
            "Subtle" = "#666666"
            "Primary" = "#0000FF"
            "Accent" = "#FF0000"
            "Secondary" = "#008000"
            "Error" = "#FF0000"
            "Warning" = "#FF8800"
            "Success" = "#008000"
            "Info" = "#0000FF"
            
            # Component specific
            "component.background" = "#FFFFFF"
            "component.border" = "#000000"
            "component.title" = "#0000FF"
            
            # Input
            "input.background" = "#FFFFF0"
            "input.foreground" = "#000000"
            "input.placeholder" = "#999999"
            
            # Button states
            "button.normal.fg" = "#000000"
            "button.normal.bg" = "#E0E0E0"
            "button.focused.fg" = "#FFFFFF"
            "button.focused.bg" = "#0000FF"
            "button.pressed.fg" = "#FFFFFF"
            "button.pressed.bg" = "#000080"
            "button.disabled.fg" = "#999999"
            "button.disabled.bg" = "#F0F0F0"
            
            # List/Table
            "list.header.fg" = "#FFFFFF"
            "list.header.bg" = "#000080"
            "list.item.normal" = "#000000"
            "list.item.selected" = "#FFFFFF"
            "list.item.selected.background" = "#0000FF"
            "list.scrollbar" = "#666666"
        }
    }
    
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
        }
    }
    
    [void] LoadDefaultTheme() {
        $this.LoadTheme("Synthwave")
    }
    
    [string] GetColor([string]$colorName) {
        return $this.GetColor($colorName, "#FFFFFF")
    }
    
    [string] GetColor([string]$colorName, [string]$defaultColor) {
        if ($this.CurrentTheme.ContainsKey($colorName)) {
            return $this.CurrentTheme[$colorName]
        }
        return $defaultColor
    }
    
    [void] SetColor([string]$colorName, [string]$colorValue) {
        $this.CurrentTheme[$colorName] = $colorValue
    }
    
    [string[]] GetAvailableThemes() {
        return $this.Themes.Keys | Sort-Object
    }
    
    [void] CycleTheme() {
        $availableThemes = $this.GetAvailableThemes()
        $currentIndex = [array]::IndexOf($availableThemes, $this.ThemeName)
        $nextIndex = ($currentIndex + 1) % $availableThemes.Count
        $this.LoadTheme($availableThemes[$nextIndex])
    }
}

#endregion
#<!-- END_PAGE: ASE.005 -->

#<!-- PAGE: ASE.006 - Logger Class -->
#region Logger Class

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
        
        # Write-Verbose "Logger: Initialized with log path: $($this.LogPath)"
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
        
        $detailsJson = $exceptionDetails | ConvertTo-Json -Compress -Depth 10 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        if (-not $detailsJson) {
            # If serialization fails, create a simple string representation
            $detailsJson = "ExceptionType: $($exceptionDetails.ExceptionType), Message: $($exceptionDetails.ExceptionMessage)"
        }
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
        # Write-Verbose "Logger: Cleanup complete"
    }
}

#endregion
#<!-- END_PAGE: ASE.006 -->

#<!-- PAGE: ASE.007 - EventManager Class -->
#region EventManager Class

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
        # Write-Verbose "EventManager: Initialized"
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
        
        # Write-Verbose "EventManager: Subscribed handler '$handlerId' to event '$eventName'"
        return $handlerId
    }
    
    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            if ($this.EventHandlers[$eventName].ContainsKey($handlerId)) {
                $this.EventHandlers[$eventName].Remove($handlerId)
                # Write-Verbose "EventManager: Unsubscribed handler '$handlerId' from event '$eventName'"
                
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
            # Write-Verbose "EventManager: Unsubscribed all $handlerCount handlers from event '$eventName'"
        }
    }
    
    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        # Sanitize event data to prevent circular reference issues
        $sanitizedData = @{}
        foreach ($key in $eventData.Keys) {
            $value = $eventData[$key]
            if ($value -is [string] -or $value -is [int] -or $value -is [double] -or 
                $value -is [bool] -or $value -is [datetime] -or $value -eq $null) {
                # Simple types are safe
                $sanitizedData[$key] = $value
            }
            elseif ($value -is [UIElement]) {
                # Never store UIElement objects - just store identifying info
                $sanitizedData[$key] = "[UIElement: $($value.Name)]"
            }
            elseif ($value.GetType().Name -match 'Task|Project') {
                # For task/project objects, only store essential data
                try {
                    if ($value.PSObject.Properties['Id']) {
                        $sanitizedData[$key] = @{
                            Type = $value.GetType().Name
                            Id = $value.Id
                            Title = if ($value.PSObject.Properties['Title']) { $value.Title } else { $null }
                        }
                    } else {
                        $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
                    }
                } catch {
                    $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
                }
            }
            else {
                # For other complex types, just store the type name
                $sanitizedData[$key] = "[Object: $($value.GetType().Name)]"
            }
        }
        
        # Add to history if enabled (using sanitized data)
        if ($this.EnableHistory) {
            $historyEntry = @{
                EventName = $eventName
                EventData = $sanitizedData
                Timestamp = [DateTime]::Now
                HandlerCount = 0
            }
            
            $this.EventHistory.Add($historyEntry)
            
            if ($this.EventHistory.Count -gt $this.MaxHistorySize) {
                $this.EventHistory.RemoveAt(0)
            }
        }
        
        # Execute handlers with original data
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
            
            if ($this.EnableHistory -and $this.EventHistory.Count -gt 0) {
                $this.EventHistory[-1].HandlerCount = $handlers.Count
            }
            
            foreach ($entry in $handlers) {
                try {
                    $handlerData = $entry.Value
                    $handlerData.ExecutionCount++
                    & $handlerData.Handler $eventData
                }
                catch {
                    # Log errors without complex data
                    if ($global:TuiState.Services.Logger) {
                        $global:TuiState.Services.Logger.Log(
                            "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $($_.Exception.Message)", 
                            "Error"
                        )
                    }
                }
            }
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
        # Write-Verbose "EventManager: Cleared event history"
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

#endregion
#<!-- END_PAGE: ASE.007 -->

#<!-- PAGE: ASE.008 - AsyncJobService Class -->
#region AsyncJobService Class

# ===== CLASS: AsyncJobService =====
# Module: async-jobs (from axiom)
# Dependencies: None
# Purpose: Framework utilities and async operations
class AsyncJobService {
    [hashtable]$AsyncJobs = @{}
    [int]$NextJobId = 1
    [bool]$IsRunning = $false
    
    AsyncJobService() {
        # Write-Verbose "AsyncJobService: Initialized"
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
            
            # Write-Verbose "AsyncJobService: Started async job '$jobName' with ID $jobId"
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
            # Write-Verbose "AsyncJobService: Waiting for job $jobId to complete"
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
        # Write-Verbose "AsyncJobService: Stopping all async jobs"
        
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
        # Write-Verbose "AsyncJobService: Started"
    }
    
    [void] Stop() {
        $this.StopAllAsyncJobs()
        $this.IsRunning = $false
        # Write-Verbose "AsyncJobService: Stopped"
    }
    
    [void] Cleanup() {
        $this.Stop()
    }
}

#endregion
#<!-- END_PAGE: ASE.008 -->

#<!-- PAGE: ASE.009 - FocusManager Class -->
#region Additional Service Classes

# ===== CLASS: FocusManager =====
# Module: focus-manager (new service)
# Dependencies: EventManager (optional)
# Purpose: Centralized focus management for UI components
class FocusManager {
    [UIElement]$FocusedComponent = $null
    [EventManager]$EventManager = $null

    FocusManager([EventManager]$eventManager) {
        $this.EventManager = $eventManager
        # Write-Log -Level Debug -Message "FocusManager: Initialized."
    }

    [void] SetFocus([UIElement]$component) {
        $componentName = if ($null -ne $component) { $component.Name } else { 'null' }
        Write-Log -Level Debug -Message "FocusManager.SetFocus called with: $componentName"
        
        if ($this.FocusedComponent -eq $component) {
            Write-Log -Level Debug -Message "  - Already focused, returning"
            return
        }
        
        if ($null -ne $this.FocusedComponent) {
            Write-Log -Level Debug -Message "  - Removing focus from: $($this.FocusedComponent.Name)"
            $this.FocusedComponent.IsFocused = $false
            $this.FocusedComponent.OnBlur()
            $this.FocusedComponent.RequestRedraw()
        }

        $this.FocusedComponent = $null
        if ($null -ne $component -and $component.IsFocusable -and $component.Enabled -and $component.Visible) {
            Write-Log -Level Debug -Message "  - Setting focus to: $($component.Name)"
            Write-Log -Level Debug -Message "    - IsFocusable: $($component.IsFocusable)"
            Write-Log -Level Debug -Message "    - Enabled: $($component.Enabled)"
            Write-Log -Level Debug -Message "    - Visible: $($component.Visible)"
            $this.FocusedComponent = $component
            $component.IsFocused = $true
            $component.OnFocus()
            $component.RequestRedraw()
            
            # CRITICAL: Only pass simple data types in events
            if ($this.EventManager) {
                $this.EventManager.Publish("Focus.Changed", @{ 
                    ComponentName = if ($component.Name) { $component.Name } else { "Unnamed" }
                    ComponentType = $component.GetType().Name 
                })
            }
            Write-Log -Level Debug -Message "  - Focus set successfully"
        } else {
            Write-Log -Level Debug -Message "  - Focus NOT set. Component check failed:"
            Write-Log -Level Debug -Message "    - Component null: $($null -eq $component)"
            if ($null -ne $component) {
                Write-Log -Level Debug -Message "    - IsFocusable: $($component.IsFocusable)"
                Write-Log -Level Debug -Message "    - Enabled: $($component.Enabled)"
                Write-Log -Level Debug -Message "    - Visible: $($component.Visible)"
            }
        }
        $global:TuiState.IsDirty = $true
    }

    [void] MoveFocus([bool]$reverse = $false) {
        if (-not $global:TuiState.CurrentScreen) { return }

        $focusableComponents = [System.Collections.Generic.List[UIElement]]::new()
        
        # Helper to recursively find all focusable components within the current screen
        function Find-Focusable([UIElement]$comp, [System.Collections.Generic.List[UIElement]]$list) {
            if ($comp -and $comp.IsFocusable -and $comp.Visible -and $comp.Enabled) {
                $list.Add($comp)
            }
            foreach ($child in $comp.Children) { Find-Focusable $child $list }
        }
        
        Find-Focusable $global:TuiState.CurrentScreen $focusableComponents
        
        if ($focusableComponents.Count -eq 0) {
            $this.SetFocus($null) # Clear focus if no focusable components
            return
        }
        
        # Sort components by TabIndex, then Y, then X for consistent order
        $sorted = $focusableComponents | Sort-Object { $_.TabIndex * 10000 + $_.Y * 100 + $_.X }

        $currentIndex = -1
        if ($this.FocusedComponent) {
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                if ($sorted[$i] -eq $this.FocusedComponent) {
                    $currentIndex = $i
                    break
                }
            }
        }
        
        $nextIndex = -1
        if ($reverse) {
            $nextIndex = ($currentIndex - 1 + $sorted.Count) % $sorted.Count
        } else {
            $nextIndex = ($currentIndex + 1) % $sorted.Count
        }

        # If no component was focused or current one not found, default to first/last
        if ($currentIndex -eq -1) {
            $nextIndex = if ($reverse) { $sorted.Count - 1 } else { 0 }
        }

        $this.SetFocus($sorted[$nextIndex])
    }

    [void] ReleaseFocus() {
        $this.SetFocus($null)
        # Write-Log -Level Debug -Message "FocusManager: All focus released."
    }

    [void] Cleanup() {
        $this.FocusedComponent = $null
        # Write-Log -Level Debug -Message "FocusManager: Cleanup complete."
    }
}

# ===== CLASS: DialogManager =====
# Module: dialog-manager (new service)
# Dependencies: EventManager, FocusManager
# Purpose: Centralized dialog management
class DialogManager {
    [System.Collections.Generic.List[UIElement]] $_activeDialogs = [System.Collections.Generic.List[UIElement]]::new()
    [EventManager]$EventManager = $null
    [FocusManager]$FocusManager = $null
    hidden [UIElement]$_previousFocus = $null

    DialogManager([EventManager]$eventManager, [FocusManager]$focusManager) {
        $this.EventManager = $eventManager
        $this.FocusManager = $focusManager
        # Write-Log -Level Debug -Message "DialogManager: Initialized."
    }

    [void] ShowDialog([UIElement]$dialog) {
        if ($null -eq $dialog) {
            throw [System.ArgumentException]::new("Provided element is null.", "dialog")
        }
        
        # Store previous focus for restoration
        if ($this.FocusManager) {
            $this._previousFocus = $this.FocusManager.FocusedComponent
        }
        
        # Calculate center position based on console size
        $consoleWidth = $global:TuiState.BufferWidth
        $consoleHeight = $global:TuiState.BufferHeight

        $dialog.X = [Math]::Max(0, [Math]::Floor(($consoleWidth - $dialog.Width) / 2))
        $dialog.Y = [Math]::Max(0, [Math]::Floor(($consoleHeight - $dialog.Height) / 2))

        # If there's a currently focused component, release it
        if ($this.FocusManager) {
            $this.FocusManager.ReleaseFocus() # Release current focus
        }

        # Add to local tracking list and global overlay stack
        $this._activeDialogs.Add($dialog)
        $dialog.Visible = $true
        $dialog.IsOverlay = $true # Mark as an overlay for rendering

        # Explicitly add to global overlay stack
        $global:TuiState.OverlayStack.Add($dialog)
        
        # Initialize and enter the dialog if it implements these methods
        if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
            $dialog.Initialize()
            $dialog._isInitialized = $true
        }
        if ($dialog.PSObject.Methods['OnEnter']) {
            $dialog.OnEnter()
        }

        $dialog.RequestRedraw()
        # Write-Log -Level Info -Message "DialogManager: Showing dialog '$($dialog.Name)' at X=$($dialog.X), Y=$($dialog.Y)."
        
        # Set focus to the dialog itself or its first focusable child
        if ($this.FocusManager) {
            # Let the dialog class handle finding its first internal focusable
            if ($dialog.PSObject.Methods['SetInitialFocus']) {
                # Force a redraw first to ensure components are ready
                $dialog.RequestRedraw()
                $global:TuiState.IsDirty = $true
                
                # Now set initial focus
                $dialog.SetInitialFocus()
            } else {
                $this.FocusManager.SetFocus($dialog) # Fallback to focusing the dialog container
            }
        }
    }

    [void] HideDialog([UIElement]$dialog) {
        if ($null -eq $dialog) { return }

        if ($this._activeDialogs.Remove($dialog)) {
            $dialog.Visible = $false
            $dialog.IsOverlay = $false

            # Remove from global overlay stack
            if ($global:TuiState.OverlayStack.Contains($dialog)) {
                $global:TuiState.OverlayStack.Remove($dialog)
            }

            # Call Cleanup on the dialog to release its resources
            $dialog.Cleanup()

            # Restore previous focus
            if ($this.FocusManager) {
                $this.FocusManager.SetFocus($this._previousFocus)
            }

            $dialog.RequestRedraw() # Force redraw to remove dialog from screen
            # Write-Log -Level Info -Message "DialogManager: Hiding dialog '$($dialog.Name)'."
        } else {
            # Write-Log -Level Warning -Message "DialogManager: Attempted to hide a dialog '$($dialog.Name)' that was not active."
        }
    }

    [void] Cleanup() {
        foreach ($dialog in $this._activeDialogs.ToArray()) { # Use ToArray to avoid collection modification during iteration
            $this.HideDialog($dialog) # This will also cleanup and remove from overlay stack
        }
        $this._activeDialogs.Clear()
        # Write-Log -Level Debug -Message "DialogManager: Cleanup complete."
    }
}

#endregion
#<!-- END_PAGE: ASE.009 -->

#<!-- PAGE: ASE.010 - TuiFrameworkService Class -->
#region TuiFrameworkService - Framework State Management

# ==============================================================================
# CLASS: TuiFrameworkService
#
# INHERITS: N/A
#
# DEPENDENCIES: None (directly accesses global state)
#
# PURPOSE:
#   Provides a clean service interface for accessing framework state and
#   dimensions instead of components directly accessing $global:TuiState.
#   This encapsulates global state access and provides a more maintainable
#   architecture.
#
# KEY LOGIC:
#   - GetDimensions: Returns current buffer dimensions
#   - GetCurrentScreen: Returns the currently active screen
#   - IsRunning: Returns whether the engine is running
#   - RequestRedraw: Marks the global state as dirty for redraw
#   - GetFrameCount: Returns current frame count for debugging
# ==============================================================================
class TuiFrameworkService {
    [hashtable]$_globalState = $null
    
    TuiFrameworkService() {
        $this._globalState = $global:TuiState
        Write-Log -Level Debug -Message "TuiFrameworkService: Initialized with global state access"
    }
    
    [hashtable] GetDimensions() {
        return @{
            Width = $this._globalState.BufferWidth
            Height = $this._globalState.BufferHeight
        }
    }
    
    [int] GetWidth() {
        return $this._globalState.BufferWidth
    }
    
    [int] GetHeight() {
        return $this._globalState.BufferHeight
    }
    
    [object] GetCurrentScreen() {
        return $this._globalState.CurrentScreen
    }
    
    [bool] IsRunning() {
        return $this._globalState.Running
    }
    
    [void] RequestRedraw() {
        $this._globalState.IsDirty = $true
    }
    
    [int] GetFrameCount() {
        return $this._globalState.FrameCount
    }
    
    [object] GetCompositorBuffer() {
        return $this._globalState.CompositorBuffer
    }
    
    [object] GetFocusedComponent() {
        return $this._globalState.FocusedComponent
    }
    
    [System.Collections.Generic.List[UIElement]] GetOverlayStack() {
        return $this._globalState.OverlayStack
    }
    
    [void] AddOverlay([UIElement]$overlay) {
        $this._globalState.OverlayStack.Add($overlay)
        $this.RequestRedraw()
    }
    
    [bool] RemoveOverlay([UIElement]$overlay) {
        $removed = $this._globalState.OverlayStack.Remove($overlay)
        if ($removed) {
            $this.RequestRedraw()
        }
        return $removed
    }
    
    [void] Cleanup() {
        Write-Log -Level Debug -Message "TuiFrameworkService: Cleanup completed"
        # No cleanup needed - just reports completion
    }
}

#endregion
#<!-- END_PAGE: ASE.010 -->

#<!-- PAGE: ASE.011 - ViewDefinitionService Class -->
# ===== CLASS: ViewDefinitionService =====  
# Module: view-definition-service
# Dependencies: None
# Purpose: Centralized service for defining how data models are presented in UI components
class ViewDefinitionService {
    hidden [hashtable]$_definitions = @{}
    
    ViewDefinitionService() {
        $this._RegisterDefaultViewDefinitions()
    }
    
    [hashtable] GetViewDefinition([string]$viewName) {
        if (-not $this._definitions.ContainsKey($viewName)) {
            throw "View definition '$viewName' not found. Available definitions: $($this._definitions.Keys -join ', ')"
        }
        return $this._definitions[$viewName]
    }
    
    [void] RegisterViewDefinition([string]$viewName, [hashtable]$definition) {
        if ([string]::IsNullOrWhiteSpace($viewName)) {
            throw "View name cannot be null or empty"
        }
        
        if (-not $definition -or -not $definition.ContainsKey("Columns") -or -not $definition.ContainsKey("Transformer")) {
            throw "View definition must contain 'Columns' and 'Transformer' keys"
        }
        
        $this._definitions[$viewName] = $definition
    }
    
    [string[]] GetAvailableViewNames() {
        return $this._definitions.Keys
    }
    
    hidden [void] _RegisterDefaultViewDefinitions() {
        # Task summary view for lists and grids
        $this.RegisterViewDefinition('task.summary', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=3 },
                @{ Name="Priority"; Header="!"; Width=3 },
                @{ Name="Title";    Header="Task Title"; Width=40 },
                @{ Name="Progress"; Header="Progress"; Width=8 }
            )
            Transformer = {
                param($task)
                
                # Status indicator  
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "o" }
                    ([TaskStatus]::InProgress) { "*" }
                    ([TaskStatus]::Completed) { "✓" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                # Priority indicator
                $priorityChar = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "↓" }
                    ([TaskPriority]::Medium) { "-" }
                    ([TaskPriority]::High) { "↑" }
                    default { "-" }
                }
                
                # Progress display
                $progressText = "$($task.Progress)%"
                
                return @{
                    Status   = $statusChar
                    Priority = $priorityChar  
                    Title    = $task.Title
                    Progress = $progressText
                }
            }
        })
        
        # Task detail view with more information
        $this.RegisterViewDefinition('task.detailed', @{
            Columns = @(
                @{ Name="Status";     Header="Status"; Width=12 },
                @{ Name="Priority";   Header="Priority"; Width=10 },
                @{ Name="Title";      Header="Task Title"; Width=30 },
                @{ Name="Progress";   Header="Progress"; Width=10 },
                @{ Name="DueDate";    Header="Due Date"; Width=12 },
                @{ Name="Project";    Header="Project"; Width=15 }
            )
            Transformer = {
                param($task)
                
                # Full status name
                $statusText = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "Pending" }
                    ([TaskStatus]::InProgress) { "In Progress" }
                    ([TaskStatus]::Completed) { "Completed" }
                    ([TaskStatus]::Cancelled) { "Cancelled" }
                    default { "Unknown" }
                }
                
                # Full priority name
                $priorityText = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "Low" }
                    ([TaskPriority]::Medium) { "Medium" }
                    ([TaskPriority]::High) { "High" }
                    default { "Unknown" }
                }
                
                # Formatted due date
                $dueDateText = if ($task.DueDate) {
                    $task.DueDate.ToString("MM/dd/yyyy")
                } else {
                    "None"
                }
                
                # Progress with bar
                $progressText = "$($task.Progress)%"
                
                # Project key or default
                $projectText = if ($task.ProjectKey) { $task.ProjectKey } else { "None" }
                
                return @{
                    Status   = $statusText
                    Priority = $priorityText
                    Title    = $task.Title
                    Progress = $progressText
                    DueDate  = $dueDateText
                    Project  = $projectText
                }
            }
        })
        
        # Compact task view for narrow displays
        $this.RegisterViewDefinition('task.compact', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=1 },
                @{ Name="Title";    Header="Task"; Width=30 }
            )
            Transformer = {
                param($task)
                
                # Single character status
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                return @{
                    Status = $statusChar
                    Title  = $task.Title
                }
            }
        })
        
        # Project summary view
        $this.RegisterViewDefinition('project.summary', @{
            Columns = @(
                @{ Name="Key";        Header="Key"; Width=10 },
                @{ Name="Name";       Header="Project Name"; Width=30 },
                @{ Name="Status";     Header="Status"; Width=10 },
                @{ Name="Owner";      Header="Owner"; Width=15 }
            )
            Transformer = {
                param($project)
                
                $statusText = if ($project.IsActive) { "Active" } else { "Inactive" }
                $ownerText = if ($project.Owner) { $project.Owner } else { "Unassigned" }
                
                return @{
                    Key    = $project.Key
                    Name   = $project.Name
                    Status = $statusText
                    Owner  = $ownerText
                }
            }
        })
        
        # Dashboard recent tasks view - compact for overview
        $this.RegisterViewDefinition('dashboard.recent.tasks', @{
            Columns = @(
                @{ Name="Status";   Header="S"; Width=1 },
                @{ Name="Priority"; Header="!"; Width=1 },
                @{ Name="Title";    Header="Recent Tasks"; Width=35 },
                @{ Name="Age";      Header="Age"; Width=8 }
            )
            Transformer = {
                param($task)
                
                # Status indicator with unicode symbols
                $statusChar = switch ($task.Status) {
                    ([TaskStatus]::Pending) { "○" }
                    ([TaskStatus]::InProgress) { "◐" }
                    ([TaskStatus]::Completed) { "●" }
                    ([TaskStatus]::Cancelled) { "✗" }
                    default { "?" }
                }
                
                # Priority indicator
                $priorityChar = switch ($task.Priority) {
                    ([TaskPriority]::Low) { "↓" }
                    ([TaskPriority]::Medium) { "→" }
                    ([TaskPriority]::High) { "↑" }
                    default { "?" }
                }
                
                # Calculate age in days
                $age = [DateTime]::Now - $task.CreatedAt
                $ageText = if ($age.Days -gt 0) {
                    "$($age.Days)d"
                } elseif ($age.Hours -gt 0) {
                    "$($age.Hours)h"
                } else {
                    "$($age.Minutes)m"
                }
                
                return @{
                    Status   = $statusChar
                    Priority = $priorityChar
                    Title    = $task.Title
                    Age      = $ageText
                }
            }
        })
        
        # Dashboard summary statistics view
        $this.RegisterViewDefinition('dashboard.task.stats', @{
            Columns = @(
                @{ Name="Metric";    Header="Task Statistics"; Width=20 },
                @{ Name="Value";     Header="Count"; Width=8 },
                @{ Name="Indicator"; Header=""; Width=5 }
            )
            Transformer = {
                param($statsData)
                
                # This transformer expects a hashtable with metrics
                # Example: @{ Name="Total Tasks"; Count=15; Type="info" }
                
                $indicator = switch ($statsData.Type) {
                    "success" { "✓" }
                    "warning" { "⚠" }
                    "error" { "✗" }
                    "info" { "ⓘ" }
                    default { " " }
                }
                
                return @{
                    Metric    = $statsData.Name
                    Value     = $statsData.Count.ToString()
                    Indicator = $indicator
                }
            }
        })
        
        # Dashboard navigation menu view
        $this.RegisterViewDefinition('dashboard.navigation', @{
            Columns = @(
                @{ Name="Key";         Header="Key"; Width=5 },
                @{ Name="Action";      Header="Quick Actions"; Width=25 },
                @{ Name="Description"; Header="Description"; Width=20 }
            )
            Transformer = {
                param($navItem)
                
                return @{
                    Key         = "[$($navItem.Key)]"
                    Action      = $navItem.Name
                    Description = $navItem.Description
                }
            }
        })
    }
}
#<!-- END_PAGE: ASE.011 -->

