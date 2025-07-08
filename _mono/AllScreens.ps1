# ==============================================================================
# Axiom-Phoenix v4.0 - All Screens (Load After Components)
# Application screens that extend Screen base class
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASC.###" to find specific sections.
# Each section ends with "END_PAGE: ASC.###"
# ==============================================================================

using namespace System.Collections.Generic

#<!-- PAGE: ASC.001 - DashboardScreen Class -->
#region Screen Classes

class DashboardScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_summaryPanel
    hidden [Panel] $_statusPanel
    hidden [Panel] $_helpPanel
    #endregion

    #region State
    hidden [int] $_totalTasks = 0
    hidden [int] $_completedTasks = 0
    hidden [int] $_pendingTasks = 0
    hidden [string] $_dataChangeSubscriptionId = $null # Store event subscription ID
    #endregion

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        Write-Verbose "DashboardScreen.Initialize called. Screen size: $($this.Width)x$($this.Height)"
        
        if (-not $this.ServiceContainer) {
            Write-Verbose "DashboardScreen.Initialize: ServiceContainer is null"
            return
        }
        
        $this._mainPanel = [Panel]::new("Axiom-Phoenix Dashboard")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = "Axiom-Phoenix Dashboard"
        $this.AddChild($this._mainPanel)

        $summaryWidth = [Math]::Floor($this.Width * 0.5)
        $this._summaryPanel = [Panel]::new("Task Summary")
        $this._summaryPanel.X = 1
        $this._summaryPanel.Y = 1
        $this._summaryPanel.Width = $summaryWidth
        $this._summaryPanel.Height = 12
        $this._summaryPanel.Title = "Task Summary"
        $this._mainPanel.AddChild($this._summaryPanel)

        $helpX = $summaryWidth + 2
        $helpWidth = $this.Width - $helpX - 1
        $this._helpPanel = [Panel]::new("Quick Start")
        $this._helpPanel.X = $helpX
        $this._helpPanel.Y = 1
        $this._helpPanel.Width = $helpWidth
        $this._helpPanel.Height = 12
        $this._helpPanel.Title = "Quick Start"
        $this._mainPanel.AddChild($this._helpPanel)

        $this._statusPanel = [Panel]::new("System Status")
        $this._statusPanel.X = 1
        $this._statusPanel.Y = 14
        $this._statusPanel.Width = $this.Width - 2
        $this._statusPanel.Height = $this.Height - 15
        $this._statusPanel.Title = "System Status"
        $this._mainPanel.AddChild($this._statusPanel)
    }

    [void] OnEnter() {
        # Subscribe to data change events for reactive updates
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            # Create handler that properly captures $this
            $thisScreen = $this
            $handler = {
                param($eventData)
                Write-Verbose "DashboardScreen received data change event. Refreshing..."
                $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
                $thisScreen._RefreshData($dataManager)
            }.GetNewClosure()
            
            # Subscribe to both task and project changes
            $this._dataChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
            Write-Verbose "DashboardScreen subscribed to data change events"
        }
        
        # Force a complete redraw of all panels
        if ($this._summaryPanel) { $this._summaryPanel.RequestRedraw() }
        if ($this._helpPanel) { $this._helpPanel.RequestRedraw() }
        if ($this._statusPanel) { $this._statusPanel.RequestRedraw() }
        if ($this._mainPanel) { $this._mainPanel.RequestRedraw() }
        
        if ($this.ServiceContainer) {
            $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
        } else {
            Write-Verbose "DashboardScreen.OnEnter: ServiceContainer is null, using defaults"
            $this._RefreshData($null)
        }
        
        # Force another redraw after data refresh
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        # Unsubscribe from data change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._dataChangeSubscriptionId) {
            $eventManager.Unsubscribe("Tasks.Changed", $this._dataChangeSubscriptionId)
            $this._dataChangeSubscriptionId = $null
            Write-Verbose "DashboardScreen unsubscribed from data change events"
        }
        
        # Call base OnExit
        ([Screen]$this).OnExit()
    }

    hidden [void] _RefreshData([object]$dataManager) {
        if(-not $dataManager) {
            Write-Verbose "DashboardScreen: DataManager service not found."
            $this._totalTasks = 0
            $this._completedTasks = 0
            $this._pendingTasks = 0
        } else {
            $allTasks = $dataManager.GetTasks()
            if ($allTasks) {
                $this._totalTasks = @($allTasks).Count
                $this._completedTasks = @($allTasks | Where-Object { $_.Completed }).Count
                $this._pendingTasks = $this._totalTasks - $this._completedTasks
            } else {
                $this._totalTasks = 0
                $this._completedTasks = 0
                $this._pendingTasks = 0
            }
        }
        $this._UpdateDisplay()
    }
    
    hidden [void] _UpdateDisplay() {
        $this._UpdateSummaryPanel()
        $this._UpdateHelpPanel()
        $this._UpdateStatusPanel()
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateSummaryPanel() {
        $panel = $this._summaryPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()

        # Create label components instead of direct buffer drawing
        $titleLabel = [LabelComponent]::new("SummaryTitle")
        $titleLabel.Text = "Task Overview"
        $titleLabel.ForegroundColor = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF"
        $titleLabel.X = 1
        $titleLabel.Y = 0
        $titleLabel.Width = $panel.ContentWidth - 2
        $titleLabel.Height = 1
        $panel.AddChild($titleLabel)
        
        $separatorLabel = [LabelComponent]::new("SummarySeparator")
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        $separatorLabel.Text = if ($lineWidth -gt 0) { '─' * $lineWidth } else { "" }
        $separatorLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $separatorLabel.X = 1
        $separatorLabel.Y = 1
        $separatorLabel.Width = $panel.ContentWidth - 2
        $separatorLabel.Height = 1
        $panel.AddChild($separatorLabel)
        
        $totalLabel = [LabelComponent]::new("TotalTasks")
        $totalLabel.Text = "Total Tasks:    $($this._totalTasks)"
        $totalLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $totalLabel.X = 1
        $totalLabel.Y = 3
        $totalLabel.Width = $panel.ContentWidth - 2
        $totalLabel.Height = 1
        $panel.AddChild($totalLabel)
        
        $completedLabel = [LabelComponent]::new("CompletedTasks")
        $completedLabel.Text = "Completed:      $($this._completedTasks)"
        $completedLabel.ForegroundColor = Get-ThemeColor -ColorName "Success" -DefaultColor "#00FF00"
        $completedLabel.X = 1
        $completedLabel.Y = 4
        $completedLabel.Width = $panel.ContentWidth - 2
        $completedLabel.Height = 1
        $panel.AddChild($completedLabel)
        
        $pendingLabel = [LabelComponent]::new("PendingTasks")
        $pendingLabel.Text = "Pending:        $($this._pendingTasks)"
        $pendingLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
        $pendingLabel.X = 1
        $pendingLabel.Y = 5
        $pendingLabel.Width = $panel.ContentWidth - 2
        $pendingLabel.Height = 1
        $panel.AddChild($pendingLabel)
        
        # Create progress bar as labels
        $percentage = if ($this._totalTasks -eq 0) { 0 } else { [Math]::Round(($this._completedTasks / $this._totalTasks) * 100) }
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Overall Progress: $percentage%"
        $progressLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $progressLabel.X = 1
        $progressLabel.Y = 7
        $progressLabel.Width = $panel.ContentWidth - 2
        $progressLabel.Height = 1
        $panel.AddChild($progressLabel)
        
        # Progress bar visualization
        $barWidth = 20
        $filledWidth = [Math]::Floor($barWidth * $percentage / 100)
        $emptyWidth = $barWidth - $filledWidth
        $barText = "[" + ("█" * $filledWidth) + ("░" * $emptyWidth) + "]"
        
        $barLabel = [LabelComponent]::new("ProgressBar")
        $barLabel.Text = $barText
        $barLabel.ForegroundColor = Get-ThemeColor -ColorName "Success" -DefaultColor "#00FF00"
        $barLabel.X = 1
        $barLabel.Y = 8
        $barLabel.Width = $panel.ContentWidth - 2
        $barLabel.Height = 1
        $panel.AddChild($barLabel)
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateHelpPanel() {
        $panel = $this._helpPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        $paletteHotkey = "Ctrl+P"
        
        # Create label components for help panel
        $welcomeLabel = [LabelComponent]::new("WelcomeLabel")
        $welcomeLabel.Text = "Welcome to Axiom-Phoenix!"
        $welcomeLabel.ForegroundColor = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF"
        $welcomeLabel.X = 1
        $welcomeLabel.Y = 0
        $welcomeLabel.Width = $panel.ContentWidth - 2
        $welcomeLabel.Height = 1
        $panel.AddChild($welcomeLabel)
        
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        if ($lineWidth -gt 0) {
            $separatorLabel = [LabelComponent]::new("HelpSeparator")
            $separatorLabel.Text = '─' * $lineWidth
            $separatorLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $separatorLabel.X = 1
            $separatorLabel.Y = 1
            $separatorLabel.Width = $panel.ContentWidth - 2
            $separatorLabel.Height = 1
            $panel.AddChild($separatorLabel)
        }
        
        # Create multi-part label for the hotkey instruction
        $instructionLabel1 = [LabelComponent]::new("Instruction1")
        $instructionLabel1.Text = "Press $paletteHotkey to open the"
        $instructionLabel1.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $instructionLabel1.X = 1
        $instructionLabel1.Y = 3
        $instructionLabel1.Width = $panel.ContentWidth - 2
        $instructionLabel1.Height = 1
        $panel.AddChild($instructionLabel1)
        
        $instructionLabel2 = [LabelComponent]::new("Instruction2")
        $instructionLabel2.Text = "Command Palette."
        $instructionLabel2.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $instructionLabel2.X = 1
        $instructionLabel2.Y = 4
        $instructionLabel2.Width = $panel.ContentWidth - 2
        $instructionLabel2.Height = 1
        $panel.AddChild($instructionLabel2)

        $infoLabel1 = [LabelComponent]::new("InfoLabel1")
        $infoLabel1.Text = "All navigation and actions are"
        $infoLabel1.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $infoLabel1.X = 1
        $infoLabel1.Y = 6
        $infoLabel1.Width = $panel.ContentWidth - 2
        $infoLabel1.Height = 1
        $panel.AddChild($infoLabel1)
        
        $infoLabel2 = [LabelComponent]::new("InfoLabel2")
        $infoLabel2.Text = "now available from there."
        $infoLabel2.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $infoLabel2.X = 1
        $infoLabel2.Y = 7
        $infoLabel2.Width = $panel.ContentWidth - 2
        $infoLabel2.Height = 1
        $panel.AddChild($infoLabel2)
        
        $panel.RequestRedraw()
    }
    
    hidden [void] _UpdateStatusPanel() {
        $panel = $this._statusPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()

        $memoryMB = try { [Math]::Round((Get-Process -Id $global:PID).WorkingSet64 / 1MB, 2) } catch { 0 }

        # Create label components for status panel
        $titleLabel = [LabelComponent]::new("StatusTitle")
        $titleLabel.Text = "Environment"
        $titleLabel.ForegroundColor = Get-ThemeColor -ColorName "Primary" -DefaultColor "#00FFFF"
        $titleLabel.X = 1
        $titleLabel.Y = 0
        $titleLabel.Width = $panel.ContentWidth - 2
        $titleLabel.Height = 1
        $panel.AddChild($titleLabel)
        
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        if ($lineWidth -gt 0) {
            $separatorLabel = [LabelComponent]::new("StatusSeparator")
            $separatorLabel.Text = '─' * $lineWidth
            $separatorLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $separatorLabel.X = 1
            $separatorLabel.Y = 1
            $separatorLabel.Width = $panel.ContentWidth - 2
            $separatorLabel.Height = 1
            $panel.AddChild($separatorLabel)
        }
        
        $versionLabel = [LabelComponent]::new("PSVersion")
        $versionLabel.Text = "PowerShell Version: $($global:PSVersionTable.PSVersion)"
        $versionLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $versionLabel.X = 1
        $versionLabel.Y = 3
        $versionLabel.Width = $panel.ContentWidth - 2
        $versionLabel.Height = 1
        $panel.AddChild($versionLabel)
        
        $memoryLabel = [LabelComponent]::new("MemoryUsage")
        $memoryLabel.Text = "Memory Usage: ${memoryMB} MB"
        $memoryLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $memoryLabel.X = 1
        $memoryLabel.Y = 4
        $memoryLabel.Width = $panel.ContentWidth - 2
        $memoryLabel.Height = 1
        $panel.AddChild($memoryLabel)
        
        $hostLabel = [LabelComponent]::new("HostName")
        $hostLabel.Text = "Host: $($global:Host.Name)"
        $hostLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $hostLabel.X = 1
        $hostLabel.Y = 5
        $hostLabel.Width = $panel.ContentWidth - 2
        $hostLabel.Height = 1
        $panel.AddChild($hostLabel)
        
        $panel.RequestRedraw()
    }


    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Dashboard doesn't handle specific input - all navigation via command palette
        # Input not handled
    }
}

#endregion
#<!-- END_PAGE: ASC.001 -->

#<!-- PAGE: ASC.002 - TaskListScreen Class -->
#region TaskListScreen Class

class TaskListScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [ScrollablePanel] $_taskListPanel
    hidden [Panel] $_detailPanel
    hidden [Panel] $_statusBar
    #endregion

    #region State
    hidden [System.Collections.Generic.List[PmcTask]] $_tasks
    hidden [int] $_selectedIndex = 0
    hidden [PmcTask] $_selectedTask
    hidden [string] $_filterText = ""
    hidden [TaskStatus] $_filterStatus = $null
    hidden [TaskPriority] $_filterPriority = $null
    hidden [string] $_taskChangeSubscriptionId = $null # Store event subscription ID
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) {
            Write-Verbose "TaskListScreen.Initialize: ServiceContainer is null"
            return
        }
        
        $this._mainPanel = [Panel]::new("Task List")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = "Task List"
        $this.AddChild($this._mainPanel)

        # Task list panel (left side)
        $listWidth = [Math]::Floor($this.Width * 0.6)
        $this._taskListPanel = [ScrollablePanel]::new("Tasks")
        $this._taskListPanel.X = 1
        $this._taskListPanel.Y = 1
        $this._taskListPanel.Width = $listWidth
        $this._taskListPanel.Height = $this.Height - 4
        $this._taskListPanel.Title = "Tasks"
        $this._mainPanel.AddChild($this._taskListPanel)

        # Detail panel (right side)
        $detailX = $listWidth + 2
        $detailWidth = $this.Width - $detailX - 1
        $this._detailPanel = [Panel]::new("Task Details")
        $this._detailPanel.X = $detailX
        $this._detailPanel.Y = 1
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - 4
        $this._detailPanel.Title = "Task Details"
        $this._mainPanel.AddChild($this._detailPanel)

        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 2
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 1
        $this._statusBar.HasBorder = $false
        $this._mainPanel.AddChild($this._statusBar)
        
        $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
    }

    [void] OnEnter() {
        # Subscribe to data change events for reactive updates
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            # Create handler that properly captures $this
            $thisScreen = $this
            $handler = {
                param($eventData)
                Write-Verbose "TaskListScreen received Tasks.Changed event. Refreshing tasks."
                $thisScreen._RefreshTasks()
                $thisScreen._UpdateDisplay()
            }.GetNewClosure()
            
            # Store subscription ID for later cleanup
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
            Write-Verbose "TaskListScreen subscribed to Tasks.Changed events"
        }
        
        if ($this.ServiceContainer) {
            $this._RefreshTasks()
        }
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        # Unsubscribe from data change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._taskChangeSubscriptionId) {
            $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
            $this._taskChangeSubscriptionId = $null
            Write-Verbose "TaskListScreen unsubscribed from Tasks.Changed events"
        }
        
        # Call base OnExit if needed
        ([Screen]$this).OnExit()
    }

    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        if (-not $dataManager) {
            Write-Verbose "TaskListScreen: DataManager service not found"
            return
        }
        
        $allTasks = $dataManager.GetTasks()
        $this._tasks.Clear()
        if ($allTasks -and $allTasks.Count -gt 0) {
            $this._tasks.AddRange($allTasks)
        }
        
        # Apply filters if any
        if (-not [string]::IsNullOrEmpty($this._filterText)) {
            $filtered = $this._tasks | Where-Object { 
                $_.Title -like "*$($this._filterText)*" -or 
                $_.Description -like "*$($this._filterText)*" 
            }
            $this._tasks.Clear()
            if ($filtered) {
                $this._tasks.AddRange(@($filtered))
            }
        }
        
        if ($null -ne $this._filterStatus) {
            $filtered = $this._tasks | Where-Object { $_.Status -eq $this._filterStatus }
            $this._tasks.Clear()
            if ($filtered) {
                $this._tasks.AddRange(@($filtered))
            }
        }
        
        if ($null -ne $this._filterPriority) {
            $filtered = $this._tasks | Where-Object { $_.Priority -eq $this._filterPriority }
            $this._tasks.Clear()
            if ($filtered) {
                $this._tasks.AddRange(@($filtered))
            }
        }
        
        # Update selection
        if ($this._selectedIndex -ge @($this._tasks).Count) {
            $this._selectedIndex = [Math]::Max(0, @($this._tasks).Count - 1)
        }
        
        if ($this._tasks.Count -gt 0) {
            $this._selectedTask = $this._tasks[$this._selectedIndex]
        } else {
            $this._selectedTask = $null
        }
        
        $this._UpdateDisplay()
    }

    hidden [void] _UpdateDisplay() {
        $this._UpdateTaskList()
        $this._UpdateDetailPanel()
        $this._UpdateStatusBar()
        $this.RequestRedraw()
    }

    hidden [void] _UpdateTaskList() {
        $panel = $this._taskListPanel
        if (-not $panel) { return }
        
        # CRITICAL: Clear the panel's CHILDREN, not its buffer directly.
        $panel.Children.Clear()
        
        if ($this._tasks.Count -eq 0) {
            # Add a label to show there are no tasks
            $noTasksLabel = [LabelComponent]::new("NoTasksLabel")
            $noTasksLabel.X = 2
            $noTasksLabel.Y = 2
            $noTasksLabel.Text = "No tasks found."
            $noTasksLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $panel.AddChild($noTasksLabel)
            $panel.RequestRedraw()
            return
        }
        
        for ($i = 0; $i -lt $this._tasks.Count; $i++) {
            $task = $this._tasks[$i]
            
            # Create a Panel for each task item (to support background color)
            $taskPanel = [Panel]::new("TaskItem_$($task.Id)")
            $taskPanel.X = 0
            $taskPanel.Y = $i # Y position is its index in the list
            $taskPanel.Width = $panel.ContentWidth
            $taskPanel.Height = 1
            $taskPanel.HasBorder = $false
            
            # Set background based on selection
            $is_selected = ($i -eq $this._selectedIndex)
            $taskPanel.BackgroundColor = if ($is_selected) { Get-ThemeColor -ColorName "list.item.selected.background" -DefaultColor "#0000FF" } else { Get-ThemeColor -ColorName "Background" -DefaultColor "#000000" }
            
            # Create a Label component for the task text
            $taskLabel = [LabelComponent]::new("TaskLabel_$($task.Id)")
            $taskLabel.X = 1 # Indent slightly
            $taskLabel.Y = 0 # Relative to the task panel
            
            # Status indicator
            $statusChar = switch ($task.Status) {
                ([TaskStatus]::Pending) { "○" }
                ([TaskStatus]::InProgress) { "◐" }
                ([TaskStatus]::Completed) { "●" }
                ([TaskStatus]::Cancelled) { "✕" }
                default { "?" }
            }
            
            # Priority indicator
            $priorityChar = switch ($task.Priority) {
                ([TaskPriority]::Low) { "↓" }
                ([TaskPriority]::Medium) { "→" }
                ([TaskPriority]::High) { "↑" }
                default { "-" }
            }
            
            # Truncate title if needed
            $maxTitleLength = $panel.ContentWidth - 6 # Adjusted for status/priority chars and padding
            $title = if ($task.Title.Length -gt $maxTitleLength) {
                $task.Title.Substring(0, $maxTitleLength - 3) + "..."
            } else {
                $task.Title
            }
            
            $taskLine = "$statusChar $priorityChar $title"
            $taskLabel.Text = $taskLine
            
            # Set text color based on selection
            $taskLabel.ForegroundColor = if ($is_selected) { Get-ThemeColor -ColorName "list.item.selected" -DefaultColor "#FFFFFF" } else { Get-ThemeColor -ColorName "list.item.normal" -DefaultColor "#C0C0C0" }
            
            # Add the label to the task panel
            $taskPanel.AddChild($taskLabel)
            
            # Add the task panel as a CHILD of the scrollable panel
            $panel.AddChild($taskPanel)
        }
        
        # The ScrollablePanel's own Render method will now correctly handle everything else.
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateDetailPanel() {
        $panel = $this._detailPanel
        if (-not $panel -or -not $this._selectedTask) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        $task = $this._selectedTask
        $y = 1 # Start position relative to panel
        
        # Title label
        $titleLabel = [LabelComponent]::new("DetailTitle")
        $titleLabel.X = 1
        $titleLabel.Y = $y++
        $titleLabel.Text = "Title: $($task.Title)"
        $titleLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
        $panel.AddChild($titleLabel)
        
        # Status label
        $statusLabel = [LabelComponent]::new("DetailStatus")
        $statusLabel.X = 1
        $statusLabel.Y = $y++
        $statusLabel.Text = "Status: $($task.Status)"
        $statusLabel.ForegroundColor = Get-ThemeColor -ColorName "Info" -DefaultColor "#00BFFF"
        $panel.AddChild($statusLabel)
        
        # Priority label
        $priorityLabel = [LabelComponent]::new("DetailPriority")
        $priorityLabel.X = 1
        $priorityLabel.Y = $y++
        $priorityLabel.Text = "Priority: $($task.Priority)"
        $priorityLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
        $panel.AddChild($priorityLabel)
        
        # Progress label
        $progressLabel = [LabelComponent]::new("DetailProgress")
        $progressLabel.X = 1
        $progressLabel.Y = $y++
        $progressLabel.Text = "Progress: $($task.Progress)%"
        $progressLabel.ForegroundColor = Get-ThemeColor -ColorName "Success" -DefaultColor "#00FF00"
        $panel.AddChild($progressLabel)
        
        $y++ # Empty line
        
        # Description header
        $descHeaderLabel = [LabelComponent]::new("DetailDescHeader")
        $descHeaderLabel.X = 1
        $descHeaderLabel.Y = $y++
        $descHeaderLabel.Text = "Description:"
        $descHeaderLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $panel.AddChild($descHeaderLabel)
        
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            # Word wrap description
            $words = $task.Description -split '\s+'
            $line = ""
            $maxLineLength = $panel.ContentWidth - 2
            $lineIndex = 0
            
            foreach ($word in $words) {
                if (($line + " " + $word).Length -gt $maxLineLength) {
                    if ($line) {
                        # Create label for this line
                        $descLineLabel = [LabelComponent]::new("DetailDescLine$lineIndex")
                        $descLineLabel.X = 1
                        $descLineLabel.Y = $y++
                        $descLineLabel.Text = $line
                        $descLineLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
                        $panel.AddChild($descLineLabel)
                        $lineIndex++
                    }
                    $line = $word
                } else {
                    $line = if ($line) { "$line $word" } else { $word }
                }
            }
            
            if ($line) {
                # Create label for last line
                $descLineLabel = [LabelComponent]::new("DetailDescLine$lineIndex")
                $descLineLabel.X = 1
                $descLineLabel.Y = $y++
                $descLineLabel.Text = $line
                $descLineLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground" -DefaultColor "#FFFFFF"
                $panel.AddChild($descLineLabel)
            }
        } else {
            $noDescLabel = [LabelComponent]::new("DetailNoDesc")
            $noDescLabel.X = 1
            $noDescLabel.Y = $y++
            $noDescLabel.Text = "(No description)"
            $noDescLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $panel.AddChild($noDescLabel)
        }
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateStatusBar() {
        $panel = $this._statusBar
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        # Set panel background color
        $panel.BackgroundColor = Get-ThemeColor -ColorName "status.bar.bg" -DefaultColor "#1E1E1E"
        
        # Status text label
        $statusText = "Tasks: $($this._tasks.Count) | Selected: $($this._selectedIndex + 1)"
        if ($this._filterText) {
            $statusText += " | Filter: '$($this._filterText)'"
        }
        
        $statusLabel = [LabelComponent]::new("StatusText")
        $statusLabel.X = 0
        $statusLabel.Y = 0
        $statusLabel.Text = $statusText
        $statusLabel.ForegroundColor = Get-ThemeColor -ColorName "status.bar.fg" -DefaultColor "#FFFFFF"
        $panel.AddChild($statusLabel)
        
        # Keyboard hints label
        $hints = "↑↓: Navigate | Enter: Edit | D: Delete | N: New"
        $hintsX = $this.Width - $hints.Length - 3
        if ($hintsX -gt $statusText.Length + 2) {
            $hintsLabel = [LabelComponent]::new("StatusHints")
            $hintsLabel.X = $hintsX
            $hintsLabel.Y = 0
            $hintsLabel.Text = $hints
            $hintsLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
            $panel.AddChild($hintsLabel)
        }
        
        $panel.RequestRedraw()
    }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    $this._selectedIndex--
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                    
                    # Adjust scroll if needed
                    if ($this._selectedIndex -lt $this._taskListPanel.ScrollOffsetY) {
                        $this._taskListPanel.ScrollUp()
                    }
                    
                    $this._UpdateDisplay()
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this._selectedIndex -lt $this._tasks.Count - 1) {
                    $this._selectedIndex++
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                    
                    # Adjust scroll if needed
                    $visibleEnd = $this._taskListPanel.ScrollOffsetY + $this._taskListPanel.ContentHeight - 1
                    if ($this._selectedIndex -gt $visibleEnd) {
                        $this._taskListPanel.ScrollDown()
                    }
                    
                    $this._UpdateDisplay()
                }
            }
            ([ConsoleKey]::PageUp) {
                $this._taskListPanel.ScrollUp($this._taskListPanel.ContentHeight)
                $this._selectedIndex = [Math]::Max(0, $this._selectedIndex - $this._taskListPanel.ContentHeight)
                if ($this._tasks.Count -gt 0) {
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                }
                $this._UpdateDisplay()
            }
            ([ConsoleKey]::PageDown) {
                $this._taskListPanel.ScrollDown($this._taskListPanel.ContentHeight)
                $this._selectedIndex = [Math]::Min($this._tasks.Count - 1, $this._selectedIndex + $this._taskListPanel.ContentHeight)
                if ($this._tasks.Count -gt 0) {
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                }
                $this._UpdateDisplay()
            }
            ([ConsoleKey]::Home) {
                $this._taskListPanel.ScrollToTop()
                $this._selectedIndex = 0
                if ($this._tasks.Count -gt 0) {
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                }
                $this._UpdateDisplay()
            }
            ([ConsoleKey]::End) {
                $this._taskListPanel.ScrollToBottom()
                $this._selectedIndex = $this._tasks.Count - 1
                if ($this._tasks.Count -gt 0) {
                    $this._selectedTask = $this._tasks[$this._selectedIndex]
                }
                $this._UpdateDisplay()
            }
            ([ConsoleKey]::Enter) {
                # Edit task - would trigger command palette or dialog
                Write-Verbose "TaskListScreen: Edit task requested for: $($this._selectedTask.Title)"
            }
            ([ConsoleKey]::D) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # Delete task
                    Write-Verbose "TaskListScreen: Delete task requested for: $($this._selectedTask.Title)"
                }
            }
            ([ConsoleKey]::N) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # New task
                    Write-Verbose "TaskListScreen: New task requested"
                }
            }
            default {
                # Unhandled key
            }
        }
    }
}

#endregion
#<!-- END_PAGE: ASC.002 -->

#<!-- PAGE: ASC.003 - Screen Utilities -->
#region Screen Utilities

# No specific screen utility functions currently implemented
# This section reserved for future screen helper functions

#endregion
#<!-- END_PAGE: ASC.003 -->
