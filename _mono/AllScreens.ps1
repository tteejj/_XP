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

# ==============================================================================
# CLASS: DashboardScreen (Now serves as the Main Menu)
#
# INHERITS:
#   - Screen (ABC.006)
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (ASE.004)
#     - FocusManager (ASE.009)
#   Components:
#     - Panel (ACO.011)
#     - NavigationMenu (ACO.021)
#     - LabelComponent (ACO.001)
#
# PURPOSE:
#   Serves as the main interactive entry point for the application, allowing
#   the user to navigate to different screens.
# ==============================================================================
class DashboardScreen : Screen {
    #region UI Components
    hidden [Panel] $_mainPanel
    hidden [NavigationMenu] $_menu
    #endregion

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    # The Initialize method is called once by the NavigationService when the screen is first created.
        # The Initialize method is called once by the NavigationService when the screen is first created.
    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }

        # Main container panel to hold all elements
        $this._mainPanel = [Panel]::new("MainMenuPanel")
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 "
        $this.AddChild($this._mainPanel)

        # ASCII Art Title for branding
        $titleArt = @(
            '      ___   _  _  _  ___  __  __   ',
            '     / _ \ | \/ || |/ _ \|  \/  |  ',
            '    | |_| | >  < | | (_) | |\/| |  ',
            '    |_| |_|/_/\_\|_|\___/|_|  |_|  '
        )
        $y = 3 # Starting Y position for the title
        foreach ($line in $titleArt) {
            $label = [LabelComponent]::new("TitleLine$y")
            $label.Text = $line
            
            # =============================================================
            # THE FIX: Explicitly set the width of the label to match the
            #          length of the text it needs to display.
            # =============================================================
            $label.Width = $line.Length
            
            $label.ForegroundColor = Get-ThemeColor -ColorName "Primary"
            # This positioning calculation remains correct.
            $label.X = [Math]::Floor(($this.Width - $line.Length) / 2)
            $label.Y = $y++
            $this._mainPanel.AddChild($label)
        }
        $y++ # Add a blank line for spacing

        # Create the central navigation menu
        $this._menu = [NavigationMenu]::new("MainMenu")
        $this._menu.Orientation = "Vertical" # Stack items vertically
        $this._menu.Width = 40
        $this._menu.Height = 4 # Height will be determined by the number of items
        $this._menu.X = [Math]::Floor(($this.Width - $this._menu.Width) / 2)
        $this._menu.Y = $y

        # Populate the menu items. Each item has a label and an action.
        $this._menu.AddItem([NavigationItem]::new("TASKS", "Manage Tasks",   ($this._CreateNavigationAction([TaskListScreen]))))
        $this._menu.AddItem([NavigationItem]::new("THEME", "Change Theme",   ($this._CreateNavigationAction([ThemePickerScreen]))))
        $this._menu.AddItem([NavigationItem]::new("EXIT",  "Exit Axiom",     { $global:TuiState.Running = $false }))

        $this._mainPanel.AddChild($this._menu)
    }

    # This lifecycle method is called every time the screen becomes the active view.
    [void] OnEnter() {
        # Set the initial focus to our menu so the user can navigate immediately.
        $this.Services.FocusManager?.SetFocus($this._menu)
    }

    # A private helper method to create navigation actions, which keeps the code clean and avoids repetition.
    # It takes a screen type (like [TaskListScreen]) and returns a scriptblock that navigates to it.
    hidden [scriptblock] _CreateNavigationAction([type]$ScreenType) {
        $thisScreen = $this # Capture the current screen instance for use inside the scriptblock
        return {
            # This scriptblock will be executed when the user presses Enter on the menu item.
            $navService = $thisScreen.ServiceContainer.GetService('NavigationService')
            # Create a new instance of the target screen, passing the service container to it.
            $screenInstance = $ScreenType::new($thisScreen.ServiceContainer)
            # It's crucial to call Initialize() on the new screen before navigating.
            $screenInstance.Initialize()
            # Tell the NavigationService to make the new screen active.
            $navService.NavigateTo($screenInstance)
        }.GetNewClosure()
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
    hidden [ButtonComponent] $_newButton
    hidden [ButtonComponent] $_editButton
    hidden [ButtonComponent] $_deleteButton
    hidden [ButtonComponent] $_completeButton
    hidden [TextBoxComponent] $_filterBox
    #endregion

    #region State
    hidden [System.Collections.Generic.List[PmcTask]] $_tasks
    hidden [int] $_selectedIndex = 0
    hidden [PmcTask] $_selectedTask
    hidden [string] $_filterText = ""
    hidden [System.Nullable[TaskStatus]] $_filterStatus = $null
    hidden [System.Nullable[TaskPriority]] $_filterPriority = $null
    hidden [string] $_taskChangeSubscriptionId = $null # Store event subscription ID
    #endregion

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) {
            # Write-Verbose "TaskListScreen.Initialize: ServiceContainer is null"
            return
        }
        
        # Ensure minimum size
        if ($this.Width -lt 80) { $this.Width = 80 }
        if ($this.Height -lt 24) { $this.Height = 24 }
        
        $this._mainPanel = [Panel]::new("Task List")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = "Task List"
        $this._mainPanel.UpdateContentDimensions()
        $this.AddChild($this._mainPanel)

        # Add filter textbox at the top
        $this._filterBox = [TextBoxComponent]::new("FilterBox")
        $this._filterBox.Placeholder = "Type to filter tasks..."
        $this._filterBox.X = 2
        $this._filterBox.Y = 2
        $this._filterBox.Width = [Math]::Floor($this.Width * 0.6) - 4
        $this._filterBox.Height = 1
        $thisScreen = $this
        $this._filterBox.OnChange = {
            param($newText)
            $thisScreen._filterText = $newText
            $thisScreen._RefreshTasks()
            $thisScreen._UpdateDisplay()
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._filterBox)

        # Task list panel (left side)
        $listWidth = [Math]::Floor($this.Width * 0.6)
        $this._taskListPanel = [ScrollablePanel]::new("Tasks")
        $this._taskListPanel.X = 1
        $this._taskListPanel.Y = 4  # Move down to accommodate filter
        $this._taskListPanel.Width = $listWidth
        $this._taskListPanel.Height = $this.Height - 8  # Adjust for buttons and filter
        $this._taskListPanel.Title = "Tasks"
        $this._taskListPanel.UpdateContentDimensions()
        $this._mainPanel.AddChild($this._taskListPanel)

        # Detail panel (right side)
        $detailX = $listWidth + 2
        $detailWidth = $this.Width - $detailX - 1
        $this._detailPanel = [Panel]::new("Task Details")
        $this._detailPanel.X = $detailX
        $this._detailPanel.Y = 1
        $this._detailPanel.Width = $detailWidth
        $this._detailPanel.Height = $this.Height - 8  # Adjust for buttons
        $this._detailPanel.Title = "Task Details"
        $this._detailPanel.UpdateContentDimensions()
        $this._mainPanel.AddChild($this._detailPanel)

        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 2
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 1
        $this._statusBar.HasBorder = $false
        $this._mainPanel.AddChild($this._statusBar)
        
        # Add CRUD action buttons at the bottom
        $buttonY = $this.Height - 3
        $buttonSpacing = 15
        $currentX = 2
        
        # New button
        $this._newButton = [ButtonComponent]::new("NewButton")
        $this._newButton.Text = "[N]ew Task"
        $this._newButton.X = $currentX
        $this._newButton.Y = $buttonY
        $this._newButton.Width = 12
        $this._newButton.Height = 1
        $this._newButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager) {
                $dialog = [TaskDialog]::new("New Task", $null)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::OK) {
                    $newTask = $dialog.GetTask()
                    $dataManager.AddTask($newTask)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    # Write-Verbose "New task created: $($newTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._newButton)
        $currentX += $buttonSpacing
        
        # Edit button
        $this._editButton = [ButtonComponent]::new("EditButton")
        $this._editButton.Text = "[E]dit Task"
        $this._editButton.X = $currentX
        $this._editButton.Y = $buttonY
        $this._editButton.Width = 12
        $this._editButton.Height = 1
        $this._editButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager -and $thisScreen._selectedTask) {
                $dialog = [TaskDialog]::new("Edit Task", $thisScreen._selectedTask)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::OK) {
                    $updatedTask = $dialog.GetTask()
                    $dataManager.UpdateTask($updatedTask)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    # Write-Verbose "Task updated: $($updatedTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._editButton)
        $currentX += $buttonSpacing
        
        # Delete button
        $this._deleteButton = [ButtonComponent]::new("DeleteButton")
        $this._deleteButton.Text = "[D]elete Task"
        $this._deleteButton.X = $currentX
        $this._deleteButton.Y = $buttonY
        $this._deleteButton.Width = 14
        $this._deleteButton.Height = 1
        $this._deleteButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager -and $thisScreen._selectedTask) {
                $dialog = [TaskDeleteDialog]::new($thisScreen._selectedTask)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::Yes) {
                    $dataManager.DeleteTask($thisScreen._selectedTask.Id)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    # Write-Verbose "Task deleted: $($thisScreen._selectedTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._deleteButton)
        $currentX += $buttonSpacing + 2
        
        # Complete button
        $this._completeButton = [ButtonComponent]::new("CompleteButton")
        $this._completeButton.Text = "[C]omplete"
        $this._completeButton.X = $currentX
        $this._completeButton.Y = $buttonY
        $this._completeButton.Width = 12
        $this._completeButton.Height = 1
        $this._completeButton.OnClick = {
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dataManager -and $thisScreen._selectedTask) {
                $thisScreen._selectedTask.Complete()
                $dataManager.UpdateTask($thisScreen._selectedTask)
                $thisScreen._RefreshTasks()
                $thisScreen._UpdateDisplay()
                # Write-Verbose "Task completed: $($thisScreen._selectedTask.Title)"
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._completeButton)
        
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
                # Write-Verbose "TaskListScreen received Tasks.Changed event. Refreshing tasks."
                $thisScreen._RefreshTasks()
                $thisScreen._UpdateDisplay()
            }.GetNewClosure()
            
            # Store subscription ID for later cleanup
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
            # Write-Verbose "TaskListScreen subscribed to Tasks.Changed events"
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
            # Write-Verbose "TaskListScreen unsubscribed from Tasks.Changed events"
        }
        
        # Call base OnExit if needed
        ([Screen]$this).OnExit()
    }

    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if ($dataManager) {
            $allTasks = $dataManager.GetTasks()
            
            # Apply text filter if present
            if (![string]::IsNullOrWhiteSpace($this._filterText)) {
                $filterLower = $this._filterText.ToLower()
                $allTasks = @($allTasks | Where-Object {
                    $_.Title.ToLower().Contains($filterLower) -or
                    ($_.Description -and $_.Description.ToLower().Contains($filterLower))
                })
            }
            
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
            if ($allTasks) {
                # Fix: Explicitly cast each item to PmcTask to avoid type conversion error
                foreach ($task in $allTasks) {
                    if ($task -is [PmcTask]) {
                        $this._tasks.Add($task)
                    }
                }
            }
        } else {
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
        }
        
        # Reset selection if needed
        if ($this._selectedIndex -ge $this._tasks.Count) {
            $this._selectedIndex = [Math]::Max(0, $this._tasks.Count - 1)
        }
        
        if ($this._tasks.Count -gt 0) {
            $this._selectedTask = $this._tasks[$this._selectedIndex]
        } else {
            $this._selectedTask = $null
        }
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
            $panelContentWidth = if ($panel.ContentWidth -le 0) { [Math]::Max(30, $panel.Width - 2) } else { $panel.ContentWidth }
            $taskPanel.Width = $panelContentWidth
            $taskPanel.Height = 1
            $taskPanel.HasBorder = $false
            
            # Set background based on selection
            $is_selected = ($i -eq $this._selectedIndex)
            $taskPanel.BackgroundColor = if ($is_selected) { Get-ThemeColor -ColorName "list.item.selected.background" -DefaultColor "#0000FF" } else { Get-ThemeColor -ColorName "Background" -DefaultColor "#000000" }
            
            # Create a Label component for the task text
            $taskLabel = [LabelComponent]::new("TaskLabel_$($task.Id)")
            $taskLabel.X = 1 # Indent slightly
            $taskLabel.Y = 0 # Relative to the task panel
            $taskLabel.Width = [Math]::Max(20, $panelContentWidth - 2) # Set proper width
            $taskLabel.Height = 1
            
            # Status indicator
            $statusChar = switch ($task.Status) {
                ([TaskStatus]::Pending) { "o" }
                ([TaskStatus]::InProgress) { "*" }
                ([TaskStatus]::Completed) { "+" }
                ([TaskStatus]::Cancelled) { "x" }
                default { "?" }
            }
            
            # Priority indicator
            $priorityChar = switch ($task.Priority) {
                ([TaskPriority]::Low) { "v" }
                ([TaskPriority]::Medium) { "-" }
                ([TaskPriority]::High) { "^" }
                default { "-" }
            }
            
            # Truncate title if needed
            $maxTitleLength = [Math]::Max(10, $panelContentWidth - 6) # Ensure minimum length
            if ($task.Title.Length -gt $maxTitleLength -and $maxTitleLength -gt 3) {
                $title = $task.Title.Substring(0, [Math]::Max(1, $maxTitleLength - 3)) + "..."
            } else {
                $title = $task.Title
            }
            
            $taskLine = "$statusChar $priorityChar $title"
            $taskLabel.Text = $taskLine
            
            # Set text color based on selection
            if ($is_selected) { 
                $taskLabel.ForegroundColor = Get-ThemeColor -ColorName "list.item.selected" -DefaultColor "#FFFFFF" 
            } else { 
                $taskLabel.ForegroundColor = Get-ThemeColor -ColorName "list.item.normal" -DefaultColor "#C0C0C0" 
            }
            
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
        
        # Force content dimensions update
        $panel.UpdateContentDimensions()
        
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
            $maxLineLength = [Math]::Max(10, $panel.ContentWidth - 2)
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
                    if ($line) { 
                        $line = "$line $word" 
                    } else { 
                        $line = $word 
                    }
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
        $hints = "Up/Down: Navigate | Enter: Edit | D: Delete | N: New"
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
                # Edit task
                if ($this._selectedTask -and $this._editButton) {
                    $this._editButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::N) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # New task
                    $this._newButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::E) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Edit task
                    $this._editButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::D) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Delete task
                    $this._deleteButton.OnClick.Invoke()
                }
            }
            ([ConsoleKey]::C) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Complete task
                    $this._completeButton.OnClick.Invoke()
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
        $this.RequestRedraw()
    }
    
    [void] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    $this._selectedIndex--
                    if ($this._selectedIndex -lt $this._themePanel.ScrollOffsetY) {
                        $this._themePanel.ScrollUp()
                    }
                    $this._UpdateThemeList()
                }
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
            }
            ([ConsoleKey]::Escape) {
                # Restore original theme and cancel
                $this._themeManager.LoadTheme($this._originalTheme)
                
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
            }
            ([ConsoleKey]::Home) {
                $this._selectedIndex = 0
                $this._themePanel.ScrollToTop()
                $this._UpdateThemeList()
            }
            ([ConsoleKey]::End) {
                $this._selectedIndex = $this._themes.Count - 1
                $this._themePanel.ScrollToBottom()
                $this._UpdateThemeList()
            }
            default {
                # Unhandled key
            }
        }
    }
}

#<!-- PAGE: ASC.003 - Screen Utilities -->
#region Screen Utilities

# No specific screen utility functions currently implemented
# This section reserved for future screen helper functions

#endregion
#<!-- END_PAGE: ASC.003 -->

