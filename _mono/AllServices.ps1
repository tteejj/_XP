# ==============================================================================
# Axiom-Phoenix v4.0 - All Services
# Core application services
# ==============================================================================

#region ActionService

class ActionService {
    [hashtable] $ActionRegistry = @{}
    [hashtable] $EventSubscriptions = @{} 

    ActionService() {
        Write-Verbose "ActionService: Constructor called."
        $this.RegisterAction(
            "app.exit", 
            "Exits the PMC Terminal application.", 
            {
                Publish-Event -EventName "Application.Exit" -Data @{ Source = "ActionService"; Action = "AppExit" }
            }, 
            "Application", 
            $true
        )
        $this.RegisterAction(
            "app.help", 
            "Displays application help.", 
            {
                Publish-Event -EventName "App.HelpRequested" -Data @{ Source = "ActionService"; Action = "Help" }
            }, 
            "Application", 
            $true
        )
    }

    [void] RegisterAction([string]$name, [string]$description, [scriptblock]$scriptBlock, [string]$category = "General", [bool]$Force = $false) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ([string]::IsNullOrWhiteSpace($description)) { throw [System.ArgumentException]::new("Parameter 'description' cannot be null or empty.") }
        if ($null -eq $scriptBlock) { throw [System.ArgumentNullException]::new("scriptBlock") }

        if ($this.ActionRegistry.ContainsKey($name) -and -not $Force) {
            Write-Warning "Action '$name' already registered. Use -Force to overwrite."
            return
        }

        $this.ActionRegistry[$name] = @{
            Name = $name
            Description = $description
            ScriptBlock = $scriptBlock
            Category = $category
            RegisteredAt = (Get-Date)
        }
        Write-Verbose "ActionService: Action '$name' registered."
    }

    [void] UnregisterAction([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if ($this.ActionRegistry.ContainsKey($name)) {
            $this.ActionRegistry.Remove($name)
            Write-Verbose "ActionService: Action '$name' unregistered."
        }
    }

    [void] ExecuteAction([string]$name, [hashtable]$parameters = @{}) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        if (-not $this.ActionRegistry.ContainsKey($name)) {
            throw [System.ArgumentException]::new("Unknown action: $name", "name")
        }

        $action = $this.ActionRegistry[$name]
        Write-Verbose "ActionService: Executing action '$name'."

        try {
            & $action.ScriptBlock -ActionParameters $parameters
        } catch {
            Write-Error "Action '$name' failed: $($_.Exception.Message)"
            throw
        }
    }

    [hashtable] GetAction([string]$name) {
        if ([string]::IsNullOrWhiteSpace($name)) { throw [System.ArgumentException]::new("Parameter 'name' cannot be null or empty.") }
        return $this.ActionRegistry[$name]
    }

    [System.Collections.Generic.List[hashtable]] GetAllActions() {
        return @($this.ActionRegistry.Values | Where-Object { $_ -ne $null } | Sort-Object Name)
    }

    [void] Cleanup() {
        $this.ActionRegistry.Clear()
        Write-Verbose "ActionService: Cleaned up."
    }
}

#endregion

#region KeybindingService

class KeybindingService {
    [hashtable] $KeyMap = @{}
    [hashtable] $GlobalHandlers = @{}
    [System.Collections.Generic.List[string]] $ContextStack
    [bool] $EnableChords = $false

    KeybindingService() {
        $this.ContextStack = [System.Collections.Generic.List[string]]::new()
        $this.InitializeDefaultBindings()
        Write-Verbose "KeybindingService initialized"
    }

    hidden [void] InitializeDefaultBindings() {
        $this.KeyMap = @{
            "app.exit" = @{ Key = [System.ConsoleKey]::Q; Modifiers = @("Ctrl") }
            "app.help" = @{ Key = [System.ConsoleKey]::F1; Modifiers = @() }
            "app.showCommandPalette" = @{ Key = [System.ConsoleKey]::P; Modifiers = @("Ctrl") }
            "nav.back" = @{ Key = [System.ConsoleKey]::Escape; Modifiers = @() }
            "nav.up" = @{ Key = [System.ConsoleKey]::UpArrow; Modifiers = @() }
            "nav.down" = @{ Key = [System.ConsoleKey]::DownArrow; Modifiers = @() }
            "nav.left" = @{ Key = [System.ConsoleKey]::LeftArrow; Modifiers = @() }
            "nav.right" = @{ Key = [System.ConsoleKey]::RightArrow; Modifiers = @() }
            "nav.select" = @{ Key = [System.ConsoleKey]::Enter; Modifiers = @() }
            "nav.pageup" = @{ Key = [System.ConsoleKey]::PageUp; Modifiers = @() }
            "nav.pagedown" = @{ Key = [System.ConsoleKey]::PageDown; Modifiers = @() }
            "nav.home" = @{ Key = [System.ConsoleKey]::Home; Modifiers = @() }
            "nav.end" = @{ Key = [System.ConsoleKey]::End; Modifiers = @() }
            "nav.tab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @() }
            "nav.shifttab" = @{ Key = [System.ConsoleKey]::Tab; Modifiers = @("Shift") }
        }
    }

    [void] SetBinding([string]$actionName, [object]$key, [string[]]$modifiers) {
        if ([string]::IsNullOrWhiteSpace($actionName)) {
            throw [System.ArgumentException]::new("Action name cannot be null or empty", "actionName")
        }
        if ($null -eq $key) {
            throw [System.ArgumentNullException]::new("key", "Key cannot be null")
        }

        $binding = @{
            Modifiers = if ($modifiers) { @($modifiers) } else { @() }
        }

        if ($key -is [System.ConsoleKey]) {
            $binding.Key = $key
        } elseif ($key -is [char]) {
            $binding.KeyChar = $key
        } else {
            try {
                $binding.Key = [System.ConsoleKey]::$key
            } catch {
                throw [System.ArgumentException]::new("Invalid key: '$key'")
            }
        }

        $this.KeyMap[$actionName.ToLower()] = $binding
        Write-Verbose "Set keybinding: $actionName"
    }

    [bool] IsAction([string]$actionName, [System.ConsoleKeyInfo]$keyInfo) {
        if ([string]::IsNullOrWhiteSpace($actionName)) { return $false }

        $normalizedName = $actionName.ToLower()
        if (-not $this.KeyMap.ContainsKey($normalizedName)) { return $false }

        $binding = $this.KeyMap[$normalizedName]
        
        $keyMatches = $false
        if ($binding.ContainsKey('KeyChar') -and $keyInfo.KeyChar -eq $binding.KeyChar) {
            $keyMatches = $true
        } elseif ($binding.ContainsKey('Key') -and $keyInfo.Key -eq $binding.Key) {
            $keyMatches = $true
        }
        
        if (-not $keyMatches) { return $false }

        $hasCtrl = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Control) -ne 0
        $hasAlt = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Alt) -ne 0
        $hasShift = ($keyInfo.Modifiers -band [System.ConsoleModifiers]::Shift) -ne 0

        $expectedCtrl = $binding.Modifiers -contains "Ctrl"
        $expectedAlt = $binding.Modifiers -contains "Alt"
        $expectedShift = $binding.Modifiers -contains "Shift"

        return ($hasCtrl -eq $expectedCtrl) -and ($hasAlt -eq $expectedAlt) -and ($hasShift -eq $expectedShift)
    }

    [string] GetAction([System.ConsoleKeyInfo]$keyInfo) {
        foreach ($actionName in $this.KeyMap.Keys) {
            if ($this.IsAction($actionName, $keyInfo)) {
                return $actionName
            }
        }
        return $null
    }

    [string] GetBindingDescription([string]$actionName) {
        if ([string]::IsNullOrWhiteSpace($actionName)) { return $null }

        $normalizedName = $actionName.ToLower()
        if (-not $this.KeyMap.ContainsKey($normalizedName)) { return "Unbound" }

        $binding = $this.KeyMap[$normalizedName]
        $keyStr = ""
        if ($binding.ContainsKey('KeyChar')) {
            $keyStr = $binding.KeyChar.ToString().ToUpper()
        } elseif ($binding.ContainsKey('Key')) {
            $keyStr = $binding.Key.ToString()
        }

        if ($binding.Modifiers.Count -gt 0) {
            return "$($binding.Modifiers -join '+') + $keyStr"
        }

        return $keyStr
    }
}

#endregion

#region DataManager

class DataManager {
    [System.Collections.Generic.List[PmcTask]] $Tasks
    [System.Collections.Generic.List[PmcProject]] $Projects
    [string] $DataPath

    DataManager() {
        $this.Tasks = [System.Collections.Generic.List[PmcTask]]::new()
        $this.Projects = [System.Collections.Generic.List[PmcProject]]::new()
        $this.DataPath = Join-Path $env:APPDATA "AxiomPhoenix"
        
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        
        $this.LoadData()
    }

    [void] LoadData() {
        $tasksFile = Join-Path $this.DataPath "tasks.json"
        $projectsFile = Join-Path $this.DataPath "projects.json"
        
        if (Test-Path $tasksFile) {
            try {
                $taskData = Get-Content $tasksFile -Raw | ConvertFrom-Json
                foreach ($t in $taskData) {
                    $task = [PmcTask]::new()
                    $task.Id = $t.Id
                    $task.Title = $t.Title
                    $task.Description = $t.Description
                    $task.Status = [TaskStatus]$t.Status
                    $task.Priority = [TaskPriority]$t.Priority
                    $task.ProjectKey = $t.ProjectKey
                    $task.Progress = $t.Progress
                    $task.Completed = $t.Completed
                    if ($t.DueDate) { $task.DueDate = [datetime]$t.DueDate }
                    $task.Tags = $t.Tags
                    $this.Tasks.Add($task)
                }
            } catch {
                Write-Warning "Failed to load tasks: $($_.Exception.Message)"
            }
        }
        
        if (Test-Path $projectsFile) {
            try {
                $projectData = Get-Content $projectsFile -Raw | ConvertFrom-Json
                foreach ($p in $projectData) {
                    $project = [PmcProject]::new($p.Key, $p.Name, $p.Description, $p.Owner)
                    $project.IsActive = $p.IsActive
                    $project.Tags = $p.Tags
                    $this.Projects.Add($project)
                }
            } catch {
                Write-Warning "Failed to load projects: $($_.Exception.Message)"
            }
        }
    }

    [void] SaveData() {
        try {
            $tasksFile = Join-Path $this.DataPath "tasks.json"
            $projectsFile = Join-Path $this.DataPath "projects.json"
            
            $this.Tasks | ConvertTo-Json -Depth 10 | Out-File $tasksFile -Encoding UTF8
            $this.Projects | ConvertTo-Json -Depth 10 | Out-File $projectsFile -Encoding UTF8
        } catch {
            Write-Error "Failed to save data: $($_.Exception.Message)"
        }
    }

    [PmcTask[]] GetTasks() {
        return $this.Tasks.ToArray()
    }

    [PmcTask] GetTask([string]$id) {
        return $this.Tasks | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    }

    [void] AddTask([PmcTask]$task) {
        if ($null -eq $task) { throw [System.ArgumentNullException]::new("task") }
        $this.Tasks.Add($task)
        $this.SaveData()
        Publish-Event -EventName "Tasks.Changed" -EventData @{ Action = "Added"; Task = $task }
    }

    [void] UpdateTask([PmcTask]$task) {
        if ($null -eq $task) { throw [System.ArgumentNullException]::new("task") }
        $existingIndex = $this.Tasks.FindIndex({ param($t) $t.Id -eq $task.Id })
        if ($existingIndex -ge 0) {
            $this.Tasks[$existingIndex] = $task
            $this.SaveData()
            Publish-Event -EventName "Tasks.Changed" -EventData @{ Action = "Updated"; Task = $task }
        }
    }

    [void] DeleteTask([string]$id) {
        $task = $this.GetTask($id)
        if ($task) {
            $this.Tasks.Remove($task)
            $this.SaveData()
            Publish-Event -EventName "Tasks.Changed" -EventData @{ Action = "Deleted"; TaskId = $id }
        }
    }

    [PmcProject[]] GetProjects() {
        return $this.Projects.ToArray()
    }

    [void] AddProject([PmcProject]$project) {
        if ($null -eq $project) { throw [System.ArgumentNullException]::new("project") }
        $this.Projects.Add($project)
        $this.SaveData()
    }
}

#endregion

#region NavigationService

class NavigationService {
    [System.Collections.Stack] $NavigationStack
    [string] $CurrentScreen

    NavigationService() {
        $this.NavigationStack = [System.Collections.Stack]::new()
        Write-Verbose "NavigationService initialized"
    }

    [void] NavigateTo([string]$screenName) {
        if ([string]::IsNullOrWhiteSpace($screenName)) {
            throw [System.ArgumentException]::new("Screen name cannot be null or empty", "screenName")
        }
        
        if ($this.CurrentScreen) {
            $this.NavigationStack.Push($this.CurrentScreen)
        }
        
        $this.CurrentScreen = $screenName
        Publish-Event -EventName "Navigation.ScreenChanged" -EventData @{ 
            Screen = $screenName
            PreviousScreen = if ($this.NavigationStack.Count -gt 0) { $this.NavigationStack.Peek() } else { $null }
        }
        Write-Verbose "Navigated to screen: $screenName"
    }

    [bool] CanGoBack() {
        return $this.NavigationStack.Count -gt 0
    }

    [void] GoBack() {
        if ($this.CanGoBack()) {
            $previousScreen = $this.NavigationStack.Pop()
            $this.CurrentScreen = $previousScreen
            Publish-Event -EventName "Navigation.ScreenChanged" -EventData @{
                Screen = $previousScreen
                IsBack = $true
            }
            Write-Verbose "Navigated back to: $previousScreen"
        }
    }

    [void] Reset() {
        $this.NavigationStack.Clear()
        $this.CurrentScreen = $null
        Write-Verbose "Navigation stack reset"
    }
}

#endregion

#region ThemeManager

class ThemeManager {
    [hashtable] $CurrentTheme
    [string] $ThemeName

    ThemeManager() {
        $this.LoadDefaultTheme()
    }

    [void] LoadDefaultTheme() {
        $this.ThemeName = "Default"
        $this.CurrentTheme = @{
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
            'button.normal.background' = [ConsoleColor]::Black
            'button.normal.foreground' = [ConsoleColor]::White
            'button.normal.border' = [ConsoleColor]::Gray
            'button.focus.background' = [ConsoleColor]::Black
            'button.focus.foreground' = [ConsoleColor]::White
            'button.focus.border' = [ConsoleColor]::Cyan
            'button.pressed.background' = [ConsoleColor]::DarkGray
            'button.pressed.foreground' = [ConsoleColor]::Black
            'button.pressed.border' = [ConsoleColor]::Cyan
        }
    }

    [object] GetColor([string]$colorName) {
        if ($this.CurrentTheme.ContainsKey($colorName)) {
            return $this.CurrentTheme[$colorName]
        }
        return [ConsoleColor]::White
    }

    [void] SetColor([string]$colorName, $color) {
        $this.CurrentTheme[$colorName] = $color
        Publish-Event -EventName "Theme.Changed" -EventData @{ ColorName = $colorName; Color = $color }
    }
}

#endregion

#region Logger

class Logger {
    [string] $LogPath
    [System.Collections.Generic.Queue[string]] $LogQueue

    Logger() {
        $this.LogPath = Join-Path $env:TEMP "AxiomPhoenix.log"
        $this.LogQueue = [System.Collections.Generic.Queue[string]]::new()
    }

    [void] Log([string]$level, [string]$message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$level] $message"
        
        $this.LogQueue.Enqueue($logEntry)
        
        if ($this.LogQueue.Count -gt 1000) {
            $this.Flush()
        }
    }

    [void] Flush() {
        if ($this.LogQueue.Count -eq 0) { return }
        
        try {
            $entries = @()
            while ($this.LogQueue.Count -gt 0) {
                $entries += $this.LogQueue.Dequeue()
            }
            $entries | Add-Content -Path $this.LogPath -Encoding UTF8
        } catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}

#endregion

#region EventManager

class EventManager {
    [hashtable] $EventHandlers
    [int] $NextHandlerId

    EventManager() {
        $this.EventHandlers = @{}
        $this.NextHandlerId = 1
    }

    [string] Subscribe([string]$eventName, [scriptblock]$handler) {
        if ([string]::IsNullOrWhiteSpace($eventName)) {
            throw [System.ArgumentException]::new("Event name cannot be null or empty", "eventName")
        }
        if ($null -eq $handler) {
            throw [System.ArgumentNullException]::new("handler")
        }

        if (-not $this.EventHandlers.ContainsKey($eventName)) {
            $this.EventHandlers[$eventName] = @{}
        }

        $handlerId = "handler_$($this.NextHandlerId)"
        $this.NextHandlerId++
        
        $this.EventHandlers[$eventName][$handlerId] = $handler
        Write-Verbose "Subscribed to event '$eventName' with handler ID: $handlerId"
        
        return $handlerId
    }

    [void] Unsubscribe([string]$eventName, [string]$handlerId) {
        if ($this.EventHandlers.ContainsKey($eventName)) {
            if ($this.EventHandlers[$eventName].ContainsKey($handlerId)) {
                $this.EventHandlers[$eventName].Remove($handlerId)
                Write-Verbose "Unsubscribed handler '$handlerId' from event '$eventName'"
            }
        }
    }

    [void] Publish([string]$eventName, [hashtable]$eventData = @{}) {
        if (-not $this.EventHandlers.ContainsKey($eventName)) {
            Write-Verbose "No handlers for event: $eventName"
            return
        }

        foreach ($handler in $this.EventHandlers[$eventName].Values) {
            try {
                & $handler -EventData $eventData
            } catch {
                Write-Error "Event handler failed for '$eventName': $($_.Exception.Message)"
            }
        }
    }
}

#endregion
