# KanbanScreen - Three-column kanban task management
# Ctrl+Arrow keys move tasks between columns, standard navigation within columns

class KanbanScreen : Screen {
    [object]$DataService
    [object]$TodoColumn
    [object]$InProgressColumn
    [object]$DoneColumn
    [array]$Columns
    [int]$ActiveColumnIndex = 0
    [string]$CurrentProjectId = ""
    [array]$Projects
    [hashtable]$SelectedTask = $null
    [string]$StatusMessage = ""
    [int]$ColumnWidth = 23
    [int]$ColumnHeight = 20
    [int]$StartX = 3
    [int]$StartY = 4
    
    KanbanScreen() {
        $this.Title = "KANBAN BOARD"
        
        # Initialize data service
        try {
            $this.DataService = $global:UnifiedDataService
            
            $this.InitializeColumns()
            $this.LoadProjects()
            $this.BindKeys()
            $this.LoadTasks()
        }
        catch {
            Write-Host "KanbanScreen initialization error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
            # Don't throw - let the screen be created but mark it as inactive
            $this.Active = $false
        }
    }
    
    [void] InitializeColumns() {
        # Calculate column dimensions for standard 80-column terminal
        $terminalWidth = [Math]::Max(80, [Console]::WindowWidth)
        $availableWidth = $terminalWidth - 10  # Leave margins
        $this.ColumnWidth = [Math]::Floor($availableWidth / 3) - 1  # 3 columns with spacing
        $this.ColumnHeight = 20
        $this.StartX = 3
        $this.StartY = 4
        
        # Create three kanban columns
        $this.TodoColumn = [KanbanColumn]::new("TO DO", "Pending")
        $this.TodoColumn.X = $this.StartX
        $this.TodoColumn.Y = $this.StartY
        $this.TodoColumn.Width = $this.ColumnWidth
        $this.TodoColumn.Height = $this.ColumnHeight
        $self = $this
        $this.TodoColumn.OnTaskSelected = { param($task) if ($task -ne $null) { $self.OnTaskSelected($task) } }.GetNewClosure()
        $this.TodoColumn.OnTaskMoved = { param($task, $direction) if ($task -ne $null) { $self.OnTaskMoved($task, $direction) } }.GetNewClosure()
        
        $this.InProgressColumn = [KanbanColumn]::new("IN PROGRESS", "InProgress")
        $this.InProgressColumn.X = $this.StartX + $this.ColumnWidth + 1
        $this.InProgressColumn.Y = $this.StartY
        $this.InProgressColumn.Width = $this.ColumnWidth
        $this.InProgressColumn.Height = $this.ColumnHeight
        $this.InProgressColumn.OnTaskSelected = { param($task) if ($task -ne $null) { $self.OnTaskSelected($task) } }.GetNewClosure()
        $this.InProgressColumn.OnTaskMoved = { param($task, $direction) if ($task -ne $null) { $self.OnTaskMoved($task, $direction) } }.GetNewClosure()
        
        $this.DoneColumn = [KanbanColumn]::new("DONE", "Completed")
        $this.DoneColumn.X = $this.StartX + ($this.ColumnWidth + 1) * 2
        $this.DoneColumn.Y = $this.StartY
        $this.DoneColumn.Width = $this.ColumnWidth
        $this.DoneColumn.Height = $this.ColumnHeight
        $this.DoneColumn.OnTaskSelected = { param($task) if ($task -ne $null) { $self.OnTaskSelected($task) } }.GetNewClosure()
        $this.DoneColumn.OnTaskMoved = { param($task, $direction) if ($task -ne $null) { $self.OnTaskMoved($task, $direction) } }.GetNewClosure()
        
        # Store columns in array for easy iteration
        $this.Columns = @($this.TodoColumn, $this.InProgressColumn, $this.DoneColumn)
        
        # Set initial active column
        $this.SetActiveColumn(0)
    }
    
    # Override HandleInput to catch Ctrl+Arrow keys
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Handle Ctrl+Arrow keys for task movement
        if ($key.Modifiers -eq [ConsoleModifiers]::Control) {
            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    $this.MoveTaskLeft()
                    $this.NeedsRender = $true
                    return
                }
                ([ConsoleKey]::RightArrow) {
                    $this.MoveTaskRight()
                    $this.NeedsRender = $true
                    return
                }
            }
        }
        
        # Call base class for all other input
        ([Screen]$this).HandleInput($key)
    }
    
    [void] LoadProjects() {
        $this.Projects = $this.DataService.GetProjects()
        if ($this.Projects.Count -gt 0) {
            $this.CurrentProjectId = $this.Projects[0].ID
        }
    }
    
    [void] LoadTasks() {
        if ([string]::IsNullOrEmpty($this.CurrentProjectId)) {
            # No project selected, clear columns
            foreach ($column in $this.Columns) {
                $column.SetTasks(@())
            }
            return
        }
        
        # Load tasks for each status
        $todoTasks = $this.DataService.GetTasksByStatus("Pending") | Where-Object { $_.ProjectID -eq $this.CurrentProjectId }
        $inProgressTasks = $this.DataService.GetTasksByStatus("InProgress") | Where-Object { $_.ProjectID -eq $this.CurrentProjectId }
        $doneTasks = $this.DataService.GetTasksByStatus("Completed") | Where-Object { $_.ProjectID -eq $this.CurrentProjectId }
        
        # Organize tasks hierarchically (parents first, then their subtasks)
        $todoHierarchy = $this.BuildTaskHierarchy($todoTasks)
        $inProgressHierarchy = $this.BuildTaskHierarchy($inProgressTasks)
        $doneHierarchy = $this.BuildTaskHierarchy($doneTasks)
        
        $this.TodoColumn.SetTasks($todoHierarchy)
        $this.InProgressColumn.SetTasks($inProgressHierarchy)
        $this.DoneColumn.SetTasks($doneHierarchy)
        
        $this.UpdateStatusMessage()
    }
    
    # Build hierarchical task list (parents with their subtasks nested)
    [array] BuildTaskHierarchy([array]$tasks) {
        if (-not $tasks -or $tasks.Count -eq 0) { return @() }
        
        $hierarchy = @()
        $taskDict = @{}
        
        # Create lookup dictionary
        foreach ($task in $tasks) {
            $taskDict[$task.ID] = $task
            # Add nesting level for display
            $task | Add-Member -NotePropertyName "Level" -NotePropertyValue 0 -Force
        }
        
        # Find parent tasks (no ParentId or ParentId not in current status)
        $parentTasks = $tasks | Where-Object { -not $_.ParentId -or -not $taskDict.ContainsKey($_.ParentId) }
        
        foreach ($parentTask in $parentTasks) {
            $hierarchy += $parentTask
            
            # Add subtasks recursively
            if ($parentTask.SubtaskIds -and $parentTask.SubtaskIds.Count -gt 0) {
                $subtasks = $this.GetSubtasksRecursive($parentTask, $taskDict, 1)
                $hierarchy += $subtasks
            }
        }
        
        return $hierarchy
    }
    
    # Recursively get subtasks with proper nesting levels
    [array] GetSubtasksRecursive([hashtable]$parentTask, [hashtable]$taskDict, [int]$level) {
        $subtasks = @()
        
        if ($parentTask.SubtaskIds) {
            foreach ($subtaskId in $parentTask.SubtaskIds) {
                if ($taskDict.ContainsKey($subtaskId)) {
                    $subtask = $taskDict[$subtaskId]
                    $subtask.Level = $level
                    $subtasks += $subtask
                    
                    # Recursively add sub-subtasks
                    if ($subtask.SubtaskIds -and $subtask.SubtaskIds.Count -gt 0) {
                        $subsubtasks = $this.GetSubtasksRecursive($subtask, $taskDict, $level + 1)
                        $subtasks += $subsubtasks
                    }
                }
            }
        }
        
        return $subtasks
    }
    
    [void] BindKeys() {
        # Column navigation (using string keys to avoid ConsoleKey issues)
        $this.BindKey("Tab", { $this.NextColumn() })
        $this.BindKey("LeftArrow", { $this.HandleLeftArrow() })
        $this.BindKey("RightArrow", { $this.HandleRightArrow() })
        
        # Task navigation within column (Up/Down)
        $this.BindKey("UpArrow", { $this.GetActiveColumn().NavigateUp() })
        $this.BindKey("DownArrow", { $this.GetActiveColumn().NavigateDown() })
        
        # Task details
        $this.BindKey("Enter", { $this.EditTask() })
        
        # Task management
        $this.BindKey('n', { $this.NewTask() })
        $this.BindKey('s', { $this.NewSubtask() })  # Add subtask to selected task
        $this.BindKey('e', { $this.EditTask() })
        $this.BindKey('d', { $this.DeleteTask() })
        
        # Task movement between columns (using < and > keys)
        $this.BindKey(',', { $this.MoveTaskLeft() })   # < key (shift+comma)
        $this.BindKey('.', { $this.MoveTaskRight() })  # > key (shift+period)
        
        # Project switching
        $this.BindKey('p', { $this.SwitchProject() })
        
        # Refresh
        $this.BindKey("F5", { $this.LoadTasks() })
        
        # Exit
        $this.BindKey("Escape", { $this.Active = $false })
    }
    
    [void] SetActiveColumn([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Columns.Count) {
            # Deactivate all columns
            foreach ($column in $this.Columns) {
                $column.SetActive($false)
            }
            
            # Activate selected column
            $this.ActiveColumnIndex = $index
            $this.Columns[$index].SetActive($true)
            
            # Update selected task
            $this.OnTaskSelected($this.GetActiveColumn().GetSelectedTask())
            
            # Mark for re-render
            $this.NeedsRender = $true
        }
    }
    
    [object] GetActiveColumn() {
        return $this.Columns[$this.ActiveColumnIndex]
    }
    
    [void] NextColumn() {
        $nextIndex = ($this.ActiveColumnIndex + 1) % $this.Columns.Count
        $this.SetActiveColumn($nextIndex)
    }
    
    [void] PreviousColumn() {
        $prevIndex = ($this.ActiveColumnIndex - 1 + $this.Columns.Count) % $this.Columns.Count
        $this.SetActiveColumn($prevIndex)
    }
    
    [void] HandleLeftArrow() {
        # Check if this is being called from a key handler that might have Ctrl
        # For now, just handle as column navigation
        # TODO: Implement Ctrl+Left for task movement when we have access to key info
        $this.PreviousColumn()
    }
    
    [void] HandleRightArrow() {
        # Check if this is being called from a key handler that might have Ctrl
        # For now, just handle as column navigation
        # TODO: Implement Ctrl+Right for task movement when we have access to key info
        $this.NextColumn()
    }
    
    [void] OnTaskSelected([object]$task) {
        # Handle null tasks gracefully (task can be null or hashtable)
        $this.SelectedTask = $task
        $this.UpdateStatusMessage()
        $this.NeedsRender = $true
    }
    
    [void] OnTaskMoved([object]$task, [string]$direction) {
        # Handle null tasks gracefully
        if (-not $task) { return }
        
        if ($direction -eq "left") {
            $this.MoveTaskLeft()
        } elseif ($direction -eq "right") {
            $this.MoveTaskRight()
        }
    }
    
    [void] MoveTaskLeft() {
        $task = $this.GetActiveColumn().GetSelectedTask()
        if (-not $task) { return }
        
        $targetColumnIndex = $this.ActiveColumnIndex - 1
        if ($targetColumnIndex -lt 0) { return }  # Can't move further left
        
        $targetColumn = $this.Columns[$targetColumnIndex]
        $targetStatus = $targetColumn.Status
        
        # Update task status in data service
        if ($this.DataService.UpdateTaskStatus($task.ProjectID, $task.ID, $targetStatus)) {
            $this.StatusMessage = "Moved task to $($targetColumn.ColumnTitle)"
            $this.LoadTasks()  # Refresh all columns
        } else {
            $this.StatusMessage = "Failed to move task"
        }
    }
    
    [void] MoveTaskRight() {
        $task = $this.GetActiveColumn().GetSelectedTask()
        if (-not $task) { return }
        
        $targetColumnIndex = $this.ActiveColumnIndex + 1
        if ($targetColumnIndex -ge $this.Columns.Count) { return }  # Can't move further right
        
        $targetColumn = $this.Columns[$targetColumnIndex]
        $targetStatus = $targetColumn.Status
        
        # Update task status in data service
        if ($this.DataService.UpdateTaskStatus($task.ProjectID, $task.ID, $targetStatus)) {
            $this.StatusMessage = "Moved task to $($targetColumn.ColumnTitle)"
            $this.LoadTasks()  # Refresh all columns
        } else {
            $this.StatusMessage = "Failed to move task"
        }
    }
    
    [void] NewTask() {
        if ([string]::IsNullOrEmpty($this.CurrentProjectId)) {
            $this.StatusMessage = "No project selected. Press P to select a project."
            $this.NeedsRender = $true
            return
        }
        
        # Create a new task with basic defaults
        try {
            $taskHash = $this.DataService.AddTask($this.CurrentProjectId, "New Task", "")
            $taskObject = $this.ConvertToTaskObject($taskHash)
            
            # Create edit dialog for the new task
            $dialog = New-Object EditDialog -ArgumentList $this, $taskObject, $true
            $dialog | Add-Member -NotePropertyName ParentKanbanScreen -NotePropertyValue $this
            $dialog | Add-Member -NotePropertyName IsNewTask -NotePropertyValue $true
            
            # Push the dialog to screen manager
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
                $this.StatusMessage = "Opening task editor..."
            } else {
                $this.StatusMessage = "Error: ScreenManager not found"
            }
            $this.NeedsRender = $true
        }
        catch {
            $this.StatusMessage = "Failed to create task: $($_.Exception.Message) | Line: $($_.InvocationInfo.ScriptLineNumber)"
            $this.NeedsRender = $true
        }
    }
    
    [void] NewSubtask() {
        $parentTask = $this.GetSelectedTask()
        if (-not $parentTask) {
            $this.StatusMessage = "No parent task selected"
            $this.NeedsRender = $true
            return
        }
        
        if ([string]::IsNullOrEmpty($this.CurrentProjectId)) {
            $this.StatusMessage = "No project selected"
            $this.NeedsRender = $true
            return
        }
        
        try {
            # Create subtask with same status as parent (stays in same column)
            $subtaskHash = $this.DataService.AddTask($this.CurrentProjectId, "New Subtask", "")
            
            # Set up parent-child relationship
            $this.DataService.UpdateTask($this.CurrentProjectId, $subtaskHash.ID, @{
                ParentId = $parentTask.ID
                Status = $parentTask.Status  # Same column as parent
                KanbanColumn = $parentTask.KanbanColumn
            })
            
            # Add subtask to parent's subtask list (initialize if needed)
            $parentSubtaskIds = if ($parentTask.SubtaskIds) { 
                $parentTask.SubtaskIds 
            } else { 
                @() 
            }
            $parentSubtaskIds += $subtaskHash.ID
            
            $this.DataService.UpdateTask($this.CurrentProjectId, $parentTask.ID, @{
                SubtaskIds = $parentSubtaskIds
            })
            
            # Reload tasks to show hierarchy
            $this.LoadTasks()
            
            $subtaskObject = $this.ConvertToTaskObject($subtaskHash)
            
            # Create edit dialog for the new subtask
            $dialog = New-Object EditDialog -ArgumentList $this, $subtaskObject, $true
            $dialog | Add-Member -NotePropertyName ParentKanbanScreen -NotePropertyValue $this
            $dialog | Add-Member -NotePropertyName IsNewTask -NotePropertyValue $true
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
                $this.StatusMessage = "Opening subtask editor..."
            } else {
                $this.StatusMessage = "Error: ScreenManager not found"
            }
            $this.NeedsRender = $true
        }
        catch {
            $this.StatusMessage = "Failed to create subtask: $($_.Exception.Message)"
            $this.NeedsRender = $true
        }
    }
    
    [void] EditTask() {
        $taskHash = $this.GetSelectedTask()
        if (-not $taskHash) {
            $this.StatusMessage = "No task selected"
            $this.NeedsRender = $true
            return
        }
        
        # Create edit dialog
        try {
            $taskObject = $this.ConvertToTaskObject($taskHash)
            $dialog = New-Object EditDialog -ArgumentList $this, $taskObject, $false
            $dialog | Add-Member -NotePropertyName ParentKanbanScreen -NotePropertyValue $this
            
            if ($global:ScreenManager) {
                $global:ScreenManager.Push($dialog)
                $this.StatusMessage = "Opening task editor..."
            } else {
                $this.StatusMessage = "Error: ScreenManager not found"
            }
            $this.NeedsRender = $true
        }
        catch {
            $this.StatusMessage = "Error opening edit dialog: $($_.Exception.Message) | Line: $($_.InvocationInfo.ScriptLineNumber)"
            $this.NeedsRender = $true
        }
    }
    
    [void] DeleteTask() {
        $task = $this.GetSelectedTask()
        if (-not $task) {
            $this.StatusMessage = "No task selected"
            $this.NeedsRender = $true
            return
        }
        
        try {
            # Create confirmation dialog
            $dialog = New-Object DeleteConfirmDialog -ArgumentList $this, $task.Title
            $dialog | Add-Member -NotePropertyName TaskToDelete -NotePropertyValue $task
            $dialog | Add-Member -NotePropertyName ParentKanbanScreen -NotePropertyValue $this
            $global:ScreenManager.Push($dialog)
        }
        catch {
            $this.StatusMessage = "Error opening delete dialog: $($_.Exception.Message)"
            $this.NeedsRender = $true
        }
    }
    
    [void] SwitchProject() {
        if ($this.Projects.Count -eq 0) {
            $this.StatusMessage = "No projects available"
            return
        }
        
        # Simple project cycling for now
        $currentIndex = -1
        for ($i = 0; $i -lt $this.Projects.Count; $i++) {
            if ($this.Projects[$i].ID -eq $this.CurrentProjectId) {
                $currentIndex = $i
                break
            }
        }
        
        $nextIndex = ($currentIndex + 1) % $this.Projects.Count
        $this.CurrentProjectId = $this.Projects[$nextIndex].ID
        $this.StatusMessage = "Switched to project: $($this.Projects[$nextIndex].Name)"
        $this.LoadTasks()
    }
    
    [hashtable] GetSelectedTask() {
        return $this.GetActiveColumn().GetSelectedTask()
    }
    
    # Convert hashtable to Task object for dialogs
    [Task] ConvertToTaskObject([hashtable]$taskHash) {
        # Use the parameterless constructor
        $task = New-Object Task
        
        $task.Id = $taskHash.ID
        $task.Title = $taskHash.Title
        $task.Description = $taskHash.Description
        $task.Status = $taskHash.Status
        $task.Priority = $taskHash.Priority
        $task.Progress = $taskHash.Progress
        # Handle both ProjectID and ProjectId variations
        $task.ProjectId = if ($taskHash.ProjectID) { $taskHash.ProjectID } else { $this.CurrentProjectId }
        
        # Parse dates
        if ($taskHash.CreatedDate) {
            try { $task.CreatedDate = [datetime]::Parse($taskHash.CreatedDate) } catch { }
        }
        if ($taskHash.ModifiedDate) {
            try { $task.ModifiedDate = [datetime]::Parse($taskHash.ModifiedDate) } catch { }
        }
        if ($taskHash.DueDate) {
            try { $task.DueDate = [datetime]::Parse($taskHash.DueDate) } catch { }
        }
        
        $task.AssignedTo = $taskHash.AssignedTo
        
        return $task
    }
    
    # Convert Task object back to hashtable and update in data service
    [void] UpdateTaskFromObject([Task]$task) {
        $this.DataService.UpdateTask($task.ProjectId, $task.Id, @{
            Title = $task.Title
            Description = $task.Description
            Status = $task.Status
            Priority = $task.Priority
            Progress = $task.Progress
            DueDate = if ($task.DueDate -and $task.DueDate -ne [datetime]::MinValue) { $task.DueDate.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
            AssignedTo = $task.AssignedTo
        })
    }
    
    # Callback methods for dialogs
    [void] OnTaskUpdated([Task]$task) {
        # Update the task in the data service
        $this.UpdateTaskFromObject($task)
        # Refresh tasks display
        $this.LoadTasks()
        $this.StatusMessage = "Task updated: $($task.Title)"
        $this.NeedsRender = $true
    }
    
    [void] OnTaskDeleted([hashtable]$taskHash) {
        # Delete from data service
        $this.DataService.DeleteTask($taskHash.ProjectID, $taskHash.ID)
        # Refresh tasks display
        $this.LoadTasks()
        $this.StatusMessage = "Task deleted: $($taskHash.Title)"
        $this.NeedsRender = $true
    }
    
    [void] OnTaskCreated([Task]$task) {
        # Update the task in the data service (it was already created, just need to update with changes)
        $this.UpdateTaskFromObject($task)
        # Refresh tasks display
        $this.LoadTasks()
        $this.StatusMessage = "Task created: $($task.Title)"
        $this.NeedsRender = $true
    }
    
    [void] UpdateStatusMessage() {
        $stats = $this.DataService.GetStatistics()
        $projectName = if ($this.CurrentProjectId) {
            ($this.Projects | Where-Object { $_.ID -eq $this.CurrentProjectId }).Name
        } else {
            "No project"
        }
        
        $taskInfo = if ($this.SelectedTask) {
            " | Selected: $($this.SelectedTask.Title)"
        } else {
            ""
        }
        
        if ([string]::IsNullOrEmpty($this.StatusMessage)) {
            $this.StatusMessage = "Project: $projectName | Tasks: $($stats.TotalTasks)$taskInfo"
        }
    }
    
    [string] RenderContent() {
        # Clear screen first to avoid corruption
        $output = [VT]::Clear()
        
        # Title
        $output += [VT]::MoveTo(2, 1)
        $output += [VT]::TextBright() + $this.Title + [VT]::Reset()
        
        # Project info
        $projectName = if ($this.CurrentProjectId) {
            ($this.Projects | Where-Object { $_.ID -eq $this.CurrentProjectId }).Name
        } else {
            "No project selected"
        }
        
        $output += [VT]::MoveTo(2, 2)
        $output += [VT]::Text() + "Project: " + [VT]::Accent() + $projectName + [VT]::Reset()
        
        # Render all columns
        foreach ($column in $this.Columns) {
            $output += $column.Render()
        }
        
        # Status message
        $statusY = $this.StartY + $this.ColumnHeight + 2
        $output += [VT]::MoveTo(2, $statusY)
        $output += [VT]::Text() + $this.StatusMessage + [VT]::Reset()
        
        # Help text
        $helpY = $statusY + 1
        $output += [VT]::MoveTo(2, $helpY)
        $output += [VT]::TextDim() + "Navigation: ←→/Tab (columns) ↑↓ (tasks) | Move: Ctrl+←→ or ,. | n:New s:Subtask e:Edit d:Delete p:Project F5:Refresh Esc:Exit" + [VT]::Reset()
        
        return $output
    }
}