# Fix 1: Update NewTaskScreen to handle ESC properly and fix text input visibility
$newTaskScreenContent = @'
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
        $this._formPanel.BorderColor = Get-ThemeColor "Primary"
        $this._formPanel.BackgroundColor = Get-ThemeColor "Background" 
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
        $this._titleBox.Width = [Math]::Min(50, $this._formPanel.Width - 6)
        $this._titleBox.Height = 3
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.IsFocusable = $true
        $this._titleBox.BackgroundColor = Get-ThemeColor "Background"
        $this._titleBox.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($this._titleBox)
        
        # Description input
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = 7
        $this._formPanel.AddChild($descLabel)
        
        $this._descriptionBox = [TextBoxComponent]::new("DescInput")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = 8
        $this._descriptionBox.Width = [Math]::Min(50, $this._formPanel.Width - 6)
        $this._descriptionBox.Height = 3
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.IsFocusable = $true
        $this._descriptionBox.BackgroundColor = Get-ThemeColor "Background"
        $this._descriptionBox.ForegroundColor = Get-ThemeColor "Foreground"
        $this._formPanel.AddChild($this._descriptionBox)
        
        # Priority selection
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority: [Low/Medium/High]"
        $priorityLabel.X = 2
        $priorityLabel.Y = 12
        $this._formPanel.AddChild($priorityLabel)
        
        $this._priorityList = [ListBox]::new("PriorityList")
        $this._priorityList.X = 2
        $this._priorityList.Y = 13
        $this._priorityList.Width = 20
        $this._priorityList.Height = 5
        $this._priorityList.AddItem("Low")
        $this._priorityList.AddItem("Medium")
        $this._priorityList.AddItem("High")
        $this._priorityList.SelectedIndex = 1  # Default to Medium
        $this._priorityList.IsFocusable = $true
        $this._priorityList.SelectedBackgroundColor = Get-ThemeColor "Primary"
        $this._priorityList.SelectedForegroundColor = Get-ThemeColor "Background"
        $this._formPanel.AddChild($this._priorityList)
        
        # Project selection
        $projectLabel = [LabelComponent]::new("ProjectLabel")
        $projectLabel.Text = "Project: [General]"
        $projectLabel.X = 25
        $projectLabel.Y = 12
        $this._formPanel.AddChild($projectLabel)
        
        $this._projectList = [ListBox]::new("ProjectList")
        $this._projectList.X = 25
        $this._projectList.Y = 13
        $this._projectList.Width = 20
        $this._projectList.Height = 5
        $this._projectList.AddItem("General")
        $this._projectList.SelectedIndex = 0
        $this._projectList.IsFocusable = $true
        $this._projectList.SelectedBackgroundColor = Get-ThemeColor "Primary"
        $this._projectList.SelectedForegroundColor = Get-ThemeColor "Background"
        $this._formPanel.AddChild($this._projectList)
        
        # Status label
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 19
        $this._statusLabel.Text = "Ready to create task"
        $this._statusLabel.ForegroundColor = (Get-ThemeColor "Info")
        $this._formPanel.AddChild($this._statusLabel)
        
        # Instruction label
        $instructLabel = [LabelComponent]::new("InstructLabel")
        $instructLabel.X = 2
        $instructLabel.Y = 21
        $instructLabel.Text = "Tab: Next field | S: Save | ESC: Cancel"
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
            
            # Force save to disk
            $dataManager.SaveData()
            
            $this._statusLabel.Text = "Task created successfully!"
            $this._statusLabel.ForegroundColor = (Get-ThemeColor "Success")
            
            # Clear form
            $this._titleBox.Text = ""
            $this._descriptionBox.Text = ""
            $this._priorityList.SelectedIndex = 1
            $this._projectList.SelectedIndex = 0
            
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
        # Handle ESC first - before menu gets it
        if ($keyInfo.Key -eq [ConsoleKey]::Escape) {
            $navService = $this.Services.NavigationService
            $navService.GoBack()
            return $true
        }
        
        # Handle save shortcut
        if ($keyInfo.Key -eq [ConsoleKey]::S -and -not ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.SaveTask()
            return $true
        }
        
        # Let menu handle its keys
        if ($this._menu.HandleKey($keyInfo)) {
            return $true
        }
        
        # Let base handle focus navigation
        return ([Screen]$this).HandleInput($keyInfo)
    }
}
'@

# Fix 2: Update TextBoxComponent for better visibility
$textBoxComponentContent = @'
# ===== CLASS: TextBoxComponent =====
# Module: tui-components
# Dependencies: UIElement, TuiCell
# Purpose: Text input with viewport scrolling, non-destructive cursor
class TextBoxComponent : UIElement {
    [string]$Text = ""
    [string]$Placeholder = ""
    [ValidateRange(1, [int]::MaxValue)][int]$MaxLength = 100
    [int]$CursorPosition = 0
    [scriptblock]$OnChange
    hidden [int]$_scrollOffset = 0
    [string