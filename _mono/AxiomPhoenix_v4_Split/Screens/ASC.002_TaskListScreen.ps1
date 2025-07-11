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

#region TaskListScreen Class

class TaskListScreen : Screen { 
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [Panel] $_listPanel          # Left panel for task list
    hidden [Panel] $_contextPanel       # Top-right panel for filters
    hidden [Panel] $_detailPanel        # Main-right panel for details
    hidden [Panel] $_statusBar          # Bottom status bar
    hidden [ListBox] $_taskListBox      # Simplified task list
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
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }
        
        # Ensure minimum size
        if ($this.Width -lt 120) { $this.Width = 120 }
        if ($this.Height -lt 30) { $this.Height = 30 }
        
        # Main panel with sophisticated styling
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

        # === LEFT PANEL: Clean Task List ===
        $this._listPanel = [Panel]::new("TaskList")
        $this._listPanel.X = 1
        $this._listPanel.Y = 1
        $this._listPanel.Width = $listWidth
        $this._listPanel.Height = $this.Height - 5  # Leave room for status bar
        $this._listPanel.Title = " Tasks "
        $this._listPanel.BorderStyle = "Single"
        $this._listPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $this._mainPanel.AddChild($this._listPanel)

        # Project selector button at top of list
        $this._projectButton = [ButtonComponent]::new("ProjectSelector")
        $this._projectButton.Text = "▼ $($this._currentProject)"
        $this._projectButton.X = 2
        $this._projectButton.Y = 1
        $this._projectButton.Width = $listWidth - 4
        $this._projectButton.Height = 1
        $thisScreen = $this
        $this._projectButton.OnClick = {
            # TODO: Show project picker dialog
            Write-Host "Project picker coming soon!" -ForegroundColor Yellow
        }.GetNewClosure()
        $this._listPanel.AddChild($this._projectButton)

        # Task list with elegant styling
        $this._taskListBox = [ListBox]::new("TaskList")
        $this._taskListBox.X = 1
        $this._taskListBox.Y = 3
        $this._taskListBox.Width = $listWidth - 2
        $this._taskListBox.Height = $this._listPanel.Height - 5
        $this._taskListBox.HasBorder = $false
        $this._taskListBox.SelectedBackgroundColor = Get-ThemeColor "list.selected.bg" "#1E3A8A"
        $this._taskListBox.SelectedForegroundColor = Get-ThemeColor "list.selected.fg" "#FFFFFF"
        $this._taskListBox.ItemForegroundColor = Get-ThemeColor "list.item.fg" "#E0E0E0"
        $thisScreen = $this
        $this._taskListBox.SelectedIndexChanged = {
            param($sender, $index)
            $thisScreen._selectedIndex = $index
            if ($index -ge 0 -and $index -lt $thisScreen._filteredTasks.Count) {
                $thisScreen._selectedTask = $thisScreen._filteredTasks[$index]
            } else {
                $thisScreen._selectedTask = $null
            }
            $thisScreen._UpdateDetailPanel()
        }.GetNewClosure()
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
        $this._filterBox.Height = 1
        $thisScreen = $this
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
        $this._sortLabel.ForegroundColor = Get-ThemeColor "muted" "#888888"
        $this._contextPanel.AddChild($this._sortLabel)

        # Help text
        $this._helpLabel = [LabelComponent]::new("HelpLabel")
        $this._helpLabel.X = 2
        $this._helpLabel.Y = 3
        $this._helpLabel.Text = "↑↓ Navigate │ Enter Edit │ Space Toggle │ N New │ D Delete │ C Complete"
        $this._helpLabel.ForegroundColor = Get-ThemeColor "help" "#666666"
        $this._contextPanel.AddChild($this._helpLabel)

        # === MAIN-RIGHT PANEL: Rich Task Details ===
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

        # Action buttons with modern styling
        $buttonY = 1
        $actions = @(
            @{ Text = "[N]ew"; Key = "N"; Color = "#00FF88"; Action = { $this._ShowNewTaskDialog() } },
            @{ Text = "[E]dit"; Key = "E"; Color = "#00BFFF"; Action = { $this._ShowEditTaskDialog() } },
            @{ Text = "[D]elete"; Key = "D"; Color = "#FF4444"; Action = { $this._DeleteTask() } },
            @{ Text = "[C]omplete"; Key = "C"; Color = "#FFD700"; Action = { $this._CompleteTask() } },
            @{ Text = "[T]ags"; Key = "T"; Color = "#FF69B4"; Action = { $this._ShowTagsDialog() } },
            @{ Text = "[S]ort"; Key = "S"; Color = "#8A2BE2"; Action = { $this._CycleSortMode() } },
            @{ Text = "[Ctrl+Q]uit"; Key = "Q"; Color = "#666666"; Action = { $this._Exit() } }
        )

        $x = 2
        foreach ($action in $actions) {
            $button = [LabelComponent]::new("Action_$($action.Key)")
            $button.X = $x
            $button.Y = $buttonY
            $button.Text = $action.Text
            $button.ForegroundColor = $action.Color
            $this._statusBar.AddChild($button)
            $x += $action.Text.Length + 3
        }
    }

    [void] OnEnter() {
        # Following Rule 2.3: OnEnter() Checklist
        
        # Step 1: Fetch initial data from services  
        $this._RefreshTasks()
        
        # Step 2: Set initial focus via FocusManager (CRITICAL for input to work)
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._taskListBox) {
            $focusManager.SetFocus($this._taskListBox)
        }
        
        # Step 3: Subscribe to EventManager events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            # Create handler that properly captures $this
            $thisScreen = $this
            $handler = {
                param($eventData)
                $thisScreen._RefreshTasks()
            }.GetNewClosure()
            
            # Store subscription ID for later cleanup
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
        }
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        # Unsubscribe from data change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._taskChangeSubscriptionId) {
            $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
            $this._taskChangeSubscriptionId = $null
            # Write-Verbose "TaskListScreen unsubscribed from Tasks.Changed events"
        }
        
        # Call base OnExit if needed
        ([Screen]$this).OnExit()
    }

    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if ($dataManager) {
            $allTasks = $dataManager.GetTasks()
            
            # Clear filtered tasks
            $this._filteredTasks.Clear()
            
            # Apply filters
            foreach ($task in $allTasks) {
                # Skip if not matching project filter
                if ($this._currentProject -ne "All Projects" -and $task.ProjectKey -ne $this._currentProject) {
                    continue
                }
                
                # Skip if not matching text filter
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
        
        # Reset selection if needed
        if ($this._selectedIndex -ge $this._filteredTasks.Count) {
            $this._selectedIndex = [Math]::Max(0, $this._filteredTasks.Count - 1)
        }
        
        if ($this._filteredTasks.Count -gt 0) {
            $this._selectedTask = $this._filteredTasks[$this._selectedIndex]
        } else {
            $this._selectedTask = $null
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
            
            # Format: "○ ! Task Title"
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
        
        # === TASK TITLE HEADER ===
        $titlePanel = [Panel]::new("TitleHeader")
        $titlePanel.X = 2
        $titlePanel.Y = $y
        $titlePanel.Width = $panel.ContentWidth - 4
        $titlePanel.Height = 3
        $titlePanel.BorderStyle = "Double"
        $titlePanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
        $titlePanel.BackgroundColor = Get-ThemeColor "header.bg" "#0D1929"
        $panel.AddChild($titlePanel)
        
        $titleLabel = [LabelComponent]::new("TaskTitle")
        $titleLabel.X = 2
        $titleLabel.Y = 1
        $titleLabel.Text = $task.Title
        $titleLabel.ForegroundColor = Get-ThemeColor "title" "#FFFFFF"
        $titlePanel.AddChild($titleLabel)
        
        $y += 4
        
        # === STATUS AND PRIORITY ROW ===
        $statusRow = [Panel]::new("StatusRow")
        $statusRow.X = 2
        $statusRow.Y = $y
        $statusRow.Width = $panel.ContentWidth - 4
        $statusRow.Height = 3
        $statusRow.HasBorder = $false
        $panel.AddChild($statusRow)
        
        # Status badge
        $statusBg = switch ($task.Status) {
            ([TaskStatus]::Pending) { "#FFA500" }
            ([TaskStatus]::InProgress) { "#00BFFF" }
            ([TaskStatus]::Completed) { "#00FF88" }
            ([TaskStatus]::Cancelled) { "#FF4444" }
            default { "#808080" }
        }
        
        $statusLabel = [LabelComponent]::new("StatusBadge")
        $statusLabel.X = 0
        $statusLabel.Y = 0
        $statusLabel.Text = " $($task.Status) "
        $statusLabel.BackgroundColor = $statusBg
        $statusLabel.ForegroundColor = "#000000"
        $statusRow.AddChild($statusLabel)
        
        # Priority badge
        $priorityX = $statusLabel.Text.Length + 2
        $priorityBg = switch ($task.Priority) {
            ([TaskPriority]::Low) { "#2E7D32" }
            ([TaskPriority]::Medium) { "#ED6C02" }
            ([TaskPriority]::High) { "#D32F2F" }
            default { "#808080" }
        }
        
        $priorityLabel = [LabelComponent]::new("PriorityBadge")
        $priorityLabel.X = $priorityX
        $priorityLabel.Y = 0
        $priorityLabel.Text = " $($task.Priority) Priority "
        $priorityLabel.BackgroundColor = $priorityBg
        $priorityLabel.ForegroundColor = "#FFFFFF"
        $statusRow.AddChild($priorityLabel)
        
        # Progress bar
        $progressX = $priorityX + $priorityLabel.Text.Length + 2
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.X = $progressX
        $progressLabel.Y = 0
        $progressLabel.Text = "Progress:"
        $progressLabel.ForegroundColor = Get-ThemeColor "label" "#B0B0B0"
        $statusRow.AddChild($progressLabel)
        
        $barX = $progressX + 10
        $barWidth = 20
        $filledWidth = [Math]::Floor($barWidth * $task.Progress / 100)
        $progressBar = [LabelComponent]::new("ProgressBar")
        $progressBar.X = $barX
        $progressBar.Y = 0
        $progressBar.Text = "█" * $filledWidth + "░" * ($barWidth - $filledWidth) + " $($task.Progress)%"
        $progressBar.ForegroundColor = if ($task.Progress -eq 100) { "#00FF88" } else { "#00BFFF" }
        $statusRow.AddChild($progressBar)
        
        $y += 4
        
        # === PROJECT AND DUE DATE ===
        $metaPanel = [Panel]::new("MetaInfo")
        $metaPanel.X = 2
        $metaPanel.Y = $y
        $metaPanel.Width = $panel.ContentWidth - 4
        $metaPanel.Height = 4
        $metaPanel.BorderStyle = "Single"
        $metaPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $metaPanel.BackgroundColor = Get-ThemeColor "meta.bg" "#111111"
        $panel.AddChild($metaPanel)
        
        # Project
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.X = 2
        $projectLabel.Y = 1
        $projectLabel.Text = "Project: $($task.ProjectKey)"
        $projectLabel.ForegroundColor = Get-ThemeColor "project" "#FFD700"
        $metaPanel.AddChild($projectLabel)
        
        # Due date with conditional formatting
        if ($task.DueDate) {
            $dueLabel = [LabelComponent]::new("DueLabel")
            $dueLabel.X = $projectLabel.Text.Length + 5
            $dueLabel.Y = 1
            $daysUntil = ($task.DueDate - [DateTime]::Now).Days
            $dueText = "Due: $($task.DueDate.ToString('MMM dd, yyyy'))"
            
            if ($daysUntil -lt 0) {
                $dueText += " (OVERDUE)"
                $dueLabel.ForegroundColor = "#FF4444"
            } elseif ($daysUntil -eq 0) {
                $dueText += " (TODAY)"
                $dueLabel.ForegroundColor = "#FFA500"
            } elseif ($daysUntil -le 3) {
                $dueText += " ($daysUntil days)"
                $dueLabel.ForegroundColor = "#FFD700"
            } else {
                $dueLabel.ForegroundColor = Get-ThemeColor "due" "#00FF88"
            }
            
            $dueLabel.Text = $dueText
            $metaPanel.AddChild($dueLabel)
        }
        
        # Created date
        $createdLabel = [LabelComponent]::new("CreatedLabel")
        $createdLabel.X = 2
        $createdLabel.Y = 2
        $age = $task.GetAge()
        $ageText = if ($age.Days -gt 0) { "$($age.Days)d" } elseif ($age.Hours -gt 0) { "$($age.Hours)h" } else { "$($age.Minutes)m" }
        $createdLabel.Text = "Created: $($task.CreatedAt.ToString('MMM dd, yyyy')) ($ageText ago)"
        $createdLabel.ForegroundColor = Get-ThemeColor "muted" "#808080"
        $metaPanel.AddChild($createdLabel)
        
        $y += 5
        
        # === DESCRIPTION SECTION ===
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            $descPanel = [Panel]::new("DescriptionPanel")
            $descPanel.X = 2
            $descPanel.Y = $y
            $descPanel.Width = $panel.ContentWidth - 4
            $descPanel.Height = [Math]::Min(8, $panel.ContentHeight - $y - 4)
            $descPanel.Title = " Description "
            $descPanel.BorderStyle = "Single"
            $descPanel.BorderColor = Get-ThemeColor "border" "#333333"
            $panel.AddChild($descPanel)
            
            # Word wrap description
            $words = $task.Description -split '\s+'
            $line = ""
            $maxLineLength = $descPanel.ContentWidth - 2
            $lineY = 1
            
            foreach ($word in $words) {
                if (($line + " " + $word).Length -gt $maxLineLength) {
                    if ($line -and $lineY -lt $descPanel.ContentHeight - 1) {
                        $descLine = [LabelComponent]::new("DescLine$lineY")
                        $descLine.X = 1
                        $descLine.Y = $lineY
                        $descLine.Text = $line
                        $descLine.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
                        $descPanel.AddChild($descLine)
                        $lineY++
                    }
                    $line = $word
                } else {
                    $line = if ($line) { "$line $word" } else { $word }
                }
            }
            
            if ($line -and $lineY -lt $descPanel.ContentHeight - 1) {
                $descLine = [LabelComponent]::new("DescLineLast")
                $descLine.X = 1
                $descLine.Y = $lineY
                $descLine.Text = $line
                $descLine.ForegroundColor = Get-ThemeColor "text" "#E0E0E0"
                $descPanel.AddChild($descLine)
            }
            
            $y += $descPanel.Height + 1
        }
        
        # === TAGS SECTION ===
        if ($task.Tags.Count -gt 0) {
            $tagsY = if ($task.Description) { $y } else { $y + 1 }
            $tagsLabel = [LabelComponent]::new("TagsLabel")
            $tagsLabel.X = 2
            $tagsLabel.Y = $tagsY
            $tagsLabel.Text = "Tags: "
            $tagsLabel.ForegroundColor = Get-ThemeColor "label" "#B0B0B0"
            $panel.AddChild($tagsLabel)
            
            $tagX = $tagsLabel.X + $tagsLabel.Text.Length
            foreach ($tag in $task.Tags) {
                $tagBadge = [LabelComponent]::new("Tag_$tag")
                $tagBadge.X = $tagX
                $tagBadge.Y = $tagsY
                $tagBadge.Text = " #$tag "
                $tagBadge.BackgroundColor = Get-ThemeColor "tag.bg" "#FF69B4"
                $tagBadge.ForegroundColor = Get-ThemeColor "tag.fg" "#000000"
                $panel.AddChild($tagBadge)
                $tagX += $tagBadge.Text.Length + 1
            }
        }
        
        $panel.RequestRedraw()
    }

    hidden [void] _UpdateContextPanel() {
        if (-not $this._sortLabel) { return }
        
        # Update sort indicator
        $arrow = if ($this._sortDescending) { "↓" } else { "↑" }
        $this._sortLabel.Text = "Sort: $($this._sortBy) $arrow"
        
        # Update help text based on context
        if ($this._selectedTask) {
            $this._helpLabel.Text = "↑↓ Navigate │ Enter Edit │ Space Toggle │ N New │ D Delete │ C Complete"
        } else {
            $this._helpLabel.Text = "Press N to create your first task │ Ctrl+Q to quit"
        }
    }

    #region CRUD Operations

    hidden [void] _ShowNewTaskDialog() {
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if (-not $navService) { return }
        
        # Create simple input dialog instead of complex TaskEditDialog
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
        
        # Create simple input dialog with existing task
        $dialog = [SimpleTaskDialog]::new($this.ServiceContainer, $this._selectedTask.Clone())
        $thisScreen = $this
        $dialog.OnSave = {
            param($task)
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                # Update the original task with edited values
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
        
        # Create confirmation dialog
        $dialog = [ConfirmDialog]::new($this.ServiceContainer)
        $dialog.Title = "Delete Task"
        $dialog.Message = "Are you sure you want to delete:`n`n'$($this._selectedTask.Title)'`n`nThis action cannot be undone."
        $dialog.OnConfirm = {
            $dataManager = $this.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $dataManager.DeleteTask($this._selectedTask.Id)
                $this._RefreshTasks()
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
    
    hidden [void] _ShowTagsDialog() {
        if (-not $this._selectedTask) { return }
        
        # TODO: Implement tags dialog
        Write-Host "Tags dialog coming soon!" -ForegroundColor Yellow
    }
    
    hidden [void] _CycleSortMode() {
        # Cycle through sort modes
        $modes = @("Priority", "Title", "DueDate", "Status")
        $currentIndex = [Array]::IndexOf($modes, $this._sortBy)
        
        if ($currentIndex -eq $modes.Length - 1) {
            # Was at the end, go back to start and toggle order
            $this._sortBy = $modes[0]
            $this._sortDescending = -not $this._sortDescending
        } else {
            # Move to next sort mode
            $this._sortBy = $modes[$currentIndex + 1]
        }
        
        $this._RefreshTasks()
    }
    
    hidden [void] _Exit() {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            $actionService.ExecuteAction("app.exit", @{})
        }
    }
    
    #endregion

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Check if focus is on filter box - let it handle input first
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $focusManager.FocusedComponent -eq $this._filterBox) {
            # Only handle escape to unfocus
            if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
                $focusManager.SetFocus($this._taskListBox)
                return $true
            }
            return $false
        }
        
        # Handle single key commands
        switch ($keyInfo.KeyChar) {
            'n' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._ShowNewTaskDialog()
                    return $true
                }
            }
            'N' {
                $this._ShowNewTaskDialog()
                return $true
            }
            'e' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    return $true
                }
            }
            'E' {
                if ($this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    return $true
                }
            }
            'd' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._DeleteTask()
                    return $true
                }
            }
            'D' {
                if ($this._selectedTask) {
                    $this._DeleteTask()
                    return $true
                }
            }
            'c' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._CompleteTask()
                    return $true
                }
            }
            'C' {
                if ($this._selectedTask) {
                    $this._CompleteTask()
                    return $true
                }
            }
            't' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._ShowTagsDialog()
                    return $true
                }
            }
            'T' {
                if ($this._selectedTask) {
                    $this._ShowTagsDialog()
                    return $true
                }
            }
            's' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._CycleSortMode()
                    return $true
                }
            }
            'S' {
                $this._CycleSortMode()
                return $true
            }
            '/' {
                # Focus on filter box
                if ($focusManager) {
                    $focusManager.SetFocus($this._filterBox)
                }
                return $true
            }
        }
        
        # Handle special keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                if ($this._selectedTask) {
                    $this._ShowEditTaskDialog()
                    return $true
                }
            }
            ([ConsoleKey]::Spacebar) {
                if ($this._selectedTask) {
                    # Toggle task progress between 0 and 100
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
                    return $true
                }
            }
            ([ConsoleKey]::F5) {
                # Refresh data
                $this._RefreshTasks()
                return $true
            }
        }
        
        # Handle Ctrl combinations
        if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Q) {
                    $this._Exit()
                    return $true
                }
                ([ConsoleKey]::N) {
                    # Create sub-task
                    if ($this._selectedTask) {
                        # TODO: Implement sub-task creation
                        Write-Host "Sub-task feature coming soon!" -ForegroundColor Yellow
                    }
                    return $true
                }
            }
        }
        
        # Let base class handle input routing to focused component
        return ([Screen]$this).HandleInput($keyInfo)
    }
}

#endregion
#<!-- END_PAGE: ASC.002 -->

#region Dialog Screens

class SimpleTaskDialog : Screen {
    hidden [Panel] $_dialogPanel
    hidden [Panel] $_contentPanel
    hidden [TextBoxComponent] $_titleBox
    hidden [TextBoxComponent] $_descriptionBox
    hidden [PmcTask] $_task
    hidden [TaskPriority] $_selectedPriority
    hidden [string] $_selectedProject
    hidden [int] $_focusIndex = 0
    hidden [int] $_maxFocusIndex = 4  # title, desc, priority, project, save/cancel
    
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
        
        $projLabel = [LabelComponent]::new("ProjLabel")
        $projLabel.X = 25
        $projLabel.Y = $y
        $projLabel.Text = "Project:"
        $projLabel.ForegroundColor = Get-ThemeColor "label" "#8A2BE2"
        $this._contentPanel.AddChild($projLabel)
        
        $projValue = [LabelComponent]::new("ProjValue")
        $projValue.X = 34
        $projValue.Y = $y
        $projValue.Text = "[$($this._selectedProject)]"
        $projValue.ForegroundColor = Get-ThemeColor "project" "#FFD700"
        $this._contentPanel.AddChild($projValue)
        
        $y += 2
        
        # Status message
        $statusLabel = [LabelComponent]::new("Status")
        $statusLabel.X = 0
        $statusLabel.Y = $y
        $statusLabel.Text = if ($this._isNewTask) { "Ready to create task" } else { "Ready to save changes" }
        $statusLabel.ForegroundColor = Get-ThemeColor "muted" "#888888"
        $this._contentPanel.AddChild($statusLabel)
        
        $y += 2
        
        # Buttons
        $saveLabel = [LabelComponent]::new("SaveBtn")
        $saveLabel.X = [Math]::Floor($this._contentPanel.Width / 2) - 15
        $saveLabel.Y = $y
        $saveLabel.Text = "  Save (S)  "
        $saveLabel.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $saveLabel.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $this._contentPanel.AddChild($saveLabel)
        
        $cancelLabel = [LabelComponent]::new("CancelBtn")
        $cancelLabel.X = [Math]::Floor($this._contentPanel.Width / 2) + 2
        $cancelLabel.Y = $y
        $cancelLabel.Text = " Cancel (C) "
        $cancelLabel.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        $cancelLabel.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $this._contentPanel.AddChild($cancelLabel)
    }
    
    [void] OnEnter() {
        # Set initial focus to title box
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._titleBox) {
            $focusManager.SetFocus($this._titleBox)
            $this._focusIndex = 0
        }
        $this.RequestRedraw()
    }
    
    hidden [void] _SaveTask() {
        # Validate
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            # Update status
            $status = $this._contentPanel.Children | Where-Object { $_.Name -eq "Status" }
            if ($status) {
                $status.Text = "Title is required!"
                $status.ForegroundColor = "#FF4444"
                $this.RequestRedraw()
            }
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
    
    hidden [void] _NextFocus() {
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if (-not $focusManager) { return }
        
        $this._focusIndex = ($this._focusIndex + 1) % 3  # Only 0, 1, 2 (title, desc, buttons)
        
        switch ($this._focusIndex) {
            0 { $focusManager.SetFocus($this._titleBox) }
            1 { $focusManager.SetFocus($this._descriptionBox) }
            2 { $focusManager.SetFocus($this) }  # Focus dialog for button handling
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Let focused component handle input first
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager) {
            $focused = $focusManager.FocusedComponent
            if ($focused -and $focused -ne $this) {
                # Special handling for Tab to move focus
                if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
                    $this._NextFocus()
                    return $true
                }
                # Let component handle other input
                return $false
            }
        }
        
        # Dialog-level shortcuts
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
            ([ConsoleKey]::Tab) {
                $this._NextFocus()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this._focusIndex -eq 2) {
                    $this._SaveTask()
                    return $true
                }
            }
        }
        
        # Let base class handle remaining input
        return ([Screen]$this).HandleInput($keyInfo)
    }
}


class ConfirmDialog : Screen {
    hidden [Panel] $_mainPanel
    hidden [LabelComponent] $_messageLabel
    hidden [ButtonComponent] $_yesButton
    hidden [ButtonComponent] $_noButton
    
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
        
        # Buttons
        $buttonY = $dialogHeight - 2
        $thisDialog = $this
        
        $this._yesButton = [ButtonComponent]::new("YesButton")
        $this._yesButton.Text = "[Y]es"
        $this._yesButton.X = [Math]::Floor($dialogWidth / 2) - 8
        $this._yesButton.Y = $buttonY
        $this._yesButton.Width = 7
        $this._yesButton.Height = 1
        $this._yesButton.OnClick = {
            if ($thisDialog.OnConfirm) {
                & $thisDialog.OnConfirm
            }
            $navService = $thisDialog.ServiceContainer?.GetService("NavigationService")
            if ($navService -and $navService.CanGoBack()) {
                $navService.GoBack()
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._yesButton)
        
        $this._noButton = [ButtonComponent]::new("NoButton")
        $this._noButton.Text = "[N]o"
        $this._noButton.X = [Math]::Floor($dialogWidth / 2) + 2
        $this._noButton.Y = $buttonY
        $this._noButton.Width = 6
        $this._noButton.Height = 1
        $this._noButton.OnClick = {
            if ($thisDialog.OnCancel) {
                & $thisDialog.OnCancel
            }
            $navService = $thisDialog.ServiceContainer?.GetService("NavigationService")
            if ($navService -and $navService.CanGoBack()) {
                $navService.GoBack()
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._noButton)
    }
    
    [void] OnEnter() {
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager) {
            $focusManager.SetFocus($this._noButton)
        }
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        switch ($keyInfo.KeyChar) {
            'y' {
                $this._yesButton.OnClick.Invoke()
                return $true
            }
            'Y' {
                $this._yesButton.OnClick.Invoke()
                return $true
            }
            'n' {
                $this._noButton.OnClick.Invoke()
                return $true
            }
            'N' {
                $this._noButton.OnClick.Invoke()
                return $true
            }
        }
        
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            $this._noButton.OnClick.Invoke()
            return $true
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
}

#endregion

class ThemePickerScreen : Screen {
    hidden [ScrollablePanel] $_themePanel
    hidden [Panel] $_mainPanel
    hidden [array] $_themes
    hidden [int] $_selectedIndex = 0
    hidden $_themeManager  # Remove type annotation since ThemeManager is defined later
    hidden [string] $_originalTheme  # Store original theme to restore on cancel
    
    ThemePickerScreen([object]$serviceContainer) : base("ThemePickerScreen", $serviceContainer) {}
    
    [void] Initialize() {
        # Get theme manager
        $this._themeManager = $this.ServiceContainer?.GetService("ThemeManager")
        if (-not $this._themeManager) {
            # Write-Verbose "ThemePickerScreen: ThemeManager not found"
            return
        }
        
        # Get available themes
        $this._themes = $this._themeManager.GetAvailableThemes()
        # Write-Verbose "ThemePickerScreen: Found $($this._themes.Count) themes: $($this._themes -join ', ')"
        
        # Store original theme
        $this._originalTheme = $this._themeManager.ThemeName
        
        # Main panel
        $this._mainPanel = [Panel]::new("Theme Selector")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = "Select Theme"
        $this.AddChild($this._mainPanel)
        
        # Instructions
        $instructionLabel = [LabelComponent]::new("Instructions")
        $instructionLabel.Text = "Use Up/Down to navigate, Enter to select theme, Esc to cancel"
        $instructionLabel.X = 2
        $instructionLabel.Y = 2
        $instructionLabel.Width = [Math]::Min(60, $this.Width - 4)
        $instructionLabel.Height = 1
        $instructionLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle" -DefaultColor "#808080"
        $this._mainPanel.AddChild($instructionLabel)
        
        # Theme scrollable panel
        $panelWidth = [Math]::Min(60, $this.Width - 10)
        $panelHeight = [Math]::Min(20, $this.Height - 8)
        $panelX = [Math]::Floor(($this.Width - $panelWidth) / 2)
        
        $this._themePanel = [ScrollablePanel]::new("ThemeList")
        $this._themePanel.X = $panelX
        $this._themePanel.Y = 4
        $this._themePanel.Width = $panelWidth
        $this._themePanel.Height = $panelHeight
        $this._themePanel.Title = "Available Themes"
        $this._themePanel.ShowScrollbar = $true
        $this._mainPanel.AddChild($this._themePanel)
        
        # Find current theme index
        $currentTheme = $this._themeManager.ThemeName
        $selectedIdx = 0
        for ($i = 0; $i -lt $this._themes.Count; $i++) {
            if ($this._themes[$i] -eq $currentTheme) {
                $selectedIdx = $i
                break
            }
        }
        $this._selectedIndex = $selectedIdx
        
        # Update display
        $this._UpdateThemeList()
    }
    
    hidden [void] _UpdateThemeList() {
        # Clear the panel
        $this._themePanel.Children.Clear()
        
        # Add theme items
        for ($i = 0; $i -lt $this._themes.Count; $i++) {
            $themeName = $this._themes[$i]
            $isSelected = ($i -eq $this._selectedIndex)
            
            # Create panel for each theme item
            $itemPanel = [Panel]::new("ThemeItem_$i")
            $itemPanel.X = 0
            $itemPanel.Y = $i
            $itemPanel.Width = $this._themePanel.ContentWidth
            $itemPanel.Height = 1
            $itemPanel.HasBorder = $false
            
            # Set background based on selection
            $itemPanel.BackgroundColor = if ($isSelected) { 
                Get-ThemeColor -ColorName "list.item.selected.background" -DefaultColor "#0000FF" 
            } else { 
                Get-ThemeColor -ColorName "Background" -DefaultColor "#000000" 
            }
            
            # Create label for theme name
            $themeLabel = [LabelComponent]::new("ThemeLabel_$i")
            $themeLabel.X = 2
            $themeLabel.Y = 0
            $themeLabel.Width = $itemPanel.Width - 4
            $themeLabel.Height = 1
            
            # Format display text
            $indicator = if ($isSelected) { "> " } else { "  " }
            $currentMarker = if ($themeName -eq $this._originalTheme) { " (current)" } else { "" }
            $themeLabel.Text = "$indicator$themeName$currentMarker"
            
            # Set text color based on selection
            $themeLabel.ForegroundColor = if ($isSelected) { 
                Get-ThemeColor -ColorName "list.item.selected" -DefaultColor "#FFFFFF" 
            } else { 
                Get-ThemeColor -ColorName "list.item.normal" -DefaultColor "#C0C0C0" 
            }
            
            $itemPanel.AddChild($themeLabel)
            $this._themePanel.AddChild($itemPanel)
        }
        
        # Ensure selected item is visible
        if ($this._selectedIndex -lt $this._themePanel.ScrollOffsetY) {
            $this._themePanel.ScrollOffsetY = $this._selectedIndex
        } elseif ($this._selectedIndex -ge ($this._themePanel.ScrollOffsetY + $this._themePanel.ContentHeight)) {
            $this._themePanel.ScrollOffsetY = $this._selectedIndex - $this._themePanel.ContentHeight + 1
        }
        
        $this._themePanel.RequestRedraw()
    }
    
    [void] OnEnter() {
        # Following Rule 2.3: Set initial focus for input to work
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager) {
            $focusManager.SetFocus($this) # Focus the screen itself since it handles input
        }
        $this.RequestRedraw()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    $this._selectedIndex--
                    if ($this._selectedIndex -lt $this._themePanel.ScrollOffsetY) {
                        $this._themePanel.ScrollUp()
                    }
                    $this._UpdateThemeList()
                }
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this._selectedIndex -lt $this._themes.Count - 1) {
                    $this._selectedIndex++
                    $visibleEnd = $this._themePanel.ScrollOffsetY + $this._themePanel.ContentHeight - 1
                    if ($this._selectedIndex -gt $visibleEnd) {
                        $this._themePanel.ScrollDown()
                    }
                    $this._UpdateThemeList()
                }
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Apply selected theme
                if ($this._selectedIndex -ge 0 -and $this._selectedIndex -lt $this._themes.Count) {
                    $selectedTheme = $this._themes[$this._selectedIndex]
                    $this._themeManager.LoadTheme($selectedTheme)
                    # Write-Verbose "Applied theme: $selectedTheme"
                    
                    # Publish theme change event
                    $eventManager = $this.ServiceContainer?.GetService("EventManager")
                    if ($eventManager) {
                        $eventManager.Publish("Theme.Changed", @{ Theme = $selectedTheme })
                    }
                    
                    # Go back
                    $navService = $this.ServiceContainer?.GetService("NavigationService")
                    if ($navService -and $navService.CanGoBack()) {
                        $navService.GoBack()
                    }
                }
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Restore original theme and cancel
                $this._themeManager.LoadTheme($this._originalTheme)
                
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Home) {
                $this._selectedIndex = 0
                $this._themePanel.ScrollToTop()
                $this._UpdateThemeList()
                return $true
            }
            ([ConsoleKey]::End) {
                $this._selectedIndex = $this._themes.Count - 1
                $this._themePanel.ScrollToBottom()
                $this._UpdateThemeList()
                return $true
            }
            default {
                # Unhandled key
                return $false
            }
        }
        return $false
    }
}
