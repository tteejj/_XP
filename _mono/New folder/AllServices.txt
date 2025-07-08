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

# ==============================================================================
# CLASS: ActionService
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Services:
#     - EventManager (ASE.007) (optional)
#
# PURPOSE:
#   Provides a central registry for all application commands ("actions"). This
#   decouples the invoker of a command (e.g., a keybinding, a menu item) from
#   the implementation of the command itself.
#
# KEY LOGIC:
#   - `RegisterAction`: Adds a named action (a scriptblock) along with metadata
#     like Category and Description to an internal hashtable.
#   - `ExecuteAction`: Looks up an action by its name and invokes the
#     scriptblock, passing in parameters. It also handles metadata updates
#     (execution count) and publishes `Action.Executed` events.
#   - `Get*` methods allow other parts of the UI (like the CommandPalette) to
#     discover and list available actions.
# ==============================================================================
class ActionService {
    [hashtable]$ActionRegistry = @{}
    [hashtable]$EventSubscriptions = @{}
    [object]$EventManager = $null
    
    ActionService() {
        Write-Log -Level Debug -Message "ActionService: Initialized with empty registry"
    }
    
    ActionService([object]$eventManager) {
        $this.EventManager = $eventManager
        Write-Log -Level Debug -Message "ActionService: Initialized with EventManager integration"
    }
    
    [void] RegisterAction([string]$actionName, [scriptblock]$action, [hashtable]$metadata = @{}) {
        try {
            if ([string]::IsNullOrWhiteSpace($actionName)) { throw "Action name cannot be null or empty" }
            if (-not $action) { throw "Action scriptblock cannot be null" }
            
            $actionData = @{
                Name = $actionName; Action = $action; Metadata = $metadata
                Category = $metadata.Category ?? "General"
                Description = $metadata.Description ?? ""
                Hotkey = $metadata.Hotkey ?? ""
                RegisteredAt = [datetime]::Now; ExecutionCount = 0; LastExecuted = $null
            }
            
            $this.ActionRegistry[$actionName] = $actionData
            $this.EventManager?.Publish("Action.Registered", @{ ActionName = $actionName; Category = $actionData.Category })
            Write-Log -Level Debug -Message "ActionService: Registered action '$actionName' in category '$($actionData.Category)'"
        }
        catch {
            Write-Log -Level Error -Message "Failed to register action '$actionName': $_" -Data $_
            throw
        }
    }
    
    [void] UnregisterAction([string]$actionName) {
        if ($this.ActionRegistry.ContainsKey($actionName)) {
            $this.ActionRegistry.Remove($actionName)
            $this.EventManager?.Publish("Action.Unregistered", @{ ActionName = $actionName })
            Write-Log -Level Debug -Message "ActionService: Unregistered action '$actionName'"
        }
    }
    
    [object] ExecuteAction([string]$actionName, [hashtable]$parameters = @{}) {
        try {
            if (-not $this.ActionRegistry.ContainsKey($actionName)) { throw "Action '$actionName' not found in registry" }
            
            $actionData = $this.ActionRegistry[$actionName]
            $actionData.ExecutionCount++; $actionData.LastExecuted = [datetime]::Now
            
            Write-Log -Level Info -Message "ActionService: Executing action '$actionName'"
            
            $result = & $actionData.Action @parameters
            
            $this.EventManager?.Publish("Action.Executed", @{ ActionName = $actionName; Parameters = $parameters; Success = $true })
            return $result
        }
        catch {
            Write-Log -Level Error -Message "Failed to execute action '$actionName': $($_.Exception.Message)" -Data $_
            $this.EventManager?.Publish("Action.Executed", @{ ActionName = $actionName; Parameters = $parameters; Success = $false; Error = $_.ToString() })
            throw
        }
    }
    
    [hashtable] GetAction([string]$actionName) { return $this.ActionRegistry[$actionName] }
    [hashtable] GetAllActions() { return $this.ActionRegistry }
    [hashtable[]] GetActionsByCategory([string]$category) { return @($this.ActionRegistry.Values | Where-Object { $_.Category -eq $category }) }
    
    [void] RegisterDefaultActions() {
        $this.RegisterAction("app.exit", { $global:TuiState.Running = $false }, @{ Category = "Application"; Description = "Exit the application" })
        $this.RegisterAction("app.help", { }, @{ Category = "Application"; Description = "Show help" })
        $this.RegisterAction("app.commandPalette", { $global:TuiState.CommandPalette?.Show(); $global:TuiState.IsDirty = $true }, @{ Category = "Application"; Description = "Show command palette" })
        
        $this.RegisterAction("ui.theme.picker", {
            $navService = $global:TuiState.Services.NavigationService; $container = $global:TuiState.Services.ServiceContainer
            $themeScreen = [ThemePickerScreen]::new($container); $themeScreen.Initialize(); $navService.NavigateTo($themeScreen)
        }, @{ Category = "UI"; Description = "Change Theme" })

        $this.RegisterAction("navigation.dashboard", {
            $navService = $global:TuiState.Services.NavigationService; $container = $global:TuiState.Services.ServiceContainer
            $dashScreen = [DashboardScreen]::new($container); $dashScreen.Initialize(); $navService.NavigateTo($dashScreen)
        }, @{ Category = "Navigation"; Description = "Go to Dashboard" })
        
        $this.RegisterAction("navigation.taskList", {
            $navService = $global:TuiState.Services.NavigationService; $container = $global:TuiState.Services.ServiceContainer
            $taskScreen = [TaskListScreen]::new($container); $taskScreen.Initialize(); $navService.NavigateTo($taskScreen)
        }, @{ Category = "Navigation"; Description = "Go to Task List" })
        
        Write-Log -Level Debug -Message "ActionService: Registered default actions"
    }
}

#endregion
#<!-- END_PAGE: ASE.001 -->

#<!-- PAGE: ASE.002 - KeybindingService Class -->
#region KeybindingService Class

# ==============================================================================
# CLASS: KeybindingService
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Services:
#     - ActionService (ASE.001) (optional)
#
# PURPOSE:
#   Translates raw keyboard input (`ConsoleKeyInfo`) into named actions. It
#   supports different contexts, allowing keybindings to change depending on
#   which part of the UI is active.
#
# KEY LOGIC:
#   - `_GetKeyPattern`: Converts a `ConsoleKeyInfo` object into a canonical
#     string format (e.g., "Ctrl+Shift+A"). This is the key used in the maps.
#   - `SetBinding`: Maps a key pattern string to an action name string within a
#     given context (e.g., "Global", "Editor").
#   - `GetAction`: The main lookup method. Given a `ConsoleKeyInfo`, it generates
#     the pattern and checks for a matching action, first in the contextual
#     key maps and then falling back to the "Global" map.
# ==============================================================================
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
        $this.SetBinding("Ctrl+Q", "app.exit", "Global")
        $this.SetBinding("F1", "app.help", "Global")
        $this.SetBinding("Ctrl+P", "app.commandPalette", "Global")
        $this.SetBinding("Ctrl+D", "navigation.dashboard", "Global")
        $this.SetBinding("Ctrl+T", "navigation.taskList", "Global")
        $this.SetBinding("Tab", "navigation.nextComponent", "Global")
        $this.SetBinding("Shift+Tab", "navigation.previousComponent", "Global")
        Write-Log -Level Debug -Message "KeybindingService: Initialized default keybindings"
    }
    
    [void] SetBinding([string]$keyPattern, [string]$actionName, [string]$context = "Global") {
        if (-not $this.KeyMap.ContainsKey($context)) { $this.KeyMap[$context] = @{} }
        $this.KeyMap[$context][$keyPattern] = $actionName
        Write-Log -Level Debug -Message "KeybindingService: Bound '$keyPattern' to '$actionName' in context '$context'"
    }
    
    [void] RemoveBinding([string]$keyPattern, [string]$context = "Global") {
        if ($this.KeyMap.ContainsKey($context)) {
            $this.KeyMap[$context].Remove($keyPattern)
            Write-Log -Level Debug -Message "KeybindingService: Removed binding for '$keyPattern' in context '$context'"
        }
    }
    
    [bool] IsAction([System.ConsoleKeyInfo]$keyInfo, [string]$actionName) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        foreach ($context in $this.ContextStack) { if ($context.ContainsKey($keyPattern) -and $context[$keyPattern] -eq $actionName) { return $true } }
        return ($this.KeyMap.Global?.$keyPattern -eq $actionName)
    }
    
    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        $keyPattern = $this._GetKeyPattern($keyInfo)
        foreach ($context in $this.ContextStack) { if ($context.ContainsKey($keyPattern)) { return $context[$keyPattern] } }
        return $this.KeyMap.Global?.$keyPattern
    }
    
    [string] GetBindingDescription([System.ConsoleKeyInfo]$keyInfo) {
        $action = $this.GetAction($keyInfo)
        if ($action -and $this.ActionService) { return $this.ActionService.GetAction($action)?.Description }
        return $null
    }
    
    hidden [string] _GetKeyPattern([System.ConsoleKeyInfo]$keyInfo) {
        $parts = [System.Collections.Generic.List[string]]::new()
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) { $parts.Add("Ctrl") }
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Alt) { $parts.Add("Alt") }
        if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) { $parts.Add("Shift") }
        $parts.Add($keyInfo.Key.ToString())
        return $parts -join "+"
    }
    
    [void] PushContext([hashtable]$contextBindings) {
        $this.ContextStack.Push($contextBindings)
        Write-Log -Level Debug -Message "KeybindingService: Pushed new context with $($contextBindings.Count) bindings"
    }
    
    [void] PopContext() {
        if ($this.ContextStack.Count -gt 0) {
            $removed = $this.ContextStack.Pop()
            Write-Log -Level Debug -Message "KeybindingService: Popped context with $($removed.Count) bindings"
        }
    }
    
    [void] RegisterGlobalHandler([string]$handlerId, [scriptblock]$handler) {
        $this.GlobalHandlers[$handlerId] = $handler
        Write-Log -Level Debug -Message "KeybindingService: Registered global handler '$handlerId'"
    }
    
    [void] UnregisterGlobalHandler([string]$handlerId) {
        $this.GlobalHandlers.Remove($handlerId)
        Write-Log -Level Debug -Message "KeybindingService: Unregistered global handler '$handlerId'"
    }

    [void] Cleanup() {
        $this.KeyMap.Clear(); $this.GlobalHandlers.Clear(); $this.ContextStack.Clear()
        Write-Log -Level Debug -Message "KeybindingService: Cleanup complete"
    }
}

#endregion
#<!-- END_PAGE: ASE.002 -->

#<!-- PAGE: ASE.003 - DataManager Class -->
#region DataManager Class

# ==============================================================================
# CLASS: DataManager
#
# INHERITS:
#   - System.IDisposable
#
# DEPENDENCIES:
#   Models:
#     - PmcTask (AMO.003)
#     - PmcProject (AMO.003)
#   Services:
#     - EventManager (ASE.007) (optional)
#
# PURPOSE:
#   Handles all data persistence for the application. It loads and saves the
#   application's state (tasks, projects) to a JSON file, provides safe
#   CRUD operations, and manages automatic backups.
#
# KEY LOGIC:
#   - Uses Dictionaries (`_taskIndex`, `_projectIndex`) for fast O(1) lookups
#     of items by their ID/Key.
#   - `LoadData`/`SaveData`: Serializes and deserializes the entire data model
#     to/from JSON. `SaveData` also calls `CreateBackup`.
#   - `CreateBackup`: Manages a rotating set of timestamped backup files.
#   - `BeginUpdate`/`EndUpdate`: Provides a transactional mechanism to batch
#     multiple data modifications, preventing multiple file saves in a short
#     period and ensuring data consistency. A save only occurs when the
#     outermost transaction is completed.
# ==============================================================================
class DataManager : System.IDisposable {
    hidden [System.Collections.Generic.Dictionary[string, PmcTask]]$_taskIndex
    hidden [System.Collections.Generic.Dictionary[string, PmcProject]]$_projectIndex
    hidden [string]$_dataFilePath
    hidden [string]$_backupPath
    hidden [datetime]$_lastSaveTime
    hidden [bool]$_dataModified = $false
    hidden [int]$_updateTransactionCount = 0
    
    [hashtable]$Metadata = @{}
    [bool]$AutoSave = $true
    [int]$BackupCount = 5
    [EventManager]$EventManager = $null
    
    DataManager([string]$dataPath, [EventManager]$eventManager = $null) {
        $this._dataFilePath = $dataPath
        $this.EventManager = $eventManager
        $this._Initialize()
    }
    
    hidden [void] _Initialize() {
        $this._taskIndex = [System.Collections.Generic.Dictionary[string, PmcTask]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $this._projectIndex = [System.Collections.Generic.Dictionary[string, PmcProject]]::new([System.StringComparer]::OrdinalIgnoreCase)
        
        $baseDir = Split-Path -Path $this._dataFilePath -Parent
        $this._backupPath = Join-Path $baseDir "backups"
        
        if (-not (Test-Path $baseDir)) { New-Item -ItemType Directory -Path $baseDir -Force | Out-Null }
        if (-not (Test-Path $this._backupPath)) { New-Item -ItemType Directory -Path $this._backupPath -Force | Out-Null }
        
        Write-Log -Level Info -Message "DataManager: Initialized with path '$($this._dataFilePath)'"
    }
    
    [void] LoadData() {
        try {
            if (-not (Test-Path $this._dataFilePath)) { Write-Log -Level Info -Message "DataManager: No existing data file found at '$($this._dataFilePath)'"; return }
            $jsonContent = Get-Content -Path $this._dataFilePath -Raw -Encoding UTF8
            if ([string]::IsNullOrWhiteSpace($jsonContent)) { Write-Log -Level Info -Message "DataManager: Data file is empty"; return }
            
            $data = $jsonContent | ConvertFrom-Json -AsHashtable
            $this._taskIndex.Clear(); $this._projectIndex.Clear()
            
            if ($data.Tasks) { foreach ($taskData in $data.Tasks) { try { $task = [PmcTask]::FromLegacyFormat($taskData); $this._taskIndex[$task.Id] = $task } catch { Write-Log -Level Warning -Message "DataManager: Failed to load task: $($_.Exception.Message)" } } }
            if ($data.Projects) { foreach ($projectData in $data.Projects) { try { $project = [PmcProject]::FromLegacyFormat($projectData); $this._projectIndex[$project.Key] = $project } catch { Write-Log -Level Warning -Message "DataManager: Failed to load project: $($_.Exception.Message)" } } }
            if ($data.Metadata) { $this.Metadata = $data.Metadata.Clone() }
            
            $this._lastSaveTime = [datetime]::Now; $this._dataModified = $false
            Write-Log -Level Info -Message "DataManager: Loaded $($this._taskIndex.Count) tasks and $($this._projectIndex.Count) projects"
            $this.EventManager?.Publish("Data.Loaded", @{ TaskCount = $this._taskIndex.Count; ProjectCount = $this._projectIndex.Count; Source = $this._dataFilePath })
        }
        catch {
            Write-Log -Level Error -Message "DataManager: Failed to load data from '$($this._dataFilePath)': $($_.Exception.Message)" -Data $_
            throw
        }
    }
    
    [void] SaveData() {
        if ($this._updateTransactionCount -gt 0) { Write-Log -Level Debug -Message "DataManager: SaveData deferred - inside update transaction (level $($this._updateTransactionCount))"; return }
        
        try {
            $this.CreateBackup()
            $saveData = @{ Tasks = @(); Projects = @(); Metadata = $this.Metadata.Clone(); SavedAt = [datetime]::Now; Version = "4.0" }
            foreach ($task in $this._taskIndex.Values) { $saveData.Tasks += $task.ToLegacyFormat() }
            foreach ($project in $this._projectIndex.Values) { $saveData.Projects += $project.ToLegacyFormat() }
            
            $saveData | ConvertTo-Json -Depth 10 | Set-Content -Path $this._dataFilePath -Encoding UTF8 -Force
            $this._lastSaveTime = [datetime]::Now; $this._dataModified = $false
            
            Write-Log -Level Info -Message "DataManager: Data saved to '$($this._dataFilePath)'"
            $this.EventManager?.Publish("Data.Saved", @{ TaskCount = $saveData.Tasks.Count; ProjectCount = $saveData.Projects.Count; Destination = $this._dataFilePath })
        }
        catch {
            Write-Log -Level Error -Message "DataManager: Failed to save data: $($_.Exception.Message)" -Data $_
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
                
                if ($this.BackupCount -gt 0) {
                    $backups = Get-ChildItem -Path $this._backupPath -Filter "data-backup-*.json" | Sort-Object LastWriteTime -Descending
                    if ($backups.Count -gt $this.BackupCount) {
                        $backups | Select-Object -Skip $this.BackupCount | Remove-Item -Force -Verbose:$false
                    }
                }
            }
        }
        catch { Write-Log -Level Warning -Message "DataManager: Failed to create backup: $($_.Exception.Message)" }
    }
    
    [void] BeginUpdate() { $this._updateTransactionCount++; Write-Log -Level Debug -Message "DataManager: Began update transaction. Depth: $($this._updateTransactionCount)" }
    [void] EndUpdate([bool]$forceSave = $false) {
        if ($this._updateTransactionCount -gt 0) { $this._updateTransactionCount-- }
        Write-Log -Level Debug -Message "DataManager: Ended update transaction. Depth: $($this._updateTransactionCount)"
        if ($this._updateTransactionCount -eq 0 -and ($this._dataModified -or $forceSave)) { if ($this.AutoSave -or $forceSave) { $this.SaveData() } }
    }
    
    [PmcTask[]] GetTasks() { return @($this._taskIndex.Values) }
    [PmcTask] GetTask([string]$taskId) { if ($this._taskIndex.ContainsKey($taskId)) { return $this._taskIndex[$taskId] } return $null }
    [PmcTask[]] GetTasksByProject([string]$projectKey) { return @($this._taskIndex.Values | Where-Object { $_.ProjectKey -eq $projectKey }) }
    
    [PmcTask] AddTask([PmcTask]$task) {
        if (-not $task) { throw [System.ArgumentNullException]::new("task") }
        if ([string]::IsNullOrEmpty($task.Id)) { $task.Id = [guid]::NewGuid().ToString() }
        if ($this._taskIndex.ContainsKey($task.Id)) { throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' already exists") }
        
        $this._taskIndex[$task.Id] = $task; $this._dataModified = $true
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) { $this.SaveData() }
        $this.EventManager?.Publish("Tasks.Changed", @{ Action = "Created"; Task = $task })
        return $task
    }
    
    [PmcTask] UpdateTask([PmcTask]$task) {
        if (-not $task) { throw [System.ArgumentNullException]::new("task") }
        if (-not $this._taskIndex.ContainsKey($task.Id)) { throw [System.InvalidOperationException]::new("Task with ID '$($task.Id)' not found") }
        
        $task.UpdatedAt = [datetime]::Now
        $this._taskIndex[$task.Id] = $task; $this._dataModified = $true
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) { $this.SaveData() }
        $this.EventManager?.Publish("Tasks.Changed", @{ Action = "Updated"; Task = $task })
        return $task
    }
    
    [bool] DeleteTask([string]$taskId) {
        if (-not $this._taskIndex.ContainsKey($taskId)) { return $false }
        
        $this._taskIndex.Remove($taskId) | Out-Null; $this._dataModified = $true
        if ($this.AutoSave -and $this._updateTransactionCount -eq 0) { $this.SaveData() }
        $this.EventManager?.Publish("Tasks.Changed", @{ Action = "Deleted"; TaskId = $taskId })
        return $true
    }
    
    [PmcProject[]] GetProjects() { return @($this._projectIndex.Values) }
    [PmcProject] GetProject([string]$projectKey) { if ($this._projectIndex.ContainsKey($projectKey)) { return $this._projectIndex[$projectKey] } return $null }
    
    [void] Dispose() {
        Write-Log -Level Debug -Message "DataManager: Disposing - checking for unsaved data"
        if ($this._dataModified) { try { $this.ForceSave() } catch { Write-Log -Level Warning -Message "DataManager: Failed to save data during dispose: $($_.Exception.Message)" } }
    }
    
    [void] ForceSave() { $originalCount = $this._updateTransactionCount; $this._updateTransactionCount = 0; try { $this.SaveData() } finally { $this._updateTransactionCount = $originalCount } }
    [void] Cleanup() { $this.Dispose() }
}

#endregion
#<!-- END_PAGE: ASE.003 -->

#<!-- PAGE: ASE.004 - NavigationService Class -->
#region NavigationService Class

# ==============================================================================
# CLASS: NavigationService
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - Screen (ABC.006)
#   Services:
#     - EventManager (ASE.007) (optional)
#
# PURPOSE:
#   Manages the application's screen flow. It maintains a navigation stack,
#   allowing for forward and backward navigation between different `Screen`
#   instances.
#
# KEY LOGIC:
#   - A `Stack[Screen]` is used to keep track of the navigation history.
#   - `NavigateTo`: The core forward-navigation method. It calls `OnExit` on
#     the current screen, pushes it to the stack, sets the new screen as
#     current, and calls `OnEnter` on the new screen. It also updates the
#     `$global:TuiState.CurrentScreen`.
#   - `GoBack`: Pops a screen from the stack, calls `OnExit` and `Cleanup` on
#     the current screen, and then calls `OnResume` on the newly restored
#     screen.
# ==============================================================================
class NavigationService {
    [System.Collections.Generic.Stack[Screen]]$NavigationStack
    [Screen]$CurrentScreen
    [EventManager]$EventManager
    [hashtable]$ScreenRegistry
    [int]$MaxStackSize = 10
    [object]$ServiceContainer

    NavigationService([object]$serviceContainer) {
        $this.ServiceContainer = $serviceContainer
        $this.EventManager = $this.ServiceContainer.GetService("EventManager")
        $this.NavigationStack = [System.Collections.Generic.Stack[Screen]]::new()
        $this.ScreenRegistry = @{}
    }

    [void] NavigateTo([Screen]$screen) {
        if ($null -eq $screen) { throw [System.ArgumentNullException]::new("screen") }
        
        try {
            if ($this.CurrentScreen) {
                Write-Log -Level Debug -Message "NavigationService: Exiting screen '$($this.CurrentScreen.Name)'"
                $this.CurrentScreen.OnExit()
                $this.NavigationStack.Push($this.CurrentScreen)
            }
            
            $this.CurrentScreen = $screen
            Write-Log -Level Debug -Message "NavigationService: Entering screen '$($screen.Name)'"
            
            if (-not $screen._isInitialized) {
                $screen.Initialize(); $screen._isInitialized = $true
            }
            
            $screen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
            $screen.OnEnter()
            
            $this.EventManager?.Publish("Navigation.ScreenChanged", @{ Screen = $screen; ScreenName = $screen.Name; StackDepth = $this.NavigationStack.Count })
            
            $global:TuiState.CurrentScreen = $screen
            $global:TuiState.Services.FocusManager?.ReleaseFocus()
            $global:TuiState.IsDirty = $true

        }
        catch {
            Write-Log -Level Error -Message "NavigationService: Failed to navigate to screen '$($screen.Name)': $($_.Exception.Message)" -Data $_
            throw
        }
    }

    [void] NavigateToByName([string]$screenName) {
        if (-not $this.ScreenRegistry.ContainsKey($screenName)) {
            throw [System.ArgumentException]::new("Screen '$screenName' not found in registry. Registered: $($this.ScreenRegistry.Keys -join ', ').", "screenName")
        }
        $this.NavigateTo($this.ScreenRegistry[$screenName])
    }
    
    [bool] CanGoBack() { return $this.NavigationStack.Count -gt 0 }
    
    [void] GoBack() {
        if (-not $this.CanGoBack()) { Write-Log -Level Warning -Message "NavigationService: Cannot go back - navigation stack is empty"; return }
        
        try {
            if ($this.CurrentScreen) {
                $this.CurrentScreen.OnExit(); $this.CurrentScreen.Cleanup()
            }
            
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            Write-Log -Level Debug -Message "NavigationService: Resuming screen '$($previousScreen.Name)'"
            
            $previousScreen.Resize($global:TuiState.BufferWidth, $global:TuiState.BufferHeight)
            $previousScreen.OnResume()
            
            $this.EventManager?.Publish("Navigation.BackNavigation", @{ Screen = $previousScreen; ScreenName = $previousScreen.Name; StackDepth = $this.NavigationStack.Count })
            
            $global:TuiState.CurrentScreen = $previousScreen
            $global:TuiState.Services.FocusManager?.ReleaseFocus()
            $global:TuiState.IsDirty = $true
        }
        catch {
            Write-Log -Level Error -Message "NavigationService: Failed to go back: $($_.Exception.Message)" -Data $_
            throw
        }
    }
    
    [void] Reset() {
        while ($this.NavigationStack.Count -gt 0) { $this.NavigationStack.Pop().Cleanup() }
        if ($this.CurrentScreen) { $this.CurrentScreen.OnExit(); $this.CurrentScreen.Cleanup(); $this.CurrentScreen = $null }
        Write-Log -Level Debug -Message "NavigationService: Reset complete, all screens cleaned up."
    }
}

#endregion
#<!-- END_PAGE: ASE.004 -->

#<!-- PAGE: ASE.005 - ThemeManager Class -->
#region ThemeManager Class

# ==============================================================================
# CLASS: ThemeManager
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   Manages the application's visual themes. It stores multiple themes as
#   hashtables of color definitions and provides a central point of access for
#   all UI components to retrieve theme-aware colors.
#
# KEY LOGIC:
#   - `InitializeThemes` defines the built-in themes (e.g., "Synthwave"). Each
#     theme is a hashtable mapping a semantic color name (e.g.,
#     "button.focused.bg") to a hex color string.
#   - `LoadTheme`: Switches the active theme.
#   - `GetColor`: The primary method used by components. It retrieves a color
#     from the current theme by its semantic name, ensuring a consistent look
#     and feel that can be changed globally.
# ==============================================================================
class ThemeManager {
    [hashtable]$CurrentTheme = @{}
    [string]$ThemeName = "Synthwave"
    [hashtable]$Themes = @{}
    
    ThemeManager() {
        $this.InitializeThemes()
        $this.LoadTheme($this.ThemeName)
    }
    
    [void] InitializeThemes() {
        # Synthwave Theme
        $this.Themes["Synthwave"] = @{ "Background"="#0a0e27";"Foreground"="#f92aad";"Subtle"="#72f1b8";"Primary"="#ff6ac1";"Accent"="#ffcc00";"Error"="#ff006e";"Warning"="#ffbe0b";"Success"="#3bf4fb";"Info"="#8338ec";"component.background"="#0a0e27";"component.border"="#f92aad";"component.title"="#ffcc00";"input.background"="#1a1e3a";"input.foreground"="#f92aad";"input.placeholder"="#72f1b8";"button.normal.fg"="#0a0e27";"button.normal.bg"="#f92aad";"button.focused.fg"="#0a0e27";"button.focused.bg"="#ff6ac1";"button.pressed.fg"="#0a0e27";"button.pressed.bg"="#ffcc00";"button.disabled.fg"="#555555";"button.disabled.bg"="#2a2e4a";"list.header.fg"="#ffcc00";"list.header.bg"="#1a1e3a";"list.item.normal"="#f92aad";"list.item.selected"="#0a0e27";"list.item.selected.background"="#ff6ac1";"list.scrollbar"="#72f1b8" }
        # Aurora Theme
        $this.Themes["Aurora"] = @{ "Background"="#011627";"Foreground"="#d6deeb";"Subtle"="#7fdbca";"Primary"="#82aaff";"Accent"="#21c7a8";"Error"="#ef5350";"Warning"="#ffeb95";"Success"="#22da6e";"Info"="#82aaff";"component.background"="#011627";"component.border"="#5f7e97";"component.title"="#21c7a8";"input.background"="#0e293f";"input.foreground"="#d6deeb";"input.placeholder"="#637777";"button.normal.fg"="#011627";"button.normal.bg"="#82aaff";"button.focused.fg"="#011627";"button.focused.bg"="#21c7a8";"button.pressed.fg"="#011627";"button.pressed.bg"="#c792ea";"button.disabled.fg"="#444444";"button.disabled.bg"="#1d3b53";"list.header.fg"="#21c7a8";"list.header.bg"="#0e293f";"list.item.normal"="#d6deeb";"list.item.selected"="#011627";"list.item.selected.background"="#82aaff";"list.scrollbar"="#5f7e97" }
        # Forest Theme
        $this.Themes["Forest"] = @{ "Background"="#0d1117";"Foreground"="#c9d1d9";"Subtle"="#8b949e";"Primary"="#58a6ff";"Accent"="#56d364";"Error"="#f85149";"Warning"="#f0883e";"Success"="#56d364";"Info"="#58a6ff";"component.background"="#0d1117";"component.border"="#30363d";"component.title"="#56d364";"input.background"="#161b22";"input.foreground"="#c9d1d9";"input.placeholder"="#484f58";"button.normal.fg"="#0d1117";"button.normal.bg"="#58a6ff";"button.focused.fg"="#0d1117";"button.focused.bg"="#56d364";"button.pressed.fg"="#0d1117";"button.pressed.bg"="#d29922";"button.disabled.fg"="#484f58";"button.disabled.bg"="#21262d";"list.header.fg"="#56d364";"list.header.bg"="#161b22";"list.item.normal"="#c9d1d9";"list.item.selected"="#0d1117";"list.item.selected.background"="#58a6ff";"list.scrollbar"="#8b949e" }
    }
    
    [void] LoadTheme([string]$themeName) {
        if ($this.Themes.ContainsKey($themeName)) {
            $this.CurrentTheme = $this.Themes[$themeName].Clone()
            $this.ThemeName = $themeName
        }
    }
    
    [string] GetColor([string]$colorName, [string]$defaultColor = "#808080") {
        return $this.CurrentTheme[$colorName] ?? $defaultColor
    }
    
    [string[]] GetAvailableThemes() { return @($this.Themes.Keys | Sort-Object) }
}

#endregion
#<!-- END_PAGE: ASE.005 -->

#<!-- PAGE: ASE.006 - Logger Class -->
#region Logger Class

# ==============================================================================
# CLASS: Logger
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   Provides a robust, application-wide logging service. All diagnostic
#   messages from the framework should be routed through this service.
#
# KEY LOGIC:
#   - `Log`: The primary method. It checks the message's level against the
#     `MinimumLevel` before processing. It creates a structured log entry
#     (hashtable) with a timestamp, level, message, and thread ID.
#   - `LogQueue`: A `System.Collections.Queue` is used to batch log messages
#     in memory before writing them to a file.
#   - `Flush`: Writes the contents of the queue to the specified log file. This
#     is called automatically when the queue is full or manually on cleanup.
# ==============================================================================
class Logger {
    [string]$LogPath
    [System.Collections.Queue]$LogQueue
    [int]$MaxQueueSize = 1000
    [bool]$EnableFileLogging = $true
    [bool]$EnableConsoleLogging = $false
    [string]$MinimumLevel = "Info"
    [hashtable]$LevelPriority = @{ 'Trace' = 0; 'Debug' = 1; 'Info' = 2; 'Warning' = 3; 'Error' = 4; 'Fatal' = 5 }
    
    Logger([string]$logPath) {
        $this.LogPath = $logPath
        $this.LogQueue = [System.Collections.Queue]::new()
        $logDir = Split-Path -Parent $this.LogPath
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    }
    
    [void] Log([string]$level, [string]$message, [object]$Data = $null) {
        if ($this.LevelPriority[$level] -lt $this.LevelPriority[$this.MinimumLevel]) { return }
        $finalMessage = if($Data) { "$message | Data: $($Data | ConvertTo-Json -Compress -Depth 5)" } else { $message }
        $logEntry = @{ Timestamp = [DateTime]::Now; Level = $level; Message = $finalMessage; ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId }
        $this.LogQueue.Enqueue($logEntry)
        if ($this.LogQueue.Count -ge $this.MaxQueueSize) { $this.Flush() }
        if ($this.EnableConsoleLogging) { $this._WriteToConsole($logEntry) }
    }
    
    [void] Flush() {
        if ($this.LogQueue.Count -eq 0 -or -not $this.EnableFileLogging) { return }
        try {
            $logContent = [System.Text.StringBuilder]::new()
            while ($this.LogQueue.Count -gt 0) {
                $entry = $this.LogQueue.Dequeue()
                $logLine = "$($entry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss.fff')) [$($entry.Level.ToUpper().PadRight(7))] [T$($entry.ThreadId)] $($entry.Message)"
                [void]$logContent.AppendLine($logLine)
            }
            if ($logContent.Length -gt 0) { Add-Content -Path $this.LogPath -Value $logContent.ToString() -NoNewline }
        }
        catch { Write-Warning "Logger: Failed to flush logs: $_" }
    }
    
    hidden [void] _WriteToConsole([hashtable]$logEntry) {
        # This is for debug purposes and should not be used in the final TUI
    }
    
    [void] Cleanup() { $this.Flush() }
}

#endregion
#<!-- END_PAGE: ASE.006 -->

#<!-- PAGE: ASE.007 - EventManager Class -->
#region EventManager Class

# ==============================================================================
# CLASS: EventManager
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   - None
#
# PURPOSE:
#   Implements a publish-subscribe pattern to allow for decoupled communication
#   between different parts of the framework. This prevents components from
#   needing direct references to each other.
#
# KEY LOGIC:
#   - `Subscribe`: Adds a scriptblock (handler) to a list of handlers for a
#     named event. Returns a unique handler ID for unsubscribing.
#   - `Publish`: Given an event name, it iterates through all subscribed
#     handlers for that event and invokes them, passing along event data.
#   - `Unsubscribe`: Removes a specific handler from an event's subscription list.
# ==============================================================================
class EventManager {
    [hashtable]$EventHandlers = @{}
    [int]$NextHandlerId = 1
    
    EventManager() {
        Write-Log -Level Debug -Message "EventManager: Initialized"
    }
    
    [string] Subscribe([string]$eventName, [scriptblock]$handler) {
        if ([string]::IsNullOrWhiteSpace($eventName)) { throw [ArgumentException]::new("Event name cannot be null or empty") }
        if (-not $handler) { throw [ArgumentNullException]::new("handler") }
        
        if (-not $this.EventHandlers.ContainsKey($eventName)) { $this.EventHandlers[$eventName] = @{} }
        $handlerId = "handler_$($this.NextHandlerId++)"
        $this.EventHandlers[$eventName][$handlerId] = @{ Handler = $handler; SubscribedAt = [DateTime]::Now }
        Write-Log -Level Debug -Message "EventManager: Subscribed handler '$handlerId' to event '$eventName'"
        return $handlerId
    }
    
    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers[$eventName]?.ContainsKey($handlerId)) {
            $this.EventHandlers[$eventName].Remove($handlerId)
            if ($this.EventHandlers[$eventName].Count -eq 0) { $this.EventHandlers.Remove($eventName) }
            Write-Log -Level Debug -Message "EventManager: Unsubscribed handler '$handlerId' from event '$eventName'"
        }
    }
    
    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            $handlers = @($this.EventHandlers[$eventName].GetEnumerator())
            Write-Log -Level Debug -Message "EventManager: Publishing event '$eventName' to $($handlers.Count) handlers."
            foreach ($entry in $handlers) {
                try { & $entry.Value.Handler $eventData }
                catch { Write-Log -Level Error -Message "EventManager: Error in handler '$($entry.Key)' for event '$eventName': $($_.Exception.Message)" -Data $_ }
            }
        }
    }
}

#endregion
#<!-- END_PAGE: ASE.007 -->

#<!-- PAGE: ASE.008 - TuiFrameworkService Class -->
#region TuiFrameworkService Class

# ===== CLASS: TuiFrameworkService =====
# Module: tui-framework (from axiom)
# Dependencies: None
# Purpose: Framework utilities and async operations
class TuiFrameworkService {
    [hashtable]$AsyncJobs = @{}
    [int]$NextJobId = 1
    
    TuiFrameworkService() {}
}

#endregion
#<!-- END_PAGE: ASE.008 -->

#<!-- PAGE: ASE.009 - FocusManager Class -->
#region Additional Service Classes

# ==============================================================================
# CLASS: FocusManager
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - UIElement (ABC.004)
#   Services:
#     - EventManager (ASE.007) (optional)
#
# PURPOSE:
#   Provides a centralized, authoritative source for which UI component has
#   input focus. This is critical for routing keyboard input correctly.
#
# KEY LOGIC:
#   - `SetFocus`: The core method. It correctly blurs the previously focused
#     component (setting `IsFocused` to false and calling `OnBlur`) before
#     focusing the new component (setting `IsFocused` to true and calling `OnFocus`).
#   - `MoveFocus`: Implements Tab and Shift+Tab navigation. It queries the
#     current screen for all focusable children, sorts them by TabIndex/position,
#     and calls `SetFocus` on the next or previous one in the sequence.
#   - `ReleaseFocus`: A convenience method to blur the current component without
#     focusing a new one.
# ==============================================================================
class FocusManager {
    [UIElement]$FocusedComponent = $null
    [EventManager]$EventManager = $null

    FocusManager([EventManager]$eventManager = $null) {
        $this.EventManager = $eventManager
    }

    [void] SetFocus([UIElement]$component) {
        if ($this.FocusedComponent -eq $component) { return }
        
        if ($this.FocusedComponent) {
            $this.FocusedComponent.IsFocused = $false
            $this.FocusedComponent.OnBlur()
            $this.FocusedComponent.RequestRedraw()
            Write-Log -Level Debug -Message "FocusManager: Blurred '$($this.FocusedComponent.Name)'."
        }

        $this.FocusedComponent = $null
        if ($component -and $component.IsFocusable -and $component.Enabled -and $component.Visible) {
            $this.FocusedComponent = $component
            $component.IsFocused = $true
            $component.OnFocus()
            $component.RequestRedraw()
            Write-Log -Level Debug -Message "FocusManager: Focused '$($component.Name)'."
            $this.EventManager?.Publish("Focus.Changed", @{ ComponentName = $component.Name; Component = $component })
        }
        $global:TuiState.IsDirty = $true
    }

    [void] MoveFocus([bool]$reverse = $false) {
        if (-not $global:TuiState.CurrentScreen) { return }

        $focusableComponents = [System.Collections.Generic.List[UIElement]]::new()
        $this._FindFocusableRecursive($global:TuiState.CurrentScreen, $focusableComponents)
        
        if ($focusableComponents.Count -eq 0) { $this.SetFocus($null); return }
        
        $sorted = $focusableComponents | Sort-Object { $_.TabIndex * 10000 + $_.Y * 100 + $_.X }
        $currentIndex = if ($this.FocusedComponent) { $sorted.IndexOf($this.FocusedComponent) } else { -1 }
        
        $nextIndex = if ($currentIndex -eq -1) {
            if ($reverse) { $sorted.Count - 1 } else { 0 }
        } else {
            ($currentIndex + ($if ($reverse) { -1 } else { 1 }) + $sorted.Count) % $sorted.Count
        }
        
        $this.SetFocus($sorted[$nextIndex])
    }

    hidden [void] _FindFocusableRecursive([UIElement]$component, [System.Collections.Generic.List[UIElement]]$list) {
        if ($component -and $component.IsFocusable -and $component.Visible -and $component.Enabled) { $list.Add($component) }
        foreach ($child in $component.Children) { $this._FindFocusableRecursive($child, $list) }
    }

    [void] ReleaseFocus() { $this.SetFocus($null) }
    [void] Cleanup() { $this.FocusedComponent = $null }
}

# ==============================================================================
# CLASS: DialogManager
#
# INHERITS:
#   - None
#
# DEPENDENCIES:
#   Classes:
#     - UIElement (ABC.004)
#   Services:
#     - EventManager (ASE.007)
#     - FocusManager (ASE.009)
#
# PURPOSE:
#   Manages the lifecycle of modal dialogs and other overlays. It ensures that
#   dialogs are rendered on top of other content and that input focus is
#   handled correctly.
#
# KEY LOGIC:
#   - `ShowDialog`: Positions the dialog, adds it to the global `OverlayStack`
#     for rendering, and crucially, tells the `FocusManager` to set focus to
#     the dialog's first focusable child. It also saves the previously focused
#     component.
#   - `HideDialog`: Removes the dialog from the `OverlayStack`, calls its
#     `Cleanup` method, and tells `FocusManager` to restore focus to the
#     component that was focused before the dialog appeared.
# ==============================================================================
class DialogManager {
    hidden [System.Collections.Generic.List[UIElement]] $_activeDialogs = [System.Collections.Generic.List[UIElement]]::new()
    [EventManager]$EventManager
    [FocusManager]$FocusManager

    DialogManager([EventManager]$eventManager, [FocusManager]$focusManager) {
        $this.EventManager = $eventManager
        $this.FocusManager = $focusManager
    }

    [void] ShowDialog([UIElement]$dialog) {
        if (-not $dialog) { throw [System.ArgumentNullException]::new("dialog") }
        
        $dialog.X = [Math]::Max(0, [Math]::Floor(($global:TuiState.BufferWidth - $dialog.Width) / 2))
        $dialog.Y = [Math]::Max(0, [Math]::Floor(($global:TuiState.BufferHeight - $dialog.Height) / 2))

        $dialog.Metadata.PreviousFocus = $this.FocusManager?.FocusedComponent
        $this.FocusManager?.ReleaseFocus()

        $this._activeDialogs.Add($dialog)
        $dialog.Visible = $true
        $dialog.IsOverlay = $true
        $global:TuiState.OverlayStack.Add($dialog)
        
        if ($dialog.PSObject.Methods['Initialize'] -and -not $dialog._isInitialized) {
            $dialog.Initialize(); $dialog._isInitialized = $true
        }
        if ($dialog.PSObject.Methods['OnEnter']) { $dialog.OnEnter() }

        $dialog.RequestRedraw()
        Write-Log -Level Info -Message "DialogManager: Showing dialog '$($dialog.Name)' at X=$($dialog.X), Y=$($dialog.Y)."
        
        if ($dialog.PSObject.Methods['SetInitialFocus']) { $dialog.SetInitialFocus() }
        else { $this.FocusManager?.SetFocus($dialog) }
    }

    [void] HideDialog([UIElement]$dialog) {
        if (-not $dialog) { return }

        if ($this._activeDialogs.Remove($dialog)) {
            $dialog.Visible = $false; $dialog.IsOverlay = $false
            if ($global:TuiState.OverlayStack.Contains($dialog)) { $global:TuiState.OverlayStack.Remove($dialog) }
            $dialog.Cleanup()

            $this.FocusManager?.SetFocus($dialog.Metadata.PreviousFocus)
            $dialog.RequestRedraw()
            Write-Log -Level Info -Message "DialogManager: Hiding dialog '$($dialog.Name)'."
        }
    }

    [void] Cleanup() {
        foreach ($dialog in $this._activeDialogs.ToArray()) { $this.HideDialog($dialog) }
        $this._activeDialogs.Clear()
    }
}

#endregion
#<!-- END_PAGE: ASE.009 -->