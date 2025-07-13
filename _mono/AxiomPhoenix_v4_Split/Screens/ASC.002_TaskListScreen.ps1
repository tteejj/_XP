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
    hidden [bool] $_isInitialized = $false
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
        $this._mainPanel.BorderColor = (Get-ThemeColor "Panel.Border" "#007acc")
        $this._mainPanel.BackgroundColor = (Get-ThemeColor "Panel.Background" "#1e1e1e")
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
        $this._listPanel.BorderColor = (Get-ThemeColor "Panel.Border" "#404040")
        $this._mainPanel.AddChild($this._listPanel)

        # Project selector button
        $this._projectButton = [ButtonComponent]::new("ProjectSelector")
        $this._projectButton.Text = "▼ $($this._currentProject)"
        $this._projectButton.X = 2
        $this._projectButton.Y = 1
        $this._projectButton.Width = $listWidth - 4
        $this._projectButton.Height = 1
        $this._projectButton.IsFocusable = $true
        $this._projectButton.TabIndex = 2
        
        # Add visual focus feedback
        $this._projectButton | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BackgroundColor = Get-ThemeColor "button.focused.background" "#0e7490"
            $this.RequestRedraw()
        } -Force
        
        $this._projectButton | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BackgroundColor = Get-ThemeColor "button.normal.background" "#007acc"
            $this.RequestRedraw()
        } -Force
        
        # Add click handler
        $this._projectButton.OnClick = {
            # TODO: Show project selection dialog
            Write-Log -Level Debug -Message "Project button clicked"
        }
        
        $this._listPanel.AddChild($this._projectButton)

        # Task list
        $this._taskListBox = [ListBox]::new("TaskList")
        $this._taskListBox.X = 1
        $this._taskListBox.Y = 3
        $this._taskListBox.Width = $listWidth - 2
        $this._taskListBox.Height = $this._listPanel.Height - 5
        $this._taskListBox.HasBorder = $false
        $this._taskListBox.IsFocusable = $true
        $this._taskListBox.TabIndex = 0
        $this._taskListBox.SelectedBackgroundColor = (Get-ThemeColor "List.ItemSelectedBackground" "#007acc")
        $this._taskListBox.SelectedForegroundColor = (Get-ThemeColor "List.ItemSelected" "#ffffff")
        $this._taskListBox.ItemForegroundColor = (Get-ThemeColor "List.ItemNormal" "#d4d4d4")
        
        # Add visual focus feedback
        $this._taskListBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.SelectedBackgroundColor = Get-ThemeColor "listbox.focusedselectedbackground" "#0078d4"
            $this.BorderColor = Get-ThemeColor "primary.accent" "#0078d4"
            $this.RequestRedraw()
        } -Force
        
        $this._taskListBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.SelectedBackgroundColor = Get-ThemeColor "listbox.selectedbackground" "#007acc"
            $this.BorderColor = Get-ThemeColor "border" "#404040"
            $this.RequestRedraw()
        } -Force
        
        # Add selection change handler to update details
        $thisScreen = $this
        $this._taskListBox.SelectedIndexChanged = {
            param($sender, $newIndex)
            if ($newIndex -ge 0 -and $newIndex -lt $thisScreen._filteredTasks.Count) {
                $thisScreen._selectedIndex = $newIndex
                $thisScreen._selectedTask = $thisScreen._filteredTasks[$newIndex]
                $thisScreen._UpdateDetailPanel()
            }
        }.GetNewClosure()
        
        # ListBox already handles arrow keys internally, no need to override
        
        $this._listPanel.AddChild($this._taskListBox)

        # === TOP-RIGHT PANEL: Context & Filters ===
        $this._contextPanel = [Panel]::new("Context")
        $this._contextPanel.X = $listWidth + 2
        $this._contextPanel.Y = 1
        $this._contextPanel.Width = $detailWidth
        $this._contextPanel.Height = $contextHeight
        $this._contextPanel.BorderStyle = "Single"
        $this._contextPanel.BorderColor = (Get-ThemeColor "Panel.Border" "#404040")
        $this._contextPanel.BackgroundColor = (Get-ThemeColor "Panel.Background" "#1e1e1e")
        $this._mainPanel.AddChild($this._contextPanel)

        # Filter box with icon
        $filterLabel = [LabelComponent]::new("FilterIcon")
        $filterLabel.Text = "🔍"
        $filterLabel.X = 2
        $filterLabel.Y = 1
        $filterLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#d4d4d4")
        $this._contextPanel.AddChild($filterLabel)

        $this._filterBox = [TextBoxComponent]::new("FilterBox")
        $this._filterBox.Placeholder = "Type to filter tasks..."
        $this._filterBox.X = 5
        $this._filterBox.Y = 1
        $this._filterBox.Width = [Math]::Floor($detailWidth * 0.5)
        $this._filterBox.Height = 3
        $this._filterBox.IsFocusable = $true
        $this._filterBox.TabIndex = 1
        
        # Add visual focus feedback
        $this._filterBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.borderfocused" "#0078d4"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._filterBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#404040" 
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        # Add text change handler to trigger filtering
        $this._filterBox.OnChange = {
            param($sender, $newText)
            $thisScreen._filterText = $newText
            $thisScreen._RefreshTasks()
        }.GetNewClosure()
        
        $this._contextPanel.AddChild($this._filterBox)

        # Sort indicator
        $this._sortLabel = [LabelComponent]::new("SortLabel")
        $this._sortLabel.X = $this._filterBox.X + $this._filterBox.Width + 3
        $this._sortLabel.Y = 1
        $this._sortLabel.Text = "Sort: $($this._sortBy) ↓"
        $this._sortLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#9ca3af")
        $this._contextPanel.AddChild($this._sortLabel)

        # Help text
        $this._helpLabel = [LabelComponent]::new("HelpLabel")
        $this._helpLabel.X = 2
        $this._helpLabel.Y = 4
        $this._helpLabel.Text = "↑↓ Navigate | Enter: Edit | Space: Toggle | N: New | Tab: Switch Focus | Esc: Back"
        $this._helpLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#666666")
        $this._contextPanel.AddChild($this._helpLabel)

        # === MAIN-RIGHT PANEL: Task Details ===
        $this._detailPanel = [Panel]::new("TaskDetails")
        $this._detailPanel.X = $listWidth + 2
        $this._detailPanel.Y = $contextHeight + 2
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - $contextHeight - 6
        $this._detailPanel.BorderStyle = "Single"
        $this._detailPanel.BorderColor = (Get-ThemeColor "Panel.Border" "#333333")
        $this._detailPanel.BackgroundColor = (Get-ThemeColor "Panel.Background" "#0A0A0A")
        $this._mainPanel.AddChild($this._detailPanel)

        # === BOTTOM STATUS BAR ===
        $this._CreateStatusBar()
        
        # Initialize empty task lists
        $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
        $this._filteredTasks = [System.Collections.Generic.List[PmcTask]]::new()
        
        # Mark as initialized
        $this._isInitialized = $true
        
        Write-Log -Level Debug -Message "TaskListScreen.Initialize: Completed"
    }

    hidden [void] _CreateStatusBar() {
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 3
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 2
        $this._statusBar.HasBorder = $false
        $this._statusBar.BackgroundColor = (Get-ThemeColor "Panel.Background" "#1A1A1A")
        $this._mainPanel.AddChild($this._statusBar)

        # Separator line
        $separator = [LabelComponent]::new("StatusSep")
        $separator.X = 0
        $separator.Y = 0
        $separator.Text = "─" * ($this._statusBar.Width)
        $separator.ForegroundColor = (Get-ThemeColor "Panel.Border" "#333333")
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
        
        # Call base to set initial focus
        ([Screen]$this).OnEnter()
        
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
            $emptyLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#666666")
            $panel.AddChild($emptyLabel)
            $panel.RequestRedraw()
            return
        }
        
        $task = $this._selectedTask
        $y = 2
        
        # Task title
        $titleLabel = [LabelComponent]::new("TaskTitle")
        $titleLabel.X = 2
        $titleLabel.Y = $y
        $titleLabel.Text = $task.Title
        $titleLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#FFFFFF")
        $panel.AddChild($titleLabel)
        
        $y += 2
        
        # Status and Priority
        $statusLabel = [LabelComponent]::new("Status")
        $statusLabel.X = 2
        $statusLabel.Y = $y
        $statusLabel.Text = "Status: $($task.Status)"
        $statusLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#E0E0E0")
        $panel.AddChild($statusLabel)
        
        $priorityLabel = [LabelComponent]::new("Priority")
        $priorityLabel.X = 25
        $priorityLabel.Y = $y
        $priorityLabel.Text = "Priority: $($task.Priority)"
        $priorityLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#E0E0E0")
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
        $progressColor = "#00BFFF"
        if ($task.Progress -eq 100) { $progressColor = "#00FF88" }
        $progressLabel.ForegroundColor = $progressColor
        $panel.AddChild($progressLabel)
        
        $y += 2
        
        # Description
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            $descLabel = [LabelComponent]::new("DescLabel")
            $descLabel.X = 2
            $descLabel.Y = $y
            $descLabel.Text = "Description:"
            $descLabel.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#B0B0B0")
            $panel.AddChild($descLabel)
            
            $y++
            $descText = [LabelComponent]::new("DescText")
            $descText.X = 2
            $descText.Y = $y
            $descText.Text = $task.Description
            $descText.ForegroundColor = (Get-ThemeColor "Label.Foreground" "#E0E0E0")
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
        $dialog.Initialize()
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
        $dialog.Initialize()
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
        $dialog.Initialize()
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

    # === INPUT HANDLING (HYBRID WINDOW MODEL) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # ALWAYS FIRST - Let base handle Tab and component routing
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle screen-level shortcuts and actions
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                } else {
                    $actionService = $this.ServiceContainer?.GetService("ActionService")
                    if ($actionService) {
                        $actionService.ExecuteAction("navigation.dashboard", @{})
                    }
                }
                return $true
            }
            ([ConsoleKey]::F5) {
                $this._RefreshTasks()
                return $true
            }
            ([ConsoleKey]::F1) {
                # Show help dialog
                return $true
            }
            ([ConsoleKey]::Enter) {
                # If task list has focus and a task is selected, edit it
                if ($this.FocusedChild -eq $this._taskListBox -and $this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Spacebar) {
                # If task list has focus and a task is selected, toggle completion
                if ($this.FocusedChild -eq $this._taskListBox -and $this._selectedTask) {
                    $this._CompleteTask()
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Delete) {
                # If task list has focus and a task is selected, delete it
                if ($this.FocusedChild -eq $this._taskListBox -and $this._selectedTask) {
                    $this._DeleteTask()
                    return $true
                }
                return $false
            }
        }
        
        # Handle letter shortcuts
        switch ($keyInfo.KeyChar) {
            'n' { $this._ShowNewTaskDialog(); return $true }
            'N' { $this._ShowNewTaskDialog(); return $true }
            'e' { 
                if ($this._selectedTask) { 
                    $this._ShowEditTaskDialog()
                    return $true 
                }
                return $false
            }
            'E' { 
                if ($this._selectedTask) { 
                    $this._ShowEditTaskDialog()
                    return $true 
                }
                return $false
            }
            'd' { 
                if ($this._selectedTask) { 
                    $this._DeleteTask()
                    return $true 
                }
                return $false
            }
            'D' { 
                if ($this._selectedTask) { 
                    $this._DeleteTask()
                    return $true 
                }
                return $false
            }
            'c' { 
                if ($this._selectedTask) { 
                    $this._CompleteTask()
                    return $true 
                }
                return $false
            }
            'C' { 
                if ($this._selectedTask) { 
                    $this._CompleteTask()
                    return $true 
                }
                return $false
            }
            's' { $this._CycleSortMode(); return $true }
            'S' { $this._CycleSortMode(); return $true }
            '/' { 
                # Focus the filter box
                $this.SetChildFocus($this._filterBox)
                return $true 
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF TASK LIST SCREEN
# ==============================================================================