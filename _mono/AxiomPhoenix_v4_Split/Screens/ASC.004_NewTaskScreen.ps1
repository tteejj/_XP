# ===== CLASS: NewTaskScreen =====
# Purpose: Full screen for creating new tasks
class NewTaskScreen : Screen {
    hidden [Panel]$_formPanel
    hidden [TextBoxComponent]$_titleBox
    hidden [TextBoxComponent]$_descriptionBox
    hidden [ListBox]$_priorityList
    hidden [ListBox]$_projectList
    hidden [LabelComponent]$_statusLabel
    
    NewTaskScreen([object]$serviceContainer) : base("NewTaskScreen", $serviceContainer) {}
    
    [void] Initialize() {
        # Main form panel - full screen
        $this._formPanel = [Panel]::new("NewTaskForm")
        $this._formPanel.X = 0
        $this._formPanel.Y = 0
        $this._formPanel.Width = $this.Width
        $this._formPanel.Height = $this.Height
        $this._formPanel.Title = " New Task "
        $this._formPanel.BorderStyle = "Double"
        $this._formPanel.BorderColor = Get-ThemeColor "Primary"
        $this._formPanel.BackgroundColor = Get-ThemeColor "Background"
        $this.AddChild($this._formPanel)
        
        # Use generous spacing - we have the room!
        $leftMargin = 5
        $topMargin = 3
        $labelHeight = 1     # Height of each label
        $componentSpacing = 1  # Space between label and input
        $sectionSpacing = 2    # Space between sections
        $contentWidth = [Math]::Min(100, $this._formPanel.Width - ($leftMargin * 2))
        
        # Title Section
        $y = $topMargin
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = $leftMargin
        $titleLabel.Y = $y
        $titleLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($titleLabel)
        
        $y += $labelHeight + $componentSpacing
        $this._titleBox = [TextBoxComponent]::new("TitleInput")
        $this._titleBox.X = $leftMargin
        $this._titleBox.Y = $y
        $this._titleBox.Width = $contentWidth
        $this._titleBox.Height = 1
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.IsFocusable = $true
        $this._formPanel.AddChild($this._titleBox)
        
        # Description Section - with proper spacing
        $y += $this._titleBox.Height + $sectionSpacing
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = $leftMargin
        $descLabel.Y = $y
        $descLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($descLabel)
        
        $y += $labelHeight + $componentSpacing
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = $leftMargin
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $contentWidth
        $this._descriptionBox.Height = 1
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.IsFocusable = $true
        $this._formPanel.AddChild($this._descriptionBox)
        
        # Priority and Project side by side
        $y += $this._descriptionBox.Height + $sectionSpacing
        $halfWidth = [Math]::Floor($contentWidth / 2) - 2
        
        # Priority
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = $leftMargin
        $priorityLabel.Y = $y
        $priorityLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = $leftMargin
        $this._priorityList.Y = $y + $labelHeight + $componentSpacing
        $this._priorityList.Width = $halfWidth
        $this._priorityList.Height = 5
        $this._priorityList.HasBorder = $true
        $this._priorityList.BorderStyle = "Single"
        $this._priorityList.AddItem("Low")
        $this._priorityList.AddItem("Medium")
        $this._priorityList.AddItem("High")
        $this._priorityList.SelectedIndex = 1
        $this._priorityList.IsFocusable = $true
        $this._formPanel.AddChild($this._priorityList)
        
        # Project - with more spacing between columns
        $projectX = $leftMargin + $halfWidth + 8
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project:"
        $projectLabel.X = $projectX
        $projectLabel.Y = $y
        $projectLabel.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = $projectX
        $this._projectList.Y = $y + $labelHeight + $componentSpacing
        $this._projectList.Width = $halfWidth
        $this._projectList.Height = 5
        $this._projectList.HasBorder = $true
        $this._projectList.BorderStyle = "Single"
        $this._projectList.AddItem("General")
        $this._projectList.SelectedIndex = 0
        $this._projectList.IsFocusable = $true
        $this._formPanel.AddChild($this._projectList)
        
        # Status and instructions at bottom - with proper spacing from form elements
        $bottomMargin = 3
        $y = $this._formPanel.Height - ($bottomMargin + 3)  # 3 lines for status and instructions
        
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = $leftMargin
        $this._statusLabel.Y = $y
        $this._statusLabel.Text = "Ready to create task"
        $this._statusLabel.ForegroundColor = Get-ThemeColor "Info"
        $this._formPanel.AddChild($this._statusLabel)
        
        $instructLabel = [LabelComponent]::new("InstructLabel")
        $instructLabel.X = $leftMargin
        $instructLabel.Y = $y + 2
        $instructLabel.Text = "Tab: Next field | Ctrl+S: Save | ESC: Cancel"
        $instructLabel.ForegroundColor = Get-ThemeColor "Subtle"
        $this._formPanel.AddChild($instructLabel)
    }
    
    [void] OnEnter() {
        # Load projects
        $dataManager = $this.Services.DataManager
        $projects = $dataManager.GetProjects()
        
        $this._projectList.ClearItems()
        $this._projectList.AddItem("General")
        foreach ($project in $projects) {
            $this._projectList.AddItem($project.Name)
        }
        $this._projectList.SelectedIndex = 0
        
        # Set initial focus
        $focusManager = $this.Services.FocusManager
        $focusManager.SetFocus($this._titleBox)
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
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Error"
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
            if (($this._projectList.SelectedIndex - 1) -lt $projects.Count) {
                $task.ProjectKey = $projects[$this._projectList.SelectedIndex - 1].Key
            }
        }
        
        # Save task
        try {
            $dataManager = $this.Services.DataManager
            $dataManager.AddTask($task)
            $dataManager.SaveData()  # Force save to disk
            
            $this._statusLabel.Text = "Task created successfully!"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Success"
            
            # Navigate back after short delay
            Start-Sleep -Milliseconds 500
            $navService = $this.Services.NavigationService
            $navService.GoBack()
        }
        catch {
            $this._statusLabel.Text = "Error: $($_.Exception.Message)"
            $this._statusLabel.ForegroundColor = Get-ThemeColor "Error"
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle ESC to cancel
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            $navService = $this.Services.NavigationService
            $navService.GoBack()
            return $true
        }
        
        # Handle Ctrl+S to save
        if ($keyInfo.Key -eq [ConsoleKey]::S -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.SaveTask()
            return $true
        }
        
        # Let base handle focus navigation
        return ([Screen]$this).HandleInput($keyInfo)
    }
}
