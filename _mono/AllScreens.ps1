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
# CLASS: DashboardScreen (Simplified Launcher)
#
# PURPOSE:
#   Simple dashboard that serves as a launcher for other screens.
#   No sidebar, just essential navigation options.
# ==============================================================================
class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [ListBox] $_menuList
    hidden [LabelComponent] $_statusLabel
    hidden [hashtable[]] $_menuItems = @()

    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }

        # Main panel
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix Dashboard "
        $this._mainPanel.BorderStyle = "Double"
        $this.AddChild($this._mainPanel)

        # Title
        $titleLabel = [LabelComponent]::new("Title")
        $titleLabel.Text = "AXIOM-PHOENIX v4.0"
        $titleLabel.X = [Math]::Floor(($this.Width - $titleLabel.Text.Length) / 2)
        $titleLabel.Y = 3
        $titleLabel.ForegroundColor = Get-ThemeColor -ColorName "Primary"
        $this._mainPanel.AddChild($titleLabel)

        # Subtitle
        $subtitleLabel = [LabelComponent]::new("Subtitle")
        $subtitleLabel.Text = "Main Menu"
        $subtitleLabel.X = [Math]::Floor(($this.Width - $subtitleLabel.Text.Length) / 2)
        $subtitleLabel.Y = 5
        $subtitleLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
        $this._mainPanel.AddChild($subtitleLabel)

        # Menu list
        $this._menuList = [ListBox]::new("MenuList")
        $this._menuList.X = [Math]::Floor(($this.Width - 40) / 2)
        $this._menuList.Y = 8
        $this._menuList.Width = 40
        $this._menuList.Height = 10
        $this._menuList.BorderColor = Get-ThemeColor -ColorName "Primary"
        $this._mainPanel.AddChild($this._menuList)

        # Define menu items
        $this._menuItems = @(
            @{ Name = "Task Management"; Action = "navigation.taskList"; Description = "View and manage tasks" },
            @{ Name = "Theme Settings"; Action = "ui.theme.picker"; Description = "Change application theme" },
            @{ Name = "Exit Application"; Action = "app.exit"; Description = "Quit Axiom-Phoenix" }
        )

        # Populate menu
        foreach ($item in $this._menuItems) {
            $this._menuList.AddItem($item.Name)
        }
        $this._menuList.SelectedIndex = 0

        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.Text = "Use arrows to navigate, Enter to select, Esc to exit"
        $this._statusLabel.X = [Math]::Floor(($this.Width - $this._statusLabel.Text.Length) / 2)
        $this._statusLabel.Y = $this.Height - 3
        $this._statusLabel.ForegroundColor = Get-ThemeColor -ColorName "Info"
        $this._mainPanel.AddChild($this._statusLabel)

        # Description label
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = $this._menuItems[0].Description
        $descLabel.X = [Math]::Floor(($this.Width - $descLabel.Text.Length) / 2)
        $descLabel.Y = 19
        $descLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
        $this._mainPanel.AddChild($descLabel)
    }

    [void] OnEnter() {
        # Manually handle focus since FocusManager was removed
        if ($this._menuList) {
            $this._menuList.IsFocused = $true
            $this._menuList.RequestRedraw()
        }
        
        # Update description for selected item
        $this._UpdateDescription()
        
        # Force redraw
        $this.RequestRedraw()
        $global:TuiState.IsDirty = $true
    }

    hidden [void] _UpdateDescription() {
        if ($this._menuList.SelectedIndex -ge 0 -and $this._menuList.SelectedIndex -lt $this._menuItems.Count) {
            $selectedItem = $this._menuItems[$this._menuList.SelectedIndex]
            $descLabel = $this._mainPanel.Children | Where-Object { $_.Name -eq "DescLabel" } | Select-Object -First 1
            if ($descLabel) {
                $descLabel.Text = $selectedItem.Description
                $descLabel.X = [Math]::Floor(($this.Width - $descLabel.Text.Length) / 2)
                $descLabel.RequestRedraw()
            }
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # First, let the focused component (menu list) handle the input
        if ($this._menuList -and $this._menuList.IsFocused) {
            $oldIndex = $this._menuList.SelectedIndex
            
            # Handle arrow keys and navigation
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this._menuList.HandleInput($keyInfo)) {
                        if ($oldIndex -ne $this._menuList.SelectedIndex) {
                            $this._UpdateDescription()
                        }
                        return $true
                    }
                    break
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._menuList.HandleInput($keyInfo)) {
                        if ($oldIndex -ne $this._menuList.SelectedIndex) {
                            $this._UpdateDescription()
                        }
                        return $true
                    }
                    break
                }
                ([ConsoleKey]::Home) {
                    if ($this._menuList.HandleInput($keyInfo)) {
                        if ($oldIndex -ne $this._menuList.SelectedIndex) {
                            $this._UpdateDescription()
                        }
                        return $true
                    }
                    break
                }
                ([ConsoleKey]::End) {
                    if ($this._menuList.HandleInput($keyInfo)) {
                        if ($oldIndex -ne $this._menuList.SelectedIndex) {
                            $this._UpdateDescription()
                        }
                        return $true
                    }
                    break
                }
            }
        }
        
        # Handle action keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                if ($this._menuList.SelectedIndex -ge 0 -and $this._menuList.SelectedIndex -lt $this._menuItems.Count) {
                    $selectedItem = $this._menuItems[$this._menuList.SelectedIndex]
                    $this._ExecuteAction($selectedItem.Action)
                }
                return $true
            }
            ([ConsoleKey]::Escape) {
                $this._ExecuteAction("app.exit")
                return $true
            }
            # Quick keys
            ([ConsoleKey]::T) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._ExecuteAction("navigation.taskList")
                    return $true
                }
                break
            }
            ([ConsoleKey]::Q) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._ExecuteAction("app.exit")
                    return $true
                }
                break
            }
        }
        
        # Let base handle other keys
        return ([Screen]$this).HandleInput($keyInfo)
    }

    hidden [void] _ExecuteAction([string]$actionName) {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if ($actionService) {
            try {
                $actionService.ExecuteAction($actionName)
            }
            catch {
                Write-Log -Level Error -Message "DashboardScreen: Failed to execute action '$actionName': $_"
            }
        }
    }
}

#endregion
#<!-- END_PAGE: ASC.001 -->

#<!-- PAGE: ASC.002 - TaskListScreen Class -->
#region TaskListScreen Class

# ==============================================================================
# CLASS: TaskListScreen (Simplified Task Management)
#
# PURPOSE:
#   Simple task list screen for managing tasks without sidebar menu.
#   Focus on core task management functionality.
# ==============================================================================
class TaskListScreen : Screen { 
    hidden [Panel] $_mainPanel
    hidden [ListBox] $_taskList
    hidden [Panel] $_detailPanel
    hidden [Panel] $_statusBar
    hidden [System.Collections.Generic.List[PmcTask]] $_tasks
    hidden [int] $_selectedIndex = 0
    hidden [PmcTask] $_selectedTask
    hidden [string] $_taskChangeSubscriptionId = $null

    TaskListScreen([object]$serviceContainer) : base("TaskListScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }
        
        # Main panel
        $this._mainPanel = [Panel]::new("TaskPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Task Management "
        $this._mainPanel.BorderStyle = "Double"
        $this.AddChild($this._mainPanel)

        # Task list (left side)
        $listWidth = [Math]::Floor($this.Width * 0.6)
        $this._taskList = [ListBox]::new("TaskList")
        $this._taskList.X = 2
        $this._taskList.Y = 2
        $this._taskList.Width = $listWidth - 3
        $this._taskList.Height = $this.Height - 8
        $this._taskList.BorderColor = Get-ThemeColor -ColorName "Primary"
        $this._mainPanel.AddChild($this._taskList)

        # Detail panel (right side)
        $this._detailPanel = [Panel]::new("TaskDetails")
        $this._detailPanel.X = $listWidth + 1
        $this._detailPanel.Y = 2
        $this._detailPanel.Width = $this.Width - $listWidth - 3
        $this._detailPanel.Height = $this.Height - 8
        $this._detailPanel.Title = "Task Details"
        $this._detailPanel.BorderStyle = "Single"
        $this._mainPanel.AddChild($this._detailPanel)

        # Status bar
        $this._statusBar = [Panel]::new("StatusBar")
        $this._statusBar.X = 1
        $this._statusBar.Y = $this.Height - 4
        $this._statusBar.Width = $this.Width - 2
        $this._statusBar.Height = 3
        $this._statusBar.HasBorder = $false
        $this._statusBar.BackgroundColor = Get-ThemeColor -ColorName "status.bar.bg" -DefaultColor "#1E1E1E"
        $this._mainPanel.AddChild($this._statusBar)
        
        # Status text
        $statusLabel = [LabelComponent]::new("StatusText")
        $statusLabel.X = 1
        $statusLabel.Y = 0
        $statusLabel.Text = "[N]ew  [Enter]Edit  [D]elete  [C]omplete  [Esc]Back  [Q]uit"
        $statusLabel.ForegroundColor = Get-ThemeColor -ColorName "Info"
        $this._statusBar.AddChild($statusLabel)
        
        $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
    }

    [void] OnEnter() {
        # Fetch initial data
        $this._RefreshTasks()
        $this._UpdateDisplay()
        
        # Manually handle focus since FocusManager was removed
        if ($this._taskList) {
            $this._taskList.IsFocused = $true
            $this._taskList.RequestRedraw()
        }
        
        # Subscribe to task change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $thisScreen = $this
            $handler = {
                param($eventData)
                $thisScreen._RefreshTasks()
                $thisScreen._UpdateDisplay()
            }.GetNewClosure()
            $this._taskChangeSubscriptionId = $eventManager.Subscribe("Tasks.Changed", $handler)
        }
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        # Unsubscribe from events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._taskChangeSubscriptionId) {
            $eventManager.Unsubscribe("Tasks.Changed", $this._taskChangeSubscriptionId)
            $this._taskChangeSubscriptionId = $null
        }
        ([Screen]$this).OnExit()
    }

    hidden [void] _RefreshTasks() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if ($dataManager) {
            $allTasks = $dataManager.GetTasks()
            $this._tasks = [System.Collections.Generic.List[PmcTask]]::new()
            if ($allTasks) {
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
        $this.RequestRedraw()
    }

    hidden [void] _UpdateTaskList() {
        if (-not $this._taskList) { return }
        
        $this._taskList.ClearItems()
        
        foreach ($task in $this._tasks) {
            # Format: [Status] Priority - Title (Progress%)
            $statusChar = switch ($task.Status) {
                ([TaskStatus]::Pending) { "○" }
                ([TaskStatus]::InProgress) { "◐" }
                ([TaskStatus]::Completed) { "●" }
                ([TaskStatus]::Cancelled) { "✗" }
                default { "?" }
            }
            
            $priorityChar = switch ($task.Priority) {
                ([TaskPriority]::Low) { "↓" }
                ([TaskPriority]::Medium) { "→" }
                ([TaskPriority]::High) { "↑" }
                default { "?" }
            }
            
            $displayText = "$statusChar $priorityChar $($task.Title) ($($task.Progress)%)"
            $this._taskList.AddItem($displayText)
        }
        
        if ($this._selectedIndex -lt $this._tasks.Count) {
            $this._taskList.SelectedIndex = $this._selectedIndex
        }
    }

    hidden [void] _UpdateDetailPanel() {
        $panel = $this._detailPanel
        if (-not $panel -or -not $this._selectedTask) { return }
        
        # Clear children
        $panel.Children.Clear()
        
        $task = $this._selectedTask
        $y = 1
        
        # Title
        $titleLabel = [LabelComponent]::new("DetailTitle")
        $titleLabel.X = 1
        $titleLabel.Y = $y++
        $titleLabel.Text = "Title: $($task.Title)"
        $titleLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground"
        $panel.AddChild($titleLabel)
        
        # Status
        $statusLabel = [LabelComponent]::new("DetailStatus")
        $statusLabel.X = 1
        $statusLabel.Y = $y++
        $statusLabel.Text = "Status: $($task.Status)"
        $statusLabel.ForegroundColor = Get-ThemeColor -ColorName "Info"
        $panel.AddChild($statusLabel)
        
        # Priority
        $priorityLabel = [LabelComponent]::new("DetailPriority")
        $priorityLabel.X = 1
        $priorityLabel.Y = $y++
        $priorityLabel.Text = "Priority: $($task.Priority)"
        $priorityLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning"
        $panel.AddChild($priorityLabel)
        
        # Progress
        $progressLabel = [LabelComponent]::new("DetailProgress")
        $progressLabel.X = 1
        $progressLabel.Y = $y++
        $progressLabel.Text = "Progress: $($task.Progress)%"
        $progressLabel.ForegroundColor = Get-ThemeColor -ColorName "Success"
        $panel.AddChild($progressLabel)
        
        $y++ # Empty line
        
        # Description
        $descHeaderLabel = [LabelComponent]::new("DetailDescHeader")
        $descHeaderLabel.X = 1
        $descHeaderLabel.Y = $y++
        $descHeaderLabel.Text = "Description:"
        $descHeaderLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
        $panel.AddChild($descHeaderLabel)
        
        if (-not [string]::IsNullOrEmpty($task.Description)) {
            # Simple description display
            $descLabel = [LabelComponent]::new("DetailDesc")
            $descLabel.X = 1
            $descLabel.Y = $y++
            $maxWidth = $panel.Width - 3
            $descText = if ($task.Description.Length -gt $maxWidth) {
                $task.Description.Substring(0, $maxWidth - 3) + "..."
            } else {
                $task.Description
            }
            $descLabel.Text = $descText
            $descLabel.ForegroundColor = Get-ThemeColor -ColorName "Foreground"
            $panel.AddChild($descLabel)
        } else {
            $noDescLabel = [LabelComponent]::new("DetailNoDesc")
            $noDescLabel.X = 1
            $noDescLabel.Y = $y++
            $noDescLabel.Text = "(No description)"
            $noDescLabel.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
            $panel.AddChild($noDescLabel)
        }
        
        $panel.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Handle task list navigation first
        if ($this._taskList -and $this._taskList.IsFocused) {
            $oldIndex = $this._taskList.SelectedIndex
            if ($this._taskList.HandleInput($keyInfo)) {
                if ($oldIndex -ne $this._taskList.SelectedIndex) {
                    $this._selectedIndex = $this._taskList.SelectedIndex
                    if ($this._selectedIndex -ge 0 -and $this._selectedIndex -lt $this._tasks.Count) {
                        $this._selectedTask = $this._tasks[$this._selectedIndex]
                        $this._UpdateDetailPanel()
                    }
                }
                return $true
            }
        }
        
        # Handle action keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # Edit task
                if ($this._selectedTask) {
                    $this._ShowEditDialog()
                }
                return $true
            }
            ([ConsoleKey]::N) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._ShowNewTaskDialog()
                    return $true
                }
            }
            ([ConsoleKey]::D) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._ShowDeleteDialog()
                    return $true
                }
            }
            ([ConsoleKey]::C) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    $this._CompleteTask()
                    return $true
                }
            }
            ([ConsoleKey]::Escape) {
                # Go back
                $navService = $this.ServiceContainer?.GetService("NavigationService")
                if ($navService -and $navService.CanGoBack()) {
                    $navService.GoBack()
                }
                return $true
            }
            ([ConsoleKey]::Q) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $global:TuiState.Running = $false
                    return $true
                }
            }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }

    hidden [void] _ShowNewTaskDialog() {
        $dialogManager = $this.ServiceContainer?.GetService("DialogManager")
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        
        if ($dialogManager -and $dataManager) {
            $dialog = [TaskEditPanel]::new("New Task", $null)
            $dialog.OnSave = {
                $newTask = $dialog.GetTask()
                $dataManager.AddTask($newTask)
                $dialogManager.HideDialog($dialog)
                $this._RefreshTasks()
                $this._UpdateDisplay()
            }.GetNewClosure()
            $dialog.OnCancel = {
                $dialogManager.HideDialog($dialog)
            }.GetNewClosure()
            $dialogManager.ShowDialog($dialog)
        }
    }

    hidden [void] _ShowEditDialog() {
        $dialogManager = $this.ServiceContainer?.GetService("DialogManager")
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        
        if ($dialogManager -and $dataManager -and $this._selectedTask) {
            $dialog = [TaskEditPanel]::new("Edit Task", $this._selectedTask)
            $dialog.OnSave = {
                $updatedTask = $dialog.GetTask()
                $dataManager.UpdateTask($updatedTask)
                $dialogManager.HideDialog($dialog)
                $this._RefreshTasks()
                $this._UpdateDisplay()
            }.GetNewClosure()
            $dialog.OnCancel = {
                $dialogManager.HideDialog($dialog)
            }.GetNewClosure()
            $dialogManager.ShowDialog($dialog)
        }
    }

    hidden [void] _ShowDeleteDialog() {
        $dialogManager = $this.ServiceContainer?.GetService("DialogManager")
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        
        if ($dialogManager -and $dataManager -and $this._selectedTask) {
            $dialog = [TaskDeleteDialog]::new($this._selectedTask)
            $dialog.OnConfirm = {
                $dataManager.DeleteTask($this._selectedTask.Id)
                $dialogManager.HideDialog($dialog)
                $this._RefreshTasks()
                $this._UpdateDisplay()
            }.GetNewClosure()
            $dialog.OnCancel = {
                $dialogManager.HideDialog($dialog)
            }.GetNewClosure()
            $dialogManager.ShowDialog($dialog)
        }
    }

    hidden [void] _CompleteTask() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        
        if ($dataManager -and $this._selectedTask) {
            $this._selectedTask.Complete()
            $dataManager.UpdateTask($this._selectedTask)
            $this._RefreshTasks()
            $this._UpdateDisplay()
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

#<!-- PAGE: ASC.003 - CRUD Screens -->
#region CRUD Screens

# ===== CLASS: NewTaskScreen =====
# Purpose: Full screen for creating new tasks
class NewTaskScreen : Screen {
    hidden [Panel]$_formPanel
    hidden [SidebarMenu]$_menu
    hidden [TextBoxComponent]$_titleBox
    hidden [TextBoxComponent]$_descriptionBox
    hidden [ListBox]$_priorityList
    hidden [ListBox]$_projectList
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    hidden [LabelComponent]$_statusLabel
    
    NewTaskScreen([object]$serviceContainer) : base("NewTaskScreen", $serviceContainer) {}
    
    [void] Initialize() {
        # Create menu
        $this._menu = [SidebarMenu]::new("MainMenu")
        $this._menu.X = 0
        $this._menu.Y = 0
        $this._menu.Height = $this.Height
        $this._menu.Width = 22
        $this._menu.Title = "Navigation"
        
        $this._menu.AddMenuItem("1", "Dashboard", "navigation.dashboard")
        $this._menu.AddMenuItem("2", "Task List", "navigation.taskList")
        $this._menu.AddMenuItem("-", "", "")
        $this._menu.AddMenuItem("S", "Save Task", "task.save.current")
        $this._menu.AddMenuItem("C", "Cancel", "navigation.back")
        $this._menu.AddMenuItem("-", "", "")
        $this._menu.AddMenuItem("Q", "Quit", "app.exit")
        
        $this.AddChild($this._menu)
        
        # Create form panel
        $this._formPanel = [Panel]::new("NewTaskForm")
        $this._formPanel.X = 23
        $this._formPanel.Y = 0
        $this._formPanel.Width = $this.Width - 24
        $this._formPanel.Height = $this.Height
        $this._formPanel.Title = "Create New Task"
        $this._formPanel.BorderStyle = "Double"
        $this.AddChild($this._formPanel)
        
        # Title input
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = 2
        $titleLabel.Y = 2
        $this._formPanel.AddChild($titleLabel)
        
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.X = 2
        $this._titleBox.Y = 3
        $this._titleBox.Width = $this._formPanel.Width - 6
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.IsFocusable = $true
        $this._formPanel.AddChild($this._titleBox)
        
        # Description input
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = 5
        $this._formPanel.AddChild($descLabel)
        
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = 6
        $this._descriptionBox.Width = $this._formPanel.Width - 6
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.IsFocusable = $true
        $this._formPanel.AddChild($this._descriptionBox)
        
        # Priority selection
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 2
        $priorityLabel.Y = 8
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = 2
        $this._priorityList.Y = 9
        $this._priorityList.Width = 20
        $this._priorityList.Height = 5
        $this._priorityList.AddItem("Low")
        $this._priorityList.AddItem("Medium")
        $this._priorityList.AddItem("High")
        $this._priorityList.SelectedIndex = 1  # Default to Medium
        $this._priorityList.IsFocusable = $true
        $this._formPanel.AddChild($this._priorityList)
        
        # Project selection
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project:"
        $projectLabel.X = 25
        $projectLabel.Y = 8
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = 25
        $this._projectList.Y = 9
        $this._projectList.Width = 20
        $this._projectList.Height = 5
        $this._projectList.AddItem("None")
        $this._projectList.SelectedIndex = 0
        $this._projectList.IsFocusable = $true
        $this._formPanel.AddChild($this._projectList)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 15
        $this._statusLabel.Text = "Ready to create task"
        $this._statusLabel.ForegroundColor = (Get-ThemeColor "Info")
        $this._formPanel.AddChild($this._statusLabel)
        
        # Buttons
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save (S)"
        $this._saveButton.X = 2
        $this._saveButton.Y = 17
        $this._saveButton.IsFocusable = $true
        $this._saveButton.OnClick = {
            $this.SaveTask()
        }.GetNewClosure()
        $this._formPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel (C)"
        $this._cancelButton.X = 15
        $this._cancelButton.Y = 17
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.OnClick = {
            $navService = $this.Services.NavigationService
            $navService.GoBack()
        }.GetNewClosure()
        $this._formPanel.AddChild($this._cancelButton)
    }
    
    [void] OnEnter() {
        # Load projects
        $dataManager = $this.Services.DataManager
        $projects = $dataManager.GetProjects()
        
        $this._projectList.ClearItems()
        $this._projectList.AddItem("None")
        foreach ($project in $projects) {
            $this._projectList.AddItem($project.Name)
        }
        $this._projectList.SelectedIndex = 0
        
        # Set initial focus
        $focusManager = $this.Services.FocusManager
        $focusManager.SetFocus($this._titleBox)
        
        # Register save action
        $actionService = $this.Services.ActionService
        $actionService.RegisterAction("task.save.current", {
            $currentScreen = $global:TuiState.CurrentScreen
            if ($currentScreen -is [NewTaskScreen]) {
                $currentScreen.SaveTask()
            }
        }, @{ Category = "Tasks"; Description = "Save current task" })
    }
    
    [void] OnExit() {
        # Unregister temporary action
        $actionService = $this.Services.ActionService
        $actionService.UnregisterAction("task.save.current")
    }
    
    [void] SaveTask() {
        # Validate input
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._statusLabel.Text = "Error: Title is required"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Error")
            return
        }
        
        # Create new task
        $task = [PmcTask]::new()
        $task.Title = $this._titleBox.Text
        $task.Description = $this._descriptionBox.Text
        
        # Set priority
        $priorityMap = @{
            0 = [TaskPriority]::Low
            1 = [TaskPriority]::Medium  
            2 = [TaskPriority]::High
        }
        $task.Priority = $priorityMap[$this._priorityList.SelectedIndex]
        
        # Set project
        if ($this._projectList.SelectedIndex -gt 0) {
            $dataManager = $this.Services.DataManager
            $projects = $dataManager.GetProjects()
            if ($this._projectList.SelectedIndex -le $projects.Count) {
                $task.ProjectKey = $projects[$this._projectList.SelectedIndex - 1].Key
            }
        }
        
        # Save task
        try {
            $dataManager = $this.Services.DataManager
            $dataManager.AddTask($task)
            
            $this._statusLabel.Text = "Task created successfully!"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Success")
            
            # Navigate back after short delay
            Start-Sleep -Milliseconds 500
            $navService = $this.Services.NavigationService
            $navService.GoBack()
        }
        catch {
            $this._statusLabel.Text = "Error: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Error")
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Let menu handle its keys first
        if ($this._menu.HandleKey($keyInfo)) {
            return $true
        }
        
        # Handle form-specific keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::S) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
                    $this.SaveTask()
                    return $true
                }
                break
            }
            ([ConsoleKey]::Escape) {
                $navService = $this.Services.NavigationService
                $navService.GoBack()
                return $true
            }
        }
        
        # Let base handle focus navigation
        return ([Screen]$this).HandleInput($keyInfo)
    }
}

# ===== CLASS: EditTaskScreen =====
# Purpose: Full screen for editing existing tasks
class EditTaskScreen : Screen {
    hidden [Panel]$_formPanel
    hidden [SidebarMenu]$_menu
    hidden [TextBoxComponent]$_titleBox
    hidden [TextBoxComponent]$_descriptionBox
    hidden [ListBox]$_priorityList
    hidden [ListBox]$_statusList
    hidden [ListBox]$_projectList
    hidden [TextBoxComponent]$_progressBox
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    hidden [LabelComponent]$_statusLabel
    hidden [PmcTask]$_task
    
    EditTaskScreen([object]$serviceContainer, [PmcTask]$task) : base("EditTaskScreen", $serviceContainer) {
        $this._task = $task
    }
    
    [void] Initialize() {
        # Create menu
        $this._menu = [SidebarMenu]::new("MainMenu")
        $this._menu.X = 0
        $this._menu.Y = 0
        $this._menu.Height = $this.Height
        $this._menu.Width = 22
        $this._menu.Title = "Navigation"
        
        $this._menu.AddMenuItem("1", "Dashboard", "navigation.dashboard")
        $this._menu.AddMenuItem("2", "Task List", "navigation.taskList")
        $this._menu.AddMenuItem("-", "", "")
        $this._menu.AddMenuItem("S", "Save Changes", "task.save.current")
        $this._menu.AddMenuItem("C", "Cancel", "navigation.back")
        $this._menu.AddMenuItem("-", "", "")
        $this._menu.AddMenuItem("Q", "Quit", "app.exit")
        
        $this.AddChild($this._menu)
        
        # Create form panel
        $this._formPanel = [Panel]::new("EditTaskForm")
        $this._formPanel.X = 23
        $this._formPanel.Y = 0
        $this._formPanel.Width = $this.Width - 24
        $this._formPanel.Height = $this.Height
        $this._formPanel.Title = "Edit Task"
        $this._formPanel.BorderStyle = "Double"
        $this.AddChild($this._formPanel)
        
        # Title input
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = 2
        $titleLabel.Y = 2
        $this._formPanel.AddChild($titleLabel)
        
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.X = 2
        $this._titleBox.Y = 3
        $this._titleBox.Width = $this._formPanel.Width - 6
        $this._titleBox.Text = $this._task.Title
        $this._titleBox.IsFocusable = $true
        $this._formPanel.AddChild($this._titleBox)
        
        # Description input
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = 5
        $this._formPanel.AddChild($descLabel)
        
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = 6
        $this._descriptionBox.Width = $this._formPanel.Width - 6
        $this._descriptionBox.Text = $this._task.Description
        $this._descriptionBox.IsFocusable = $true
        $this._formPanel.AddChild($this._descriptionBox)
        
        # Status selection
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = 8
        $this._formPanel.AddChild($statusLabel)
        
        $this._statusList = [ListBox]::new("StatusList")
        $this._statusList.X = 2
        $this._statusList.Y = 9
        $this._statusList.Width = 15
        $this._statusList.Height = 6
        $this._statusList.AddItem("Pending")
        $this._statusList.AddItem("InProgress")
        $this._statusList.AddItem("Completed")
        $this._statusList.AddItem("Cancelled")
        $this._statusList.SelectedIndex = [int]$this._task.Status
        $this._statusList.IsFocusable = $true
        $this._formPanel.AddChild($this._statusList)
        
        # Priority selection
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 20
        $priorityLabel.Y = 8
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = 20
        $this._priorityList.Y = 9
        $this._priorityList.Width = 12
        $this._priorityList.Height = 5
        $this._priorityList.AddItem("Low")
        $this._priorityList.AddItem("Medium")
        $this._priorityList.AddItem("High")
        $this._priorityList.SelectedIndex = [int]$this._task.Priority
        $this._priorityList.IsFocusable = $true
        $this._formPanel.AddChild($this._priorityList)
        
        # Progress input
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Progress (%):"
        $progressLabel.X = 35
        $progressLabel.Y = 8
        $this._formPanel.AddChild($progressLabel)
        
        $this._progressBox = [TextBoxComponent]::new("ProgressInput")
        $this._progressBox.X = 35
        $this._progressBox.Y = 9
        $this._progressBox.Width = 10
        $this._progressBox.Text = $this._task.Progress.ToString()
        $this._progressBox.MaxLength = 3
        $this._progressBox.IsFocusable = $true
        $this._formPanel.AddChild($this._progressBox)
        
        # Project selection
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project:"
        $projectLabel.X = 2
        $projectLabel.Y = 15
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = 2
        $this._projectList.Y = 16
        $this._projectList.Width = 30
        $this._projectList.Height = 4
        $this._projectList.AddItem("None")
        $this._projectList.IsFocusable = $true
        $this._formPanel.AddChild($this._projectList)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusMessageLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 21
        $this._statusLabel.Text = "Ready to save changes"
        $this._statusLabel.ForegroundColor = (Get-ThemeColor "Info")
        $this._formPanel.AddChild($this._statusLabel)
        
        # Buttons
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save (S)"
        $this._saveButton.X = 2
        $this._saveButton.Y = 23
        $this._saveButton.IsFocusable = $true
        $this._saveButton.OnClick = {
            $this.SaveTask()
        }.GetNewClosure()
        $this._formPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel (C)"
        $this._cancelButton.X = 15
        $this._cancelButton.Y = 23
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.OnClick = {
            $navService = $this.Services.NavigationService
            $navService.GoBack()
        }.GetNewClosure()
        $this._formPanel.AddChild($this._cancelButton)
    }
    
    [void] OnEnter() {
        # Load projects
        $dataManager = $this.Services.DataManager
        $projects = $dataManager.GetProjects()
        
        $this._projectList.ClearItems()
        $this._projectList.AddItem("None")
        $selectedIndex = 0
        $i = 1
        foreach ($project in $projects) {
            $this._projectList.AddItem($project.Name)
            if ($project.Key -eq $this._task.ProjectKey) {
                $selectedIndex = $i
            }
            $i++
        }
        $this._projectList.SelectedIndex = $selectedIndex
        
        # Set initial focus
        $focusManager = $this.Services.FocusManager
        $focusManager.SetFocus($this._titleBox)
        
        # Register save action
        $actionService = $this.Services.ActionService
        $actionService.RegisterAction("task.save.current", {
            $currentScreen = $global:TuiState.CurrentScreen
            if ($currentScreen -is [EditTaskScreen]) {
                $currentScreen.SaveTask()
            }
        }, @{ Category = "Tasks"; Description = "Save current task" })
    }
    
    [void] OnExit() {
        # Unregister temporary action
        $actionService = $this.Services.ActionService
        $actionService.UnregisterAction("task.save.current")
    }
    
    [void] SaveTask() {
        # Validate input
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._statusLabel.Text = "Error: Title is required"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Error")
            return
        }
        
        # Validate progress
        $progress = 0
        if (-not [int]::TryParse($this._progressBox.Text, [ref]$progress) -or $progress -lt 0 -or $progress -gt 100) {
            $this._statusLabel.Text = "Error: Progress must be 0-100"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Error")
            return
        }
        
        # Update task
        $this._task.Title = $this._titleBox.Text
        $this._task.Description = $this._descriptionBox.Text
        $this._task.Status = [TaskStatus]$this._statusList.SelectedIndex
        $this._task.Priority = [TaskPriority]$this._priorityList.SelectedIndex
        $this._task.SetProgress($progress)
        
        # Set project
        if ($this._projectList.SelectedIndex -eq 0) {
            $this._task.ProjectKey = $null
        } else {
            $dataManager = $this.Services.DataManager
            $projects = $dataManager.GetProjects()
            if ($this._projectList.SelectedIndex -le $projects.Count) {
                $this._task.ProjectKey = $projects[$this._projectList.SelectedIndex - 1].Key
            }
        }
        
        # Save task
        try {
            $dataManager = $this.Services.DataManager
            $dataManager.UpdateTask($this._task)
            
            $this._statusLabel.Text = "Task updated successfully!"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Success")
            
            # Navigate back after short delay
            Start-Sleep -Milliseconds 500
            $navService = $this.Services.NavigationService
            $navService.GoBack()
        }
        catch {
            $this._statusLabel.Text = "Error: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Error")
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # Let menu handle its keys first
        if ($this._menu.HandleKey($keyInfo)) {
            return $true
        }
        
        # Handle form-specific keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::S) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
                    $this.SaveTask()
                    return $true
                }
                break
            }
            ([ConsoleKey]::Escape) {
                $navService = $this.Services.NavigationService
                $navService.GoBack()
                return $true
            }
        }
        
        # Let base handle focus navigation
        return ([Screen]$this).HandleInput($keyInfo)
    }
}

#endregion
#<!-- END_PAGE: ASC.003 -->

#<!-- PAGE: ASC.004 - Screen Utilities -->
#region Screen Utilities

# No specific screen utility functions currently implemented
# This section reserved for future screen helper functions

#endregion
#<!-- END_PAGE: ASC.004 -->

