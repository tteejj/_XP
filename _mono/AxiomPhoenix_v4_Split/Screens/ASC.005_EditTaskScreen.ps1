# ==============================================================================
# Axiom-Phoenix v4.0 - Edit Task Screen  
# REFACTORED: Uses Hybrid Window Model for focus management
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: EditTaskScreen
#
# PURPOSE:
#   Full screen for editing existing tasks
#   Uses hybrid window model with automatic focus management
#
# FOCUS MODEL:
#   - Components are focusable and handle their own input
#   - Screen base class manages Tab navigation automatically  
#   - Components show visual focus feedback via OnFocus/OnBlur
#   - Screen handles only global shortcuts and actions
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (for screen transitions)
#     - DataManager (for task CRUD operations)
#     - EventManager (for data change notifications)
#   Components:
#     - Panel (containers)
#     - TextBoxComponent (input fields)
#     - ListBox (selection lists)
#     - LabelComponent (display elements)
#     - ButtonComponent (action buttons)
# ==============================================================================
class EditTaskScreen : Screen {
    #region UI Components
    hidden [Panel]$_mainPanel              # Main container
    hidden [Panel]$_formPanel              # Form content panel
    hidden [Panel]$_statusBar              # Bottom status bar
    hidden [TextBoxComponent]$_titleBox
    hidden [TextBoxComponent]$_descriptionBox
    hidden [ListBox]$_priorityList
    hidden [ListBox]$_statusList
    hidden [ListBox]$_projectList
    hidden [TextBoxComponent]$_progressBox
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    hidden [LabelComponent]$_statusLabel
    #endregion
    
    #region State
    hidden [PmcTask]$_task
    hidden [PmcTask]$_originalTask  # For cancel/revert
    #endregion
    
    EditTaskScreen([object]$serviceContainer, [PmcTask]$task) : base("EditTaskScreen", $serviceContainer) {
        if (-not $task) { 
            throw "Task is required for EditTaskScreen" 
        }
        $this._task = $task
        $this._originalTask = $task.Clone()  # Keep original for cancel
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "EditTaskScreen.Initialize: Starting"
        
        # === MAIN PANEL ===
        $this._mainPanel = [Panel]::new("EditTaskMain")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " ╔═ Edit Task ═╗ "
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
        $this._mainPanel.BackgroundColor = Get-ThemeColor "background" "#0A0A0A"
        $this.AddChild($this._mainPanel)
        
        # === FORM PANEL ===
        $this._formPanel = [Panel]::new("EditTaskForm")
        $this._formPanel.X = 1
        $this._formPanel.Y = 1
        $this._formPanel.Width = $this.Width - 2
        $this._formPanel.Height = $this.Height - 5  # Leave room for status bar
        $this._formPanel.Title = " Task Details "
        $this._formPanel.BorderStyle = "Single"
        $this._formPanel.BorderColor = Get-ThemeColor "border" "#333333"
        $this._mainPanel.AddChild($this._formPanel)
        
        # Calculate layout dimensions
        $contentWidth = $this._formPanel.Width - 4
        $leftColumnX = 2
        $rightColumnX = [Math]::Floor($contentWidth / 2) + 2
        $fieldWidth = [Math]::Floor($contentWidth / 2) - 2
        
        $y = 2
        
        # === TITLE FIELD ===
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = $leftColumnX
        $titleLabel.Y = $y
        $titleLabel.ForegroundColor = Get-ThemeColor "label" "#FFD700"
        $this._formPanel.AddChild($titleLabel)
        
        $y++
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.X = $leftColumnX
        $this._titleBox.Y = $y
        $this._titleBox.Width = $contentWidth
        $this._titleBox.Height = 3
        $this._titleBox.Text = $this._task.Title
        $this._titleBox.IsFocusable = $true
        $this._titleBox.TabIndex = 0
        $this._titleBox.BorderColor = Get-ThemeColor "input.border" "#444444"
        
        # Add focus visual feedback
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._formPanel.AddChild($this._titleBox)
        
        $y += 4
        
        # === DESCRIPTION FIELD ===
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = $leftColumnX
        $descLabel.Y = $y
        $descLabel.ForegroundColor = Get-ThemeColor "label" "#00D4FF"
        $this._formPanel.AddChild($descLabel)
        
        $y++
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = $leftColumnX
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $contentWidth
        $this._descriptionBox.Height = 3
        $this._descriptionBox.Text = $this._task.Description
        $this._descriptionBox.IsFocusable = $true
        $this._descriptionBox.TabIndex = 1
        $this._descriptionBox.BorderColor = Get-ThemeColor "input.border" "#444444"
        
        # Add focus visual feedback
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._formPanel.AddChild($this._descriptionBox)
        
        $y += 4
        
        # === STATUS & PRIORITY (Left Column) ===
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = $leftColumnX
        $statusLabel.Y = $y
        $statusLabel.ForegroundColor = Get-ThemeColor "label" "#FF69B4"
        $this._formPanel.AddChild($statusLabel)
        
        $y++
        $this._statusList = [ListBox]::new("StatusList")
        $this._statusList.X = $leftColumnX
        $this._statusList.Y = $y
        $this._statusList.Width = $fieldWidth
        $this._statusList.Height = 6
        $this._statusList.HasBorder = $true
        $this._statusList.BorderColor = Get-ThemeColor "input.border" "#444444"
        $this._statusList.AddItem("○ Pending")
        $this._statusList.AddItem("◐ InProgress")
        $this._statusList.AddItem("● Completed")
        $this._statusList.AddItem("✕ Cancelled")
        $this._statusList.SelectedIndex = [int]$this._task.Status
        $this._statusList.IsFocusable = $true
        $this._statusList.TabIndex = 2
        
        # Add focus visual feedback  
        $this._statusList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.RequestRedraw()
        } -Force
        
        $this._statusList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.RequestRedraw()
        } -Force
        
        $this._formPanel.AddChild($this._statusList)
        
        # Priority (Right Column)
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = $rightColumnX
        $priorityLabel.Y = $y - 1
        $priorityLabel.ForegroundColor = Get-ThemeColor "label" "#FFA500"
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = $rightColumnX
        $this._priorityList.Y = $y
        $this._priorityList.Width = $fieldWidth
        $this._priorityList.Height = 5
        $this._priorityList.HasBorder = $true
        $this._priorityList.BorderColor = Get-ThemeColor "input.border" "#444444"
        $this._priorityList.AddItem("↓ Low")
        $this._priorityList.AddItem("- Medium")
        $this._priorityList.AddItem("! High")
        $this._priorityList.SelectedIndex = [int]$this._task.Priority
        $this._priorityList.IsFocusable = $true
        $this._priorityList.TabIndex = 3
        
        # Add focus visual feedback
        $this._priorityList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.RequestRedraw()
        } -Force
        
        $this._priorityList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.RequestRedraw()
        } -Force
        
        $this._formPanel.AddChild($this._priorityList)
        
        $y += 7
        
        # === PROGRESS & PROJECT ===
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Progress (%):"
        $progressLabel.X = $leftColumnX
        $progressLabel.Y = $y
        $progressLabel.ForegroundColor = Get-ThemeColor "label" "#00FF88"
        $this._formPanel.AddChild($progressLabel)
        
        $y++
        $this._progressBox = [TextBoxComponent]::new("ProgressInput")
        $this._progressBox.X = $leftColumnX
        $this._progressBox.Y = $y
        $this._progressBox.Width = 15
        $this._progressBox.Height = 3
        $this._progressBox.Text = $this._task.Progress.ToString()
        $this._progressBox.MaxLength = 3
        $this._progressBox.IsFocusable = $true
        $this._progressBox.TabIndex = 4
        $this._progressBox.BorderColor = Get-ThemeColor "input.border" "#444444"
        
        # Add focus visual feedback
        $this._progressBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._progressBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        # Add progress bar update when text changes
        $this._progressBox | Add-Member -MemberType ScriptMethod -Name OnTextChanged -Value {
            $parent = $this.Parent
            if ($parent) {
                $screen = $parent.Parent
                if ($screen -and $screen.GetType().Name -eq "EditTaskScreen") {
                    $screen._UpdateProgressBar()
                }
            }
        } -Force
        
        $this._formPanel.AddChild($this._progressBox)
        
        # Progress bar visualization
        $progressBarLabel = [LabelComponent]::new("ProgressBar")
        $progressBarLabel.X = $leftColumnX + 18
        $progressBarLabel.Y = $y + 1
        $barWidth = 20
        $filledWidth = [Math]::Floor($barWidth * $this._task.Progress / 100)
        $progressBar = "█" * $filledWidth + "░" * ($barWidth - $filledWidth)
        $progressBarLabel.Text = $progressBar
        $progressBarLabel.ForegroundColor = if ($this._task.Progress -eq 100) { "#00FF88" } else { "#00BFFF" }
        $this._formPanel.AddChild($progressBarLabel)
        
        # Project (Right Column)
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project:"
        $projectLabel.X = $rightColumnX
        $projectLabel.Y = $y - 1
        $projectLabel.ForegroundColor = Get-ThemeColor "label" "#8A2BE2"
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = $rightColumnX
        $this._projectList.Y = $y
        $this._projectList.Width = $fieldWidth
        $this._projectList.Height = 5
        $this._projectList.HasBorder = $true
        $this._projectList.BorderColor = Get-ThemeColor "input.border" "#444444"
        $this._projectList.AddItem("None")
        $this._projectList.IsFocusable = $true
        $this._projectList.TabIndex = 5
        
        # Add focus visual feedback
        $this._projectList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            $this.RequestRedraw()
        } -Force
        
        $this._projectList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border" "#444444"
            $this.RequestRedraw()
        } -Force
        
        $this._formPanel.AddChild($this._projectList)
        
        $y += 6
        
        # === STATUS MESSAGE ===
        $this._statusLabel = [LabelComponent]::new("StatusMessageLabel")
        $this._statusLabel.X = $leftColumnX
        $this._statusLabel.Y = $y
        $this._statusLabel.Text = "Ready to save changes"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "info" "#00D4FF"
        $this._formPanel.AddChild($this._statusLabel)
        
        $y += 2
        
        # === ACTION BUTTONS ===
        $buttonX = [Math]::Floor($contentWidth / 2) - 15
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = " Save Changes "
        $this._saveButton.X = $buttonX
        $this._saveButton.Y = $y
        $this._saveButton.IsFocusable = $true
        $this._saveButton.TabIndex = 6
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $this._saveButton.ForegroundColor = "#FFFFFF"
        
        # Add focus visual feedback and click handler
        $this._saveButton | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BackgroundColor = Get-ThemeColor "button.hover" "#1976D2"
            $this.RequestRedraw()
        } -Force
        
        $this._saveButton | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
            $this.RequestRedraw()
        } -Force
        
        $this._saveButton.OnClick = { 
            $screen = $this.Parent.Parent
            if ($screen -and $screen.GetType().Name -eq "EditTaskScreen") {
                $screen._SaveTask()
            }
        }
        
        $this._formPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "   Cancel   "
        $this._cancelButton.X = $buttonX + 20
        $this._cancelButton.Y = $y
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 7
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        $this._cancelButton.ForegroundColor = "#FFFFFF"
        
        # Add focus visual feedback and click handler
        $this._cancelButton | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BackgroundColor = Get-ThemeColor "button.cancel.hover" "#D32F2F"
            $this.RequestRedraw()
        } -Force
        
        $this._cancelButton | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
            $this.RequestRedraw()
        } -Force
        
        $this._cancelButton.OnClick = {
            $screen = $this.Parent.Parent
            if ($screen -and $screen.GetType().Name -eq "EditTaskScreen") {
                $screen._CancelEdit()
            }
        }
        
        $this._formPanel.AddChild($this._cancelButton)
        
        # === BOTTOM STATUS BAR ===
        $this._CreateStatusBar()
        
        Write-Log -Level Debug -Message "EditTaskScreen.Initialize: Completed"
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

        # Help text
        $helpLabel = [LabelComponent]::new("HelpLabel")
        $helpLabel.X = 2
        $helpLabel.Y = 1
        $helpLabel.Text = "[Tab] Next Field | [↑↓] Navigate Lists | [Enter] Save | [Esc] Cancel | [F5] Reset"
        $helpLabel.ForegroundColor = Get-ThemeColor "help" "#666666"
        $this._statusBar.AddChild($helpLabel)
        
        # Shortcut hints on right
        $shortcutsLabel = [LabelComponent]::new("Shortcuts")
        $shortcutsLabel.X = $this._statusBar.Width - 30
        $shortcutsLabel.Y = 1
        $shortcutsLabel.Text = "[P] Priority | [S] Status"
        $shortcutsLabel.ForegroundColor = Get-ThemeColor "help" "#888888"
        $this._statusBar.AddChild($shortcutsLabel)
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "EditTaskScreen.OnEnter: Starting"
        
        # Load projects
        $this._LoadProjects()
        
        # Call base to set initial focus automatically
        ([Screen]$this).OnEnter()
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "EditTaskScreen.OnExit: Cleaning up"
        # Nothing to clean up
    }
    
    # === DATA LOADING ===
    hidden [void] _LoadProjects() {
        $dataManager = $this.ServiceContainer?.GetService("DataManager")
        if (-not $dataManager) { return }
        
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
    }
    
    # === SAVE/CANCEL OPERATIONS ===
    hidden [void] _SaveTask() {
        Write-Log -Level Debug -Message "EditTaskScreen._SaveTask: Starting save"
        
        # Validate input
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._statusLabel.Text = "Error: Title is required"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "error" "#FF4444"
            $this.RequestRedraw()
            return
        }
        
        # Validate progress
        $progress = 0
        if (-not [int]::TryParse($this._progressBox.Text, [ref]$progress) -or $progress -lt 0 -or $progress -gt 100) {
            $this._statusLabel.Text = "Error: Progress must be 0-100"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "error" "#FF4444"
            $this.RequestRedraw()
            return
        }
        
        # Update task object
        $this._task.Title = $this._titleBox.Text.Trim()
        $this._task.Description = $this._descriptionBox.Text.Trim()
        $this._task.Status = [TaskStatus]$this._statusList.SelectedIndex
        $this._task.Priority = [TaskPriority]$this._priorityList.SelectedIndex
        $this._task.SetProgress($progress)
        
        # Set project
        if ($this._projectList.SelectedIndex -eq 0) {
            $this._task.ProjectKey = $null
        } else {
            $dataManager = $this.ServiceContainer?.GetService("DataManager")
            $projects = $dataManager.GetProjects()
            if ($this._projectList.SelectedIndex -le $projects.Count) {
                $this._task.ProjectKey = $projects[$this._projectList.SelectedIndex - 1].Key
            }
        }
        
        # Update timestamp
        $this._task.UpdatedAt = [DateTime]::Now
        
        # Save task
        try {
            $dataManager = $this.ServiceContainer?.GetService("DataManager")
            if ($dataManager) {
                $dataManager.UpdateTask($this._task)
                
                $this._statusLabel.Text = "Task updated successfully!"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "success" "#00FF88"
                $this.RequestRedraw()
                
                # Publish event
                $eventManager = $this.ServiceContainer?.GetService("EventManager")
                if ($eventManager) {
                    $eventManager.Publish("Tasks.Changed", @{ Action = "Updated"; Task = $this._task })
                }
                
                # Navigate back after short delay
                Start-Sleep -Milliseconds 300
                $this._NavigateBack()
            }
        }
        catch {
            $this._statusLabel.Text = "Error: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "error" "#FF4444"
            $this.RequestRedraw()
        }
    }
    
    hidden [void] _CancelEdit() {
        Write-Log -Level Debug -Message "EditTaskScreen._CancelEdit: Cancelling edit"
        
        # Restore original values
        $this._task.Title = $this._originalTask.Title
        $this._task.Description = $this._originalTask.Description
        $this._task.Status = $this._originalTask.Status
        $this._task.Priority = $this._originalTask.Priority
        $this._task.Progress = $this._originalTask.Progress
        $this._task.ProjectKey = $this._originalTask.ProjectKey
        
        $this._NavigateBack()
    }
    
    hidden [void] _NavigateBack() {
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        } else {
            # Fallback to task list
            $actionService = $this.ServiceContainer?.GetService("ActionService")
            if ($actionService) {
                $actionService.ExecuteAction("navigation.taskList", @{})
            }
        }
    }
    
    hidden [void] _ResetForm() {
        # Reset to original values
        $this._titleBox.Text = $this._originalTask.Title
        $this._descriptionBox.Text = $this._originalTask.Description
        $this._statusList.SelectedIndex = [int]$this._originalTask.Status
        $this._priorityList.SelectedIndex = [int]$this._originalTask.Priority
        $this._progressBox.Text = $this._originalTask.Progress.ToString()
        
        # Update progress bar
        $this._UpdateProgressBar()
        
        # Load projects again to reset selection
        $this._LoadProjects()
        
        $this._statusLabel.Text = "Form reset to original values"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "info" "#00D4FF"
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdateProgressBar() {
        $progressBar = $this._formPanel.Children | Where-Object { $_.Name -eq "ProgressBar" }
        if ($progressBar) {
            $progress = 0
            if ([int]::TryParse($this._progressBox.Text, [ref]$progress)) {
                $barWidth = 20
                $filledWidth = [Math]::Floor($barWidth * $progress / 100)
                $bar = "█" * $filledWidth + "░" * ($barWidth - $filledWidth)
                $progressBar.Text = $bar
                $progressBar.ForegroundColor = if ($progress -eq 100) { "#00FF88" } else { "#00BFFF" }
            }
        }
    }
    
    # === QUICK ACTIONS ===
    hidden [void] _CyclePriority() {
        $currentIndex = $this._priorityList.SelectedIndex
        $this._priorityList.SelectedIndex = ($currentIndex + 1) % 3
        $this._statusLabel.Text = "Priority changed to $([TaskPriority]$this._priorityList.SelectedIndex)"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "info" "#00D4FF"
        $this.RequestRedraw()
    }
    
    hidden [void] _CycleStatus() {
        $currentIndex = $this._statusList.SelectedIndex
        $this._statusList.SelectedIndex = ($currentIndex + 1) % 4
        $this._statusLabel.Text = "Status changed to $([TaskStatus]$this._statusList.SelectedIndex)"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "info" "#00D4FF"
        $this.RequestRedraw()
    }
    
    # === INPUT HANDLING (HYBRID MODEL) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "EditTaskScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "EditTaskScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)'"
        
        # The base Screen class handles Tab navigation automatically!
        # Just call the base implementation first
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle global shortcuts that work regardless of focus
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this._CancelEdit()
                return $true
            }
            ([ConsoleKey]::F5) {
                $this._ResetForm()
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Enter saves from anywhere
                $this._SaveTask()
                return $true
            }
        }
        
        # Handle global character shortcuts
        if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) {
                    $this._SaveTask()
                    return $true
                }
            }
        }
        
        # Quick action shortcuts (case-insensitive)
        switch ($keyInfo.KeyChar) {
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
            's' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this._CycleStatus()
                    return $true
                }
            }
            'S' {
                $this._CycleStatus()
                return $true
            }
        }
        
        Write-Log -Level Debug -Message "EditTaskScreen.HandleInput: Key not handled"
        return $false
    }
}

# ==============================================================================
# END OF EDIT TASK SCREEN
# ==============================================================================
