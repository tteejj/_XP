# ==============================================================================
# Axiom-Phoenix v4.0 - TimeEntryDialog
# Dialog for adding/editing time entries
# ==============================================================================

class TimeEntryDialog : Dialog {
    # Services
    hidden $_dataManager
    hidden $_timeSheetService
    
    # UI Components
    hidden [Panel]$_panel
    hidden [LabelComponent]$_titleLabel
    
    # Project selection
    hidden [LabelComponent]$_projectLabel
    hidden [ComboBoxComponent]$_projectCombo
    
    # Task selection
    hidden [LabelComponent]$_taskLabel
    hidden [ComboBoxComponent]$_taskCombo
    
    # Date input
    hidden [LabelComponent]$_dateLabel
    hidden [DateInputComponent]$_dateInput
    
    # Time inputs
    hidden [LabelComponent]$_startTimeLabel
    hidden [TextBoxComponent]$_startTimeInput
    hidden [LabelComponent]$_endTimeLabel
    hidden [TextBoxComponent]$_endTimeInput
    hidden [LabelComponent]$_hoursLabel
    hidden [NumericInputComponent]$_hoursInput
    
    # Description
    hidden [LabelComponent]$_descriptionLabel
    hidden [TextBoxComponent]$_descriptionInput
    
    # Billing type
    hidden [LabelComponent]$_billingLabel
    hidden [ComboBoxComponent]$_billingCombo
    
    # Buttons
    hidden [ButtonComponent]$_saveButton
    hidden [ButtonComponent]$_cancelButton
    
    # State
    hidden [TimeEntry]$_timeEntry
    hidden [bool]$_isEditMode
    hidden [hashtable]$_projectsIndex = @{}
    hidden [array]$_currentTasks = @()
    
    TimeEntryDialog([object]$serviceContainer) : base("TimeEntryDialog", $serviceContainer) {
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._timeSheetService = $serviceContainer.GetService("TimeSheetService")
        $this.Width = 60
        $this.Height = 20
    }
    
    TimeEntryDialog([object]$serviceContainer, [TimeEntry]$entry) : base("TimeEntryDialog", $serviceContainer) {
        $this._dataManager = $serviceContainer.GetService("DataManager")
        $this._timeSheetService = $serviceContainer.GetService("TimeSheetService")
        $this._timeEntry = $entry
        $this._isEditMode = $true
        $this.Width = 60
        $this.Height = 20
    }
    
    [void] Initialize() {
        # Main panel
        $this._panel = [Panel]::new("MainPanel")
        $this._panel.Width = $this.Width - 4
        $this._panel.Height = $this.Height - 4
        $this._panel.X = 2
        $this._panel.Y = 2
        $this._panel.HasBorder = $true
        $this._panel.BackgroundColor = Get-ThemeColor "dialog.background"
        $this._panel.BorderColor = Get-ThemeColor "dialog.border"
        $this.AddChild($this._panel)
        
        # Title
        $this._titleLabel = [LabelComponent]::new("TitleLabel")
        $this._titleLabel.Text = if ($this._isEditMode) { "Edit Time Entry" } else { "Add Time Entry" }
        $this._titleLabel.X = 2
        $this._titleLabel.Y = 1
        $this._titleLabel.ForegroundColor = Get-ThemeColor "text.primary"
        $this._panel.AddChild($this._titleLabel)
        
        $currentY = 3
        $labelWidth = 12
        $inputX = $labelWidth + 2
        
        # Project selection
        $this._projectLabel = [LabelComponent]::new("ProjectLabel")
        $this._projectLabel.Text = "Project:"
        $this._projectLabel.X = 2
        $this._projectLabel.Y = $currentY
        $this._projectLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._projectLabel)
        
        $this._projectCombo = [ComboBoxComponent]::new("ProjectCombo")
        $this._projectCombo.X = $inputX
        $this._projectCombo.Y = $currentY
        $this._projectCombo.Width = 30
        $this._projectCombo.Height = 1
        $this._projectCombo.IsFocusable = $true
        $this._projectCombo.TabIndex = 0
        
        # Load projects
        $projects = $this._dataManager.GetProjects() | Where-Object { $_.IsActive }
        foreach ($project in $projects) {
            $this._projectCombo.AddItem($project.Name)
            $this._projectsIndex[$project.Name] = $project
        }
        
        # Set event handler for project change
        $currentDialogRef = $this
        $this._projectCombo.SelectedIndexChanged = {
            param($sender, $index)
            $currentDialogRef._OnProjectChanged()
        }.GetNewClosure()
        
        $this._panel.AddChild($this._projectCombo)
        $currentY += 2
        
        # Task selection
        $this._taskLabel = [LabelComponent]::new("TaskLabel")
        $this._taskLabel.Text = "Task:"
        $this._taskLabel.X = 2
        $this._taskLabel.Y = $currentY
        $this._taskLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._taskLabel)
        
        $this._taskCombo = [ComboBoxComponent]::new("TaskCombo")
        $this._taskCombo.X = $inputX
        $this._taskCombo.Y = $currentY
        $this._taskCombo.Width = 30
        $this._taskCombo.Height = 1
        $this._taskCombo.IsFocusable = $true
        $this._taskCombo.TabIndex = 1
        $this._panel.AddChild($this._taskCombo)
        $currentY += 2
        
        # Date input
        $this._dateLabel = [LabelComponent]::new("DateLabel")
        $this._dateLabel.Text = "Date:"
        $this._dateLabel.X = 2
        $this._dateLabel.Y = $currentY
        $this._dateLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._dateLabel)
        
        $this._dateInput = [DateInputComponent]::new("DateInput")
        $this._dateInput.X = $inputX
        $this._dateInput.Y = $currentY
        $this._dateInput.Width = 12
        $this._dateInput.Height = 1
        $this._dateInput.IsFocusable = $true
        $this._dateInput.TabIndex = 2
        $this._dateInput.Value = if ($this._timeEntry) { $this._timeEntry.StartTime.Date } else { [DateTime]::Today }
        $this._panel.AddChild($this._dateInput)
        $currentY += 2
        
        # Hours input (simpler than start/end time)
        $this._hoursLabel = [LabelComponent]::new("HoursLabel")
        $this._hoursLabel.Text = "Hours:"
        $this._hoursLabel.X = 2
        $this._hoursLabel.Y = $currentY
        $this._hoursLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._hoursLabel)
        
        $this._hoursInput = [NumericInputComponent]::new("HoursInput")
        $this._hoursInput.X = $inputX
        $this._hoursInput.Y = $currentY
        $this._hoursInput.Width = 8
        $this._hoursInput.Height = 1
        $this._hoursInput.IsFocusable = $true
        $this._hoursInput.TabIndex = 3
        $this._hoursInput.MinValue = 0.25
        $this._hoursInput.MaxValue = 24
        $this._hoursInput.Step = 0.25
        $this._hoursInput.Value = if ($this._timeEntry) { $this._timeEntry.GetHours() } else { 1 }
        $this._panel.AddChild($this._hoursInput)
        $currentY += 2
        
        # Description
        $this._descriptionLabel = [LabelComponent]::new("DescriptionLabel")
        $this._descriptionLabel.Text = "Description:"
        $this._descriptionLabel.X = 2
        $this._descriptionLabel.Y = $currentY
        $this._descriptionLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._descriptionLabel)
        
        $this._descriptionInput = [TextBoxComponent]::new("DescriptionInput")
        $this._descriptionInput.X = $inputX
        $this._descriptionInput.Y = $currentY
        $this._descriptionInput.Width = 30
        $this._descriptionInput.Height = 1
        $this._descriptionInput.IsFocusable = $true
        $this._descriptionInput.TabIndex = 4
        $this._descriptionInput.Text = if ($this._timeEntry) { $this._timeEntry.Description } else { "" }
        
        # Add focus handlers to TextBox
        $this._descriptionInput | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "input.focused.border"
            $this.ShowCursor = $true
            $this.RequestRedraw()
        } -Force
        
        $this._descriptionInput | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "input.border"
            $this.ShowCursor = $false
            $this.RequestRedraw()
        } -Force
        
        $this._panel.AddChild($this._descriptionInput)
        $currentY += 2
        
        # Billing type
        $this._billingLabel = [LabelComponent]::new("BillingLabel")
        $this._billingLabel.Text = "Billing:"
        $this._billingLabel.X = 2
        $this._billingLabel.Y = $currentY
        $this._billingLabel.ForegroundColor = Get-ThemeColor "text.secondary"
        $this._panel.AddChild($this._billingLabel)
        
        $this._billingCombo = [ComboBoxComponent]::new("BillingCombo")
        $this._billingCombo.X = $inputX
        $this._billingCombo.Y = $currentY
        $this._billingCombo.Width = 20
        $this._billingCombo.Height = 1
        $this._billingCombo.IsFocusable = $true
        $this._billingCombo.TabIndex = 5
        $this._billingCombo.AddItem("Billable")
        $this._billingCombo.AddItem("Non-Billable")
        $this._billingCombo.SelectedIndex = if ($this._timeEntry -and $this._timeEntry.BillingType -eq [BillingType]::NonBillable) { 1 } else { 0 }
        $this._panel.AddChild($this._billingCombo)
        $currentY += 3
        
        # Buttons
        $buttonY = $this._panel.Height - 3
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save"
        $this._saveButton.X = $this._panel.Width - 24
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = 10
        $this._saveButton.Height = 1
        $this._saveButton.IsFocusable = $true
        $this._saveButton.TabIndex = 6
        $this._saveButton.BackgroundColor = Get-ThemeColor "button.primary.background"
        $this._saveButton.ForegroundColor = Get-ThemeColor "button.primary.foreground"
        $this._saveButton.OnClick = {
            $currentDialogRef._SaveEntry()
        }.GetNewClosure()
        $this._panel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $this._panel.Width - 12
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = 10
        $this._cancelButton.Height = 1
        $this._cancelButton.IsFocusable = $true
        $this._cancelButton.TabIndex = 7
        $this._cancelButton.OnClick = {
            $currentDialogRef.Cancel()
        }.GetNewClosure()
        $this._panel.AddChild($this._cancelButton)
        
        # If editing, populate fields
        if ($this._isEditMode -and $this._timeEntry) {
            # Set project
            $project = $this._dataManager.GetProject($this._timeEntry.ProjectKey)
            if ($project) {
                $projectIndex = $this._projectCombo.Items.IndexOf($project.Name)
                if ($projectIndex -ge 0) {
                    $this._projectCombo.SelectedIndex = $projectIndex
                    $this._OnProjectChanged()
                    
                    # Set task
                    if ($this._timeEntry.TaskId) {
                        $task = $this._dataManager.GetTask($this._timeEntry.TaskId)
                        if ($task) {
                            $taskIndex = $this._taskCombo.Items.IndexOf($task.Title)
                            if ($taskIndex -ge 0) {
                                $this._taskCombo.SelectedIndex = $taskIndex
                            }
                        }
                    }
                }
            }
        }
    }
    
    hidden [void] _OnProjectChanged() {
        # Clear task combo
        $this._taskCombo.ClearItems()
        $this._currentTasks = @()
        
        # Get selected project
        if ($this._projectCombo.SelectedIndex -ge 0) {
            $projectName = $this._projectCombo.Items[$this._projectCombo.SelectedIndex]
            $project = $this._projectsIndex[$projectName]
            
            if ($project) {
                # Load tasks for this project
                $tasks = $this._dataManager.GetTasksByProject($project.Key) | 
                    Where-Object { $_.Status -ne [TaskStatus]::Completed -and $_.Status -ne [TaskStatus]::Cancelled }
                
                $this._taskCombo.AddItem("(No specific task)")
                foreach ($task in $tasks) {
                    $this._taskCombo.AddItem($task.Title)
                    $this._currentTasks += $task
                }
                
                $this._taskCombo.SelectedIndex = 0
            }
        }
        
        $this.RequestRedraw()
    }
    
    hidden [void] _SaveEntry() {
        try {
            # Validate inputs
            if ($this._projectCombo.SelectedIndex -lt 0) {
                $this._ShowError("Please select a project")
                return
            }
            
            # Get selected values
            $projectName = $this._projectCombo.Items[$this._projectCombo.SelectedIndex]
            $project = $this._projectsIndex[$projectName]
            
            $taskId = $null
            if ($this._taskCombo.SelectedIndex -gt 0) {
                $taskIndex = $this._taskCombo.SelectedIndex - 1
                if ($taskIndex -lt $this._currentTasks.Count) {
                    $taskId = $this._currentTasks[$taskIndex].Id
                }
            }
            
            $date = $this._dateInput.Value
            $hours = $this._hoursInput.Value
            $description = $this._descriptionInput.Text
            $billingType = if ($this._billingCombo.SelectedIndex -eq 0) { 
                [BillingType]::Billable 
            } else { 
                [BillingType]::NonBillable 
            }
            
            if ($this._isEditMode) {
                # Update existing entry
                $this._timeEntry.ProjectKey = $project.Key
                $this._timeEntry.TaskId = $taskId
                $this._timeEntry.StartTime = $date.Date.AddHours(9) # Default 9 AM
                $this._timeEntry.EndTime = $date.Date.AddHours(9).AddHours($hours)
                $this._timeEntry.Description = $description
                $this._timeEntry.BillingType = $billingType
                
                $this._dataManager.UpdateTimeEntry($this._timeEntry)
            } else {
                # Create new entry
                $entry = [TimeEntry]::new()
                $entry.ProjectKey = $project.Key
                $entry.TaskId = $taskId
                $entry.StartTime = $date.Date.AddHours(9) # Default 9 AM
                $entry.EndTime = $date.Date.AddHours(9).AddHours($hours)
                $entry.Description = $description
                $entry.BillingType = $billingType
                $entry.UserId = "CurrentUser" # TODO: Get from session/context
                
                $this._dataManager.AddTimeEntry($entry)
            }
            
            $this.Complete($true)
        }
        catch {
            Write-Log -Level Error -Message "Failed to save time entry: $_"
            $this._ShowError("Failed to save time entry: $($_.Exception.Message)")
        }
    }
    
    hidden [void] _ShowError([string]$message) {
        # TODO: Show error in dialog
        Write-Log -Level Error -Message $message
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Escape) {
                $this.Cancel()
                return $true
            }
        }
        
        return ([Dialog]$this).HandleInput($keyInfo)
    }
}