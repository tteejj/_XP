# ==============================================================================
# Axiom-Phoenix v4.0 - ProjectDetailScreen
# Comprehensive project viewing and editing interface with all enhanced fields
# ==============================================================================

class ProjectDetailScreen : Screen {
    # Services
    hidden $_navService
    hidden $_dataManager
    hidden $_dialogManager
    hidden $_fileSystemService
    
    # UI Components
    hidden [Panel]$_mainPanel
    hidden [Panel]$_headerPanel
    hidden [LabelComponent]$_titleLabel
    hidden [LabelComponent]$_statusLabel
    hidden [ScrollablePanel]$_contentPanel
    
    # Form fields
    hidden [hashtable]$_fields = @{}
    hidden [Panel]$_buttonPanel
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    hidden [ButtonComponent]$_deleteButton
    hidden [ButtonComponent]$_folderButton
    
    # State
    hidden [PmcProject]$_project
    hidden [bool]$_isNewProject
    hidden [bool]$_isDirty = $false
    
    ProjectDetailScreen([object]$serviceContainer, [PmcProject]$project = $null) : base("ProjectDetailScreen", $serviceContainer) {
        $this._navService = $serviceContainer.GetService("NavigationService")
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._dialogManager = $serviceContainer.GetService("DialogManager")
        $this._fileSystemService = $serviceContainer.GetService("FileSystemService")
        
        $this._project = if ($project) { $project } else { [PmcProject]::new() }
        $this._isNewProject = ($null -eq $project)
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
        $this._mainPanel.Title = if ($this._isNewProject) { " New Project " } else { " Project Details " }
        $this.AddChild($this._mainPanel)
        
        # Header panel
        $this._headerPanel = [Panel]::new("HeaderPanel")
        $this._headerPanel.Width = $this._mainPanel.Width - 2
        $this._headerPanel.Height = 4
        $this._headerPanel.X = 1
        $this._headerPanel.Y = 1
        $this._headerPanel.HasBorder = $false
        $this._headerPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._headerPanel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = if ($this._isNewProject) { "Create New Project" } else { $this._project.Name }
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 0
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._headerPanel.AddChild($this._titleLabel)
        
        # Status
        $this._statusLabel = [LabelComponent]::new("StatusLabel")
        $this._statusLabel.X = 2
        $this._statusLabel.Y = 2
        $this._statusLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._UpdateStatusLabel()
        $this._headerPanel.AddChild($this._statusLabel)
        
        # Scrollable content panel
        $this._contentPanel = [ScrollablePanel]::new("ContentPanel")
        $this._contentPanel.X = 1
        $this._contentPanel.Y = $this._headerPanel.Y + $this._headerPanel.Height + 1
        $this._contentPanel.Width = $this._mainPanel.Width - 2
        $this._contentPanel.Height = $this._mainPanel.Height - $this._contentPanel.Y - 5
        $this._contentPanel.ShowScrollbar = $true
        $this._contentPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._contentPanel)
        
        # Create form fields
        $this._CreateFormFields()
        
        # Button panel
        $this._buttonPanel = [Panel]::new("ButtonPanel")
        $this._buttonPanel.X = 1
        $this._buttonPanel.Y = $this._mainPanel.Height - 4
        $this._buttonPanel.Width = $this._mainPanel.Width - 2
        $this._buttonPanel.Height = 3
        $this._buttonPanel.HasBorder = $false
        $this._buttonPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.AddChild($this._buttonPanel)
        
        # Create buttons
        $this._CreateButtons()
    }
    
    hidden [void] _CreateFormFields() {
        $y = 1
        $labelWidth = 20
        $fieldWidth = $this._contentPanel.ContentWidth - $labelWidth - 4
        $currentRef = $this
        
        # Project Key (required)
        $y = $this._AddTextField("Key", "Project Key*", $this._project.Key, $y, $labelWidth, $fieldWidth, 
            "e.g., PROJ-001", 20, (-not $this._isNewProject), $true)
        
        # Project Name (required)  
        $y = $this._AddTextField("Name", "Project Name*", $this._project.Name, $y, $labelWidth, $fieldWidth,
            "Enter project name", 100, $false, $true)
        
        # ID1 (optional)
        $y = $this._AddTextField("ID1", "ID1 Code", $this._project.ID1, $y, $labelWidth, $fieldWidth,
            "Secondary identifier", 50, $false, $false)
        
        # ID2 (optional)
        $y = $this._AddTextField("ID2", "ID2 (Main Case)", $this._project.ID2, $y, $labelWidth, $fieldWidth,
            "Main case identifier", 50, $false, $false)
        
        # Owner
        $y = $this._AddTextField("Owner", "Owner", $this._project.Owner, $y, $labelWidth, $fieldWidth,
            "Project owner name", 100, $false, $false)
        
        # Contact Person (NEW FIELD)
        $y = $this._AddTextField("Contact", "Contact Person", $this._project.Contact, $y, $labelWidth, $fieldWidth,
            "Primary contact name", 100, $false, $false)
        
        # Contact Phone (NEW FIELD)
        $y = $this._AddTextField("ContactPhone", "Contact Phone", $this._project.ContactPhone, $y, $labelWidth, $fieldWidth,
            "Primary contact phone", 30, $false, $false)
        
        # Category (NEW FIELD)
        $y = $this._AddTextField("Category", "Category", $this._project.Category, $y, $labelWidth, $fieldWidth,
            "Project category/type", 50, $false, $false)
        
        # Client ID
        $y = $this._AddTextField("ClientID", "Client ID (BN)", $this._project.GetMetadata("ClientID"), $y, $labelWidth, $fieldWidth,
            "BN-XXXXXX", 50, $false, $false)
        
        # Assigned Date
        $assignedDateText = if ($this._project.AssignedDate) { $this._project.AssignedDate.ToString("yyyy-MM-dd") } else { "" }
        $y = $this._AddTextField("AssignedDate", "Assigned Date", $assignedDateText, $y, $labelWidth, $fieldWidth,
            "YYYY-MM-DD", 10, $false, $false)
        
        # BF Date (Due Date)
        $bfDateText = if ($this._project.BFDate) { $this._project.BFDate.ToString("yyyy-MM-dd") } else { "" }
        $y = $this._AddTextField("BFDate", "Due Date (BF)", $bfDateText, $y, $labelWidth, $fieldWidth,
            "YYYY-MM-DD", 10, $false, $false)
        
        # Completed Date (NEW FIELD)
        $completedDateText = if ($this._project.CompletedDate) { $this._project.CompletedDate.ToString("yyyy-MM-dd") } else { "" }
        $y = $this._AddTextField("CompletedDate", "Completed Date", $completedDateText, $y, $labelWidth, $fieldWidth,
            "YYYY-MM-DD", 10, $false, $false)
        
        # Project Status
        $y = $this._AddCheckboxField("IsActive", "Project Active", $this._project.IsActive, $y, $labelWidth)
        
        # Description (multiline)
        $y = $this._AddMultilineField("Description", "Description", $this._project.Description, $y, $labelWidth, $fieldWidth)
        
        # Project Folder Path
        $y = $this._AddTextField("ProjectFolderPath", "Project Folder", $this._project.ProjectFolderPath, $y, $labelWidth, $fieldWidth,
            "File system path", 200, $false, $false)
        
        # File references
        $y = $this._AddTextField("CaaFileName", "CAA File", $this._project.CaaFileName, $y, $labelWidth, $fieldWidth,
            "CAA filename", 100, $false, $false)
        
        $y = $this._AddTextField("RequestFileName", "Request File", $this._project.RequestFileName, $y, $labelWidth, $fieldWidth,
            "Request filename", 100, $false, $false)
        
        $y = $this._AddTextField("T2020FileName", "T2020 File", $this._project.T2020FileName, $y, $labelWidth, $fieldWidth,
            "T2020 filename", 100, $false, $false)
        
        # Additional metadata fields
        $y = $this._AddTextField("Budget", "Budget", $this._project.GetMetadata("Budget"), $y, $labelWidth, $fieldWidth,
            "Project budget", 50, $false, $false)
        
        $y = $this._AddTextField("Phase", "Phase", $this._project.GetMetadata("Phase"), $y, $labelWidth, $fieldWidth,
            "Current phase", 50, $false, $false)
        
        # Set content height for scrolling
        $this._contentPanel.ContentHeight = $y + 2
    }
    
    hidden [int] _AddTextField([string]$name, [string]$label, [string]$value, [int]$y, [int]$labelWidth, [int]$fieldWidth, [string]$placeholder, [int]$maxLength, [bool]$readOnly, [bool]$required) {
        # Label
        $fieldLabel = [LabelComponent]::new("${name}Label")
        $fieldLabel.Text = $label + ":"
        $fieldLabel.X = 2
        $fieldLabel.Y = $y
        $fieldLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._contentPanel.AddChild($fieldLabel)
        
        # Field
        $field = [TextBoxComponent]::new("${name}Field")
        $field.X = $labelWidth + 2
        $field.Y = $y
        $field.Width = $fieldWidth
        $field.Text = if ($value) { $value } else { "" }
        $field.Placeholder = $placeholder
        $field.MaxLength = $maxLength
        $field.ReadOnly = $readOnly
        $field.IsFocusable = -not $readOnly
        $field.BackgroundColor = Get-ThemeColor "input.background"
        $field.BorderColor = Get-ThemeColor "input.border"
        
        # Add change tracking
        $currentRef = $this
        $field | Add-Member -MemberType ScriptMethod -Name OnTextChanged -Value {
            $currentRef._isDirty = $true
            $currentRef._UpdateStatusLabel()
        } -Force
        
        $this._contentPanel.AddChild($field)
        $this._fields[$name] = $field
        
        return $y + 2
    }
    
    hidden [int] _AddCheckboxField([string]$name, [string]$label, [bool]$value, [int]$y, [int]$labelWidth) {
        # Label
        $fieldLabel = [LabelComponent]::new("${name}Label")
        $fieldLabel.Text = $label + ":"
        $fieldLabel.X = 2
        $fieldLabel.Y = $y
        $fieldLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._contentPanel.AddChild($fieldLabel)
        
        # Checkbox
        $field = [CheckBoxComponent]::new("${name}Field")
        $field.X = $labelWidth + 2
        $field.Y = $y
        $field.Checked = $value
        $field.IsFocusable = $true
        
        # Add change tracking
        $currentRef = $this
        $field | Add-Member -MemberType ScriptMethod -Name OnCheckedChanged -Value {
            $currentRef._isDirty = $true
            $currentRef._UpdateStatusLabel()
        } -Force
        
        $this._contentPanel.AddChild($field)
        $this._fields[$name] = $field
        
        return $y + 2
    }
    
    hidden [int] _AddMultilineField([string]$name, [string]$label, [string]$value, [int]$y, [int]$labelWidth, [int]$fieldWidth) {
        # Label
        $fieldLabel = [LabelComponent]::new("${name}Label")
        $fieldLabel.Text = $label + ":"
        $fieldLabel.X = 2
        $fieldLabel.Y = $y
        $fieldLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._contentPanel.AddChild($fieldLabel)
        
        # Multiline field
        $field = [MultilineTextBoxComponent]::new("${name}Field")
        $field.X = 2
        $field.Y = $y + 1
        $field.Width = $this._contentPanel.ContentWidth - 4
        $field.Height = 4
        $fieldText = if ($value) { $value } else { "" }
        $field.SetText($fieldText)
        $field.HasBorder = $true
        $field.IsFocusable = $true
        $field.BackgroundColor = Get-ThemeColor "input.background"
        $field.BorderColor = Get-ThemeColor "input.border"
        
        # Add change tracking
        $currentRef = $this
        $field | Add-Member -MemberType ScriptMethod -Name OnTextChanged -Value {
            $currentRef._isDirty = $true
            $currentRef._UpdateStatusLabel()
        } -Force
        
        $this._contentPanel.AddChild($field)
        $this._fields[$name] = $field
        
        return $y + 6
    }
    
    hidden [void] _CreateButtons() {
        $buttonWidth = 12
        $buttonSpacing = 2
        $buttonY = 1
        
        # Save button
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = if ($this._isNewProject) { "Create" } else { "Save" }
        $this._saveButton.X = 2
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = $buttonWidth
        $this._saveButton.Height = 1
        $this._saveButton.IsFocusable = $true
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.primary.background"
        $this._saveButton.ForegroundColor = Get-ThemeColor "button.primary.foreground"
        
        $currentRef = $this
        $this._saveButton.OnClick = {
            $currentRef._SaveProject()
        }.GetNewClosure()
        
        $this._buttonPanel.AddChild($this._saveButton)
        
        # Cancel button
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $buttonWidth + $buttonSpacing + 2
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.IsFocusable = $true
        
        $this._cancelButton.OnClick = {
            $currentRef._CancelEdit()
        }.GetNewClosure()
        
        $this._buttonPanel.AddChild($this._cancelButton)
        
        # Delete button (only for existing projects)
        if (-not $this._isNewProject) {
            $this._deleteButton = [ButtonComponent]::new("DeleteButton")
            $this._deleteButton.Text = "Delete"
            $this._deleteButton.X = ($buttonWidth + $buttonSpacing) * 2 + 2
            $this._deleteButton.Y = $buttonY
            $this._deleteButton.Width = $buttonWidth
            $this._deleteButton.Height = 1
            $this._deleteButton.IsFocusable = $true
            $this._deleteButton.BackgroundColor = Get-ThemeColor "button.danger.background"
            $this._deleteButton.ForegroundColor = Get-ThemeColor "button.danger.foreground"
            
            $this._deleteButton.OnClick = {
                $currentRef._DeleteProject()
            }.GetNewClosure()
            
            $this._buttonPanel.AddChild($this._deleteButton)
        }
        
        # Open Folder button (only for existing projects with folder path)
        if (-not $this._isNewProject -and -not [string]::IsNullOrEmpty($this._project.ProjectFolderPath)) {
            $this._folderButton = [ButtonComponent]::new("FolderButton")
            $this._folderButton.Text = "Open Folder"
            $this._folderButton.X = ($buttonWidth + $buttonSpacing) * 3 + 2
            $this._folderButton.Y = $buttonY
            $this._folderButton.Width = $buttonWidth + 2
            $this._folderButton.Height = 1
            $this._folderButton.IsFocusable = $true
            
            $this._folderButton.OnClick = {
                $currentRef._OpenProjectFolder()
            }.GetNewClosure()
            
            $this._buttonPanel.AddChild($this._folderButton)
        }
    }
    
    hidden [void] _UpdateStatusLabel() {
        if ($this._isNewProject) {
            $this._statusLabel.Text = "Fill in the required fields (*) and click Create"
        } else {
            $statusText = "Key: $($this._project.Key)"
            if ($this._project.IsActive) {
                $statusText += " | Status: Active"
            } else {
                $statusText += " | Status: Archived"
            }
            
            if ($this._isDirty) {
                $statusText += " | UNSAVED CHANGES"
                $this._statusLabel.ForegroundColor = Get-ThemeColor "text.warning"
            } else {
                $this._statusLabel.ForegroundColor = Get-ThemeColor "text.secondary"
            }
            
            $this._statusLabel.Text = $statusText
        }
    }
    
    hidden [void] _SaveProject() {
        try {
            # Validate required fields
            $key = $this._fields["Key"].Text.Trim()
            $name = $this._fields["Name"].Text.Trim()
            
            if ([string]::IsNullOrEmpty($key)) {
                $this._dialogManager.ShowMessage("Validation Error", "Project Key is required.")
                return
            }
            
            if ([string]::IsNullOrEmpty($name)) {
                $this._dialogManager.ShowMessage("Validation Error", "Project Name is required.")
                return
            }
            
            # Check for duplicate key (only for new projects)
            if ($this._isNewProject) {
                $existing = $this._dataManager.GetProject($key)
                if ($existing) {
                    $this._dialogManager.ShowMessage("Validation Error", "A project with key '$key' already exists.")
                    return
                }
                $this._project.Key = $key
            }
            
            # Update project fields
            $this._project.Name = $name
            $this._project.ID1 = $this._fields["ID1"].Text.Trim()
            $this._project.ID2 = $this._fields["ID2"].Text.Trim()
            $this._project.Owner = $this._fields["Owner"].Text.Trim()
            $this._project.Contact = $this._fields["Contact"].Text.Trim()
            $this._project.ContactPhone = $this._fields["ContactPhone"].Text.Trim()
            $this._project.Category = $this._fields["Category"].Text.Trim()
            $this._project.Description = $this._fields["Description"].GetText()
            $this._project.IsActive = $this._fields["IsActive"].Checked
            $this._project.ProjectFolderPath = $this._fields["ProjectFolderPath"].Text.Trim()
            $this._project.CaaFileName = $this._fields["CaaFileName"].Text.Trim()
            $this._project.RequestFileName = $this._fields["RequestFileName"].Text.Trim()
            $this._project.T2020FileName = $this._fields["T2020FileName"].Text.Trim()
            
            # Parse dates
            $this._ParseAndSetDate("AssignedDate", "AssignedDate")
            $this._ParseAndSetDate("BFDate", "BFDate")
            $this._ParseAndSetDate("CompletedDate", "CompletedDate")
            
            # Update metadata
            $clientId = $this._fields["ClientID"].Text.Trim()
            if (-not [string]::IsNullOrEmpty($clientId)) {
                $this._project.SetMetadata("ClientID", $clientId)
            }
            
            $budget = $this._fields["Budget"].Text.Trim()
            if (-not [string]::IsNullOrEmpty($budget)) {
                $this._project.SetMetadata("Budget", $budget)
            }
            
            $phase = $this._fields["Phase"].Text.Trim()
            if (-not [string]::IsNullOrEmpty($phase)) {
                $this._project.SetMetadata("Phase", $phase)
            }
            
            # Save to data manager
            if ($this._isNewProject) {
                $this._dataManager.AddProject($this._project)
                $this._dialogManager.ShowMessage("Success", "Project '$($this._project.Name)' created successfully!")
            } else {
                $this._dataManager.UpdateProject($this._project)
                $this._dialogManager.ShowMessage("Success", "Project '$($this._project.Name)' updated successfully!")
            }
            
            $this._isDirty = $false
            $this._UpdateStatusLabel()
            
            # Go back to previous screen
            $this._navService.GoBack()
            
        } catch {
            $this._dialogManager.ShowMessage("Error", "Failed to save project: $($_.Exception.Message)")
        }
    }
    
    hidden [void] _ParseAndSetDate([string]$fieldName, [string]$propertyName) {
        $dateText = $this._fields[$fieldName].Text.Trim()
        if (-not [string]::IsNullOrEmpty($dateText)) {
            try {
                $parsedDate = [DateTime]::ParseExact($dateText, "yyyy-MM-dd", $null)
                $this._project.$propertyName = $parsedDate
            } catch {
                # Invalid date format - could show warning but for now just ignore
                $this._project.$propertyName = $null
            }
        } else {
            $this._project.$propertyName = $null
        }
    }
    
    hidden [void] _CancelEdit() {
        if ($this._isDirty) {
            $result = $this._dialogManager.ShowConfirmation("Unsaved Changes", "You have unsaved changes. Are you sure you want to cancel?")
            if (-not $result) {
                return
            }
        }
        
        $this._navService.GoBack()
    }
    
    hidden [void] _DeleteProject() {
        $result = $this._dialogManager.ShowConfirmation("Delete Project", 
            "Are you sure you want to delete project '$($this._project.Name)'? This action cannot be undone.")
        
        if ($result) {
            try {
                $this._dataManager.DeleteProject($this._project.Key)
                $this._dialogManager.ShowMessage("Success", "Project '$($this._project.Name)' deleted successfully!")
                $this._navService.GoBack()
            } catch {
                $this._dialogManager.ShowMessage("Error", "Failed to delete project: $($_.Exception.Message)")
            }
        }
    }
    
    hidden [void] _OpenProjectFolder() {
        if (-not [string]::IsNullOrEmpty($this._project.ProjectFolderPath)) {
            try {
                if (Test-Path $this._project.ProjectFolderPath) {
                    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
                        Start-Process "explorer.exe" -ArgumentList $this._project.ProjectFolderPath
                    } else {
                        # Linux/Mac
                        Start-Process "xdg-open" -ArgumentList $this._project.ProjectFolderPath
                    }
                } else {
                    $this._dialogManager.ShowMessage("Error", "Project folder does not exist: $($this._project.ProjectFolderPath)")
                }
            } catch {
                $this._dialogManager.ShowMessage("Error", "Failed to open project folder: $($_.Exception.Message)")
            }
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this._CancelEdit()
                return $true
            }
            ([ConsoleKey]::F5) {
                # Refresh/reload project data
                if (-not $this._isNewProject) {
                    $refreshedProject = $this._dataManager.GetProject($this._project.Key)
                    if ($refreshedProject) {
                        $this._project = $refreshedProject
                        $this._isDirty = $false
                        # Reinitialize to refresh field values
                        $this.Initialize()
                    }
                }
                return $true
            }
        }
        
        # Handle keyboard shortcuts
        if ($keyInfo.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::S) {
                    $this._SaveProject()
                    return $true
                }
            }
        }
        
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    [void] OnEnter() {
        # Set initial focus to first editable field
        if ($this._isNewProject -and $this._fields.ContainsKey("Key")) {
            $this._fields["Key"].IsFocused = $true
        } elseif ($this._fields.ContainsKey("Name")) {
            $this._fields["Name"].IsFocused = $true
        }
        
        ([Screen]$this).OnEnter()
    }
    
    [void] OnExit() {
        ([Screen]$this).OnExit()
    }
}