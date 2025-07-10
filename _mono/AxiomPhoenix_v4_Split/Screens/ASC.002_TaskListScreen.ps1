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
    hidden [DataGridComponent] $_taskGrid
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
        
        # Create sidebar menu
        $menu = [SidebarMenu]::new("MainMenu")
        $menu.X = 0
        $menu.Y = 0
        $menu.Height = $this.Height
        $menu.Width = 22
        $menu.Title = "Navigation"
        
        $menu.AddMenuItem("1", "Dashboard", "navigation.dashboard")
        $menu.AddMenuItem("2", "Task List", "navigation.taskList")
        $menu.AddMenuItem("-", "", "")
        $menu.AddMenuItem("N", "New Task", "navigation.newTask")
        $menu.AddMenuItem("E", "Edit Task", "task.edit.selected")
        $menu.AddMenuItem("D", "Delete Task", "task.delete.selected")
        $menu.AddMenuItem("C", "Complete", "task.complete.selected")
        $menu.AddMenuItem("-", "", "")
        $menu.AddMenuItem("Q", "Quit", "app.exit")
        
        $this.AddChild($menu)
        
        # Main panel (adjusted for menu)
        $this._mainPanel = [Panel]::new("Task List")
        $this._mainPanel.X = 23
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width - 24
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
            param($sender, $newText)
            $thisScreen._filterText = $newText
            $thisScreen._RefreshTasks()
            $thisScreen._UpdateDisplay()
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._filterBox)

        # Task list grid (left side) - Using new DataGridComponent
        $listWidth = [Math]::Floor($this.Width * 0.6)
        $this._taskGrid = [DataGridComponent]::new("TaskGrid")
        $this._taskGrid.X = 1
        $this._taskGrid.Y = 4  # Move down to accommodate filter
        $this._taskGrid.Width = $listWidth
        $this._taskGrid.Height = $this.Height - 8  # Adjust for buttons and filter
        $this._taskGrid.ShowHeaders = $true
        $this._taskGrid.OnSelectionChanged = {
            param($sender, $selectedIndex)
            $thisScreen._selectedIndex = $selectedIndex
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $thisScreen._tasks.Count) {
                $thisScreen._selectedTask = $thisScreen._tasks[$selectedIndex]
            } else {
                $thisScreen._selectedTask = $null
            }
            $thisScreen._UpdateDetailPanel()
            $thisScreen._UpdateStatusBar()
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._taskGrid)

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
            # TaskEditPanel not available in this version
            Write-Host "New task feature coming soon!" -ForegroundColor Yellow
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
            # TaskEditPanel not available in this version
            Write-Host "Edit task feature coming soon!" -ForegroundColor Yellow
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
            # TaskDeleteDialog not available in this version
            Write-Host "Delete task feature coming soon!" -ForegroundColor Yellow
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
        # Following Rule 2.3: OnEnter() Checklist
        
        # Step 1: Fetch initial data from services  
        $this._RefreshTasks()
        $this._UpdateDisplay()
        
        # Step 2: Set initial focus via FocusManager (CRITICAL for input to work)
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._taskGrid) {
            $focusManager.SetFocus($this._taskGrid)
        }
        
        # Step 3: Subscribe to EventManager events
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
        if (-not $this._taskGrid) { return }
        
        # Get the ViewDefinitionService and view definition
        $viewDefService = $this.ServiceContainer?.GetService("ViewDefinitionService")
        if (-not $viewDefService) { return }
        
        $viewDef = $viewDefService.GetViewDefinition('task.summary')
        
        # Configure the grid columns from the view definition
        $this._taskGrid.SetColumns($viewDef.Columns)
        
        if ($this._tasks.Count -eq 0) {
            # Clear the grid if no tasks
            $this._taskGrid.SetItems(@())
            return
        }
        
        # Transform tasks using the view definition transformer
        $transformer = $viewDef.Transformer
        $displayItems = @()
        
        foreach ($task in $this._tasks) {
            $displayItem = & $transformer $task
            $displayItems += $displayItem
        }
        
        # Set the transformed data on the grid
        $this._taskGrid.SetItems($displayItems)
        
        # Preserve selection if possible
        if ($this._selectedIndex -lt $this._tasks.Count) {
            $this._taskGrid.SelectedIndex = $this._selectedIndex
        } else {
            $this._selectedIndex = 0
            $this._taskGrid.SelectedIndex = 0
            if ($this._tasks.Count -gt 0) {
                $this._selectedTask = $this._tasks[0]
            }
        }
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
        $statusText = "Tasks: $($this._tasks.Count)"
        if ($this._tasks.Count -gt 0) {
            $statusText += " | Selected: $($this._selectedIndex + 1)"
        }
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
        $hints = "Up/Down: Navigate | Enter: Edit | D: Delete | N: New | T/P/S/Q: Quick Nav"
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

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # First, let the sidebar menu handle its keys
        $menu = $this.Children | Where-Object { $_ -is [SidebarMenu] } | Select-Object -First 1
        if ($menu -and $menu.HandleKey($keyInfo)) {
            return $true
        }
        
        # Handle action keys (navigation is now handled by DataGridComponent)
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # Edit task
                if ($this._selectedTask -and $this._editButton) {
                    $this._editButton.OnClick.Invoke()
                }
                return $true
            }
            ([ConsoleKey]::N) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    # New task
                    $this._newButton.OnClick.Invoke()
                }
                return $true
            }
            ([ConsoleKey]::E) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Edit task
                    $this._editButton.OnClick.Invoke()
                }
                return $true
            }
            ([ConsoleKey]::D) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Delete task
                    $this._deleteButton.OnClick.Invoke()
                }
                return $true
            }
            ([ConsoleKey]::C) {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -and $this._selectedTask) {
                    # Complete task
                    $this._completeButton.OnClick.Invoke()
                }
                return $true
            }
            default {
                # Unhandled key - let base class handle it
                return ([Screen]$this).HandleInput($keyInfo)
            }
        }
        return $false
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
