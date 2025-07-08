# Implement CRUD Dialogs for TaskListScreen
# This script adds functional dialogs for Create, Update, Delete operations

Write-Host "Implementing CRUD dialogs for task management..." -ForegroundColor Cyan

# PART 1: Add Task CRUD Dialogs to AllComponents.ps1
Write-Host "`nPart 1: Adding task dialogs..." -ForegroundColor Yellow

$componentsFile = "AllComponents.ps1"
$componentsContent = Get-Content $componentsFile -Raw

# Add task dialogs after existing dialog classes
$taskDialogs = @'

# Task Create/Edit Dialog
class TaskDialog : Dialog {
    hidden [TextBoxComponent] $_titleBox
    hidden [TextBoxComponent] $_descriptionBox
    hidden [ComboBoxComponent] $_statusCombo
    hidden [ComboBoxComponent] $_priorityCombo
    hidden [NumericInputComponent] $_progressInput
    hidden [ButtonComponent] $_saveButton
    hidden [ButtonComponent] $_cancelButton
    hidden [PmcTask] $_task
    hidden [bool] $_isNewTask
    
    TaskDialog([string]$title, [PmcTask]$task) : base($title) {
        $this._task = if ($task) { $task } else { [PmcTask]::new() }
        $this._isNewTask = ($null -eq $task)
    }
    
    [void] Initialize() {
        ([Dialog]$this).Initialize()
        
        $contentY = 2
        $labelWidth = 12
        $inputX = $labelWidth + 2
        $inputWidth = $this.ContentWidth - $inputX - 2
        
        # Title
        $titleLabel = [LabelComponent]::new("TitleLabel")
        $titleLabel.Text = "Title:"
        $titleLabel.X = 2
        $titleLabel.Y = $contentY
        $this._contentPanel.AddChild($titleLabel)
        
        $this._titleBox = [TextBoxComponent]::new("TitleBox")
        $this._titleBox.X = $inputX
        $this._titleBox.Y = $contentY
        $this._titleBox.Width = $inputWidth
        $this._titleBox.Height = 1
        $this._titleBox.Text = $this._task.Title
        $this._contentPanel.AddChild($this._titleBox)
        $contentY += 2
        
        # Description
        $descLabel = [LabelComponent]::new("DescLabel")
        $descLabel.Text = "Description:"
        $descLabel.X = 2
        $descLabel.Y = $contentY
        $this._contentPanel.AddChild($descLabel)
        
        $this._descriptionBox = [TextBoxComponent]::new("DescBox")
        $this._descriptionBox.X = $inputX
        $this._descriptionBox.Y = $contentY
        $this._descriptionBox.Width = $inputWidth
        $this._descriptionBox.Height = 1
        $this._descriptionBox.Text = $this._task.Description
        $this._contentPanel.AddChild($this._descriptionBox)
        $contentY += 2
        
        # Status
        $statusLabel = [LabelComponent]::new("StatusLabel")
        $statusLabel.Text = "Status:"
        $statusLabel.X = 2
        $statusLabel.Y = $contentY
        $this._contentPanel.AddChild($statusLabel)
        
        $this._statusCombo = [ComboBoxComponent]::new("StatusCombo")
        $this._statusCombo.X = $inputX
        $this._statusCombo.Y = $contentY
        $this._statusCombo.Width = $inputWidth
        $this._statusCombo.Height = 1
        $this._statusCombo.Items = @([TaskStatus]::GetEnumNames())
        $this._statusCombo.SelectedIndex = [Array]::IndexOf($this._statusCombo.Items, $this._task.Status.ToString())
        $this._contentPanel.AddChild($this._statusCombo)
        $contentY += 2
        
        # Priority
        $priorityLabel = [LabelComponent]::new("PriorityLabel")
        $priorityLabel.Text = "Priority:"
        $priorityLabel.X = 2
        $priorityLabel.Y = $contentY
        $this._contentPanel.AddChild($priorityLabel)
        
        $this._priorityCombo = [ComboBoxComponent]::new("PriorityCombo")
        $this._priorityCombo.X = $inputX
        $this._priorityCombo.Y = $contentY
        $this._priorityCombo.Width = $inputWidth
        $this._priorityCombo.Height = 1
        $this._priorityCombo.Items = @([TaskPriority]::GetEnumNames())
        $this._priorityCombo.SelectedIndex = [Array]::IndexOf($this._priorityCombo.Items, $this._task.Priority.ToString())
        $this._contentPanel.AddChild($this._priorityCombo)
        $contentY += 2
        
        # Progress
        $progressLabel = [LabelComponent]::new("ProgressLabel")
        $progressLabel.Text = "Progress %:"
        $progressLabel.X = 2
        $progressLabel.Y = $contentY
        $this._contentPanel.AddChild($progressLabel)
        
        $this._progressInput = [NumericInputComponent]::new("ProgressInput")
        $this._progressInput.X = $inputX
        $this._progressInput.Y = $contentY
        $this._progressInput.Width = 10
        $this._progressInput.Height = 1
        $this._progressInput.MinValue = 0
        $this._progressInput.MaxValue = 100
        $this._progressInput.Value = $this._task.Progress
        $this._contentPanel.AddChild($this._progressInput)
        $contentY += 3
        
        # Buttons
        $buttonY = $this.ContentHeight - 3
        $buttonWidth = 12
        $spacing = 2
        $totalButtonWidth = ($buttonWidth * 2) + $spacing
        $startX = [Math]::Floor(($this.ContentWidth - $totalButtonWidth) / 2)
        
        $this._saveButton = [ButtonComponent]::new("SaveButton")
        $this._saveButton.Text = "Save"
        $this._saveButton.X = $startX
        $this._saveButton.Y = $buttonY
        $this._saveButton.Width = $buttonWidth
        $this._saveButton.Height = 1
        $this._saveButton.OnClick = {
            $this.DialogResult = [DialogResult]::OK
            $this.Hide()
        }.GetNewClosure()
        $this._contentPanel.AddChild($this._saveButton)
        
        $this._cancelButton = [ButtonComponent]::new("CancelButton")
        $this._cancelButton.Text = "Cancel"
        $this._cancelButton.X = $startX + $buttonWidth + $spacing
        $this._cancelButton.Y = $buttonY
        $this._cancelButton.Width = $buttonWidth
        $this._cancelButton.Height = 1
        $this._cancelButton.OnClick = {
            $this.DialogResult = [DialogResult]::Cancel
            $this.Hide()
        }.GetNewClosure()
        $this._contentPanel.AddChild($this._cancelButton)
        
        # Set initial focus
        Set-ComponentFocus -Component $this._titleBox
    }
    
    [PmcTask] GetTask() {
        if ($this.DialogResult -eq [DialogResult]::OK) {
            # Update task with form values
            $this._task.Title = $this._titleBox.Text
            $this._task.Description = $this._descriptionBox.Text
            $this._task.Status = [TaskStatus]::($this._statusCombo.Items[$this._statusCombo.SelectedIndex])
            $this._task.Priority = [TaskPriority]::($this._priorityCombo.Items[$this._priorityCombo.SelectedIndex])
            $this._task.SetProgress($this._progressInput.Value)
            $this._task.UpdatedAt = [DateTime]::Now
        }
        return $this._task
    }
}

# Task Delete Confirmation Dialog
class TaskDeleteDialog : ConfirmDialog {
    hidden [PmcTask] $_task
    
    TaskDeleteDialog([PmcTask]$task) : base("Confirm Delete", "Are you sure you want to delete this task?") {
        $this._task = $task
    }
    
    [void] Initialize() {
        ([ConfirmDialog]$this).Initialize()
        
        # Add task details to the message
        if ($this._task) {
            $detailsLabel = [LabelComponent]::new("TaskDetails")
            $detailsLabel.Text = "Task: $($this._task.Title)"
            $detailsLabel.X = 2
            $detailsLabel.Y = 4
            $detailsLabel.ForegroundColor = Get-ThemeColor -ColorName "Warning" -DefaultColor "#FFA500"
            $this._contentPanel.AddChild($detailsLabel)
        }
    }
}
'@

# Add dialogs before the NavigationMenu class
$navMenuPattern = "#region NavigationMenu"
if ($componentsContent -match $navMenuPattern -and $componentsContent -notmatch "class TaskDialog") {
    $componentsContent = $componentsContent.Replace($navMenuPattern, "$taskDialogs`r`n`r`n$navMenuPattern")
    Write-Host "  - Added TaskDialog and TaskDeleteDialog" -ForegroundColor Green
}

Set-Content $componentsFile $componentsContent -Encoding UTF8

# PART 2: Wire up the CRUD buttons in TaskListScreen
Write-Host "`nPart 2: Wiring up CRUD functionality..." -ForegroundColor Yellow

$screensFile = "AllScreens.ps1"
$screensContent = Get-Content $screensFile -Raw

# Update the button click handlers with actual functionality
$crudImplementation = @'
        # New button
        $this._newButton = [ButtonComponent]::new("NewButton")
        $this._newButton.Text = "[N]ew Task"
        $this._newButton.X = $currentX
        $this._newButton.Y = $buttonY
        $this._newButton.Width = 12
        $this._newButton.Height = 1
        $thisScreen = $this
        $this._newButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager) {
                $dialog = [TaskDialog]::new("New Task", $null)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::OK) {
                    $newTask = $dialog.GetTask()
                    $dataManager.AddTask($newTask)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    Write-Verbose "New task created: $($newTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._newButton)
        $currentX += $buttonSpacing
        
        # Edit button
        $this._editButton = [ButtonComponent]::new("EditButton")
        $this._editButton.Text = "[E]dit Task"
        $this._editButton.X = $currentX
        $this._editButton.Y = $buttonY
        $this._editButton.Width = 12
        $this._editButton.Height = 1
        $this._editButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager -and $thisScreen._selectedTask) {
                $dialog = [TaskDialog]::new("Edit Task", $thisScreen._selectedTask)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::OK) {
                    $updatedTask = $dialog.GetTask()
                    $dataManager.UpdateTask($updatedTask)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    Write-Verbose "Task updated: $($updatedTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._editButton)
        $currentX += $buttonSpacing
        
        # Delete button
        $this._deleteButton = [ButtonComponent]::new("DeleteButton")
        $this._deleteButton.Text = "[D]elete Task"
        $this._deleteButton.X = $currentX
        $this._deleteButton.Y = $buttonY
        $this._deleteButton.Width = 14
        $this._deleteButton.Height = 1
        $this._deleteButton.OnClick = {
            $dialogManager = $thisScreen.ServiceContainer?.GetService("DialogManager")
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dialogManager -and $dataManager -and $thisScreen._selectedTask) {
                $dialog = [TaskDeleteDialog]::new($thisScreen._selectedTask)
                $dialogManager.ShowDialog($dialog)
                
                if ($dialog.DialogResult -eq [DialogResult]::Yes) {
                    $dataManager.DeleteTask($thisScreen._selectedTask.Id)
                    $thisScreen._RefreshTasks()
                    $thisScreen._UpdateDisplay()
                    Write-Verbose "Task deleted: $($thisScreen._selectedTask.Title)"
                }
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._deleteButton)
        $currentX += $buttonSpacing + 2
        
        # Complete button
        $this._completeButton = [ButtonComponent]::new("CompleteButton")
        $this._completeButton.Text = "[C]omplete"
        $this._completeButton.X = $currentX
        $this._completeButton.Y = $buttonY
        $this._completeButton.Width = 12
        $this._completeButton.Height = 1
        $this._completeButton.OnClick = {
            $dataManager = $thisScreen.ServiceContainer?.GetService("DataManager")
            
            if ($dataManager -and $thisScreen._selectedTask) {
                $thisScreen._selectedTask.Complete()
                $dataManager.UpdateTask($thisScreen._selectedTask)
                $thisScreen._RefreshTasks()
                $thisScreen._UpdateDisplay()
                Write-Verbose "Task completed: $($thisScreen._selectedTask.Title)"
            }
        }.GetNewClosure()
        $this._mainPanel.AddChild($this._completeButton)
'@

# Replace the existing button creation code
$buttonPattern = "# New button[\s\S]*?`$this\._mainPanel\.AddChild\(`$this\._completeButton\)"
if ($screensContent -match $buttonPattern) {
    $screensContent = $screensContent -replace $buttonPattern, $crudImplementation
    Write-Host "  - Wired up CRUD button functionality" -ForegroundColor Green
}

# Add dialog manager to the required services
$taskListFieldsPattern = "(hidden \[Panel\] `$_statusBar)"
$dialogManagerField = @"
$1
    hidden [DialogManager] `$_dialogManager
"@

if ($screensContent -notmatch "_dialogManager") {
    $screensContent = $screensContent -replace $taskListFieldsPattern, $dialogManagerField
}

Set-Content $screensFile $screensContent -Encoding UTF8

# PART 3: Add task management actions to ActionService
Write-Host "`nPart 3: Adding task management actions..." -ForegroundColor Yellow

$servicesFile = "AllServices.ps1"
$servicesContent = Get-Content $servicesFile -Raw

# Add task actions
$taskActions = @'
        
        # Task management actions
        $this.RegisterAction("task.new", "New Task", "Tasks", {
            $navService = $global:ServiceContainer.GetService("NavigationService")
            $currentScreen = $navService?.CurrentScreen
            if ($currentScreen -is [TaskListScreen]) {
                $currentScreen._newButton.OnClick.Invoke()
            }
        })
        
        $this.RegisterAction("task.list", "View All Tasks", "Tasks", {
            $navService = $global:ServiceContainer.GetService("NavigationService")
            $taskScreen = [TaskListScreen]::new($global:ServiceContainer)
            $taskScreen.Initialize()
            $navService.NavigateTo($taskScreen)
        })
'@

# Add after theme picker action
$themeActionPattern = "(ui\.theme\.picker[^}]+\}[^)]*\))"
if ($servicesContent -match $themeActionPattern -and $servicesContent -notmatch "task\.new") {
    $servicesContent = $servicesContent -replace $themeActionPattern, "`$1$taskActions"
    Write-Host "  - Added task management actions" -ForegroundColor Green
}

Set-Content $servicesFile $servicesContent -Encoding UTF8

Write-Host "`nCRUD implementation complete!" -ForegroundColor Green
Write-Host "Task management features added:" -ForegroundColor Cyan
Write-Host "  - TaskDialog for creating/editing tasks" -ForegroundColor White
Write-Host "  - TaskDeleteDialog for delete confirmation" -ForegroundColor White
Write-Host "  - Fully functional CRUD buttons in TaskListScreen" -ForegroundColor White
Write-Host "  - Task actions in command palette" -ForegroundColor White
