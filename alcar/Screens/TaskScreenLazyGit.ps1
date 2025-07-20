# TaskScreen - Lazygit-inspired design
# Clean multi-pane interface with context-sensitive navigation

class TaskScreenLazyGit : Screen {
    # Data
    [object]$TaskService
    [System.Collections.ArrayList]$AllTasks
    [System.Collections.ArrayList]$FilteredTasks
    [System.Collections.ArrayList]$Filters
    
    # UI State
    [int]$FilterIndex = 0
    [int]$TaskIndex = 0
    [string]$CurrentFilter = "All"
    [Task]$SelectedTask = $null
    [int]$CurrentPane = 0
    [int]$PaneCount = 3
    
    # Layout (lazygit style - no heavy borders)
    [int]$LeftPaneWidth = 20
    [int]$BottomHelpHeight = 3
    
    # Context-sensitive commands
    [hashtable]$ContextCommands = @{}
    
    TaskScreenLazyGit() {
        $this.Title = "TASKS"
        Write-Host "TaskScreenLazyGit constructor called" -ForegroundColor Yellow
        try {
            $this.Initialize()
            Write-Host "TaskScreenLazyGit initialized successfully" -ForegroundColor Green
        } catch {
            Write-Host "TaskScreenLazyGit initialization failed: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    
    [void] Initialize() {
        Write-Host "Initializing TaskScreenLazyGit..." -ForegroundColor Cyan
        
        # Get services
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        Write-Host "TaskService obtained" -ForegroundColor Cyan
        
        # Initialize data
        $this.AllTasks = [System.Collections.ArrayList]::new()
        $this.FilteredTasks = [System.Collections.ArrayList]::new()
        Write-Host "ArrayLists initialized" -ForegroundColor Cyan
        
        $this.InitializeFilters()
        Write-Host "Filters initialized" -ForegroundColor Cyan
        
        $this.LoadTasks()
        Write-Host "Tasks loaded: $($this.AllTasks.Count) total, $($this.FilteredTasks.Count) filtered" -ForegroundColor Cyan
        
        # Setup context commands
        $this.InitializeContextCommands()
        Write-Host "Context commands initialized" -ForegroundColor Cyan
        
        # Add custom key bindings (lazygit style)
        $this.BindCustomKeys()
        Write-Host "Key bindings set up" -ForegroundColor Cyan
    }
    
    [void] InitializeFilters() {
        $this.Filters = [System.Collections.ArrayList]@(
            @{Name = "All"; Count = 0; Icon = "○"},
            @{Name = "Pending"; Count = 0; Icon = "◐"},
            @{Name = "InProgress"; Count = 0; Icon = "◑"},
            @{Name = "Completed"; Count = 0; Icon = "●"},
            @{Name = "Overdue"; Count = 0; Icon = "⚠"}
        )
    }
    
    [void] InitializeContextCommands() {
        # Commands change based on current pane (lazygit style)
        $this.ContextCommands = @{
            0 = @{  # Filter pane
                "↑↓" = "navigate"
                "Enter" = "apply filter"
                "←" = "back"
            }
            1 = @{  # Task pane
                "↑↓" = "navigate"
                "Enter" = "edit task"
                "n" = "new task"
                "d" = "delete"
                "Space" = "toggle status"
                "←→" = "change pane"
            }
            2 = @{  # Detail pane
                "↑↓" = "scroll"
                "e" = "edit"
                "←" = "back to tasks"
            }
        }
    }
    
    [void] BindCustomKeys() {
        # Standard navigation keys
        $this.BindKey([ConsoleKey]::UpArrow, { $this.MoveUp() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.MoveDown() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.PreviousPane() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NextPane() })
        $this.BindKey([ConsoleKey]::Tab, { $this.NextPane() })
        $this.BindKey([ConsoleKey]::Enter, { $this.SelectItem() })
        $this.BindKey([ConsoleKey]::Escape, { $this.GoBack() })
        
        # Task-specific keys (lazygit style single letters)
        $this.BindKey('n', { $this.NewTask() })
        $this.BindKey('d', { $this.DeleteTask() })
        $this.BindKey('e', { $this.EditTask() })
        $this.BindKey(' ', { $this.ToggleTaskStatus() })  # Space bar
        $this.BindKey('r', { $this.RefreshTasks() })
        $this.BindKey('f', { $this.FocusFilterPane() })
        $this.BindKey('t', { $this.FocusTaskPane() })
        $this.BindKey('q', { $this.GoBack() })
    }
    
    [void] LoadTasks() {
        $this.AllTasks = $this.TaskService.GetAllTasks()
        $this.ApplyFilter()
        $this.UpdateFilterCounts()
    }
    
    [void] ApplyFilter() {
        $this.FilteredTasks.Clear()
        $filter = $this.Filters[$this.FilterIndex].Name
        
        foreach ($task in $this.AllTasks) {
            $include = $false
            
            switch ($filter) {
                "All" { $include = $true }
                "Pending" { $include = $task.Status -eq "Pending" }
                "InProgress" { $include = $task.Status -eq "InProgress" }
                "Completed" { $include = $task.Status -eq "Completed" }
                "Overdue" { $include = $task.IsOverdue() }
            }
            
            if ($include) {
                $this.FilteredTasks.Add($task) | Out-Null
            }
        }
        
        # Reset task selection
        $this.TaskIndex = 0
        $this.UpdateSelectedTask()
    }
    
    [void] UpdateFilterCounts() {
        foreach ($filter in $this.Filters) {
            $count = 0
            switch ($filter.Name) {
                "All" { $count = $this.AllTasks.Count }
                "Pending" { $count = ($this.AllTasks | Where-Object { $_.Status -eq "Pending" }).Count }
                "InProgress" { $count = ($this.AllTasks | Where-Object { $_.Status -eq "InProgress" }).Count }
                "Completed" { $count = ($this.AllTasks | Where-Object { $_.Status -eq "Completed" }).Count }
                "Overdue" { $count = ($this.AllTasks | Where-Object { $_.IsOverdue() }).Count }
            }
            $filter.Count = $count
        }
    }
    
    [void] UpdateSelectedTask() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.TaskIndex -ge 0 -and $this.TaskIndex -lt $this.FilteredTasks.Count) {
            $this.SelectedTask = $this.FilteredTasks[$this.TaskIndex]
        } else {
            $this.SelectedTask = $null
        }
    }
    
    # Navigation overrides
    [void] MoveUp() {
        switch ($this.CurrentPane) {
            0 {  # Filter pane
                if ($this.FilterIndex -gt 0) {
                    $this.FilterIndex--
                    $this.ApplyFilter()
                    $this.RequestRender()
                }
            }
            1 {  # Task pane
                if ($this.TaskIndex -gt 0) {
                    $this.TaskIndex--
                    $this.UpdateSelectedTask()
                    $this.RequestRender()
                }
            }
            2 {  # Detail pane - scroll up
                # TODO: Implement detail scrolling
            }
        }
    }
    
    [void] MoveDown() {
        switch ($this.CurrentPane) {
            0 {  # Filter pane
                if ($this.FilterIndex -lt $this.Filters.Count - 1) {
                    $this.FilterIndex++
                    $this.ApplyFilter()
                    $this.RequestRender()
                }
            }
            1 {  # Task pane
                if ($this.TaskIndex -lt $this.FilteredTasks.Count - 1) {
                    $this.TaskIndex++
                    $this.UpdateSelectedTask()
                    $this.RequestRender()
                }
            }
            2 {  # Detail pane - scroll down
                # TODO: Implement detail scrolling
            }
        }
    }
    
    [void] SelectItem() {
        switch ($this.CurrentPane) {
            0 {  # Filter pane - switch to task pane
                $this.CurrentPane = 1
                $this.RequestRender()
            }
            1 {  # Task pane - edit task
                $this.EditTask()
            }
            2 {  # Detail pane - edit task
                $this.EditTask()
            }
        }
    }
    
    [void] NextPane() {
        if ($this.PaneCount -gt 1) {
            $this.CurrentPane = ($this.CurrentPane + 1) % $this.PaneCount
            $this.RequestRender()
        }
    }
    
    [void] PreviousPane() {
        if ($this.PaneCount -gt 1) {
            $this.CurrentPane = ($this.CurrentPane - 1)
            if ($this.CurrentPane -lt 0) {
                $this.CurrentPane = $this.PaneCount - 1
            }
            $this.RequestRender()
        }
    }
    
    [void] GoBack() {
        $this.Active = $false
    }
    
    # Task operations
    [void] NewTask() {
        $newTask = $this.TaskService.AddTask("New Task")
        $dialog = New-Object EditDialog -ArgumentList $this, $newTask, $true
        $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
        $global:ScreenManager.Push($dialog)
    }
    
    [void] EditTask() {
        if ($this.SelectedTask) {
            $dialog = New-Object EditDialog -ArgumentList $this, $this.SelectedTask, $false
            $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] DeleteTask() {
        if ($this.SelectedTask) {
            # Simple confirmation
            $dialog = New-Object ConfirmDialog -ArgumentList $this, "Delete Task", "Delete '$($this.SelectedTask.Title)'?"
            $dialog | Add-Member -NotePropertyName TaskToDelete -NotePropertyValue $this.SelectedTask
            $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ToggleTaskStatus() {
        if ($this.SelectedTask) {
            switch ($this.SelectedTask.Status) {
                "Pending" { $this.SelectedTask.Status = "InProgress" }
                "InProgress" { $this.SelectedTask.Status = "Completed" }
                "Completed" { $this.SelectedTask.Status = "Pending" }
            }
            $this.TaskService.SaveTasks()
            $this.LoadTasks()
            $this.RequestRender()
        }
    }
    
    [void] RefreshTasks() {
        $this.LoadTasks()
        $this.RequestRender()
    }
    
    [void] FocusFilterPane() {
        $this.CurrentPane = 0
        $this.RequestRender()
    }
    
    [void] FocusTaskPane() {
        $this.CurrentPane = 1
        $this.RequestRender()
    }
    
    # Rendering (lazygit style - clean and minimal)
    [string] RenderContent() {
        $output = ""
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Clear screen
        $output += [VT]::Clear()
        
        # Header (minimal, lazygit style)
        $output += [VT]::MoveTo(1, 1)
        $output += [VT]::TextBright() + "Tasks" + [VT]::Reset()
        
        # Calculate layout
        $contentHeight = $height - $this.BottomHelpHeight - 2
        $taskPaneWidth = $width - $this.LeftPaneWidth - 1
        $detailPaneStart = $this.LeftPaneWidth + ($taskPaneWidth / 2) + 1
        $detailPaneWidth = $width - $detailPaneStart
        
        # Render filter pane (left)
        $output += $this.RenderFilterPane(1, 3, $this.LeftPaneWidth, $contentHeight)
        
        # Render task pane (middle)
        $output += $this.RenderTaskPane($this.LeftPaneWidth + 1, 3, [int]($taskPaneWidth / 2), $contentHeight)
        
        # Render detail pane (right)
        $output += $this.RenderDetailPane([int]$detailPaneStart, 3, [int]$detailPaneWidth, $contentHeight)
        
        # Render context help (bottom, lazygit style)
        $output += $this.RenderContextHelp($height - $this.BottomHelpHeight + 1)
        
        return $output
    }
    
    [string] RenderFilterPane([int]$x, [int]$y, [int]$width, [int]$height) {
        $output = ""
        $isActive = $this.CurrentPane -eq 0
        
        # Pane title
        $titleColor = if ($isActive) { [VT]::TextBright() } else { [VT]::TextDim() }
        $output += [VT]::MoveTo($x, $y - 1)
        $output += $titleColor + "Filters" + [VT]::Reset()
        
        # Render filters
        for ($i = 0; $i -lt $this.Filters.Count; $i++) {
            $filter = $this.Filters[$i]
            $isSelected = $isActive -and $i -eq $this.FilterIndex
            
            $output += [VT]::MoveTo($x, $y + $i)
            
            if ($isSelected) {
                $output += [VT]::TextBright() + [VT]::RGBBG(0, 64, 128) + " "
            } else {
                $output += " "
            }
            
            # Icon and name
            $text = "$($filter.Icon) $($filter.Name) ($($filter.Count))"
            $output += $text.PadRight($width - 2)
            
            if ($isSelected) {
                $output += " " + [VT]::Reset()
            } else {
                $output += [VT]::Reset()
            }
        }
        
        return $output
    }
    
    [string] RenderTaskPane([int]$x, [int]$y, [int]$width, [int]$height) {
        $output = ""
        $isActive = $this.CurrentPane -eq 1
        
        # Pane title
        $titleColor = if ($isActive) { [VT]::TextBright() } else { [VT]::TextDim() }
        $output += [VT]::MoveTo($x, $y - 1)
        $output += $titleColor + "Tasks ($($this.FilteredTasks.Count))" + [VT]::Reset()
        
        # Render tasks
        $maxTasks = [Math]::Min($height, $this.FilteredTasks.Count)
        for ($i = 0; $i -lt $maxTasks; $i++) {
            $task = $this.FilteredTasks[$i]
            $isSelected = $isActive -and $i -eq $this.TaskIndex
            
            $output += [VT]::MoveTo($x, $y + $i)
            
            if ($isSelected) {
                $output += [VT]::TextBright() + [VT]::RGBBG(0, 64, 128) + " "
            } else {
                $output += " "
            }
            
            # Task status icon and title
            $statusIcon = $task.GetStatusSymbol()
            $statusColor = $task.GetStatusColor()
            $text = "$statusIcon $($task.Title)"
            
            if ($task.IsOverdue()) {
                $text = "[!] $text"
                $statusColor = [VT]::Error()
            }
            
            if ($isSelected) {
                $output += $text.PadRight($width - 2)
                $output += " " + [VT]::Reset()
            } else {
                $output += $statusColor + $text.PadRight($width - 1) + [VT]::Reset()
            }
        }
        
        return $output
    }
    
    [string] RenderDetailPane([int]$x, [int]$y, [int]$width, [int]$height) {
        $output = ""
        $isActive = $this.CurrentPane -eq 2
        
        # Pane title
        $titleColor = if ($isActive) { [VT]::TextBright() } else { [VT]::TextDim() }
        $output += [VT]::MoveTo($x, $y - 1)
        $output += $titleColor + "Details" + [VT]::Reset()
        
        if ($this.SelectedTask) {
            $task = $this.SelectedTask
            $line = 0
            
            # Task title
            $output += [VT]::MoveTo($x, $y + $line)
            $output += [VT]::TextBright() + $task.Title + [VT]::Reset()
            $line += 2
            
            # Task details
            $details = @(
                "Status: $($task.GetStatusColor())$($task.Status)$([VT]::Reset())",
                "Priority: $($task.GetPriorityColor())$($task.Priority)$([VT]::Reset())",
                "Progress: $($task.Progress)%",
                "Created: $($task.CreatedDate.ToString('yyyy-MM-dd'))"
            )
            
            if ($task.DueDate -and $task.DueDate -ne [datetime]::MinValue) {
                $details += "Due: $($task.DueDate.ToString('yyyy-MM-dd'))"
            }
            
            if ($task.Description) {
                $details += ""
                $details += "Description:"
                $details += $task.Description
            }
            
            foreach ($detail in $details) {
                if ($line -lt $height) {
                    $output += [VT]::MoveTo($x, $y + $line)
                    $output += $detail
                    $line++
                }
            }
        } else {
            $output += [VT]::MoveTo($x, $y)
            $output += [VT]::TextDim() + "No task selected" + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] RenderContextHelp([int]$y) {
        $output = ""
        $commands = $this.ContextCommands[$this.CurrentPane]
        
        # Separator line
        $output += [VT]::MoveTo(1, $y - 1)
        $output += [VT]::TextDim() + ("─" * [Console]::WindowWidth) + [VT]::Reset()
        
        # Help text (lazygit style)
        $output += [VT]::MoveTo(1, $y)
        $helpText = ""
        
        foreach ($key in $commands.Keys) {
            $action = $commands[$key]
            $helpText += "[" + [VT]::TextBright() + $key + [VT]::Reset() + "] $action  "
        }
        
        $helpText += "[" + [VT]::TextBright() + "q" + [VT]::Reset() + "] quit"
        
        $output += $helpText
        
        return $output
    }
    
    # Callback for when dialogs complete
    [void] OnTaskUpdated() {
        $this.LoadTasks()
        $this.RequestRender()
    }
    
    [void] OnTaskDeleted() {
        $this.LoadTasks()
        $this.RequestRender()
    }
}