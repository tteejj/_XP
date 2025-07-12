# ==============================================================================
# Axiom-Phoenix v4.0 - Edit Task Screen  
# FIXED: Removed sidebar, removed FocusManager dependency
# Uses NCURSES-style window focus model with direct input handling
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: EditTaskScreen
#
# PURPOSE:
#   Full screen for editing existing tasks
#   Uses direct input handling without external focus manager
#
# FOCUS MODEL:
#   - Screen manages which field is "active" internally
#   - Tab cycles through all fields sequentially
#   - Up/Down arrows move between fields
#   - Direct key handling for all operations
#   - NO EXTERNAL FOCUS MANAGER SERVICE
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
    hidden [string]$_activeField = "title"  # Current active field
    hidden [System.Collections.Generic.List[string]]$_fieldOrder  # Tab order
    hidden [int]$_currentFieldIndex = 0
    #endregion
    
    EditTaskScreen([object]$serviceContainer, [PmcTask]$task) : base("EditTaskScreen", $serviceContainer) {
        if (-not $task) { 
            throw "Task is required for EditTaskScreen" 
        }
        $this._task = $task
        $this._originalTask = $task.Clone()  # Keep original for cancel
        
        # Define tab order for fields
        $this._fieldOrder = [System.Collections.Generic.List[string]]::new()
        $this._fieldOrder.AddRange(@(
            "title", "description", "status", "priority", 
            "progress", "project", "save", "cancel"
        ))
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
        $this._titleBox.IsFocusable = $false  # We handle focus internally
        $this._titleBox.BorderColor = Get-ThemeColor "input.border" "#444444"
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
        $this._descriptionBox.IsFocusable = $false  # We handle focus internally
        $this._descriptionBox.BorderColor = Get-ThemeColor "input.border" "#444444"
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
        $this._statusList.IsFocusable = $false  # We handle focus internally
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
        $this._priorityList.IsFocusable = $false  # We handle focus internally
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
        $this._progressBox.IsFocusable = $false  # We handle focus internally
        $this._progressBox.BorderColor = Get-ThemeColor "input.border" "#444444"
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
        $this._projectList.IsFocusable = $false  # We handle focus internally
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
        $this._saveButton.IsFocusable = $false  # We handle focus internally
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $this._saveButton.ForegroundColor = "#FFFFFF"
        $this._formPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "   Cancel   "
        $this._cancelButton.X = $buttonX + 20
        $this._cancelButton.Y = $y
        $this._cancelButton.IsFocusable = $false  # We handle focus internally
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        $this._cancelButton.ForegroundColor = "#FFFFFF"
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
        
        # Set initial focus to title
        $this._activeField = "title"
        $this._currentFieldIndex = 0
        $this._UpdateVisualFocus()
        
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "EditTaskScreen.OnExit: Cleaning up"
        # Nothing to clean up
    }
    
    # === VISUAL FOCUS MANAGEMENT ===
    hidden [void] _UpdateVisualFocus() {
        # Reset all field borders to default
        $defaultBorder = Get-ThemeColor "input.border" "#444444"
        $focusBorder = Get-ThemeColor "primary.accent" "#00D4FF"
        
        $this._titleBox.BorderColor = $defaultBorder
        $this._titleBox.ShowCursor = $false
        $this._descriptionBox.BorderColor = $defaultBorder
        $this._descriptionBox.ShowCursor = $false
        $this._statusList.BorderColor = $defaultBorder
        $this._priorityList.BorderColor = $defaultBorder
        $this._progressBox.BorderColor = $defaultBorder
        $this._progressBox.ShowCursor = $false
        $this._projectList.BorderColor = $defaultBorder
        
        # Reset button colors
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        
        # Apply focus to active field
        switch ($this._activeField) {
            "title" {
                $this._titleBox.BorderColor = $focusBorder
                $this._titleBox.ShowCursor = $true
            }
            "description" {
                $this._descriptionBox.BorderColor = $focusBorder
                $this._descriptionBox.ShowCursor = $true
            }
            "status" {
                $this._statusList.BorderColor = $focusBorder
            }
            "priority" {
                $this._priorityList.BorderColor = $focusBorder
            }
            "progress" {
                $this._progressBox.BorderColor = $focusBorder
                $this._progressBox.ShowCursor = $true
            }
            "project" {
                $this._projectList.BorderColor = $focusBorder
            }
            "save" {
                $this._saveButton.BackgroundColor = Get-ThemeColor "button.hover" "#1976D2"
            }
            "cancel" {
                $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.hover" "#D32F2F"
            }
        }
        
        $this.RequestRedraw()
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
    
    # === FIELD NAVIGATION ===
    hidden [void] _MoveToNextField() {
        $this._currentFieldIndex = ($this._currentFieldIndex + 1) % $this._fieldOrder.Count
        $this._activeField = $this._fieldOrder[$this._currentFieldIndex]
        $this._UpdateVisualFocus()
    }
    
    hidden [void] _MoveToPreviousField() {
        $this._currentFieldIndex = ($this._currentFieldIndex - 1 + $this._fieldOrder.Count) % $this._fieldOrder.Count
        $this._activeField = $this._fieldOrder[$this._currentFieldIndex]
        $this._UpdateVisualFocus()
    }
    
    hidden [void] _MoveToField([string]$fieldName) {
        $index = $this._fieldOrder.IndexOf($fieldName)
        if ($index -ge 0) {
            $this._currentFieldIndex = $index
            $this._activeField = $fieldName
            $this._UpdateVisualFocus()
        }
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
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "EditTaskScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "EditTaskScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Active=$($this._activeField)"
        
        # === HANDLE TEXT INPUT FOR TEXT FIELDS ===
        if ($this._activeField -in @("title", "description", "progress")) {
            $textBox = switch ($this._activeField) {
                "title" { $this._titleBox }
                "description" { $this._descriptionBox }
                "progress" { $this._progressBox }
            }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($textBox.Text.Length -gt 0) {
                        $textBox.Text = $textBox.Text.Substring(0, $textBox.Text.Length - 1)
                        if ($this._activeField -eq "progress") {
                            $this._UpdateProgressBar()
                        }
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    # For simplicity, same as backspace
                    if ($textBox.Text.Length -gt 0) {
                        $textBox.Text = $textBox.Text.Substring(0, $textBox.Text.Length - 1)
                        if ($this._activeField -eq "progress") {
                            $this._UpdateProgressBar()
                        }
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Shift) {
                        $this._MoveToPreviousField()
                    } else {
                        $this._MoveToNextField()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Enter in text field saves the task
                    $this._SaveTask()
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $this._CancelEdit()
                    return $true
                }
                default {
                    # Add character to text field
                    if ($keyInfo.KeyChar -and $keyInfo.KeyChar -ne "`0") {
                        # Special handling for progress field - numbers only
                        if ($this._activeField -eq "progress") {
                            if ([char]::IsDigit($keyInfo.KeyChar) -and $textBox.Text.Length -lt 3) {
                                $textBox.Text += $keyInfo.KeyChar
                                $this._UpdateProgressBar()
                                $this.RequestRedraw()
                            }
                        } else {
                            # Normal text input
                            $textBox.Text += $keyInfo.KeyChar
                            $this.RequestRedraw()
                        }
                        return $true
                    }
                }
            }
        }
        
        # === HANDLE LIST NAVIGATION ===
        if ($this._activeField -in @("status", "priority", "project")) {
            $listBox = switch ($this._activeField) {
                "status" { $this._statusList }
                "priority" { $this._priorityList }
                "project" { $this._projectList }
            }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($listBox.SelectedIndex -gt 0) {
                        $listBox.SelectedIndex--
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($listBox.SelectedIndex -lt $listBox.Items.Count - 1) {
                        $listBox.SelectedIndex++
                        $this.RequestRedraw()
                    }
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Shift) {
                        $this._MoveToPreviousField()
                    } else {
                        $this._MoveToNextField()
                    }
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Enter in list saves the task
                    $this._SaveTask()
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $this._CancelEdit()
                    return $true
                }
            }
        }
        
        # === HANDLE BUTTON ACTIONS ===
        if ($this._activeField -in @("save", "cancel")) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Enter) {
                    if ($this._activeField -eq "save") {
                        $this._SaveTask()
                    } else {
                        $this._CancelEdit()
                    }
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Shift) {
                        $this._MoveToPreviousField()
                    } else {
                        $this._MoveToNextField()
                    }
                    return $true
                }
                ([ConsoleKey]::Escape) {
                    $this._CancelEdit()
                    return $true
                }
            }
        }
        
        # === GLOBAL SHORTCUTS (work from any field) ===
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
        
        # === FUNCTION KEYS ===
        switch ($keyInfo.Key) {
            ([ConsoleKey]::F5) {
                $this._ResetForm()
                return $true
            }
        }
        
        # === CTRL COMBINATIONS ===
        if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) {
                    $this._SaveTask()
                    return $true
                }
            }
        }
        
        Write-Log -Level Debug -Message "EditTaskScreen.HandleInput: Key not handled"
        return $false
    }
}

# ==============================================================================
# END OF EDIT TASK SCREEN
# ==============================================================================
