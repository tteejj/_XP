# ==============================================================================
# Axiom-Phoenix v4.0 - Task List Screen  
# FIXED: Removed FocusManager dependency, uses ncurses-style window focus model
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: TaskListScreen
#
# PURPOSE:
#   Task management screen with list view and details panel
#   Uses direct input handling without external focus manager
#
# FOCUS MODEL:
#   - Screen manages which component is "active" internally
#   - Tab cycles between: task list, filter box, buttons
#   - Direct key handling for all operations
#   - NO EXTERNAL FOCUS MANAGER SERVICE
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
    
    # Focus management (internal)
    hidden [string] $_activeComponent = "list"  # "list", "filter", "buttons"
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "TaskListScreen: Constructor called"
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "TaskListScreen.Initialize: Starting"
        
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
        $this._mainPanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "background" "#0A0A0A"
        $this.AddChild($this._mainPanel)

        # Calculate panel dimensions
        $listWidth = [Math]::Floor($this.Width * 0.35)  # 35% for list
        $detailWidth = $this.Width - $listWidth - 3     # Rest for details
        $contextHeight = 6                              # Fixed height for context

        # === LEFT PANEL: Task List ===
        $this._listPanel = [Panel]::new("TaskList")
        $this._listPanel.X = 1
        $this._listPanel.Y = 1
        $this._listPanel.Width = $listWidth
        $this._listPanel.Height = $this.Height - 5  # Leave room for status bar
        $this._listPanel.Title = " Tasks "
        $this._listPanel.BorderStyle = "Single"
        $this._listPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $this._mainPanel.AddChild($this._listPanel)

        # Project selector button
        $this._projectButton = [ButtonComponent]::new("ProjectSelector")
        $this._projectButton.Text = "▼ $($this._currentProject)"
        $this._projectButton.X = 2
        $this._projectButton.Y = 1
        $this._projectButton.Width = $listWidth - 4
        $this._projectButton.Height = 1
        $this._projectButton.IsFocusable = $false  # We handle input directly
        $this._listPanel.AddChild($this._projectButton)

        # Task list
        $this._taskListBox = [ListBox]::new("TaskList")
        $this._taskListBox.X = 1
        $this._taskListBox.Y = 3
        $this._taskListBox.Width = $listWidth - 2
        $this._taskListBox.Height = $this._listPanel.Height - 5
        $this._taskListBox.HasBorder = $false
        $this._taskListBox.IsFocusable = $false  # We handle input directly
        $this._taskListBox.SelectedBackgroundColor = Get-ThemeColor "list.selected.bg" "#1E3A8A"
        $this._taskListBox.SelectedForegroundColor = Get-ThemeColor "list.selected.fg" "#FFFFFF"
        $this._taskListBox.ItemForegroundColor = Get-ThemeColor "list.item.fg" "#E0E0E0"
        $this._listPanel.AddChild($this._taskListBox)

        # === TOP-RIGHT PANEL: Context & Filters ===
        $this._contextPanel = [Panel]::new("Context")
        $this._contextPanel.X = $listWidth + 2
        $this._contextPanel.Y = 1
        $this._contextPanel.Width = $detailWidth
        $this._contextPanel.Height = $contextHeight
        $this._contextPanel.BorderStyle = "Single"
        $this._contextPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $this._contextPanel.BackgroundColor = Get-ThemeColor "panel.bg" "#0F0F0F"
        $this._mainPanel.AddChild($this._contextPanel)

        # Filter box with icon
        $filterLabel = [LabelComponent]::new("FilterIcon")
        $filterLabel.Text = "🔍"
        $filterLabel.X = 2
        $filterLabel.Y = 1
        $filterLabel.ForegroundColor = Get-ThemeColor "icon" "#FFD700"
        $this._contextPanel.AddChild($filterLabel)

        $this._filterBox = [TextBoxComponent]::new("FilterBox")
        $this._filterBox.Placeholder = "Type to filter tasks..."
        $this._filterBox.X = 5
        $this._filterBox.Y = 1
        $this._filterBox.Width = [Math]::Floor($detailWidth * 0.5)
        $this._filterBox.Height = 3
        $this._filterBox.IsFocusable = $false  # We handle input directly
        $this._contextPanel.AddChild($this._filterBox)

        # Sort indicator
        $this._sortLabel = [LabelComponent]::new("SortLabel")
        $this._sortLabel.X = $this._filterBox.X + $this._filterBox.Width + 3
        $this._sortLabel.Y = 1
        $this._sortLabel.Text = "Sort: $($this._sortBy) ↓"
        $this._sortLabel.ForegroundColor = Get-ThemeColor "muted" "#888888"
        $this._contextPanel.AddChild($this._sortLabel)

        # Help text
        $this._helpLabel = [LabelComponent]::new("HelpLabel")
        $this._helpLabel.X = 2
        $this._helpLabel.Y = 4
        $this._helpLabel.Text = "↑↓ Navigate | Enter: Edit | Space: Toggle | N: New | Tab: Switch Focus | Esc: Back"
        $this._helpLabel.ForegroundColor = Get-ThemeColor "help" "#666666"
        $this._contextPanel.AddChild($this._helpLabel)

        # === MAIN-RIGHT PANEL: Task Details ===
        $this._detailPanel = [Panel]::new("TaskDetails")
        $this._detailPanel.X = $listWidth + 2
        $this._detailPanel.Y = $contextHeight + 2
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - $contextHeight - 6
        $this._detailPanel.BorderStyle = "Single"
        $this._detailPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $this._detailPanel.BackgroundColor = Get-ThemeColor "detail.bg" "#0A0A0A"
        $this._mainPanel.AddChild($this._detailPanel)

        # === BOTTOM STATUS BAR ===
        $this._CreateStatusBar()
        
        # Initialize empty task lists
        $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
        $this._filteredTasks = [System.Collections.Generic.List[PmcTask]]::new()
        
        Write-Log -Level Debug -Message "TaskListScreen.Initialize: Completed"
    }

    hidden [void] _CreateStatusBar() {
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $false
        $this._statusBar.BackgroundColor = Get-ThemeColor "status.bg" "#1A1A1A"
        $this._mainPanel.AddChild($this._statusBar)

        # Separator line
        $separator = [LabelComponent]::new("StatusSep")
        $separator.X = 0
        $separator.Y = 0
        $separator.Text = "─" * ($this._statusBar.Width)
        $separator.ForegroundColor = Get-ThemeColor "border" "#333333"
        $this._statusBar.AddChild($separator)

        # Action buttons
        $buttonY = 1
        $actions = @(
            @{ Text = "[N]ew"; Color = "#00FF88" },
            @{ Text = "[E]dit"; Color = "#00BFFF" },
            @{ Text = "[D]elete"; Color = "#FF4444" },
            @{ Text = "[C]omplete"; Color = "#FFD700" },
            @{ Text = "[T]ags"; Color = "#FF69B4" },
            @{ Text = "[S]ort"; Color = "#8A2BE2" },
            @{ Text = "[/] Filter"; Color = "#00D4FF" },
            @{ Text = "[Esc] Back"; Color = "#666666" }
        )

        $x = 2
        foreach ($action in $actions) {
            $button = [LabelComponent]::new("Action_$($action.Text)")
            $button.X = $x
            $button.Y = $buttonY
            $button.Text = $action.Text
            $button.ForegroundColor = $action.Color
            $this._statusBar.AddChild($button)
            $x += $action.Text.Length + 3
        }
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "TaskListScreen.OnEnter: Starting"
        
        # Load initial data
        $this._RefreshTasks()
        
        # Subscribe to data change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $thisScreen = $this
            $handler = {
                param($eventData)
                $thisScreen._RefreshTasks()
            }.GetNewClosure()
            
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
            Write-Log -Level Debug -Message "TaskListScreen: Subscribed to Tasks.Changed events"
        }
        
        # Set initial active component
        $this._activeComponent = "list"
        $this._UpdateVisualFocus()
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "TaskListScreen.OnExit: Cleaning up"
        
        # Unsubscribe from events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._taskChangeSubscriptionId) {
            $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
            $this._taskChangeSubscriptionId = $null
        }
    }

    # === VISUAL FOCUS INDICATOR ===
    hidden [void] _UpdateVisualFocus() {
        # Update visual indicators based on active component
        switch ($this._activeComponent) {
            "list" {
                $this._listPanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
                $this._contextPanel.BorderColor = Get-ThemeColor "border" "#333333"
            }
            "filter" {
                $this._listPanel.BorderColor = Get-ThemeColor "border" "#333333"
                $this._contextPanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
                # Show cursor in filter box
                $this._filterBox.ShowCursor = $true
            }
            default {
                $this._listPanel.BorderColor = Get-ThemeColor "border" "#333333"
                $this._contextPanel.BorderColor = Get-ThemeColor "border" "#333333"
            }
        }
        
        # Hide cursor when not in filter
        if ($this._activeComponent -ne "filter") {
            $this._filterBox.ShowCursor = $false
        }
        
        $this.RequestRedraw()
    }

    # === DATA MANAGEMENT ===
    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if ($dataManager) {
            $allTasks = $dataManager.GetTasks()
            
            # Clear and apply filters
            $this._filteredTasks.Clear()
            
            foreach ($task in $allTasks) {
                # Project filter
                if ($this._currentProject -ne "All Projects" -and $task.ProjectKey -ne $this._currentProject) {
                    continue
                }
                
                # Text filter
                if (![string]::IsNullOrWhiteSpace($this._filterText)) {
                    $filterLower = $this._filterText.ToLower()
                    if (-not ($task.Title.ToLower().Contains($filterLower) -or
                             ($task.Description -and $task.Description.ToLower().Contains($filterLower)) -or
                             ($task.Tags -join " ").ToLower().Contains($filterLower))) {
                        continue
                    }
                }
                
                $this._filteredTasks.Add($task)
            }
            
            # Apply sorting
            $this._SortTasks()
            
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new($allTasks)
        } else {
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
            $this._filteredTasks = [System.Collections.Generic.List[PmcTask]]::new()
        }
        
        # Fix selection
        if ($this._selectedIndex -ge $this._filteredTasks.Count) {
            $this._selectedIndex = [Math]::Max(0, $this._filteredTasks.Count - 1)
        }
        
        if ($this._filteredTasks.Count -gt 0) {
            $this._selectedTask = $this._filteredTasks[$this._selectedIndex]
            $this._taskListBox.SelectedIndex = $this._selectedIndex
        } else {
            $this._selectedTask = $null
            $this._taskListBox.SelectedIndex = -1
        }
        
        $this._UpdateDisplay()
    }

    hidden [void] _SortTasks() {
        if ($this._filteredTasks.Count -eq 0) { return }
        
        $sorted = switch ($this._sortBy) {
            "Priority" {
                if ($this._sortDescending) {
                    $this._filteredTasks | Sort-Object -Property Priority -Descending | Sort-Object -Property Status
                } else {
                    $this._filteredTasks | Sort-Object -Property Priority | Sort-Object -Property Status
                }
            }
            "Title" {
                if ($this._sortDescending) {
                    $this._filteredTasks | Sort-Object -Property Title -Descending
                } else {
                    $this._filteredTasks | Sort-Object -Property Title
                }
            }
            "DueDate" {
                if ($this._sortDescending) {
                    $this._filteredTasks | Sort-Object -Property DueDate -Descending
                } else {
                    $this._filteredTasks | Sort-Object -Property DueDate
                }
            }
            "Status" {
                if ($this._sortDescending) {
                    $this._filteredTasks | Sort-Object -Property Status -Descending | Sort-Object -Property Priority -Descending
                } else {
                    $this._filteredTasks | Sort-Object -Property Status | Sort-Object -Property Priority -Descending
                }
            }
            default {
                $this._filteredTasks
            }
        }
        
        $this._filteredTasks.Clear()
        foreach ($task in $sorted) {
            $this._filteredTasks.Add($task)
        }
    }

    hidden [void] _UpdateDisplay() {
        $this._UpdateTaskList()
        $this._UpdateDetailPanel()
        $this._UpdateContextPanel()
        $this.RequestRedraw()
    }

    hidden [void] _UpdateTaskList() {
        if (-not $this._taskListBox) { return }
        
        $this._taskListBox.ClearItems()
        
        if ($this._filteredTasks.Count -eq 0) {
            if ($this._tasks.Count -eq 0) {
                $this._taskListBox.AddItem("  No tasks found. Press [N] to create one.")
            } else {
                $this._taskListBox.AddItem("  No tasks match your filter.")
            }
            return
        }
        
        # Add tasks with visual indicators
        foreach ($task in $this._filteredTasks) {
            # Status indicator
            $statusIcon = switch ($task.Status) {
                ([TaskStatus]::Pending) { "○" }
                ([TaskStatus]::InProgress) { "◐" }
                ([TaskStatus]::Completed) { "●" }
                ([TaskStatus]::Cancelled) { "✕" }
                default { "?" }
            }
            
            # Priority indicator
            $priorityIcon = switch ($task.Priority) {
                ([TaskPriority]::Low) { "↓" }
                ([TaskPriority]::Medium) { "-" }
                ([TaskPriority]::High) { "!" }
                default { " " }
            }
            
            # Truncate title to fit
            $maxTitleLength = $this._taskListBox.Width - 8
            $title = if ($task.Title.Length -gt $maxTitleLength) {
                $task.Title.Substring(0, $maxTitleLength - 3) + "..."
            } else {
                $task.Title
            }
            
            $displayText = "$statusIcon $priorityIcon $title"
            $this._taskListBox.AddItem($displayText)
        }
        
        # Preserve selection
        if ($this._selectedIndex -lt $this._filteredTasks.Count) {
            $this._taskListBox.SelectedIndex = $this._selectedIndex
        }
    }

    hidden [void] _UpdateDetailPanel() {
        $panel = $this._detailPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()
        $panel.UpdateContentDimensions()
        
        if (-not $this._selectedTask) {
            # Show empty state
            $emptyLabel = [LabelComponent]::new("EmptyState")
            $emptyLabel.X = [Math]::Floor($panel.ContentWidth / 2) - 10
            $emptyLabel.Y = [Math]::Floor($panel.ContentHeight / 2)
            $emptyLabel.Text = "Select a task to view details"
            $emptyLabel.ForegroundColor = Get-ThemeColor "muted" "#666666"
            $panel.AddChild($emptyLabel)
            return
        }
        
        $task = $this._selectedTask
        $y = 2
        
        # Task title
        $titleLabel = [LabelComponent]::new("TaskTitle")
        $titleLabel.X = 2
        $titleLabel.Y = $y
        $titleLabel.Text = $task.Title
        $titleLabel.ForegroundColor = Get-ThemeColor "title" "#FFFFFF"
        $panel.AddChild($titleLabel)
        
        $y += 2
        
        # Status and Priority
        $statusLabel = [LabelComponent]::new("Status")
        $statusLabel.X = 2
        $statusLabel.Y = $y
        $statusLabel.Text = "Status: $($task.Status)"
        $statusLabel.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
        $panel.AddChild($statusLabel)
        
        $priorityLabel = [LabelComponent]::new("Priority")
        $priorityLabel.X = 25
        $priorityLabel.Y = $y
        $priorityLabel.Text = "Priority: $($task.Priority)"
        $priorityLabel.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
        $panel.AddChild($priorityLabel)
        
        $y += 2
        
        # Progress
        $progressLabel = [LabelComponent]::new("Progress")
        $progressLabel.X = 2
        $progressLabel.Y = $y
        $barWidth = 20
        $filledWidth = [Math]::Floor($barWidth * $task.Progress / 100)
        $progressBar = "█" * $filledWidth + "░" * ($barWidth - $filledWidth)
        $progressLabel.Text = "Progress: $progressBar $($task.Progress)%"
        $progressLabel.ForegroundColor = if ($task.Progress -eq 100) { "#00FF88" } else { "#00BFFF" }
        $panel.AddChild($progressLabel)
        
        $y += 2
        
        # Description
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            $descLabel = [LabelComponent]::new("DescLabel")
            $descLabel.X = 2
            $descLabel.Y = $y
            $descLabel.Text = "Description:"
            $descLabel.ForegroundColor = Get-ThemeColor "label" "#B0B0B0"
            $panel.AddChild($descLabel)
            
            $y++
            $descText = [LabelComponent]::new("DescText")
            $descText.X = 2
            $descText.Y = $y
            $descText.Text = $task.Description
            $descText.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
            $panel.AddChild($descText)
        }
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateContextPanel() {
        if (-not $this._sortLabel) { return }
        
        # Update sort indicator
        $arrow = if ($this._sortDescending) { "↓" } else { "↑" }
        $this._sortLabel.Text = "Sort: $($this._sortBy) $arrow"
    }

    #region CRUD Operations

    hidden [void] _ShowNewTaskDialog() {
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if (-not $navService) { return }
        
        $dialog = [SimpleTaskDialog]::new($this.ServiceContainer, $null)
        $thisScreen = $this
        $dialog.OnSave = {
            param($task)
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $dataManager.AddTask($task)
                $thisScreen._RefreshTasks()
            }
        }.GetNewClosure()
        
        $navService.NavigateTo($dialog)
    }
    
    hidden [void] _ShowEditTaskDialog() {
        if (-not $this._selectedTask) { return }
        
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if (-not $navService) { return }
        
        $dialog = [SimpleTaskDialog]::new($this.ServiceContainer, $this._selectedTask.Clone())
        $thisScreen = $this
        $dialog.OnSave = {
            param($task)
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $original = $thisScreen._selectedTask
                $original.Title = $task.Title
                $original.Description = $task.Description
                $original.Priority = $task.Priority
                $original.ProjectKey = $task.ProjectKey
                $original.DueDate = $task.DueDate
                $original.UpdatedAt = [DateTime]::Now
                
                $dataManager.UpdateTask($original)
                $thisScreen._RefreshTasks()
            }
        }.GetNewClosure()
        
        $navService.NavigateTo($dialog)
    }
    
    hidden [void] _DeleteTask() {
        if (-not $this._selectedTask) { return }
        
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if (-not $navService) { return }
        
        $thisScreen = $this
        $selectedTask = $this._selectedTask
        
        $dialog = [ConfirmDialog]::new($this.ServiceContainer)
        $dialog.Title = "Delete Task"
        $dialog.Message = "Are you sure you want to delete:`n`n'$($selectedTask.Title)'`n`nThis action cannot be undone."
        $dialog.OnConfirm = {
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $dataManager.DeleteTask($selectedTask.Id)
                $thisScreen._RefreshTasks()
            }
        }.GetNewClosure()
        
        $navService.NavigateTo($dialog)
    }
    
    hidden [void] _CompleteTask() {
        if (-not $this._selectedTask) { return }
        
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if ($dataManager) {
            $this._selectedTask.Complete()
            $dataManager.UpdateTask($this._selectedTask)
            $this._RefreshTasks()
        }
    }
    
    hidden [void] _CycleSortMode() {
        $modes = @("Priority", "Title", "DueDate", "Status")
        $currentIndex = [Array]::IndexOf($modes, $this._sortBy)
        
        if ($currentIndex -eq $modes.Length - 1) {
            $this._sortBy = $modes[0]
            $this._sortDescending = -not $this._sortDescending
        } else {
            $this._sortBy = $modes[$currentIndex + 1]
        }
        
        $this._RefreshTasks()
    }
    
    #endregion

    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "TaskListScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "TaskListScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Active=$($this._activeComponent)"
        
        # === HANDLE BASED ON ACTIVE COMPONENT ===
        if ($this._activeComponent -eq "filter") {
            # Filter box is active - handle text input
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) {
                    # Exit filter mode
                    $this._activeComponent = "list"
                    $this._UpdateVisualFocus()
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    # Move to next component
                    $this._activeComponent = "list"
                    $this._UpdateVisualFocus()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Apply filter and return to list
                    $this._activeComponent = "list"
                    $this._UpdateVisualFocus()
                    $this._RefreshTasks()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this._filterText.Length -gt 0) {
                        $this._filterText = $this._filterText.Substring(0, $this._filterText.Length - 1)
                        $this._filterBox.Text = $this._filterText
                        $this._RefreshTasks()
                    }
                    return $true
                }
                default {
                    # Add character to filter
                    if ($keyInfo.KeyChar -and [char]::IsLetterOrDigit($keyInfo.KeyChar) -or $keyInfo.KeyChar -eq ' ') {
                        $this._filterText += $keyInfo.KeyChar
                        $this._filterBox.Text = $this._filterText
                        $this._RefreshTasks()
                        return $true
                    }
                }
            }
            return $false
        }
        
        # === MAIN LIST MODE - HANDLE SHORTCUTS ===
        $handled = $false
        
        # Single key commands
        switch ($keyInfo.KeyChar) {
            'n' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._ShowNewTaskDialog()
                    $handled = $true
                }
            }
            'N' {
                $this._ShowNewTaskDialog()
                $handled = $true
            }
            'e' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    $handled = $true
                }
            }
            'E' {
                if ($this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    $handled = $true
                }
            }
            'd' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._DeleteTask()
                    $handled = $true
                }
            }
            'D' {
                if ($this._selectedTask) {
                    $this._DeleteTask()
                    $handled = $true
                }
            }
            'c' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._CompleteTask()
                    $handled = $true
                }
            }
            'C' {
                if ($this._selectedTask) {
                    $this._CompleteTask()
                    $handled = $true
                }
            }
            's' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._CycleSortMode()
                    $handled = $true
                }
            }
            'S' {
                $this._CycleSortMode()
                $handled = $true
            }
            '/' {
                # Switch to filter mode
                $this._activeComponent = "filter"
                $this._UpdateVisualFocus()
                $handled = $true
            }
        }
        
        # Special keys
        if (-not $handled) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this._selectedIndex -gt 0 -and $this._filteredTasks.Count -gt 0) {
                        $this._selectedIndex--
                        $this._selectedTask = $this._filteredTasks[$this._selectedIndex]
                        $this._taskListBox.SelectedIndex = $this._selectedIndex
                        $this._UpdateDetailPanel()
                        $this.RequestRedraw()
                    }
                    $handled = $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._selectedIndex -lt $this._filteredTasks.Count - 1) {
                        $this._selectedIndex++
                        $this._selectedTask = $this._filteredTasks[$this._selectedIndex]
                        $this._taskListBox.SelectedIndex = $this._selectedIndex
                        $this._UpdateDetailPanel()
                        $this.RequestRedraw()
                    }
                    $handled = $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this._selectedTask) {
                        $this._ShowEditTaskDialog()
                        $handled = $true
                    }
                }
                ([ConsoleKey]::Tab) {
                    # Cycle through components
                    switch ($this._activeComponent) {
                        "list" { $this._activeComponent = "filter" }
                        "filter" { $this._activeComponent = "list" }
                        default { $this._activeComponent = "list" }
                    }
                    $this._UpdateVisualFocus()
                    $handled = $true
                }
                ([ConsoleKey]::Spacebar) {
                    if ($this._selectedTask) {
                        # Toggle task progress
                        $dataManager = $this.ServiceContainer?.GetService("DataManager")
                        if ($dataManager) {
                            if ($this._selectedTask.Progress -eq 100) {
                                $this._selectedTask.SetProgress(0)
                            } else {
                                $this._selectedTask.SetProgress(100)
                            }
                            $dataManager.UpdateTask($this._selectedTask)
                            $this._RefreshTasks()
                        }
                        $handled = $true
                    }
                }
                ([ConsoleKey]::F5) {
                    $this._RefreshTasks()
                    $handled = $true
                }
                ([ConsoleKey]::Escape) {
                    # Go back
                    $navService = $this.ServiceContainer?.GetService("NavigationService")
                    if ($navService -and $navService.CanGoBack()) {
                        $navService.GoBack()
                    } else {
                        $actionService = $this.ServiceContainer?.GetService("ActionService")
                        if ($actionService) {
                            $actionService.ExecuteAction("navigation.dashboard", @{})
                        }
                    }
                    $handled = $true
                }
            }
        }
        
        Write-Log -Level Debug -Message "TaskListScreen.HandleInput: Returning handled=$handled"
        return $handled
    }
}

# ==============================================================================
# SIMPLE TASK DIALOG - NO FOCUS MANAGER
# ==============================================================================
class SimpleTaskDialog : Screen {
    hidden [Panel] $_dialogPanel
    hidden [Panel] $_contentPanel
    hidden [TextBoxComponent] $_titleBox
    hidden [TextBoxComponent] $_descriptionBox
    hidden [PmcTask] $_task
    hidden [TaskPriority] $_selectedPriority
    hidden [string] $_selectedProject
    hidden [string] $_activeField = "title"  # "title", "description", "buttons"
    
    [scriptblock]$OnSave = {}
    [scriptblock]$OnCancel = {}
    
    hidden [bool] $_isNewTask
    
    SimpleTaskDialog([object]$serviceContainer, [PmcTask]$existingTask) : base("SimpleTaskDialog", $serviceContainer) {
        $this.IsOverlay = $true
        if ($existingTask) {
            $this._task = $existingTask
            $this._selectedPriority = $existingTask.Priority
            $this._selectedProject = $existingTask.ProjectKey
            $this._isNewTask = $false
        } else {
            $this._task = [PmcTask]::new()
            $this._selectedPriority = [TaskPriority]::Medium
            $this._selectedProject = "General"
            $this._isNewTask = $true
        }
    }
    
    [void] Initialize() {
        # Full screen semi-transparent overlay
        $overlayPanel = [Panel]::new("Overlay")
        $overlayPanel.X = 0
        $overlayPanel.Y = 0
        $overlayPanel.Width = $this.Width
        $overlayPanel.Height = $this.Height
        $overlayPanel.HasBorder = $false
        $overlayPanel.BackgroundColor = "#000000"
        $this.AddChild($overlayPanel)
        
        # Create centered dialog
        $dialogWidth = 60
        $dialogHeight = 15
        $dialogX = [Math]::Floor(($this.Width - $dialogWidth) / 2)
        $dialogY = [Math]::Floor(($this.Height - $dialogHeight) / 2)
        
        $this._dialogPanel = [Panel]::new("DialogMain")
        $this._dialogPanel.X = $dialogX
        $this._dialogPanel.Y = $dialogY
        $this._dialogPanel.Width = $dialogWidth
        $this._dialogPanel.Height = $dialogHeight
        $this._dialogPanel.Title = if ($this._isNewTask) { " New Task " } else { " Edit Task " }
        $this._dialogPanel.BorderStyle = "Double"
        $this._dialogPanel.BorderColor = Get-ThemeColor "accent" "#00D4FF"
        $this._dialogPanel.BackgroundColor = Get-ThemeColor "dialog.bg" "#1A1A1A"
        $this.AddChild($this._dialogPanel)
        
        # Content panel
        $this._contentPanel = [Panel]::new("Content")
        $this._contentPanel.X = 2
        $this._contentPanel.Y = 1
        $this._contentPanel.Width = $dialogWidth - 4
        $this._contentPanel.Height = $dialogHeight - 2
        $this._contentPanel.HasBorder = $false
        $this._dialogPanel.AddChild($this._contentPanel)
        
        $y = 1
        
        # Title field
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.X = 0
        $titleLabel.Y = $y
        $titleLabel.Text = "Task Title:"
        $titleLabel.ForegroundColor = Get-ThemeColor "label" "#FFD700"
        $this._contentPanel.AddChild($titleLabel)
        
        $y++
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = 0
        $this._titleBox.Y = $y
        $this._titleBox.Width = $this._contentPanel.Width
        $this._titleBox.Height = 1
        $this._titleBox.Text = if ($this._task.Title) { $this._task.Title } else { "" }
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.IsFocusable = $false  # We handle input directly
        $this._contentPanel.AddChild($this._titleBox)
        
        $y += 2
        
        # Description field
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.X = 0
        $descLabel.Y = $y
        $descLabel.Text = "Description:"
        $descLabel.ForegroundColor = Get-ThemeColor "label" "#00D4FF"
        $this._contentPanel.AddChild($descLabel)
        
        $y++
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = 0
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $this._contentPanel.Width
        $this._descriptionBox.Height = 1
        $this._descriptionBox.Text = if ($this._task.Description) { $this._task.Description } else { "" }
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.IsFocusable = $false  # We handle input directly
        $this._contentPanel.AddChild($this._descriptionBox)
        
        $y += 2
        
        # Priority and Project row
        $prioLabel = [LabelComponent]::new("PrioLabel")
        $prioLabel.X = 0
        $prioLabel.Y = $y
        $prioLabel.Text = "Priority:"
        $prioLabel.ForegroundColor = Get-ThemeColor "label" "#FF69B4"
        $this._contentPanel.AddChild($prioLabel)
        
        $prioValue = [LabelComponent]::new("PrioValue")
        $prioValue.X = 10
        $prioValue.Y = $y
        $prioValue.Text = "[$($this._selectedPriority)]"
        $priorityColor = switch ($this._selectedPriority) {
            ([TaskPriority]::Low) { "#00FF88" }
            ([TaskPriority]::Medium) { "#FFD700" }
            ([TaskPriority]::High) { "#FF4444" }
        }
        $prioValue.ForegroundColor = $priorityColor
        $this._contentPanel.AddChild($prioValue)
        
        $y += 3
        
        # Buttons
        $saveLabel = [LabelComponent]::new("SaveBtn")
        $saveLabel.X = [Math]::Floor($this._contentPanel.Width / 2) - 15
        $saveLabel.Y = $y
        $saveLabel.Text = "  [S]ave  "
        $saveLabel.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $saveLabel.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $this._contentPanel.AddChild($saveLabel)
        
        $cancelLabel = [LabelComponent]::new("CancelBtn")
        $cancelLabel.X = [Math]::Floor($this._contentPanel.Width / 2) + 2
        $cancelLabel.Y = $y
        $cancelLabel.Text = " [C]ancel "
        $cancelLabel.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        $cancelLabel.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $this._contentPanel.AddChild($cancelLabel)
    }
    
    [void] OnEnter() {
        $this._activeField = "title"
        $this._UpdateVisualFocus()
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateVisualFocus() {
        # Show cursor in active field
        $this._titleBox.ShowCursor = ($this._activeField -eq "title")
        $this._descriptionBox.ShowCursor = ($this._activeField -eq "description")
        
        # Update button highlighting
        $saveBtn = $this._contentPanel.Children | Where-Object { $_.Name -eq "SaveBtn" }
        $cancelBtn = $this._contentPanel.Children | Where-Object { $_.Name -eq "CancelBtn" }
        
        if ($this._activeField -eq "buttons") {
            $saveBtn.BackgroundColor = Get-ThemeColor "button.hover" "#1976D2"
            $cancelBtn.BackgroundColor = Get-ThemeColor "button.cancel.hover" "#D32F2F"
        } else {
            $saveBtn.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
            $cancelBtn.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        }
    }
    
    hidden [void] _SaveTask() {
        # Validate
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            return
        }
        
        # Update task
        $this._task.Title = $this._titleBox.Text.Trim()
        $this._task.Description = $this._descriptionBox.Text.Trim()
        $this._task.Priority = $this._selectedPriority
        $this._task.ProjectKey = $this._selectedProject
        $this._task.UpdatedAt = [DateTime]::Now
        
        # Execute callback
        if ($this.OnSave) {
            & $this.OnSave $this._task
        }
        
        # Go back
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }
    
    hidden [void] _Cancel() {
        if ($this.OnCancel) {
            & $this.OnCancel
        }
        
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }
    
    hidden [void] _CyclePriority() {
        $priorities = @([TaskPriority]::Low, [TaskPriority]::Medium, [TaskPriority]::High)
        $currentIndex = [Array]::IndexOf($priorities, $this._selectedPriority)
        $this._selectedPriority = $priorities[($currentIndex + 1) % $priorities.Length]
        
        # Update display
        $prioValue = $this._contentPanel.Children | Where-Object { $_.Name -eq "PrioValue" }
        if ($prioValue) {
            $prioValue.Text = "[$($this._selectedPriority)]"
            $priorityColor = switch ($this._selectedPriority) {
                ([TaskPriority]::Low) { "#00FF88" }
                ([TaskPriority]::Medium) { "#FFD700" }
                ([TaskPriority]::High) { "#FF4444" }
            }
            $prioValue.ForegroundColor = $priorityColor
            $this.RequestRedraw()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle text input in active field
        if ($this._activeField -eq "title" -or $this._activeField -eq "description") {
            $textBox = if ($this._activeField -eq "title") { $this._titleBox } else { $this._descriptionBox }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($textBox.Text.Length -gt 0) {
                        $textBox.Text = $textBox.Text.Substring(0, $textBox.Text.Length - 1)
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    # Move to next field
                    switch ($this._activeField) {
                        "title" { $this._activeField = "description" }
                        "description" { $this._activeField = "buttons" }
                        "buttons" { $this._activeField = "title" }
                    }
                    $this._UpdateVisualFocus()
                    $this.RequestRedraw()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this._activeField -eq "title") {
                        $this._activeField = "description"
                        $this._UpdateVisualFocus()
                        $this.RequestRedraw()
                    } else {
                        $this._SaveTask()
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $this._Cancel()
                    return $true
                }
                default {
                    # Add character
                    if ($keyInfo.KeyChar -and ([char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                        [char]::IsPunctuation($keyInfo.KeyChar) -or 
                        [char]::IsWhiteSpace($keyInfo.KeyChar))) {
                        $textBox.Text += $keyInfo.KeyChar
                        $this.RequestRedraw()
                        return $true
                    }
                }
            }
        }
        
        # Global shortcuts
        switch ($keyInfo.KeyChar) {
            's' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._SaveTask()
                    return $true
                }
            }
            'S' {
                $this._SaveTask()
                return $true
            }
            'c' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._Cancel()
                    return $true
                }
            }
            'C' {
                $this._Cancel()
                return $true
            }
            'p' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._CyclePriority()
                    return $true
                }
            }
            'P' {
                $this._CyclePriority()
                return $true
            }
        }
        
        # Handle special keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this._Cancel()
                return $true
            }
        }
        
        return $false
    }
}

# ==============================================================================
# CONFIRM DIALOG - NO FOCUS MANAGER
# ==============================================================================
class ConfirmDialog : Screen {
    hidden [Panel] $_mainPanel
    hidden [LabelComponent] $_messageLabel
    hidden [bool] $_selectedYes = $false
    
    [string]$Title = "Confirm"
    [string]$Message = "Are you sure?"
    [scriptblock]$OnConfirm = {}
    [scriptblock]$OnCancel = {}
    
    ConfirmDialog([object]$serviceContainer) : base("ConfirmDialog", $serviceContainer) {
        $this.IsOverlay = $true
    }
    
    [void] Initialize() {
        # Create centered dialog
        $dialogWidth = 50
        $dialogHeight = 10
        $dialogX = [Math]::Floor(($this.Width - $dialogWidth) / 2)
        $dialogY = [Math]::Floor(($this.Height - $dialogHeight) / 2)
        
        $this._mainPanel = [Panel]::new("ConfirmMain")
        $this._mainPanel.X = $dialogX
        $this._mainPanel.Y = $dialogY
        $this._mainPanel.Width = $dialogWidth
        $this._mainPanel.Height = $dialogHeight
        $this._mainPanel.Title = " $($this.Title) "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "warning" "#FFA500"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "dialog.bg" "#0A0A0A"
        $this.AddChild($this._mainPanel)
        
        # Message
        $lines = $this.Message -split "`n"
        $y = 2
        foreach ($line in $lines) {
            if ($y -ge $dialogHeight - 3) { break }
            $msgLabel = [LabelComponent]::new("Message$y")
            $msgLabel.X = 2
            $msgLabel.Y = $y
            $msgLabel.Text = $line
            $msgLabel.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
            $this._mainPanel.AddChild($msgLabel)
            $y++
        }
    }
    
    [void] OnEnter() {
        $this._selectedYes = $false
        $this._UpdateButtons()
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateButtons() {
        # Clear existing buttons
        $existingButtons = @($this._mainPanel.Children | Where-Object { $_.Name -like "*Button" })
        foreach ($btn in $existingButtons) {
            $this._mainPanel.RemoveChild($btn)
        }
        
        # Add updated buttons
        $buttonY = $this._mainPanel.Height - 2
        
        $yesButton = [LabelComponent]::new("YesButton")
        $yesButton.Text = " [Y]es "
        $yesButton.X = [Math]::Floor($this._mainPanel.Width / 2) - 10
        $yesButton.Y = $buttonY
        if ($this._selectedYes) {
            $yesButton.BackgroundColor = Get-ThemeColor "button.hover" "#1976D2"
        } else {
            $yesButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        }
        $yesButton.ForegroundColor = "#FFFFFF"
        $this._mainPanel.AddChild($yesButton)
        
        $noButton = [LabelComponent]::new("NoButton")
        $noButton.Text = " [N]o "
        $noButton.X = [Math]::Floor($this._mainPanel.Width / 2) + 2
        $noButton.Y = $buttonY
        if (-not $this._selectedYes) {
            $noButton.BackgroundColor = Get-ThemeColor "button.cancel.hover" "#D32F2F"
        } else {
            $noButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        }
        $noButton.ForegroundColor = "#FFFFFF"
        $this._mainPanel.AddChild($noButton)
    }
    
    hidden [void] _Confirm() {
        if ($this.OnConfirm) {
            & $this.OnConfirm
        }
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }
    
    hidden [void] _Cancel() {
        if ($this.OnCancel) {
            & $this.OnCancel
        }
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        switch ($keyInfo.KeyChar) {
            'y' {
                $this._Confirm()
                return $true
            }
            'Y' {
                $this._Confirm()
                return $true
            }
            'n' {
                $this._Cancel()
                return $true
            }
            'N' {
                $this._Cancel()
                return $true
            }
        }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::LeftArrow) {
                $this._selectedYes = $true
                $this._UpdateButtons()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::RightArrow) {
                $this._selectedYes = $false
                $this._UpdateButtons()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Tab) {
                $this._selectedYes = -not $this._selectedYes
                $this._UpdateButtons()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this._selectedYes) {
                    $this._Confirm()
                } else {
                    $this._Cancel()
                }
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this._Cancel()
                return $true
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF TASK LIST SCREEN
# ==============================================================================
