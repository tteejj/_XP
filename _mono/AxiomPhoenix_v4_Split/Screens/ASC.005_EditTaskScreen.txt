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
