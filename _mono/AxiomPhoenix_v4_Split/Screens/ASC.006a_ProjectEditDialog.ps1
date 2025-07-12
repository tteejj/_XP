# ==============================================================================
# Axiom-Phoenix v4.0 - Project Edit Dialog
# FIXED: Removed FocusManager dependency, uses direct input handling
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
    
    # Internal focus management
    hidden [string[]] $_fieldOrder
    hidden [int] $_focusIndex = 0
    
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
        $keyField.IsFocusable = $false  # We handle input directly
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
        $nameField.IsFocusable = $false  # We handle input directly
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
        $id1Field.IsFocusable = $false  # We handle input directly
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
        $id2Field.IsFocusable = $false  # We handle input directly
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
        $ownerField.IsFocusable = $false  # We handle input directly
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
        $clientField.IsFocusable = $false  # We handle input directly
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
        $assignedField.IsFocusable = $false  # We handle input directly
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
        $dueField.IsFocusable = $false  # We handle input directly
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
        $descField.IsFocusable = $false  # We handle input directly
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
            $createFolderCheck.IsFocusable = $false  # We handle input directly
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
        $saveButton.IsFocusable = $false  # We handle input directly
        $thisDialog = $this
        $saveButton.OnClick = {
            $thisDialog.SaveProject()
        }.GetNewClosure()
        $this.ContentPanel.AddChild($saveButton)
        
        # Cancel button
        $cancelButton = [ButtonComponent]::new("CancelButton")
        $cancelButton.Text = "[C]ancel"
        $cancelButton.X = $buttonX + $buttonSpacing
        $cancelButton.Y = $buttonY
        $cancelButton.IsFocusable = $false  # We handle input directly
        $cancelButton.OnClick = {
            $thisDialog.DialogResult = $null
            $thisDialog.Close()
        }.GetNewClosure()
        $this.ContentPanel.AddChild($cancelButton)
        
        # Set up field order for Tab navigation
        $this._fieldOrder = @("Key", "Name", "ID1", "ID2", "Owner", "ClientID", "AssignedDate", "BFDate", "Description")
        if ($this._isNewProject) {
            $this._fieldOrder += "CreateFolder"
        }
        
        # Set initial focus
        if ($this._isNewProject) {
            $this._focusIndex = 0  # Focus on Key field
        } else {
            $this._focusIndex = 1  # Focus on Name field (Key is read-only)
        }
        $this._UpdateFieldFocus()
        
        Write-Log -Level Debug -Message "ProjectEditDialog.Initialize: Completed"
    }
    
    hidden [void] _UpdateFieldFocus() {
        # Update visual indicators for focused field
        foreach ($fieldName in $this._fields.Keys) {
            $field = $this._fields[$fieldName]
            if ($field -is [TextBoxComponent] -or $field -is [MultilineTextBoxComponent]) {
                $field.ShowCursor = $false
                $field.BorderColor = Get-ThemeColor "component.border"
            }
        }
        
        # Highlight current field
        if ($this._focusIndex -ge 0 -and $this._focusIndex -lt $this._fieldOrder.Count) {
            $currentFieldName = $this._fieldOrder[$this._focusIndex]
            $currentField = $this._fields[$currentFieldName]
            
            if ($currentField -is [TextBoxComponent] -or $currentField -is [MultilineTextBoxComponent]) {
                $currentField.ShowCursor = $true
                $currentField.BorderColor = Get-ThemeColor "primary.accent"
            }
        }
        
        $this.RequestRedraw()
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
        Write-Log -Level Debug -Message "ProjectEditDialog.OnEnter: Setting initial focus"
        $this._UpdateFieldFocus()
    }
    
    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "ProjectEditDialog.HandleInput: Null keyInfo"
            return $false
        }
        
        Write-Log -Level Debug -Message "ProjectEditDialog.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', FocusIndex=$($this._focusIndex)"
        
        # Check for save/cancel shortcuts first
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
        
        # Handle Tab navigation
        if ($keyInfo.Key -eq [ConsoleKey]::Tab) {
            if ($keyInfo.Modifiers -band [ConsoleModifiers]::Shift) {
                # Shift+Tab - go backwards
                $this._focusIndex--
                if ($this._focusIndex -lt 0) {
                    $this._focusIndex = $this._fieldOrder.Count - 1
                }
                # Skip read-only key field when editing
                if (-not $this._isNewProject -and $this._focusIndex -eq 0) {
                    $this._focusIndex = $this._fieldOrder.Count - 1
                }
            } else {
                # Tab - go forwards
                $this._focusIndex++
                if ($this._focusIndex -ge $this._fieldOrder.Count) {
                    $this._focusIndex = 0
                }
                # Skip read-only key field when editing
                if (-not $this._isNewProject -and $this._focusIndex -eq 0) {
                    $this._focusIndex = 1
                }
            }
            $this._UpdateFieldFocus()
            return $true
        }
        
        # Handle input based on current field
        if ($this._focusIndex -ge 0 -and $this._focusIndex -lt $this._fieldOrder.Count) {
            $currentFieldName = $this._fieldOrder[$this._focusIndex]
            $currentField = $this._fields[$currentFieldName]
            
            # Special handling for checkbox
            if ($currentField -is [CheckBoxComponent]) {
                if ($keyInfo.Key -eq [ConsoleKey]::Spacebar) {
                    $currentField.Checked = -not $currentField.Checked
                    $this.RequestRedraw()
                    return $true
                }
            }
            # Text input fields
            elseif ($currentField -is [TextBoxComponent] -or $currentField -is [MultilineTextBoxComponent]) {
                # Skip if read-only
                if ($currentField.ReadOnly) {
                    return $false
                }
                
                switch ($keyInfo.Key) {
                    ([ConsoleKey]::Backspace) {
                        if ($currentField.Text.Length -gt 0) {
                            $currentField.Text = $currentField.Text.Substring(0, $currentField.Text.Length - 1)
                            $this.RequestRedraw()
                        }
                        return $true
                    }
                    ([ConsoleKey]::Delete) {
                        # Clear field
                        $currentField.Text = ""
                        $this.RequestRedraw()
                        return $true
                    }
                    default {
                        # Add character if within max length
                        if ($keyInfo.KeyChar -and 
                            ([char]::IsLetterOrDigit($keyInfo.KeyChar) -or 
                             [char]::IsPunctuation($keyInfo.KeyChar) -or 
                             [char]::IsWhiteSpace($keyInfo.KeyChar) -or
                             $keyInfo.KeyChar -eq '-')) {
                            
                            if (-not $currentField.MaxLength -or $currentField.Text.Length -lt $currentField.MaxLength) {
                                $currentField.Text += $keyInfo.KeyChar
                                $this.RequestRedraw()
                                return $true
                            }
                        }
                    }
                }
            }
        }
        
        # Let base Dialog handle other input (like Escape)
        return ([Dialog]$this).HandleInput($keyInfo)
    }
}

# ==============================================================================
# END OF PROJECT EDIT DIALOG
# ==============================================================================
