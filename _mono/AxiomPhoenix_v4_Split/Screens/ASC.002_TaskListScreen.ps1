# ==============================================================================
# Axiom-Phoenix v4.0 - Task List Screen  
# UPDATED: Uses Hybrid Window Model for proper component focus management
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: TaskListScreen
#
# PURPOSE:
#   Task management screen with list view and details panel
#   Uses hybrid window model with automatic focus management
#
# FOCUS MODEL:
#   - Screen base class manages focus automatically
#   - Components are focusable and handle their own input
#   - Tab navigation is automatic based on TabIndex
#   - Components provide visual focus feedback
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (for screen transitions)
#     - ActionService (for executing commands)
#     - DataManager (for task CRUD operations)
#     - EventManager (for data change notifications)
#   Components:
#     - Panel (containers)
#     - ListBox (task list)
#     - TextBoxComponent (filter)
#     - LabelComponent (display elements)
# ==============================================================================
class TaskListScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_listPanel          # Left panel for task list
    hidden [Panel] $_contextPanel       # Top-right panel for filters
    hidden [Panel] $_detailPanel        # Main-right panel for details
    hidden [Panel] $_statusBar          # Bottom status bar
    hidden [ListBox] $_taskListBox      # Task list
    hidden [TextBoxComponent] $_filterBox
    hidden [LabelComponent] $_sortLabel
    hidden [LabelComponent] $_helpLabel
    hidden [ButtonComponent] $_projectButton
    #endregion

    #region State
    hidden [System.Collections.Generic.List[PmcTask]] $_tasks
    hidden [System.Collections.Generic.List[PmcTask]] $_filteredTasks
    hidden [int] $_selectedIndex = 0
    hidden [PmcTask] $_selectedTask
    hidden [string] $_filterText = ""
    hidden [string] $_currentProject = "All Projects"
    hidden [string] $_sortBy = "Priority"
    hidden [bool] $_sortDescending = $true
    hidden [string] $_taskChangeSubscriptionId = $null
    hidden [string] $_filterRefreshSubscriptionId = $null
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "TaskListScreen: Constructor called"
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "TaskListScreen.Initialize: Starting"
        
        # Guard against multiple initialization calls
        if ($this._isInitialized) {
            Write-Log -Level Debug -Message "TaskListScreen.Initialize: Already initialized, skipping"
            return
        }
        
        if (-not $this.ServiceContainer) { 
            Write-Log -Level Error -Message "TaskListScreen.Initialize: ServiceContainer is null!"
            throw "ServiceContainer is required"
        }
        
        # Ensure minimum size
        if ($this.Width -lt 120) { $this.Width = 120 }
        if ($this.Height -lt 30) { $this.Height = 30 }
        
        # === MAIN PANEL ===
        $this._mainPanel = [Panel]::new("TaskListMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " ╔═ Task Management System ═╗ "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = (Get-ThemeColor "palette.border" "#007acc")
        $this._mainPanel.BackgroundColor = (Get-ThemeColor "palette.background" "#1e1e1e")
        $this.AddChild($this._mainPanel)

        # Calculate panel dimensions
        $listWidth = [Math]::Floor($this.Width * 0.35)  # 35% for list
        $detailWidth = $this.Width - $listWidth - 3     # Rest for details
        $contextHeight = 6                              # Fixed height for context

        # === LEFT PANEL: Task List ===
        $this._listPanel = [Panel]::new("TaskListPanel")
        $this._listPanel.X = 1
        $this._listPanel.Y = 1
        $this._listPanel.Width = $listWidth
        $this._listPanel.Height = $this.Height - 4  # Account for status bar
        $this._listPanel.Title = " 📋 Tasks "
        $this._listPanel.HasBorder = $true
        $this._listPanel.BorderColor = (Get-ThemeColor "palette.border" "#444444")
        $this._listPanel.BackgroundColor = (Get-ThemeColor "palette.background" "#2a2a2a")
        $this._mainPanel.AddChild($this._listPanel)

        # === TASK LISTBOX ===
        $this._taskListBox = [ListBox]::new("TaskList")
        $this._taskListBox.X = 1
        $this._taskListBox.Y = 1
        $this._taskListBox.Width = $this._listPanel.Width - 2
        $this._taskListBox.Height = $this._listPanel.Height - 2
        $this._taskListBox.TabIndex = 0
        $this._taskListBox.IsFocusable = $true
        $this._taskListBox.BackgroundColor = (Get-ThemeColor "listbox.background" "#1a1a1a")
        $this._taskListBox.ForegroundColor = (Get-ThemeColor "listbox.foreground" "#ffffff")
        $this._taskListBox.SelectedBackgroundColor = (Get-ThemeColor "listbox.selectedbackground" "#0078d4")
        $this._taskListBox.SelectedForegroundColor = (Get-ThemeColor "listbox.selectedforeground" "#ffffff")
        $this._listPanel.AddChild($this._taskListBox)

        # === TOP-RIGHT PANEL: Context/Filters ===
        $this._contextPanel = [Panel]::new("ContextPanel")
        $this._contextPanel.X = $listWidth + 2
        $this._contextPanel.Y = 1
        $this._contextPanel.Width = $detailWidth
        $this._contextPanel.Height = $contextHeight
        $this._contextPanel.Title = " 🔍 Filters & Options "
        $this._contextPanel.HasBorder = $true
        $this._contextPanel.BorderColor = (Get-ThemeColor "palette.border" "#444444")
        $this._contextPanel.BackgroundColor = (Get-ThemeColor "palette.background" "#2a2a2a")
        $this._mainPanel.AddChild($this._contextPanel)

        # === PROJECT SELECTOR BUTTON ===
        $this._projectButton = [ButtonComponent]::new("ProjectSelector")
        $this._projectButton.Text = "🗂️ Project: $($this._currentProject)"
        $this._projectButton.X = 1
        $this._projectButton.Y = 1
        $this._projectButton.Width = 30
        $this._projectButton.Height = 1
        $this._projectButton.TabIndex = 1
        $this._projectButton.IsFocusable = $true
        $this._projectButton.BackgroundColor = (Get-ThemeColor "button.background" "#0078d4")
        $this._projectButton.ForegroundColor = (Get-ThemeColor "button.foreground" "#ffffff")
        
        # Project button click handler
        $screenRef = $this
        $this._projectButton.OnClick = {
            $screenRef.ShowProjectSelector()
        }.GetNewClosure()
        
        $this._contextPanel.AddChild($this._projectButton)

        # === FILTER TEXTBOX ===
        $this._filterBox = [TextBoxComponent]::new("FilterText")
        $this._filterBox.X = 1
        $this._filterBox.Y = 3
        $this._filterBox.Width = $this._contextPanel.Width - 2
        $this._filterBox.Height = 1
        $this._filterBox.TabIndex = 2
        $this._filterBox.IsFocusable = $true
        $this._filterBox.Placeholder = "🔎 Type to filter tasks..."
        $this._filterBox.BackgroundColor = (Get-ThemeColor "textbox.background" "#333333")
        $this._filterBox.ForegroundColor = (Get-ThemeColor "textbox.foreground" "#ffffff")
        $this._filterBox.BorderColor = (Get-ThemeColor "textbox.border" "#555555")
        
        # Filter text change handler
        $this._filterBox.OnChange = {
            param($sender, $text)
            $screenRef._filterText = $text
            $screenRef.ApplyFilters()
        }.GetNewClosure()
        
        $this._contextPanel.AddChild($this._filterBox)

        # === MAIN-RIGHT PANEL: Task Details ===
        $this._detailPanel = [Panel]::new("DetailPanel")
        $this._detailPanel.X = $listWidth + 2
        $this._detailPanel.Y = $contextHeight + 2
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - $contextHeight - 6  # Account for context panel and status bar
        $this._detailPanel.Title = " 📝 Task Details "
        $this._detailPanel.HasBorder = $true
        $this._detailPanel.BorderColor = (Get-ThemeColor "palette.border" "#444444")
        $this._detailPanel.BackgroundColor = (Get-ThemeColor "palette.background" "#2a2a2a")
        $this._mainPanel.AddChild($this._detailPanel)

        # === STATUS BAR ===
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $true
        $this._statusBar.BorderColor = (Get-ThemeColor "palette.border" "#444444")
        $this._statusBar.BackgroundColor = (Get-ThemeColor "statusbar.background" "#333333")
        $this._mainPanel.AddChild($this._statusBar)

        # === HELP LABEL ===
        $this._helpLabel = [LabelComponent]::new("HelpLabel")
        $this._helpLabel.Text = "🔑 [↑↓] Navigate • [Enter] Edit • [Del] Delete • [N] New • [F5] Refresh • [Esc] Back"
        $this._helpLabel.X = 1
        $this._helpLabel.Y = 0
        $this._helpLabel.Width = $this._statusBar.Width - 2
        $this._helpLabel.Height = 1
        $this._helpLabel.ForegroundColor = (Get-ThemeColor "statusbar.foreground" "#cccccc")
        $this._helpLabel.BackgroundColor = (Get-ThemeColor "statusbar.background" "#333333")
        $this._statusBar.AddChild($this._helpLabel)

        # Set initialization flag
        $this._isInitialized = $true
        
        Write-Log -Level Debug -Message "TaskListScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "TaskListScreen.OnEnter: Screen activated"
        
        # Load tasks
        $this.LoadTasks()
        
        # Subscribe to data change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $screenRef = $this
            
            # Task data changes
            $taskHandler = {
                param($eventData)
                Write-Log -Level Debug -Message "TaskListScreen: Task data changed, refreshing"
                $screenRef.LoadTasks()
            }.GetNewClosure()
            
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $taskHandler)
            
            # Filter refresh requests
            $filterHandler = {
                param($eventData)
                $screenRef.ApplyFilters()
            }.GetNewClosure()
            
            $this._filterRefreshSubscriptionId = $eventManager.Subscribe("TaskList.RefreshFilters", $filterHandler)
        }
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }

    [void] OnExit() {
        Write-Log -Level Debug -Message "TaskListScreen.OnExit: Cleaning up"
        
        # Unsubscribe from events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            if ($this._taskChangeSubscriptionId) {
                $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
                $this._taskChangeSubscriptionId = $null
            }
            if ($this._filterRefreshSubscriptionId) {
                $eventManager.Unsubscribe("TaskList.RefreshFilters", $this._filterRefreshSubscriptionId)
                $this._filterRefreshSubscriptionId = $null
            }
        }
        
        # Call base cleanup
        ([Screen]$this).OnExit()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # ALWAYS FIRST - Let base handle Tab and component routing
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle screen-level shortcuts
        switch ($keyInfo.Key) {
            ([ConsoleKey]::F5) {
                $this.LoadTasks()
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this.GoBack()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this._selectedTask) {
                    $this.EditSelectedTask()
                    return $true
                }
            }
            ([ConsoleKey]::Delete) {
                if ($this._selectedTask) {
                    $this.DeleteSelectedTask()
                    return $true
                }
            }
        }
        
        # Handle character shortcuts
        switch ($keyInfo.KeyChar) {
            { $_ -eq 'n' -or $_ -eq 'N' } {
                $this.CreateNewTask()
                return $true
            }
            { $_ -eq 'r' -or $_ -eq 'R' } {
                $this.LoadTasks()
                return $true
            }
        }
        
        return $false
    }

    # === DATA MANAGEMENT ===
    hidden [void] LoadTasks() {
        Write-Log -Level Debug -Message "TaskListScreen.LoadTasks: Loading task data"
        
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if (-not $dataManager) {
            Write-Log -Level Error -Message "TaskListScreen.LoadTasks: DataManager not found"
            return
        }
        
        try {
            $this._tasks = $dataManager.GetTasks()
            $this.ApplyFilters()
            Write-Log -Level Debug -Message "TaskListScreen.LoadTasks: Loaded $($this._tasks.Count) tasks"
        } catch {
            Write-Log -Level Error -Message "TaskListScreen.LoadTasks: Error loading tasks: $_"
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
            $this._filteredTasks = [System.Collections.Generic.List[PmcTask]]::new()
        }
    }

    hidden [void] ApplyFilters() {
        if (-not $this._tasks) {
            $this._filteredTasks = [System.Collections.Generic.List[PmcTask]]::new()
            $this.RefreshTaskList()
            return
        }
        
        $filtered = [System.Collections.Generic.List[PmcTask]]::new()
        
        foreach ($task in $this._tasks) {
            $include = $true
            
            # Project filter
            if ($this._currentProject -ne "All Projects" -and $task.ProjectKey -ne $this._currentProject) {
                $include = $false
            }
            
            # Text filter
            if ($this._filterText -and $include) {
                $searchText = $this._filterText.ToLower()
                if (-not ($task.Title.ToLower().Contains($searchText) -or 
                         $task.Description.ToLower().Contains($searchText))) {
                    $include = $false
                }
            }
            
            if ($include) {
                $filtered.Add($task)
            }
        }
        
        # Sort filtered results
        $this._filteredTasks = $this.SortTasks($filtered)
        $this.RefreshTaskList()
    }

    hidden [System.Collections.Generic.List[PmcTask]] SortTasks([System.Collections.Generic.List[PmcTask]]$tasks) {
        if (-not $tasks -or $tasks.Count -eq 0) {
            return $tasks
        }
        
        $sorted = switch ($this._sortBy) {
            "Priority" {
                if ($this._sortDescending) {
                    $tasks | Sort-Object { $_.Priority.value__ } -Descending
                } else {
                    $tasks | Sort-Object { $_.Priority.value__ }
                }
            }
            "Status" {
                if ($this._sortDescending) {
                    $tasks | Sort-Object { $_.Status.value__ } -Descending
                } else {
                    $tasks | Sort-Object { $_.Status.value__ }
                }
            }
            "Title" {
                if ($this._sortDescending) {
                    $tasks | Sort-Object Title -Descending
                } else {
                    $tasks | Sort-Object Title
                }
            }
            "DueDate" {
                if ($this._sortDescending) {
                    $tasks | Sort-Object DueDate -Descending
                } else {
                    $tasks | Sort-Object DueDate
                }
            }
            default {
                $tasks
            }
        }
        
        return [System.Collections.Generic.List[PmcTask]]::new($sorted)
    }

    hidden [void] RefreshTaskList() {
        if (-not $this._taskListBox) { return }
        
        $this._taskListBox.ClearItems()
        
        if (-not $this._filteredTasks -or $this._filteredTasks.Count -eq 0) {
            $this._taskListBox.AddItem("📭 No tasks found")
            $this._selectedTask = $null
            $this.UpdateTaskDetails()
            return
        }
        
        foreach ($task in $this._filteredTasks) {
            $priorityIcon = switch ($task.Priority) {
                "Critical" { "🔥" }
                "High" { "📢" }
                "Medium" { "📋" }
                "Low" { "📝" }
                default { "❓" }
            }
            
            $statusIcon = switch ($task.Status) {
                "Pending" { "⏳" }
                "InProgress" { "🔄" }
                "Completed" { "✅" }
                "Cancelled" { "❌" }
                default { "❓" }
            }
            
            $displayText = "$priorityIcon $statusIcon $($task.Title)"
            $this._taskListBox.AddItem($displayText)
        }
        
        # Update selection
        if ($this._taskListBox.SelectedIndex -ge 0 -and $this._taskListBox.SelectedIndex -lt $this._filteredTasks.Count) {
            $this._selectedTask = $this._filteredTasks[$this._taskListBox.SelectedIndex]
        } else {
            $this._selectedTask = $null
        }
        
        $this.UpdateTaskDetails()
    }

    hidden [void] UpdateTaskDetails() {
        # Clear detail panel and redraw task information
        # This would render task details in the detail panel
        # Implementation would depend on specific detail rendering needs
    }

    # === NAVIGATION ACTIONS ===
    hidden [void] CreateNewTask() {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("navigation.newTask", @{})
        }
    }

    hidden [void] EditSelectedTask() {
        if (-not $this._selectedTask) { return }
        
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("navigation.editTask", @{ TaskId = $this._selectedTask.Id })
        }
    }

    hidden [void] DeleteSelectedTask() {
        if (-not $this._selectedTask) { return }
        
        # Show confirmation dialog and delete if confirmed
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("tasks.delete", @{ TaskId = $this._selectedTask.Id })
        }
    }

    hidden [void] ShowProjectSelector() {
        # Show project selection dialog
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("dialogs.projectSelector", @{})
        }
    }

    hidden [void] GoBack() {
        $navigationService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navigationService) {
            if ($navigationService.CanGoBack()) {
                $navigationService.GoBack()
            } else {
                # Navigate to dashboard
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                if ($actionService) {
                    $actionService.ExecuteAction("navigation.dashboard", @{})
                }
            }
        }
    }
}