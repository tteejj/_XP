# ==============================================================================
# Axiom-Phoenix v4.0 - Task List Screen
# A dynamic, action-driven, and theme-aware task management screen.
# ==============================================================================

#using module ui-classes
#using module panels-class
#using module theme-manager
#using module logger
#using module tui-components
#using module models
#using module advanced-data-components

class TaskListScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_headerPanel
    hidden [Panel] $_tablePanel
    hidden [Panel] $_footerPanel
    hidden [Table] $_taskTable
    #endregion

    #region State
    hidden [string] $_filterStatus = "All"
    hidden [PmcTask] $_selectedTask
    #endregion

    # Constructor is minimal, only calling its base.
    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    # OnInitialize creates the UI, registers context-specific actions, and subscribes to events.
    [void] OnInitialize() {
        # --- UI Construction ---
        $this._mainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "Task Management")
        $this.AddChild($this._mainPanel)

        $this._headerPanel = [Panel]::new(1, 1, $this.Width - 2, 1)
        $this._headerPanel.HasBorder = $false
        $this._mainPanel.AddChild($this._headerPanel)

        # The main panel for the table, which gives it a border.
        $this._tablePanel = [Panel]::new(1, 2, $this.Width - 2, $this.Height - 4)
        $this._mainPanel.AddChild($this._tablePanel)
        
        $this._footerPanel = [Panel]::new(1, $this.Height - 2, $this.Width - 2, 1)
        $this._footerPanel.HasBorder = $false
        $this._mainPanel.AddChild($this._footerPanel)

        # --- Table Setup ---
        $this._taskTable = [Table]::new("TaskTable")
        $this._taskTable.Move(0,0)
        $this._taskTable.Resize($this._tablePanel.ContentWidth, $this._tablePanel.ContentHeight)
        $this._taskTable.ShowBorder = $false
        $this._taskTable.SetColumns(@(
            [TableColumn]::new('Title', 'Task Title', 'Auto'),
            [TableColumn]::new('Status', 'Status', 15),
            [TableColumn]::new('Priority', 'Priority', 12)
        ))
        # When the table selection changes, update our local state.
        $this._taskTable.OnSelectionChanged = { param($SelectedItem) $this._selectedTask = $SelectedItem }.GetNewClosure()
        $this._tablePanel.AddChild($this._taskTable)

        # --- Register Actions & Keybindings for THIS screen's context ---
        $this._RegisterActions()
        
        # --- Subscribe to global events ---
        $this.SubscribeToEvent("Tasks.Changed", { $this._RefreshData() })
    }

    # OnEnter/OnExit manage the keybinding context for this screen.
    [void] OnEnter() {
        $keybindingService = $this.ServiceContainer.GetService('KeybindingService')
        $keybindingService.PushContext('tasklist')
        $this._RefreshData()
        Set-ComponentFocus -Component $this._taskTable
    }

    [void] OnExit() {
        $keybindingService = $this.ServiceContainer.GetService('KeybindingService')
        $keybindingService.PopContext()
    }

    # Registers all actions and keybindings specific to this screen.
    hidden [void] _RegisterActions() {
        $actionService = $this.ServiceContainer.GetService('ActionService')
        $keybindingService = $this.ServiceContainer.GetService('KeybindingService')
        $context = 'tasklist' # Define the context for these actions/bindings

        # A helper closure to ensure an action isn't run if no task is selected.
        $withSelectedTask = {
            param($scriptblock)
            if ($this._selectedTask) { . $scriptblock $this._selectedTask }
            else { Show-AlertDialog -Title 'No Task Selected' -Message 'Please select a task first.' | Out-Null }
        }

        # New Task
        $actionService.RegisterAction("task.new", "Create a new task", { $this._ShowNewTaskDialog() }, "Tasks")
        $keybindingService.SetBinding("task.new", 'N', $context)

        # Edit Task
        $actionService.RegisterAction("task.edit", "Edit selected task", { . $withSelectedTask { param($task) $this._ShowEditTaskDialog($task) } }, "Tasks")
        $keybindingService.SetBinding("task.edit", 'E', $context)
        
        # Delete Task
        $actionService.RegisterAction("task.delete", "Delete selected task", { . $withSelectedTask { param($task) $this._ShowDeleteConfirmDialog($task) } }, "Tasks")
        $keybindingService.SetBinding("task.delete", 'Delete', $context)

        # Toggle Task Status
        $actionService.RegisterAction("task.toggleStatus", "Toggle task status", { . $withSelectedTask { param($task) $this._ToggleTaskStatus($task) } }, "Tasks")
        $keybindingService.SetBinding("task.toggleStatus", 'Spacebar', $context)

        # Cycle Filter
        $actionService.RegisterAction("task.cycleFilter", "Cycle task filter", { $this._CycleFilter() }, "Tasks")
        $keybindingService.SetBinding("task.cycleFilter", 'F', $context)

        # Navigate Back
        $actionService.RegisterAction("task.back", "Return to dashboard", { $this.ServiceContainer.GetService('NavigationService').PopScreen() }, "Navigation")
        $keybindingService.SetBinding("task.back", 'Escape', $context)
    }

    # Fetches tasks, applies filters, and updates the table and display.
    hidden [void] _RefreshData() {
        $dataManager = $this.ServiceContainer.GetService('DataManager')
        $allTasks = $dataManager.GetTasks()
        $filteredTasks = switch ($this._filterStatus) {
            "Active"    { $allTasks | Where-Object { -not $_.Completed } }
            "Completed" { $allTasks | Where-Object { $_.Completed } }
            default     { $allTasks }
        }
        $this._taskTable.SetData($filteredTasks)
        $this._UpdateDisplay()
    }
    
    # Redraws the static parts of the screen like headers and footers.
    hidden [void] _UpdateDisplay() {
        $theme = $this.ServiceContainer.GetService('ThemeManager')
        # Header
        $this._headerPanel.ClearContent()
        $headerText = " Filter: $($this._filterStatus) "
        $this._headerPanel.WriteToBuffer(0, 0, $headerText, $theme.GetColor('header.foreground'), $theme.GetColor('header.background'))
        
        # Footer (Dynamic Help Text based on current keybindings)
        $this._footerPanel.ClearContent()
        $keybindingService = $this.ServiceContainer.GetService('KeybindingService')
        $bindings = @(
            "($($keybindingService.GetBindingDescription('task.toggleStatus')))-Toggle"
            "($($keybindingService.GetBindingDescription('task.new')))-New"
            "($($keybindingService.GetBindingDescription('task.edit')))-Edit"
            "($($keybindingService.GetBindingDescription('task.cycleFilter')))-Filter"
            "($($keybindingService.GetBindingDescription('task.back')))-Back"
        )
        $this._footerPanel.WriteToBuffer(0, 0, ($bindings -join ' | '), $theme.GetColor('statusbar.foreground'), $theme.GetColor('statusbar.background'))
        
        $this.RequestRedraw()
    }
    
    # The screen's input handler delegates all input to the focused child (the table).
    # The table will then translate keystrokes into actions via the KeybindingService.
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        return $this._taskTable.HandleInput($keyInfo)
    }

    #region Task Action Implementations
    hidden [void] _ToggleTaskStatus([PmcTask]$task) {
        # The logic is simple: update the task and let the DataManager notify everyone.
        $task.UpdateProgress($task.Completed ? 0 : 100)
        $this.ServiceContainer.GetService('DataManager').UpdateTask($task)
    }

    hidden [void] _CycleFilter() {
        $this._filterStatus = switch ($this._filterStatus) {
            "All"       { "Active" }
            "Active"    { "Completed" }
            default     { "All" }
        }
        # Refresh data, which will re-filter and trigger a display update.
        $this._RefreshData() 
    }
    
    hidden [void] _ShowNewTaskDialog() {
        # Using the async/await dialog API for cleaner code.
        $title = await Show-InputDialog -Title "New Task" -Message "Enter task title:"
        if ($title) { # A non-null/non-empty result means the user pressed OK
            $newTask = [PmcTask]::new($title)
            $this.ServiceContainer.GetService('DataManager').AddTask($newTask)
        }
    }
    
    hidden [void] _ShowEditTaskDialog([PmcTask]$task) {
        $newTitle = await Show-InputDialog -Title "Edit Task" -Message "New title:" -DefaultValue $task.Title
        if ($newTitle) {
            $task.Title = $newTitle
            $this.ServiceContainer.GetService('DataManager').UpdateTask($task)
        }
    }
    
    hidden [void] _ShowDeleteConfirmDialog([PmcTask]$task) {
        $confirmed = await Show-ConfirmDialog -Title "Delete Task" -Message "Delete task `"$($task.Title)`"?"
        if ($confirmed) {
            $this.ServiceContainer.GetService('DataManager').RemoveTask($task.Id)
        }
    }
    #endregion
}