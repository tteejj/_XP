# ==============================================================================
# Axiom-Phoenix v4.1 - New Task Screen - GUIDE COMPLIANT
# ==============================================================================

class NewTaskScreen : Screen {
    # Components
    hidden $_panel
    hidden $_titleBox
    hidden $_descriptionBox
    hidden $_saveButton
    hidden $_cancelButton
    hidden $_priorityLabel
    
    # Services
    hidden $_navService
    hidden $_dataManager
    
    # State
    hidden $_priority = [TaskPriority]::Medium
    
    NewTaskScreen([object]$serviceContainer) : base("NewTaskScreen", $serviceContainer) {
        # Get ALL services in constructor - GUIDE RULE
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
    }
    
    [void] Initialize() {
        # Create main panel
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
        $this._panel.HasBorder = $true
        $this.AddChild($this._panel)
        
        $y = 2
        
        # Title
        $label = [LabelComponent]::new("TitleLabel")
        $label.Text = "Title:"
        $label.X = 2
        $label.Y = $y
        $this._panel.AddChild($label)
        
        $y += 1
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = 2
        $this._titleBox.Y = $y
        $this._titleBox.Width = $panelWidth - 4
        $this._titleBox.Height = 3
        $this._titleBox.IsFocusable = $true
        $this._titleBox.TabIndex = 0
        
        # Add missing focus handlers as per guide
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            Request-OptimizedRedraw -Source "TitleBox:OnFocus"
        } -Force
        
        $this._titleBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            Request-OptimizedRedraw -Source "TitleBox:OnBlur"
        } -Force
        
        $this._panel.AddChild($this._titleBox)
        
        $y += 4
        
        # Description
        $label2 = [LabelComponent]::new("DescLabel")
        $label2.Text = "Description:"
        $label2.X = 2
        $label2.Y = $y
        $this._panel.AddChild($label2)
        
        $y += 1
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $panelWidth - 4
        $this._descriptionBox.Height = 3
        $this._descriptionBox.IsFocusable = $true
        $this._descriptionBox.TabIndex = 1
        
        # Add missing focus handlers as per guide
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            Request-OptimizedRedraw -Source "DescBox:OnFocus"
        } -Force
        
        $this._descriptionBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            Request-OptimizedRedraw -Source "DescBox:OnBlur"
        } -Force
        
        $this._panel.AddChild($this._descriptionBox)
        
        $y += 4
        
        # Priority
        $this._priorityLabel = [LabelComponent]::new("PriorityLabel")
        $this._priorityLabel.Text = "Priority: [$($this._priority)]  [P] to change"
        $this._priorityLabel.X = 2
        $this._priorityLabel.Y = $y
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
        
        $currentScreenRef = $this
        $this._saveButton.OnClick = {
            $currentScreenRef._SaveTask()
        }.GetNewClosure()
        
        $this._saveButton.Enabled = $true
        $this._panel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = " Cancel "
        $this._cancelButton.X = 35
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 3
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 3
        
        $this._cancelButton.OnClick = {
            $currentScreenRef._Cancel()
        }.GetNewClosure()
        
        $this._cancelButton.Enabled = $true
        $this._panel.AddChild($this._cancelButton)
    }
    
    [void] OnEnter() {
        # Reset form
        $this._titleBox.Text = ""
        $this._descriptionBox.Text = ""
        $this._priority = [TaskPriority]::Medium
        $this._UpdatePriorityDisplay()
        
        $this.InvalidateFocusCache()
        ([Screen]$this).OnEnter()
        
        # Set initial focus to first input field
        $this.SetChildFocus($this._titleBox)
        Request-OptimizedRedraw -Source "NewTaskScreen:OnEnter"
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        $focused = $this.GetFocusedChild()
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                if ($focused -eq $this._saveButton) {
                    $this._SaveTask()
                    return $true
                }
                elseif ($focused -eq $this._cancelButton) {
                    $this._Cancel()
                    return $true
                }
            }
            ([ConsoleKey]::Escape) {
                $this._Cancel()
                return $true
            }
            ([ConsoleKey]::S) {
                # Handle Ctrl+S for save
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    $this._SaveTask()
                    return $true
                }
            }
        }
        
        switch ($keyInfo.KeyChar) {
            { $_ -eq 'p' -or $_ -eq 'P' } {
                $this._CyclePriority()
                return $true
            }
        }
        
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
        $color = Get-ThemeColor "label.foreground"
        switch ($this._priority) {
            ([TaskPriority]::Low) { $color = Get-ThemeColor "status.success" }
            ([TaskPriority]::Medium) { $color = Get-ThemeColor "status.warning" }
            ([TaskPriority]::High) { $color = Get-ThemeColor "status.error" }
        }
        $this._priorityLabel.ForegroundColor = $color
    }
    
    hidden [void] _SaveTask() {
        if ([string]::IsNullOrWhiteSpace($this._titleBox.Text)) {
            $this._titleBox.BorderColor = Get-ThemeColor "status.error"
            Request-OptimizedRedraw -Source "NewTaskScreen:SaveValidation"
            return
        }
        
        $task = [PmcTask]::new($this._titleBox.Text.Trim())
        if (-not [string]::IsNullOrWhiteSpace($this._descriptionBox.Text)) {
            $task.Description = $this._descriptionBox.Text.Trim()
        }
        $task.Priority = $this._priority
        $task.ProjectKey = "General"
        
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