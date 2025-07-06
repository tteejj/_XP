# ==============================================================================
# Axiom-Phoenix v4.0 - All Screens (Load After Components)
# Application screens that extend Screen base class
# ==============================================================================

using namespace System.Collections.Generic

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
    #endregion

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        Write-Host "DashboardScreen.Initialize called. Screen size: $($this.Width)x$($this.Height)" -ForegroundColor Green
        
        if (-not $this.ServiceContainer) {
            Write-Warning "DashboardScreen.Initialize: ServiceContainer is null"
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
        # Force a complete redraw of all panels
        if ($this._summaryPanel) { $this._summaryPanel.RequestRedraw() }
        if ($this._helpPanel) { $this._helpPanel.RequestRedraw() }
        if ($this._statusPanel) { $this._statusPanel.RequestRedraw() }
        if ($this._mainPanel) { $this._mainPanel.RequestRedraw() }
        
        if ($this.ServiceContainer) {
            $this._RefreshData($this.ServiceContainer.GetService("DataManager"))
        } else {
            Write-Warning "DashboardScreen.OnEnter: ServiceContainer is null, using defaults"
            $this._RefreshData($null)
        }
        
        # Force another redraw after data refresh
        $this.RequestRedraw()
    }

    hidden [void] _RefreshData([object]$dataManager) {
        if(-not $dataManager) {
            Write-Warning "DashboardScreen: DataManager service not found."
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

        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY

        # Simple text rendering using buffer
        $buffer.WriteString($contentX + 1, $contentY, "Task Overview", [ConsoleColor]::Cyan, [ConsoleColor]::Black)
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        if ($lineWidth -gt 0) {
            $buffer.WriteString($contentX + 1, $contentY + 1, ('─' * $lineWidth), [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
        }
        
        $buffer.WriteString($contentX + 1, $contentY + 3, "Total Tasks:    $($this._totalTasks)", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 4, "Completed:      $($this._completedTasks)", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 5, "Pending:        $($this._pendingTasks)", [ConsoleColor]::White, [ConsoleColor]::Black)
        
        $progress = $this._GetProgressBar()
        $buffer.WriteString($contentX + 1, $contentY + 7, "Overall Progress:", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 8, $progress, [ConsoleColor]::Yellow, [ConsoleColor]::Black)
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateHelpPanel() {
        $panel = $this._helpPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        $paletteHotkey = "Ctrl+P"
        
        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY
        
        $buffer.WriteString($contentX + 1, $contentY + 0, "Welcome to Axiom-Phoenix!", [ConsoleColor]::Cyan, [ConsoleColor]::Black)
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        if ($lineWidth -gt 0) {
            $buffer.WriteString($contentX + 1, $contentY + 1, ('─' * $lineWidth), [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
        }
        
        $buffer.WriteString($contentX + 1, $contentY + 3, "Press ", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 7, $contentY + 3, $paletteHotkey, [ConsoleColor]::Yellow, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 7 + $paletteHotkey.Length, $contentY + 3, " to open the", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 4, "Command Palette.", [ConsoleColor]::White, [ConsoleColor]::Black)

        $buffer.WriteString($contentX + 1, $contentY + 6, "All navigation and actions are", [ConsoleColor]::Gray, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 7, "now available from there.", [ConsoleColor]::Gray, [ConsoleColor]::Black)
        
        $panel.RequestRedraw()
    }
    
    hidden [void] _UpdateStatusPanel() {
        $panel = $this._statusPanel
        if (-not $panel) { return }
        
        # Clear children
        $panel.Children.Clear()

        $memoryMB = try { [Math]::Round((Get-Process -Id $global:PID).WorkingSet64 / 1MB, 2) } catch { 0 }

        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY
        
        $buffer.WriteString($contentX + 1, $contentY, "Environment", [ConsoleColor]::Cyan, [ConsoleColor]::Black)
        $lineWidth = [Math]::Max(0, $panel.ContentWidth - 2)
        if ($lineWidth -gt 0) {
            $buffer.WriteString($contentX + 1, $contentY + 1, ('─' * $lineWidth), [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
        }
        
        $buffer.WriteString($contentX + 1, $contentY + 3, "PowerShell Version: $($global:PSVersionTable.PSVersion)", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 4, "Memory Usage: ${memoryMB} MB", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $contentY + 5, "Host: $($global:Host.Name)", [ConsoleColor]::White, [ConsoleColor]::Black)
        
        $panel.RequestRedraw()
    }
    
    hidden [string] _GetProgressBar() {
        if ($this._totalTasks -eq 0) { return "[No Tasks]" }
        $percentage = [Math]::Round(($this._completedTasks / $this._totalTasks) * 100)
        $barWidth = 20
        $filled = [Math]::Max(0, [Math]::Floor($barWidth * ($percentage / 100)))
        $empty = [Math]::Max(0, $barWidth - $filled)
        $filledBar = if ($filled -gt 0) { '█' * $filled } else { '' }
        $emptyBar = if ($empty -gt 0) { '░' * $empty } else { '' }
        return "[" + $filledBar + $emptyBar + "] $percentage%"
    }

    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Dashboard doesn't handle specific input - all navigation via command palette
        # Input not handled
    }
}

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
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) {
            Write-Warning "TaskListScreen.Initialize: ServiceContainer is null"
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
        if ($this.ServiceContainer) {
            $this._RefreshTasks()
        }
        
        $this.RequestRedraw()
    }

    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        if (-not $dataManager) {
            Write-Warning "TaskListScreen: DataManager service not found"
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
        
        # Clear children
        $panel.Children.Clear()
        
        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY
        $contentHeight = $panel.ContentHeight
        
        if ($this._tasks.Count -eq 0) {
            $buffer.WriteString($contentX + 2, $contentY + 2, "No tasks found.", [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
            return
        }
        
        # Render tasks
        $startIndex = $panel.ScrollOffsetY
        $endIndex = [Math]::Min($startIndex + $contentHeight, $this._tasks.Count)
        
        for ($i = $startIndex; $i -lt $endIndex; $i++) {
            $task = $this._tasks[$i]
            $y = $contentY + ($i - $startIndex)
            
            # Highlight selected task
            $bgColor = if ($i -eq $this._selectedIndex) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Black }
            $fgColor = if ($i -eq $this._selectedIndex) { [ConsoleColor]::White } else { [ConsoleColor]::Gray }
            
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
            $maxTitleLength = $panel.ContentWidth - 10
            $title = if ($task.Title.Length -gt $maxTitleLength) {
                $task.Title.Substring(0, $maxTitleLength - 3) + "..."
            } else {
                $task.Title
            }
            
            $taskLine = "$statusChar $priorityChar $title"
            
            # Fill entire line with background color
            for ($x = 0; $x -lt $panel.ContentWidth; $x++) {
                $buffer.SetCell($contentX + $x, $y, [TuiCell]::new(' ', $fgColor, $bgColor))
            }
            
            $buffer.WriteString($contentX + 1, $y, $taskLine, $fgColor, $bgColor)
        }
        
        # Update scrollbar
        $panel.UpdateMaxScroll()
    }

    hidden [void] _UpdateDetailPanel() {
        $panel = $this._detailPanel
        if (-not $panel -or -not $this._selectedTask) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        $task = $this._selectedTask
        $buffer = $panel.GetBuffer()
        $contentX = $panel.ContentX
        $contentY = $panel.ContentY
        
        # Task details
        $y = $contentY
        $buffer.WriteString($contentX + 1, $y++, "Title: $($task.Title)", [ConsoleColor]::White, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $y++, "Status: $($task.Status)", [ConsoleColor]::Cyan, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $y++, "Priority: $($task.Priority)", [ConsoleColor]::Yellow, [ConsoleColor]::Black)
        $buffer.WriteString($contentX + 1, $y++, "Progress: $($task.Progress)%", [ConsoleColor]::Green, [ConsoleColor]::Black)
        
        $y++
        $buffer.WriteString($contentX + 1, $y++, "Description:", [ConsoleColor]::Gray, [ConsoleColor]::Black)
        
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            # Word wrap description
            $words = $task.Description -split '\s+'
            $line = ""
            $maxLineLength = $panel.ContentWidth - 2
            
            foreach ($word in $words) {
                if (($line + " " + $word).Length -gt $maxLineLength) {
                    if ($line) {
                        $buffer.WriteString($contentX + 1, $y++, $line, [ConsoleColor]::White, [ConsoleColor]::Black)
                    }
                    $line = $word
                } else {
                    $line = if ($line) { "$line $word" } else { $word }
                }
            }
            
            if ($line) {
                $buffer.WriteString($contentX + 1, $y++, $line, [ConsoleColor]::White, [ConsoleColor]::Black)
            }
        } else {
            $buffer.WriteString($contentX + 1, $y++, "(No description)", [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
        }
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateStatusBar() {
        $panel = $this._statusBar
        if (-not $panel) { return }
        
        $buffer = $panel.GetBuffer()
        
        $statusText = "Tasks: $($this._tasks.Count) | Selected: $($this._selectedIndex + 1)"
        if ($this._filterText) {
            $statusText += " | Filter: '$($this._filterText)'"
        }
        
        $buffer.WriteString(0, 0, $statusText, [ConsoleColor]::White, [ConsoleColor]::Black)
        
        # Keyboard hints
        $hints = "↑↓: Navigate | Enter: Edit | D: Delete | N: New"
        $hintsX = $this.Width - $hints.Length - 3
        if ($hintsX -gt $statusText.Length + 2) {
            $buffer.WriteString($hintsX, 0, $hints, [ConsoleColor]::DarkGray, [ConsoleColor]::Black)
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
