# ==============================================================================
# Axiom-Phoenix v4.0 - Project Edit Dialog
# HYBRID MODEL: Components handle their own input, automatic Tab navigation
# ==============================================================================

using namespace System.Collections.Generic

class ProjectEditDialog : Dialog {
    hidden [PmcProject] $_project
    hidden [bool] $_isNewProject
    hidden [Panel] $_formPanel
    hidden [ScrollablePanel] $_scrollPanel
    hidden [Dictionary[string, Component]] $_fields
    hidden [object] $_dataManager
    hidden [object] $_fileSystemService
    hidden [string] $_baseProjectPath
    
    ProjectEditDialog([object]$serviceContainer, [PmcProject]$project = $null) : base("ProjectEditDialog", $serviceContainer) {
        $this._project = if ($project) { $project } else { [PmcProject]::new() }
        $this._isNewProject = ($null -eq $project)
        $this._fields = [Dictionary[string, Component]]::new()
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._fileSystemService = $serviceContainer.GetService("FileSystemService")
        $this._baseProjectPath = Join-Path $env:TEMP "AxiomPhoenix_Projects"
        
        $this.Title = if ($this._isNewProject) { " New Project " } else { " Edit Project " }
        $this.Width = 70
        $this.Height = 30
        
        Write-Log -Level Debug -Message "ProjectEditDialog: Constructor called, isNew=$($this._isNewProject)"
    }
    
    [void] Initialize() {
        ([Dialog]$this).Initialize()
        
        Write-Log -Level Debug -Message "ProjectEditDialog.Initialize: Starting"
        
        # Create scrollable form panel
        $this._scrollPanel = [ScrollablePanel]::new("FormScrollPanel")
        $this._scrollPanel.X = 1
        $this._scrollPanel.Y = 1
        $this._scrollPanel.Width = $this.Width - 2
        $this._scrollPanel.Height = $this.Height - 6  # Leave room for buttons
        $this._scrollPanel.ShowScrollbar = $true
        $this.ContentPanel.AddChild($this._scrollPanel)
        
        # Create form fields
        $y = 1
        $labelWidth = 20
        $fieldWidth = $this._scrollPanel.ContentWidth - $labelWidth - 4
        
        # Project Key (required)
        $keyLabel = [LabelComponent]::new("KeyLabel")
        $keyLabel.Text = "Project Key*:"
        $keyLabel.X = 2
        $keyLabel.Y = $y
        $keyLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($keyLabel)
        
        $keyField = [TextBoxComponent]::new("KeyField")
        $keyField.X = $labelWidth + 2
        $keyField.Y = $y
        $keyField.Width = $fieldWidth
        $keyField.Text = $this._project.Key
        $keyField.Placeholder = "e.g., PROJ-001"
        $keyField.MaxLength = 20
        $keyField.ReadOnly = -not $this._isNewProject  # Can't change key on existing project
        $keyField.IsFocusable = if ($this._isNewProject) { $true } else { $false }
        $keyField.TabIndex = 0
        $this._AddFieldVisualFeedback($keyField)
        $this._scrollPanel.AddChild($keyField)
        $this._fields["Key"] = $keyField
        $y += 2
        
        # Project Name (required)
        $nameLabel = [LabelComponent]::new("NameLabel")
        $nameLabel.Text = "Project Name*:"
        $nameLabel.X = 2
        $nameLabel.Y = $y
        $nameLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($nameLabel)
        
        $nameField = [TextBoxComponent]::new("NameField")
        $nameField.X = $labelWidth + 2
        $nameField.Y = $y
        $nameField.Width = $fieldWidth
        $nameField.Text = $this._project.Name
        $nameField.Placeholder = "Enter project name"
        $nameField.MaxLength = 100
        $nameField.IsFocusable = $true
        $nameField.TabIndex = 1
        $this._AddFieldVisualFeedback($nameField)
        $this._scrollPanel.AddChild($nameField)
        $this._fields["Name"] = $nameField
        $y += 2
        
        # ID1 (optional)
        $id1Label = [LabelComponent]::new("ID1Label")
        $id1Label.Text = "ID1 (Non-unique):"
        $id1Label.X = 2
        $id1Label.Y = $y
        $id1Label.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($id1Label)
        
        $id1Field = [TextBoxComponent]::new("ID1Field")
        $id1Field.X = $labelWidth + 2
        $id1Field.Y = $y
        $id1Field.Width = $fieldWidth
        $id1Field.Text = $this._project.ID1
        $id1Field.Placeholder = "Optional secondary ID"
        $id1Field.MaxLength = 50
        $id1Field.IsFocusable = $true
        $id1Field.TabIndex = 2
        $this._AddFieldVisualFeedback($id1Field)
        $this._scrollPanel.AddChild($id1Field)
        $this._fields["ID1"] = $id1Field
        $y += 2
        
        # ID2 (optional)
        $id2Label = [LabelComponent]::new("ID2Label")
        $id2Label.Text = "ID2 (Main Case):"
        $id2Label.X = 2
        $id2Label.Y = $y
        $id2Label.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($id2Label)
        
        $id2Field = [TextBoxComponent]::new("ID2Field")
        $id2Field.X = $labelWidth + 2
        $id2Field.Y = $y
        $id2Field.Width = $fieldWidth
        $id2Field.Text = $this._project.ID2
        $id2Field.Placeholder = "Main case ID"
        $id2Field.MaxLength = 50
        $id2Field.IsFocusable = $true
        $id2Field.TabIndex = 3
        $this._AddFieldVisualFeedback($id2Field)
        $this._scrollPanel.AddChild($id2Field)
        $this._fields["ID2"] = $id2Field
        $y += 2
        
        # Owner (optional)
        $ownerLabel = [LabelComponent]::new("OwnerLabel")
        $ownerLabel.Text = "Owner:"
        $ownerLabel.X = 2
        $ownerLabel.Y = $y
        $ownerLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($ownerLabel)
        
        $ownerField = [TextBoxComponent]::new("OwnerField")
        $ownerField.X = $labelWidth + 2
        $ownerField.Y = $y
        $ownerField.Width = $fieldWidth
        $ownerField.Text = $this._project.Owner
        $ownerField.Placeholder = "Project owner name"
        $ownerField.MaxLength = 100
        $ownerField.IsFocusable = $true
        $ownerField.TabIndex = 4
        $this._AddFieldVisualFeedback($ownerField)
        $this._scrollPanel.AddChild($ownerField)
        $this._fields["Owner"] = $ownerField
        $y += 2
        
        # Client ID (metadata, optional)
        $clientLabel = [LabelComponent]::new("ClientLabel")
        $clientLabel.Text = "Client ID (BN):"
        $clientLabel.X = 2
        $clientLabel.Y = $y
        $clientLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($clientLabel)
        
        $clientField = [TextBoxComponent]::new("ClientField")
        $clientField.X = $labelWidth + 2
        $clientField.Y = $y
        $clientField.Width = $fieldWidth
        $clientField.Text = $this._project.GetMetadata("ClientID")
        $clientField.Placeholder = "BN-XXXXXX"
        $clientField.MaxLength = 50
        $clientField.IsFocusable = $true
        $clientField.TabIndex = 5
        $this._AddFieldVisualFeedback($clientField)
        $this._scrollPanel.AddChild($clientField)
        $this._fields["ClientID"] = $clientField
        $y += 2
        
        # Assigned Date (optional)
        $assignedLabel = [LabelComponent]::new("AssignedLabel")
        $assignedLabel.Text = "Assigned Date:"
        $assignedLabel.X = 2
        $assignedLabel.Y = $y
        $assignedLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($assignedLabel)
        
        $assignedField = [TextBoxComponent]::new("AssignedField")
        $assignedField.X = $labelWidth + 2
        $assignedField.Y = $y
        $assignedField.Width = $fieldWidth
        $assignedField.Text = if ($this._project.AssignedDate) { $this._project.AssignedDate.ToString("yyyy-MM-dd") } else { "" }
        $assignedField.Placeholder = "YYYY-MM-DD"
        $assignedField.MaxLength = 10
        $assignedField.IsFocusable = $true
        $assignedField.TabIndex = 6
        $this._AddFieldVisualFeedback($assignedField)
        $this._scrollPanel.AddChild($assignedField)
        $this._fields["AssignedDate"] = $assignedField
        $y += 2
        
        # Due Date (BF Date, optional)
        $dueLabel = [LabelComponent]::new("DueLabel")
        $dueLabel.Text = "Due Date (BF):"
        $dueLabel.X = 2
        $dueLabel.Y = $y
        $dueLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($dueLabel)
        
        $dueField = [TextBoxComponent]::new("DueField")
        $dueField.X = $labelWidth + 2
        $dueField.Y = $y
        $dueField.Width = $fieldWidth
        $dueField.Text = if ($this._project.BFDate) { $this._project.BFDate.ToString("yyyy-MM-dd") } else { "" }
        $dueField.Placeholder = "YYYY-MM-DD"
        $dueField.MaxLength = 10
        $dueField.IsFocusable = $true
        $dueField.TabIndex = 7
        $this._AddFieldVisualFeedback($dueField)
        $this._scrollPanel.AddChild($dueField)
        $this._fields["BFDate"] = $dueField
        $y += 2
        
        # Description (optional, multiline)
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $y
        $descLabel.ForegroundColor = Get-ThemeColor "label"
        $this._scrollPanel.AddChild($descLabel)
        $y += 1
        
        $descField = [MultilineTextBoxComponent]::new("DescField")
        $descField.X = 2
        $descField.Y = $y
        $descField.Width = $this._scrollPanel.ContentWidth - 4
        $descField.Height = 5
        $descField.SetText($this._project.Description)
        $descField.BorderStyle = "Single"
        $descField.IsFocusable = $true
        $descField.TabIndex = 8
        $this._AddFieldVisualFeedback($descField)
        $this._scrollPanel.AddChild($descField)
        $this._fields["Description"] = $descField
        $y += 6
        
        # Create folder checkbox (only for new projects)
        if ($this._isNewProject) {
            $createFolderCheck = [CheckBoxComponent]::new("CreateFolderCheck")
            $createFolderCheck.X = 2
            $createFolderCheck.Y = $y
            $createFolderCheck.Text = "Create project folder"
            $createFolderCheck.Checked = $true
            $createFolderCheck.IsFocusable = $true
            $createFolderCheck.TabIndex = 9
            $this._AddFieldVisualFeedback($createFolderCheck)
            $this._scrollPanel.AddChild($createFolderCheck)
            $this._fields["CreateFolder"] = $createFolderCheck
            $y += 2
        }
        
        # Buttons
        $buttonY = $this.Height - 4
        $buttonX = [Math]::Floor(($this.Width - 30) / 2)  # Center buttons
        $buttonSpacing = 15
        
        # Save button
        $saveButton = [ButtonComponent]::new("SaveButton")
        $saveButton.Text = "[S]ave"
        $saveButton.X = $buttonX
        $saveButton.Y = $buttonY
        $saveButton.IsFocusable = $true
        $saveButton.TabIndex = 10
        $thisDialog = $this
        $saveButton.OnClick = {
            $thisDialog.SaveProject()
        }.GetNewClosure()
        $this._AddFieldVisualFeedback($saveButton)
        $this.ContentPanel.AddChild($saveButton)
        
        # Cancel button
        $cancelButton = [ButtonComponent]::new("CancelButton")
        $cancelButton.Text = "[C]ancel"
        $cancelButton.X = $buttonX + $buttonSpacing
        $cancelButton.Y = $buttonY
        $cancelButton.IsFocusable = $true
        $cancelButton.TabIndex = 11
        $cancelButton.OnClick = {
            $thisDialog.DialogResult = $null
            $thisDialog.Close()
        }.GetNewClosure()
        $this._AddFieldVisualFeedback($cancelButton)
        $this.ContentPanel.AddChild($cancelButton)
        
        Write-Log -Level Debug -Message "ProjectEditDialog.Initialize: Completed"
    }
    
    # Add visual feedback for focus/blur events
    hidden [void] _AddFieldVisualFeedback([Component]$field) {
        if ($field -is [TextBoxComponent] -or $field -is [MultilineTextBoxComponent]) {
            $field | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                $this.BorderColor = Get-ThemeColor "palette.primary"
                $this.ShowCursor = $true
                $this.RequestRedraw()
            } -Force
            
            $field | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                $this.BorderColor = Get-ThemeColor "component.border"
                $this.ShowCursor = $false
                $this.RequestRedraw()
            } -Force
        }
        elseif ($field -is [ButtonComponent]) {
            $field | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                $this.BorderColor = Get-ThemeColor "palette.primary"
                $this.RequestRedraw()
            } -Force
            
            $field | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                $this.BorderColor = Get-ThemeColor "component.border"
                $this.RequestRedraw()
            } -Force
        }
        elseif ($field -is [CheckBoxComponent]) {
            $field | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                $this.ForegroundColor = Get-ThemeColor "palette.primary"
                $this.RequestRedraw()
            } -Force
            
            $field | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                $this.ForegroundColor = Get-ThemeColor "text"
                $this.RequestRedraw()
            } -Force
        }
    }
    
    hidden [void] SaveProject() {
        # Validate required fields
        $key = $this._fields["Key"].Text.Trim()
        $name = $this._fields["Name"].Text.Trim()
        
        if ([string]::IsNullOrWhiteSpace($key)) {
            $this.ShowError("Project Key is required")
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($name)) {
            $this.ShowError("Project Name is required")
            return
        }
        
        # Check if key already exists for new projects
        if ($this._isNewProject) {
            $existing = $this._dataManager.GetProject($key)
            if ($existing) {
                $this.ShowError("Project with key '$key' already exists")
                return
            }
        }
        
        # Update project object
        $this._project.Key = $key
        $this._project.Name = $name
        $this._project.ID1 = $this._fields["ID1"].Text.Trim()
        $this._project.ID2 = $this._fields["ID2"].Text.Trim()
        $this._project.Owner = $this._fields["Owner"].Text.Trim()
        $this._project.Description = $this._fields["Description"].GetText().Trim()
        
        # Handle Client ID metadata
        $clientId = $this._fields["ClientID"].Text.Trim()
        if ($clientId) {
            $this._project.SetMetadata("ClientID", $clientId)
        }
        
        # Parse dates
        $assignedDateStr = $this._fields["AssignedDate"].Text.Trim()
        if ($assignedDateStr) {
            try {
                $this._project.AssignedDate = [DateTime]::Parse($assignedDateStr)
            } catch {
                $this.ShowError("Invalid Assigned Date format. Use YYYY-MM-DD")
                return
            }
        }
        
        $dueDateStr = $this._fields["BFDate"].Text.Trim()
        if ($dueDateStr) {
            try {
                $this._project.BFDate = [DateTime]::Parse($dueDateStr)
            } catch {
                $this.ShowError("Invalid Due Date format. Use YYYY-MM-DD")
                return
            }
        }
        
        # Create project folder if requested
        if ($this._isNewProject -and $this._fields["CreateFolder"].Checked) {
            if (-not (Test-Path $this._baseProjectPath)) {
                New-Item -ItemType Directory -Path $this._baseProjectPath -Force | Out-Null
            }
            
            $safeName = $this._project.Name -replace '[^\w\s-]', '_'
            $projectPath = Join-Path $this._baseProjectPath "$($this._project.Key)_$safeName"
            
            if (-not (Test-Path $projectPath)) {
                New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
                $this._project.ProjectFolderPath = $projectPath
                Write-Log -Level Info -Message "Created project folder: $projectPath"
            }
        }
        
        # Save to data manager
        try {
            if ($this._isNewProject) {
                $this._dataManager.AddProject($this._project)
                Write-Log -Level Info -Message "Created new project: $key"
            } else {
                $this._dataManager.UpdateProject($this._project)
                Write-Log -Level Info -Message "Updated project: $key"
            }
            
            $this.DialogResult = $this._project
            $this.Close()
        } catch {
            $this.ShowError("Failed to save project: $_")
        }
    }
    
    hidden [void] ShowError([string]$message) {
        $dialogManager = $this.ServiceContainer?.GetService("DialogManager")
        if ($dialogManager) {
            $dialogManager.ShowAlert("Error", $message)
        }
    }
    
    [void] OnEnter() {
        ([Dialog]$this).OnEnter()
        Write-Log -Level Debug -Message "ProjectEditDialog.OnEnter: Dialog entered, base class will set initial focus"
    }
    
    # === HYBRID MODEL INPUT HANDLING ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ProjectEditDialog.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "ProjectEditDialog.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)'"
        
        # Base class handles Tab navigation and routes input to focused components
        if (([Dialog]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle global dialog shortcuts only
        switch ($keyInfo.KeyChar) {
            's' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.SaveProject()
                    return $true
                }
            }
            'S' {
                $this.SaveProject()
                return $true
            }
            'c' {
                if ($keyInfo.Modifiers -eq [ConsoleModifiers]::None) {
                    $this.DialogResult = $null
                    $this.Close()
                    return $true
                }
            }
            'C' {
                $this.DialogResult = $null
                $this.Close()
                return $true
            }
        }
        
        return $false
    }
}

# ==============================================================================
# END OF PROJECT EDIT DIALOG
# ==============================================================================
