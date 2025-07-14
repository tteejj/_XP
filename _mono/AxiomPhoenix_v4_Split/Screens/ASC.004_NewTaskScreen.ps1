# ==============================================================================
# Axiom-Phoenix v4.1 - New Task Screen - PROPER IMPLEMENTATION
# ==============================================================================

class NewTaskScreen : Screen {
    # Components
    hidden $_panel
    hidden $_titleBox
    hidden $_descriptionBox
    hidden $_saveButton
    hidden $_cancelButton
    hidden $_priorityLabel
    hidden $_projectLabel
    
    # Services
    hidden $_navService
    hidden $_dataManager
    hidden $_focusManager
    
    # State
    hidden $_priority = [TaskPriority]::Medium
    hidden $_project = "General"
    
    NewTaskScreen([object]$serviceContainer) : base("NewTaskScreen", $serviceContainer) {
        # Get ALL services in constructor
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._focusManager = $serviceContainer.GetService("FocusManager")
    }
    
    [void] Initialize() {
        # Single centered panel
        $panelWidth = 60
        $panelHeight = 16
        $panelX = [Math]::Floor(($this.Width - $panelWidth) / 2)
        $panelY = [Math]::Floor(($this.Height - $panelHeight) / 2)
        
        $this._panel = [Panel]::new("TaskPanel")
        $this._panel.X = $panelX
        $this._panel.Y = $panelY
        $this._panel.Width = $panelWidth
        $this._panel.Height = $panelHeight
        $this._panel.Title = " New Task "
        $this._panel.BorderStyle = "Single"
        $this._panel.BorderColor = Get-ThemeColor "primary.accent"
        $this._panel.BackgroundColor = Get-ThemeColor "panel.background"
        $this.AddChild($this._panel)
        
        $y = 2
        
        # Title label and textbox
        $label = [LabelComponent]::new("TitleLabel")
        $label.Text = "Title:"
        $label.X = 2
        $label.Y = $y
        $label.ForegroundColor = Get-ThemeColor "label.foreground"
        $this._panel.AddChild($label)
        
        $y += 1
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = 2
        $this._titleBox.Y = $y
        $this._titleBox.Width = $panelWidth - 4
        $this._titleBox.Height = 3
        $this._titleBox.IsFocusable = $true
        $this._titleBox.TabIndex = 0
        $this._titleBox.BorderColor = Get-ThemeColor "border"
        
        # Add focus handlers
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._panel.AddChild($this._titleBox)
        
        $y += 4
        
        # Description label and textbox
        $label2 = [LabelComponent]::new("DescLabel")
        $label2.Text = "Description:"
        $label2.X = 2
        $label2.Y = $y
        $label2.ForegroundColor = Get-ThemeColor "label.foreground"
        $this._panel.AddChild($label2)
        
        $y += 1
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $panelWidth - 4
        $this._descriptionBox.Height = 3
        $this._descriptionBox.IsFocusable = $true
        $this._descriptionBox.TabIndex = 1
        $this._descriptionBox.BorderColor = Get-ThemeColor "border"
        
        # Add focus handlers
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "primary.accent"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._panel.AddChild($this._descriptionBox)
        
        $y += 4
        
        # Priority and Project display
        $this._priorityLabel = [LabelComponent]::new("PriorityLabel")
        $this._priorityLabel.Text = "Priority: [$($this._priority)]  [P] to change"
        $this._priorityLabel.X = 2
        $this._priorityLabel.Y = $y
        $this._priorityLabel.ForegroundColor = $this._GetPriorityColor()
        $this._panel.AddChild($this._priorityLabel)
        
        $y += 2
        
        # Buttons
        $buttonY = $panelHeight - 3
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = " Save "
        $this._saveButton.X = 15
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = 10
        $this._saveButton.Height = 3
        $this._saveButton.IsFocusable = $true
        $this._saveButton.TabIndex = 2
        $this._saveButton.BackgroundColor = Get-ThemeColor "primary.accent"
        $this._saveButton.ForegroundColor = Get-ThemeColor "button.foreground"
        
        # Button click handler with closure
        $currentScreen = $this
        $this._saveButton.OnClick = {
            $currentScreen._SaveTask()
        }.GetNewClosure()
        
        $this._panel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = " Cancel "
        $this._cancelButton.X = 35
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 3
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 3
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.secondary"
        $this._cancelButton.ForegroundColor = Get-ThemeColor "button.foreground"
        
        $this._cancelButton.OnClick = {
            $currentScreen._Cancel()
        }.GetNewClosure()
        
        $this._panel.AddChild($this._cancelButton)
    }
    
    [void] OnEnter() {
        # Reset form
        $this._titleBox.Text = ""
        $this._descriptionBox.Text = ""
        $this._priority = [TaskPriority]::Medium
        $this._UpdatePriorityDisplay()
        
        # Base class sets initial focus
        ([Screen]$this).OnEnter()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Get focused component CORRECTLY
        $focused = $this.GetFocusedChild()
        
        # Handle screen-level actions based on focused component
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # Different behavior based on what's focused
                if ($focused -eq $this._titleBox -or $focused -eq $this._descriptionBox) {
                    $this._SaveTask()
                    return $true
                }
                # Don't handle Enter for buttons - they handle themselves
            }
            ([ConsoleKey]::Escape) {
                # Screen-level: go back
                $this._Cancel()
                return $true
            }
        }
        
        # Check for letter shortcuts
        $char = $keyInfo.KeyChar
        if ($char -eq 'p' -or $char -eq 'P') {
            $this._CyclePriority()
            return $true
        }
        
        # Let base handle Tab and route to components
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] _CyclePriority() {
        switch ($this._priority) {
            ([TaskPriority]::Low) { $this._priority = [TaskPriority]::Medium }
            ([TaskPriority]::Medium) { $this._priority = [TaskPriority]::High }
            ([TaskPriority]::High) { $this._priority = [TaskPriority]::Low }
        }
        $this._UpdatePriorityDisplay()
        $this.RequestRedraw()
    }
    
    hidden [void] _UpdatePriorityDisplay() {
        $this._priorityLabel.Text = "Priority: [$($this._priority)]  [P] to change"
        $this._priorityLabel.ForegroundColor = $this._GetPriorityColor()
    }
    
    hidden [string] _GetPriorityColor() {
        switch ($this._priority) {
            ([TaskPriority]::Low) { return Get-ThemeColor "status.success" }
            ([TaskPriority]::Medium) { return Get-ThemeColor "status.warning" }
            ([TaskPriority]::High) { return Get-ThemeColor "status.error" }
        }
        return Get-ThemeColor "label.foreground"
    }
    
    hidden [void] _SaveTask() {
        # Validate title
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._titleBox.BorderColor = Get-ThemeColor "status.error"
            $this.RequestRedraw()
            $this.SetChildFocus($this._titleBox)
            return
        }
        
        # Create task
        $task = [PmcTask]::new($this._titleBox.Text.Trim())
        if (-not [string]::IsNullOrWhiteSpace($this._descriptionBox.Text)) {
            $task.Description = $this._descriptionBox.Text.Trim()
        }
        $task.Priority = $this._priority
        $task.ProjectKey = $this._project
        
        # Save and go back
        $this._dataManager.AddTask($task)
        if ($this._navService.CanGoBack()) {
            $this._navService.GoBack()
        }
    }
    
    hidden [void] _Cancel() {
        if ($this._navService.CanGoBack()) {
            $this._navService.GoBack()
        }
    }
}

# ==============================================================================
# End NewTaskScreen
# ==============================================================================