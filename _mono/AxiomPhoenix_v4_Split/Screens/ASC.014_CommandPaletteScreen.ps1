# ==============================================================================
# Axiom-Phoenix v4.0 - CommandPaletteScreen
# Command palette for storing and retrieving command strings
# ==============================================================================

class CommandPaletteScreen : Screen {
    # Services
    hidden $_navService
    hidden $_commandService
    hidden $_dialogManager
    
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [LabelComponent]$_titleLabel
    hidden [TextBoxComponent]$_searchBox
    hidden [ListBox]$_commandList
    hidden [LabelComponent]$_instructionsLabel
    hidden [Panel]$_buttonPanel
    hidden [ButtonComponent]$_executeButton
    hidden [ButtonComponent]$_addButton
    hidden [ButtonComponent]$_editButton
    hidden [ButtonComponent]$_deleteButton
    hidden [ButtonComponent]$_cancelButton
    
    # State
    hidden [array]$_currentCommands = @()
    hidden [string]$_currentSearchTerm = ""
    
    CommandPaletteScreen([object]$serviceContainer) : base("CommandPaletteScreen", $serviceContainer) {
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._commandService = $serviceContainer.GetService("CommandService")
        $this._dialogManager = $serviceContainer.GetService("DialogManager")
    }
    
    [void] Initialize() {
        # Main panel
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.Width = $this.Width - 4
        $this._mainPanel.Height = $this.Height - 4
        $this._mainPanel.X = 2
        $this._mainPanel.Y = 2
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
        $this.AddChild($this._mainPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = "Command Palette"
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._mainPanel.AddChild($this._titleLabel)
        
        # Search box
        $this._searchBox = [TextBoxComponent]::new("SearchBox")
        $this._searchBox.X = 2
        $this._searchBox.Y = 3
        $this._searchBox.Width = $this._mainPanel.Width - 4
        $this._searchBox.Height = 1
        $this._searchBox.IsFocusable = $true
        $this._searchBox.TabIndex = 0
        $this._searchBox.Placeholder = "Search commands..."
        
        # Add search box event handlers
        $currentScreenRef = $this
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        # Add text changed event (simulated through input handling)
        $this._searchBox | Add-Member -MemberType ScriptMethod -Name OnTextChanged -Value {
            $currentScreenRef._OnSearchTextChanged()
        } -Force
        
        $this._mainPanel.AddChild($this._searchBox)
        
        # Command list
        $this._commandList = [ListBox]::new("CommandList")
        $this._commandList.X = 2
        $this._commandList.Y = 5
        $this._commandList.Width = $this._mainPanel.Width - 4
        $this._commandList.Height = $this._mainPanel.Height - 12
        $this._commandList.IsFocusable = $true
        $this._commandList.TabIndex = 1
        $this._commandList.BackgroundColor = Get-ThemeColor "listbox.background"
        $this._commandList.BorderColor = Get-ThemeColor "listbox.border"
        
        # Add selection changed event
        $this._commandList.SelectedIndexChanged = {
            param($sender, $index)
            $currentScreenRef._OnSelectionChanged($index)
        }.GetNewClosure()
        
        $this._mainPanel.AddChild($this._commandList)
        
        # Instructions
        $this._instructionsLabel = [LabelComponent]::new("InstructionsLabel")
        $this._instructionsLabel.Text = "Enter: Execute | A: Add | E: Edit | D: Delete | Esc: Cancel"
        $this._instructionsLabel.X = 2
        $this._instructionsLabel.Y = $this._mainPanel.Height - 5
        $this._instructionsLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._mainPanel.AddChild($this._instructionsLabel)
        
        # Button panel
        $this._buttonPanel = [Panel]::new("ButtonPanel")
        $this._buttonPanel.X = 2
        $this._buttonPanel.Y = $this._mainPanel.Height - 3
        $this._buttonPanel.Width = $this._mainPanel.Width - 4
        $this._buttonPanel.Height = 2
        $this._buttonPanel.HasBorder = $false
        $this._mainPanel.AddChild($this._buttonPanel)
        
        # Buttons
        $buttonY = 0
        $buttonWidth = 12
        $buttonSpacing = 2
        
        # Execute button
        $this._executeButton = [ButtonComponent]::new("ExecuteButton")
        $this._executeButton.Text = "Execute"
        $this._executeButton.X = 0
        $this._executeButton.Y = $buttonY
        $this._executeButton.Width = $buttonWidth
        $this._executeButton.Height = 1
        $this._executeButton.IsFocusable = $true
        $this._executeButton.TabIndex = 2
        $this._executeButton.BackgroundColor = Get-ThemeColor "button.primary.background"
        $this._executeButton.ForegroundColor = Get-ThemeColor "button.primary.foreground"
        $this._executeButton.OnClick = {
            $currentScreenRef._ExecuteSelectedCommand()
        }.GetNewClosure()
        $this._buttonPanel.AddChild($this._executeButton)
        
        # Add button
        $this._addButton = [ButtonComponent]::new("AddButton")
        $this._addButton.Text = "Add"
        $this._addButton.X = $buttonWidth + $buttonSpacing
        $this._addButton.Y = $buttonY
        $this._addButton.Width = $buttonWidth
        $this._addButton.Height = 1
        $this._addButton.IsFocusable = $true
        $this._addButton.TabIndex = 3
        $this._addButton.OnClick = {
            $currentScreenRef._ShowAddCommandDialog()
        }.GetNewClosure()
        $this._buttonPanel.AddChild($this._addButton)
        
        # Edit button
        $this._editButton = [ButtonComponent]::new("EditButton")
        $this._editButton.Text = "Edit"
        $this._editButton.X = ($buttonWidth + $buttonSpacing) * 2
        $this._editButton.Y = $buttonY
        $this._editButton.Width = $buttonWidth
        $this._editButton.Height = 1
        $this._editButton.IsFocusable = $true
        $this._editButton.TabIndex = 4
        $this._editButton.OnClick = {
            $currentScreenRef._ShowEditCommandDialog()
        }.GetNewClosure()
        $this._buttonPanel.AddChild($this._editButton)
        
        # Delete button
        $this._deleteButton = [ButtonComponent]::new("DeleteButton")
        $this._deleteButton.Text = "Delete"
        $this._deleteButton.X = ($buttonWidth + $buttonSpacing) * 3
        $this._deleteButton.Y = $buttonY
        $this._deleteButton.Width = $buttonWidth
        $this._deleteButton.Height = 1
        $this._deleteButton.IsFocusable = $true
        $this._deleteButton.TabIndex = 5
        $this._deleteButton.OnClick = {
            $currentScreenRef._DeleteSelectedCommand()
        }.GetNewClosure()
        $this._buttonPanel.AddChild($this._deleteButton)
        
        # Cancel button
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = ($buttonWidth + $buttonSpacing) * 4
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 6
        $this._cancelButton.OnClick = {
            $currentScreenRef._navService.GoBack()
        }.GetNewClosure()
        $this._buttonPanel.AddChild($this._cancelButton)
        
        # Load initial commands
        $this._RefreshCommandList()
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        $focused = $this.GetFocusedChild()
        
        # Handle search box text changes
        if ($focused -eq $this._searchBox) {
            # Check if the text actually changed after base input handling
            $oldText = $this._currentSearchTerm
            $result = ([Screen]$this).HandleInput($keyInfo)
            if ($this._searchBox.Text -ne $oldText) {
                $this._currentSearchTerm = $this._searchBox.Text
                $this._OnSearchTextChanged()
            }
            return $result
        }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                if ($focused -eq $this._commandList) {
                    $this._ExecuteSelectedCommand()
                    return $true
                }
            }
            ([ConsoleKey]::Escape) {
                $this._navService.GoBack()
                return $true
            }
        }
        
        # Handle keyboard shortcuts
        switch ($keyInfo.KeyChar) {
            'a' { $this._ShowAddCommandDialog(); return $true }
            'A' { $this._ShowAddCommandDialog(); return $true }
            'e' { $this._ShowEditCommandDialog(); return $true }
            'E' { $this._ShowEditCommandDialog(); return $true }
            'd' { $this._DeleteSelectedCommand(); return $true }
            'D' { $this._DeleteSelectedCommand(); return $true }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] _RefreshCommandList() {
        $this._commandList.ClearItems()
        
        if ([string]::IsNullOrWhiteSpace($this._currentSearchTerm)) {
            # Show recent commands when no search term
            $this._currentCommands = $this._commandService.GetRecentCommands(20)
        } else {
            # Search commands
            $this._currentCommands = $this._commandService.SearchCommands($this._currentSearchTerm)
        }
        
        foreach ($command in $this._currentCommands) {
            $displayText = "$($command.Name) - $($command.Description)"
            if ($command.UseCount -gt 0) {
                $displayText += " (used $($command.UseCount) times)"
            }
            $this._commandList.AddItem($displayText)
        }
        
        if ($this._currentCommands.Count -eq 0) {
            if ([string]::IsNullOrWhiteSpace($this._currentSearchTerm)) {
                $this._commandList.AddItem("No commands stored. Press 'A' to add a command.")
            } else {
                $this._commandList.AddItem("No commands found matching '$($this._currentSearchTerm)'")
            }
        }
        
        $this.RequestRedraw()
    }
    
    hidden [void] _OnSearchTextChanged() {
        $this._RefreshCommandList()
    }
    
    hidden [void] _OnSelectionChanged([int]$index) {
        # Update button states based on selection
        $hasSelection = $index -ge 0 -and $index -lt $this._currentCommands.Count
        # Could enable/disable buttons here if supported
    }
    
    hidden [void] _ExecuteSelectedCommand() {
        if ($this._commandList.SelectedIndex -ge 0 -and $this._commandList.SelectedIndex -lt $this._currentCommands.Count) {
            $selectedCommand = $this._currentCommands[$this._commandList.SelectedIndex]
            
            $success = $this._commandService.ExecuteCommand($selectedCommand.Id)
            if ($success) {
                $this._dialogManager.ShowMessage("Command Executed", 
                    "Command '$($selectedCommand.Name)' copied to clipboard:`n`n$($selectedCommand.Command)")
                $this._RefreshCommandList()  # Refresh to update usage stats
            } else {
                $this._dialogManager.ShowMessage("Error", "Failed to execute command '$($selectedCommand.Name)'")
            }
        }
    }
    
    hidden [void] _ShowAddCommandDialog() {
        # Simple input dialogs for now - could be enhanced with a proper dialog later
        $name = $this._dialogManager.ShowInput("Add Command", "Command Name:")
        if ([string]::IsNullOrWhiteSpace($name)) { return }
        
        $command = $this._dialogManager.ShowInput("Add Command", "Command String:")
        if ([string]::IsNullOrWhiteSpace($command)) { return }
        
        $description = $this._dialogManager.ShowInput("Add Command", "Description (optional):")
        if ([string]::IsNullOrWhiteSpace($description)) { $description = "No description" }
        
        $tags = $this._dialogManager.ShowInput("Add Command", "Tags (comma-separated, optional):")
        $tagArray = @()
        if (-not [string]::IsNullOrWhiteSpace($tags)) {
            $tagArray = $tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
        
        try {
            $newCommand = $this._commandService.AddCommand($name, $command, $description, $tagArray)
            $this._dialogManager.ShowMessage("Success", "Command '$name' added successfully!")
            $this._RefreshCommandList()
        }
        catch {
            $this._dialogManager.ShowMessage("Error", "Failed to add command: $($_.Exception.Message)")
        }
    }
    
    hidden [void] _ShowEditCommandDialog() {
        if ($this._commandList.SelectedIndex -ge 0 -and $this._commandList.SelectedIndex -lt $this._currentCommands.Count) {
            $selectedCommand = $this._currentCommands[$this._commandList.SelectedIndex]
            
            # Edit the selected command
            $name = $this._dialogManager.ShowInput("Edit Command", "Command Name:", $selectedCommand.Name)
            if ([string]::IsNullOrWhiteSpace($name)) { return }
            
            $command = $this._dialogManager.ShowInput("Edit Command", "Command String:", $selectedCommand.Command)
            if ([string]::IsNullOrWhiteSpace($command)) { return }
            
            $description = $this._dialogManager.ShowInput("Edit Command", "Description:", $selectedCommand.Description)
            if ([string]::IsNullOrWhiteSpace($description)) { $description = "No description" }
            
            $tags = $this._dialogManager.ShowInput("Edit Command", "Tags (comma-separated):", ($selectedCommand.Tags -join ', '))
            $tagArray = @()
            if (-not [string]::IsNullOrWhiteSpace($tags)) {
                $tagArray = $tags -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            }
            
            try {
                $selectedCommand.Name = $name
                $selectedCommand.Command = $command
                $selectedCommand.Description = $description
                $selectedCommand.Tags = $tagArray
                
                $this._commandService.UpdateCommand($selectedCommand)
                $this._dialogManager.ShowMessage("Success", "Command updated successfully!")
                $this._RefreshCommandList()
            }
            catch {
                $this._dialogManager.ShowMessage("Error", "Failed to update command: $($_.Exception.Message)")
            }
        }
    }
    
    hidden [void] _DeleteSelectedCommand() {
        if ($this._commandList.SelectedIndex -ge 0 -and $this._commandList.SelectedIndex -lt $this._currentCommands.Count) {
            $selectedCommand = $this._currentCommands[$this._commandList.SelectedIndex]
            
            $result = $this._dialogManager.ShowConfirmation("Delete Command", 
                "Are you sure you want to delete command '$($selectedCommand.Name)'?")
            
            if ($result) {
                $success = $this._commandService.DeleteCommand($selectedCommand.Id)
                if ($success) {
                    $this._dialogManager.ShowMessage("Success", "Command deleted successfully!")
                    $this._RefreshCommandList()
                } else {
                    $this._dialogManager.ShowMessage("Error", "Failed to delete command.")
                }
            }
        }
    }
    
    [void] OnEnter() {
        # Refresh commands when entering the screen
        $this._RefreshCommandList()
        
        # Set focus to search box initially
        if ($this._searchBox) {
            $this._searchBox.IsFocused = $true
        }
        
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        ([Screen]$this).OnExit()
    }
}