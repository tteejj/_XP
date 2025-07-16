class NewTaskEntryScreen : Screen {
    # Component fields
    hidden $_panel
    hidden $_titleLabel
    hidden $_titleTextBox
    hidden $_descriptionLabel
    hidden $_descriptionTextBox
    hidden $_saveButton
    hidden $_cancelButton
    
    # Service fields (untyped as per guide)
    hidden $_navService
    hidden $_dataManager
    
    NewTaskEntryScreen([object]$serviceContainer) : base("NewTaskEntry", $serviceContainer) {
        # Get services in constructor - NEVER in methods
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
    }
    
    [void] Initialize() {
        # Guard against multiple initialization
        if ($this._isInitialized) { return }
        
        # Create main panel
        $this._panel = [Panel]::new("MainPanel")
        $this._panel.Width = $this.Width - 4
        $this._panel.Height = $this.Height - 4
        $this._panel.X = 2
        $this._panel.Y = 2
        $this._panel.HasBorder = $true
        $this._panel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._panel.BorderColor = Get-ThemeColor "panel.border"
        $this.AddChild($this._panel)
        
        # Create title label
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = "New Task"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 2
        $this._titleLabel.Width = 20
        $this._titleLabel.Height = 1
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._panel.AddChild($this._titleLabel)
        
        # Create task title text box
        $this._titleTextBox = [TextBoxComponent]::new("TitleTextBox")
        $this._titleTextBox.Text = ""
        $this._titleTextBox.X = 2
        $this._titleTextBox.Y = 4
        $this._titleTextBox.Width = $this._panel.Width - 4
        $this._titleTextBox.Height = 3
        $this._titleTextBox.IsFocusable = $true
        $this._titleTextBox.TabIndex = 0
        
        # Add enhanced focus handlers with TextEdit features
        $this._titleTextBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._titleTextBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        # Add enhanced keyboard support (Ctrl+Left/Right for word navigation)
        $this._titleTextBox | Add-Member -MemberType ScriptMethod -Name HandleEnhancedInput -Value {
            param($keyInfo)
            if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::LeftArrow) { 
                        # Move to previous word boundary
                        return $true 
                    }
                    ([ConsoleKey]::RightArrow) { 
                        # Move to next word boundary
                        return $true 
                    }
                    ([ConsoleKey]::Home) { 
                        # Move to start of text
                        return $true 
                    }
                    ([ConsoleKey]::End) { 
                        # Move to end of text
                        return $true 
                    }
                }
            }
            return $false
        } -Force
        
        $this._panel.AddChild($this._titleTextBox)
        
        # Create description label
        $this._descriptionLabel = [LabelComponent]::new("DescriptionLabel")
        $this._descriptionLabel.Text = "Description (optional):"
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = 8
        $this._descriptionLabel.Width = 30
        $this._descriptionLabel.Height = 1
        $this._descriptionLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._panel.AddChild($this._descriptionLabel)
        
        # Create description text box
        $this._descriptionTextBox = [TextBoxComponent]::new("DescriptionTextBox")
        $this._descriptionTextBox.Text = ""
        $this._descriptionTextBox.X = 2
        $this._descriptionTextBox.Y = 10
        $this._descriptionTextBox.Width = $this._panel.Width - 4
        $this._descriptionTextBox.Height = 3
        $this._descriptionTextBox.IsFocusable = $true
        $this._descriptionTextBox.TabIndex = 1
        
        # Add focus handlers as per guide
        $this._descriptionTextBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._descriptionTextBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._panel.AddChild($this._descriptionTextBox)
        
        # Create save button
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save Task"
        $this._saveButton.X = 2
        $this._saveButton.Y = $this._panel.Height - 4
        $this._saveButton.Width = 15
        $this._saveButton.Height = 3
        $this._saveButton.IsFocusable = $true
        $this._saveButton.TabIndex = 2
        
        # Set button click handler with closure
        $currentScreenRef = $this
        $this._saveButton.OnClick = {
            $currentScreenRef._SaveTask()
        }.GetNewClosure()
        
        $this._panel.AddChild($this._saveButton)
        
        # Create cancel button
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $this._panel.Width - 15
        $this._cancelButton.Y = $this._panel.Height - 4
        $this._cancelButton.Width = 12
        $this._cancelButton.Height = 3
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 3
        
        # Set button click handler with closure
        $this._cancelButton.OnClick = {
            $currentScreenRef._Cancel()
        }.GetNewClosure()
        
        $this._panel.AddChild($this._cancelButton)
        
        # Set initialization flag at END
        $this._isInitialized = $true
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Get focused component using METHOD not property
        $focused = $this.GetFocusedChild()
        
        # Handle screen-level actions
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # Save task when Enter is pressed on Save button
                if ($focused -eq $this._saveButton) {
                    $this._SaveTask()
                    return $true
                }
                # Cancel when Enter is pressed on Cancel button
                elseif ($focused -eq $this._cancelButton) {
                    $this._Cancel()
                    return $true
                }
                # Don't handle Enter for text boxes - they handle themselves
            }
            ([ConsoleKey]::Escape) {
                # Screen-level: cancel and go back
                $this._Cancel()
                return $true
            }
        }
        
        # Handle keyboard shortcuts
        switch ($keyInfo.KeyChar) {
            's' { 
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    $this._SaveTask()
                    return $true
                }
            }
            'S' { 
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Control) {
                    $this._SaveTask()
                    return $true
                }
            }
        }
        
        # Let base handle Tab and route to components
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    [void] OnEnter() {
        # Clear form
        $this._titleTextBox.Text = ""
        $this._descriptionTextBox.Text = ""
        
        # Call base to set initial focus
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        # Call base for cleanup
        ([Screen]$this).OnExit()
    }
    
    # Helper methods
    hidden [void] _SaveTask() {
        # Validate title is not empty
        $title = $this._titleTextBox.Text
        if ([string]::IsNullOrWhiteSpace($title)) {
            # Visual feedback for empty title
            $this._titleTextBox.BorderColor = Get-ThemeColor "error"
            $this._titleTextBox.RequestRedraw()
            return
        }
        
        # Create new task
        if ($null -ne $this._dataManager) {
            try {
                # Create a simple task object (assuming PmcTask class exists)
                $task = [PmcTask]::new($title.Trim())
                
                # Add description if provided
                $description = $this._descriptionTextBox.Text
                if (-not [string]::IsNullOrWhiteSpace($description)) {
                    $task.Description = $description.Trim()
                }
                
                # Set default values
                $task.Priority = [TaskPriority]::Medium
                $task.Status = [TaskStatus]::Pending
                $task.ProjectKey = "General"
                
                # Save the task
                $result = $this._dataManager.AddTask($task)
                Write-Log -Level Info -Message "NewTaskEntryScreen: Successfully saved task '$title'"
                
                # Trigger events to notify other components
                $eventManager = $this.ServiceContainer.GetService("EventManager")
                if ($eventManager) {
                    $eventManager.PublishEvent("Tasks.Changed", @{ Action = "Added"; Task = $task })
                }
            }
            catch {
                Write-Log -Level Error -Message "NewTaskEntryScreen: Failed to save task '$title': $_"
                return
            }
        } else {
            Write-Log -Level Error -Message "NewTaskEntryScreen: DataManager is null, cannot save task"
            return
        }
        
        # Go back to previous screen
        $this._GoBack()
    }
    
    hidden [void] _Cancel() {
        $this._GoBack()
    }
    
    hidden [void] _GoBack() {
        if ($this._navService.CanGoBack()) {
            # Get the previous screen and refresh if it's TaskListScreen
            $previousScreen = $this._navService.GetPreviousScreen()
            if ($previousScreen -and $previousScreen.GetType().Name -eq "TaskListScreen") {
                # Trigger refresh on return
                $previousScreen | Add-Member -MemberType ScriptMethod -Name "RefreshOnReturn" -Value {
                    $this._RefreshTasks()
                } -Force
            }
            $this._navService.GoBack()
        } else {
            # Navigate to task list as fallback
            $taskListScreen = [TaskListScreen]::new($this.ServiceContainer)
            $taskListScreen.Initialize()
            $this._navService.NavigateTo($taskListScreen)
        }
    }
}