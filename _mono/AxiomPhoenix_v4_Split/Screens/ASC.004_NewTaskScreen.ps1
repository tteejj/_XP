# ==============================================================================
# Axiom-Phoenix v4.0 - New Task Screen
# FIXED: Removed FocusManager dependency, uses direct input handling
# ==============================================================================

class NewTaskScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_formPanel
    hidden [TextBoxComponent] $_titleBox
    hidden [TextBoxComponent] $_descriptionBox
    hidden [ButtonComponent] $_saveButton
    hidden [ButtonComponent] $_cancelButton
    hidden [LabelComponent] $_priorityLabel
    hidden [LabelComponent] $_projectLabel
    hidden [LabelComponent] $_priorityValue
    hidden [LabelComponent] $_projectValue
    
    hidden [TaskPriority] $_selectedPriority = [TaskPriority]::Medium
    hidden [string] $_selectedProject = "General"
    
    # Internal focus management
    hidden [int] $_focusIndex = 0
    hidden [string[]] $_focusOrder = @("title", "description", "save", "cancel")
    hidden [string] $_titleText = ""
    hidden [string] $_descriptionText = ""
    
    NewTaskScreen([object]$serviceContainer) : base("NewTaskScreen", $serviceContainer) {
        $this.Title = " Create New Task "
        Write-Log -Level Debug -Message "NewTaskScreen: Constructor called"
    }
    
    [void] Initialize() {
        Write-Log -Level Debug -Message "NewTaskScreen.Initialize: Starting"
        
        # Main panel (full screen with semi-transparent overlay effect)
        $this._mainPanel = [Panel]::new("NewTaskMainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.HasBorder = $false
        $this._mainPanel.BackgroundColor = Get-ThemeColor "Overlay" "#00000099"
        $this.AddChild($this._mainPanel)
        
        # Form panel (centered dialog)
        $formWidth = [Math]::Min(70, $this.Width - 10)
        $formHeight = 20
        $formX = [Math]::Floor(($this.Width - $formWidth) / 2)
        $formY = [Math]::Floor(($this.Height - $formHeight) / 2)
        
        $this._formPanel = [Panel]::new("FormPanel")
        $this._formPanel.X = $formX
        $this._formPanel.Y = $formY
        $this._formPanel.Width = $formWidth
        $this._formPanel.Height = $formHeight
        $this._formPanel.Title = " New Task "
        $this._formPanel.BorderStyle = "Double"
        $this._formPanel.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
        $this._formPanel.BackgroundColor = Get-ThemeColor "dialog.bg" "#1A1A1A"
        $this._mainPanel.AddChild($this._formPanel)
        
        $y = 2
        
        # Title section
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Task Title:"
        $titleLabel.X = 2
        $titleLabel.Y = $y
        $titleLabel.ForegroundColor = Get-ThemeColor "label" "#FFD700"
        $this._formPanel.AddChild($titleLabel)
        
        $y += 1
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.Placeholder = "Enter task title..."
        $this._titleBox.X = 2
        $this._titleBox.Y = $y
        $this._titleBox.Width = $formWidth - 4
        $this._titleBox.Height = 1
        $this._titleBox.IsFocusable = $false  # We handle input directly
        $this._titleBox.BackgroundColor = Get-ThemeColor "textbox.bg" "#2A2A2A"
        $this._titleBox.ForegroundColor = Get-ThemeColor "textbox.fg" "#FFFFFF"
        $this._titleBox.BorderColor = Get-ThemeColor "textbox.border" "#444444"
        $this._titleBox.ShowCursor = $true  # Initially focused
        $this._formPanel.AddChild($this._titleBox)
        
        $y += 3
        
        # Description section
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description (optional):"
        $descLabel.X = 2
        $descLabel.Y = $y
        $descLabel.ForegroundColor = Get-ThemeColor "label" "#00D4FF"
        $this._formPanel.AddChild($descLabel)
        
        $y += 1
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.Placeholder = "Enter description..."
        $this._descriptionBox.X = 2
        $this._descriptionBox.Y = $y
        $this._descriptionBox.Width = $formWidth - 4
        $this._descriptionBox.Height = 1
        $this._descriptionBox.IsFocusable = $false  # We handle input directly
        $this._descriptionBox.BackgroundColor = Get-ThemeColor "textbox.bg" "#2A2A2A"
        $this._descriptionBox.ForegroundColor = Get-ThemeColor "textbox.fg" "#FFFFFF"
        $this._descriptionBox.BorderColor = Get-ThemeColor "textbox.border" "#444444"
        $this._descriptionBox.ShowCursor = $false
        $this._formPanel.AddChild($this._descriptionBox)
        
        $y += 3
        
        # Priority and Project row
        $this._priorityLabel = [LabelComponent]::new("PriorityLabel")
        $this._priorityLabel.Text = "Priority:"
        $this._priorityLabel.X = 2
        $this._priorityLabel.Y = $y
        $this._priorityLabel.ForegroundColor = Get-ThemeColor "label" "#FF69B4"
        $this._formPanel.AddChild($this._priorityLabel)
        
        $this._priorityValue = [LabelComponent]::new("PriorityValue")
        $this._priorityValue.Text = "[$($this._selectedPriority)]"
        $this._priorityValue.X = 12
        $this._priorityValue.Y = $y
        $this._priorityValue.ForegroundColor = $this.GetPriorityColor($this._selectedPriority)
        $this._formPanel.AddChild($this._priorityValue)
        
        $this._projectLabel = [LabelComponent]::new("ProjectLabel")
        $this._projectLabel.Text = "Project:"
        $this._projectLabel.X = 30
        $this._projectLabel.Y = $y
        $this._projectLabel.ForegroundColor = Get-ThemeColor "label" "#8A2BE2"
        $this._formPanel.AddChild($this._projectLabel)
        
        $this._projectValue = [LabelComponent]::new("ProjectValue")
        $this._projectValue.Text = "[$($this._selectedProject)]"
        $this._projectValue.X = 39
        $this._projectValue.Y = $y
        $this._projectValue.ForegroundColor = Get-ThemeColor "project" "#FFD700"
        $this._formPanel.AddChild($this._projectValue)
        
        $y += 2
        
        # Help text
        $helpLabel = [LabelComponent]::new("HelpLabel")
        $helpLabel.Text = "[Tab] Next field | [P] Change priority | [Enter] Save | [Esc] Cancel"
        $helpLabel.X = 2
        $helpLabel.Y = $y
        $helpLabel.ForegroundColor = Get-ThemeColor "muted" "#666666"
        $this._formPanel.AddChild($helpLabel)
        
        $y += 2
        
        # Buttons
        $buttonWidth = 12
        $buttonSpacing = 4
        $totalButtonWidth = ($buttonWidth * 2) + $buttonSpacing
        $buttonStartX = [Math]::Floor(($formWidth - $totalButtonWidth) / 2)
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = " [S]ave "
        $this._saveButton.X = $buttonStartX
        $this._saveButton.Y = $y
        $this._saveButton.Width = $buttonWidth
        $this._saveButton.Height = 1
        $this._saveButton.IsFocusable = $false  # We handle input directly
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $this._saveButton.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $thisScreen = $this
        $this._saveButton.OnClick = { $thisScreen.SaveTask() }.GetNewClosure()
        $this._formPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = " [C]ancel "
        $this._cancelButton.X = $buttonStartX + $buttonWidth + $buttonSpacing
        $this._cancelButton.Y = $y
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.IsFocusable = $false  # We handle input directly
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        $this._cancelButton.ForegroundColor = Get-ThemeColor "button.fg" "#FFFFFF"
        $this._cancelButton.OnClick = { $thisScreen.Cancel() }.GetNewClosure()
        $this._formPanel.AddChild($this._cancelButton)
        
        Write-Log -Level Debug -Message "NewTaskScreen.Initialize: Completed"
    }
    
    [void] OnEnter() {
        Write-Log -Level Debug -Message "NewTaskScreen.OnEnter: Setting initial focus"
        
        # Reset form
        $this._titleText = ""
        $this._descriptionText = ""
        $this._titleBox.Text = ""
        $this._descriptionBox.Text = ""
        $this._selectedPriority = [TaskPriority]::Medium
        $this._selectedProject = "General"
        $this._focusIndex = 0
        
        # Update display
        $this._UpdateFocusVisuals()
        $this._UpdatePriorityDisplay()
        
        $this.RequestRedraw()
    }
    
    hidden [string] GetPriorityColor([TaskPriority]$priority) {
        return switch ($priority) {
            ([TaskPriority]::Low) { Get-ThemeColor "success" "#00FF88" }
            ([TaskPriority]::Medium) { Get-ThemeColor "warning" "#FFD700" }
            ([TaskPriority]::High) { Get-ThemeColor "error" "#FF4444" }
            default { Get-ThemeColor "text" "#E0E0E0" }
        }
    }
    
    hidden [void] _UpdatePriorityDisplay() {
        $this._priorityValue.Text = "[$($this._selectedPriority)]"
        $this._priorityValue.ForegroundColor = $this.GetPriorityColor($this._selectedPriority)
    }
    
    hidden [void] _UpdateFocusVisuals() {
        # Reset all visual states
        $this._titleBox.ShowCursor = $false
        $this._titleBox.BorderColor = Get-ThemeColor "textbox.border" "#444444"
        $this._descriptionBox.ShowCursor = $false
        $this._descriptionBox.BorderColor = Get-ThemeColor "textbox.border" "#444444"
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.bg" "#0D47A1"
        $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.bg" "#B71C1C"
        
        # Apply focus visuals
        switch ($this._focusOrder[$this._focusIndex]) {
            "title" {
                $this._titleBox.ShowCursor = $true
                $this._titleBox.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            }
            "description" {
                $this._descriptionBox.ShowCursor = $true
                $this._descriptionBox.BorderColor = Get-ThemeColor "primary.accent" "#00D4FF"
            }
            "save" {
                $this._saveButton.BackgroundColor = Get-ThemeColor "button.hover" "#1976D2"
            }
            "cancel" {
                $this._cancelButton.BackgroundColor = Get-ThemeColor "button.cancel.hover" "#D32F2F"
            }
        }
    }
    
    hidden [void] CyclePriority() {
        $priorities = @([TaskPriority]::Low, [TaskPriority]::Medium, [TaskPriority]::High)
        $currentIndex = [Array]::IndexOf($priorities, $this._selectedPriority)
        $this._selectedPriority = $priorities[($currentIndex + 1) % $priorities.Length]
        
        $this._UpdatePriorityDisplay()
        $this.RequestRedraw()
    }
    
    hidden [void] SaveTask() {
        # Validate title
        if ([string]::IsNullOrWhiteSpace($this._titleText)) {
            # Flash the title box border to indicate error
            $this._titleBox.BorderColor = Get-ThemeColor "error" "#FF0000"
            $this.RequestRedraw()
            return
        }
        
        # Create new task
        $task = [PmcTask]::new($this._titleText.Trim())
        $task.Description = $this._descriptionText.Trim()
        $task.Priority = $this._selectedPriority
        $task.ProjectKey = $this._selectedProject
        
        # Save via DataManager
        $dataManager = $this.ServiceContainer.GetService("DataManager")
        if ($dataManager) {
            $dataManager.AddTask($task)
            
            Write-Log -Level Info -Message "NewTaskScreen: Created task '$($task.Title)'"
            
            # Navigate back
            $navService = $this.ServiceContainer.GetService("NavigationService")
            if ($navService -and $navService.CanGoBack()) {
                $navService.GoBack()
            }
        }
    }
    
    hidden [void] Cancel() {
        Write-Log -Level Debug -Message "NewTaskScreen: Cancelled"
        $navService = $this.ServiceContainer.GetService("NavigationService")
        if ($navService -and $navService.CanGoBack()) {
            $navService.GoBack()
        }
    }
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "NewTaskScreen.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "NewTaskScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Focus=$($this._focusOrder[$this._focusIndex])"
        
        # Handle global shortcuts first
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.Cancel()
                return $true
            }
            ([ConsoleKey]::Tab) {
                # Cycle focus
                if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                    $this._focusIndex--
                    if ($this._focusIndex -lt 0) {
                        $this._focusIndex = $this._focusOrder.Count - 1
                    }
                } else {
                    $this._focusIndex++
                    if ($this._focusIndex -ge $this._focusOrder.Count) {
                        $this._focusIndex = 0
                    }
                }
                $this._UpdateFocusVisuals()
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) {
                # Handle based on current focus
                switch ($this._focusOrder[$this._focusIndex]) {
                    "save" { $this.SaveTask(); return $true }
                    "cancel" { $this.Cancel(); return $true }
                    default { 
                        # In text fields, Enter saves
                        $this.SaveTask()
                        return $true 
                    }
                }
            }
        }
        
        # Handle character shortcuts
        switch ($keyInfo.KeyChar) {
            { $_ -eq 'p' -or $_ -eq 'P' } {
                $this.CyclePriority()
                return $true
            }
            { $_ -eq 's' -or $_ -eq 'S' } {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -or $keyInfo.Modifiers -eq [ConsoleModifiers]::Shift) {
                    $this.SaveTask()
                    return $true
                }
            }
            { $_ -eq 'c' -or $_ -eq 'C' } {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None -or $keyInfo.Modifiers -eq [ConsoleModifiers]::Shift) {
                    $this.Cancel()
                    return $true
                }
            }
        }
        
        # Handle text input based on current focus
        $currentFocus = $this._focusOrder[$this._focusIndex]
        if ($currentFocus -eq "title" -or $currentFocus -eq "description") {
            $currentText = if ($currentFocus -eq "title") { $this._titleText } else { $this._descriptionText }
            $textBox = if ($currentFocus -eq "title") { $this._titleBox } else { $this._descriptionBox }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($currentText.Length -gt 0) {
                        $currentText = $currentText.Substring(0, $currentText.Length - 1)
                        if ($currentFocus -eq "title") {
                            $this._titleText = $currentText
                        } else {
                            $this._descriptionText = $currentText
                        }
                        $textBox.Text = $currentText
                        $this.RequestRedraw()
                    }
                    return $true
                }
                default {
                    # Add character
                    if ($keyInfo.KeyChar -and 
                        ([char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                         [char]::IsPunctuation($keyInfo.KeyChar) -or 
                         [char]::IsWhiteSpace($keyInfo.KeyChar))) {
                        
                        $currentText += $keyInfo.KeyChar
                        if ($currentFocus -eq "title") {
                            $this._titleText = $currentText
                        } else {
                            $this._descriptionText = $currentText
                        }
                        $textBox.Text = $currentText
                        $this.RequestRedraw()
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF NEW TASK SCREEN
# ==============================================================================
