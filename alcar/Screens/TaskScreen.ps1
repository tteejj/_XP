# Task Management Screen - Refactored

class TaskScreen : Screen {
    # Layout
    [ThreePaneLayout]$Layout
    
    # Services
    hidden [TaskService]$TaskService
    hidden [ViewDefinitionService]$ViewService
    
    # Data
    [System.Collections.ArrayList]$Tasks
    [System.Collections.ArrayList]$FilteredTasks
    [System.Collections.ArrayList]$Filters
    
    # State
    [int]$FilterIndex = 0
    [int]$TaskIndex = 0
    [string]$CurrentFilter = "All"
    [bool]$ShowTree = $true
    
    # Inline edit
    [bool]$InlineEditMode = $false
    [Task]$EditingTask = $null
    [string]$EditBuffer = ""
    
    # Menu mode
    [bool]$MenuMode = $false
    [int]$MenuIndex = 0
    
    TaskScreen() {
        $this.Title = "TASK MANAGER"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Get services
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        $this.ViewService = $global:ServiceContainer.GetService("ViewDefinitionService")
        
        # Setup layout
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        $this.Layout = [ThreePaneLayout]::new($width, $height, 18, 35)
        $this.Layout.LeftPane.Title = "FILTERS"
        $this.Layout.MiddlePane.Title = "TASKS"
        $this.Layout.RightPane.Title = "DETAIL"
        
        # Initialize data
        $this.Tasks = [System.Collections.ArrayList]::new()
        $this.FilteredTasks = [System.Collections.ArrayList]::new()
        $this.InitializeFilters()
        $this.LoadTasks()
        $this.ApplyFilter()
        
        # Setup key bindings
        $this.InitializeKeyBindings()
        
        # Setup status bar
        $this.UpdateStatusBar()
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::Tab, { $this.Layout.FocusNext(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Enter, { $this.HandleEnter(); $this.RequestRender() })
        
        # Actions (case-sensitive)
        $this.BindKey('a', { $this.AddTask(); $this.RequestRender() })
        $this.BindKey('A', { $this.AddTaskFull(); $this.RequestRender() })
        $this.BindKey('s', { $this.AddSubtask(); $this.RequestRender() })
        $this.BindKey('d', { $this.DeleteTask(); $this.RequestRender() })
        $this.BindKey('e', { $this.EditTaskInline(); $this.RequestRender() })
        $this.BindKey('E', { $this.EditTaskDetails(); $this.RequestRender() })
        $this.BindKey(' ', { $this.ToggleStatus(); $this.RequestRender() })
        $this.BindKey('p', { $this.CyclePriority(); $this.RequestRender() })
        $this.BindKey('x', { $this.ExpandCollapseAll(); $this.RequestRender() })
        $this.BindKey('q', { $this.Active = $false })
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        if ($this.InlineEditMode) {
            $editType = if ($this.EditingTask.ParentId) { "SUBTASK" } else { "TASK" }
            $this.StatusBarItems.Add(@{
                Label = [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + 
                       " >>> EDITING $($editType): " + $this.EditBuffer + " <<< " + 
                       [VT]::Reset()
            }) | Out-Null
            $this.StatusBarItems.Add(@{Label = "[Enter]save [Esc]cancel"}) | Out-Null
        } elseif ($this.MenuMode) {
            # Menu mode - not implemented in refactor yet
            $this.StatusBarItems.Add(@{Label = "Menu Mode"}) | Out-Null
        } else {
            # Normal mode
            $this.AddStatusItem('a/A', 'add/full')
            $this.AddStatusItem('s', 'subtask')
            $this.AddStatusItem('d', 'delete')
            $this.AddStatusItem('e/E', 'edit/full')
            $this.AddStatusItem(' ', 'toggle')
            $this.AddStatusItem('p', 'priority')
            $this.AddStatusItem('x', 'expand')
            $this.AddStatusItem('q', 'quit')
            $this.StatusBarItems.Add(@{Label = "[Tab]switch"}) | Out-Null
        }
    }
    
    [void] InitializeFilters() {
        $this.Filters = [System.Collections.ArrayList]@(
            @{Name="All"; Count=0; Filter={$true}},
            @{Name="Today"; Count=0; Filter={$_.DueDate -and $_.DueDate.Date -eq [datetime]::Today}},
            @{Name="This Week"; Count=0; Filter={$_.DueDate -and $_.DueDate -ge [datetime]::Today -and $_.DueDate -le [datetime]::Today.AddDays(7)}},
            @{Name="Overdue"; Count=0; Filter={$_.IsOverdue()}},
            @{Name="────────────"; Count=0; Filter=$null},
            @{Name="Pending"; Count=0; Filter={$_.Status -eq "Pending"}},
            @{Name="In Progress"; Count=0; Filter={$_.Status -eq "InProgress"}},
            @{Name="Completed"; Count=0; Filter={$_.Status -eq "Completed"}}
        )
    }
    
    [void] LoadTasks() {
        # Load tasks from service
        if ($this.TaskService) {
            $allTasks = $this.TaskService.GetAllTasks()
            $this.Tasks.Clear()
            foreach ($task in $allTasks) {
                $this.Tasks.Add($task) | Out-Null
            }
        }
        
        # If no tasks exist, add some sample tasks
        if ($this.Tasks.Count -eq 0) {
            # Sample tasks with subtasks
            $loginBug = $this.TaskService.AddTask("Fix login bug")
            $loginBug.Status = "InProgress"
            $loginBug.Priority = "High"
            $loginBug.Progress = 75
            $loginBug.Description = "Users report intermittent login failures after the latest deployment."
            $loginBug.DueDate = [datetime]::Today
            $this.TaskService.UpdateTask($loginBug)
            
            # Add subtasks
            $sub1 = $this.TaskService.AddTask("Reproduce the issue locally")
            $sub1.Status = "Completed"
            $sub1.ParentId = $loginBug.Id
            $this.TaskService.UpdateTask($sub1)
            $loginBug.SubtaskIds.Add($sub1.Id) | Out-Null
            
            $sub2 = $this.TaskService.AddTask("Debug authentication flow")
            $sub2.Status = "InProgress"
            $sub2.ParentId = $loginBug.Id
            $this.TaskService.UpdateTask($sub2)
            $loginBug.SubtaskIds.Add($sub2.Id) | Out-Null
            
            # More sample tasks...
            $task2 = $this.TaskService.AddTask("Review PR #234")
            $task2.DueDate = [datetime]::Today.AddDays(-2)
            $this.TaskService.UpdateTask($task2)
            
            $task3 = $this.TaskService.AddTask("Update documentation")
            $task3.Priority = "Low"
            $this.TaskService.UpdateTask($task3)
            
            # Reload tasks after adding samples
            $this.LoadTasks()
        }
    }
    
    [string] RenderContent() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $output = ""
        
        # Clear background by drawing spaces everywhere
        for ($y = 1; $y -le $height; $y++) {
            $output += [VT]::MoveTo(1, $y)
            $output += " " * $width
        }
        
        # Update all panes first
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        # Render layout in one pass
        $output += $this.Layout.Render()
        
        return $output
    }
    
    # Override to use double buffering
    [void] RenderToBuffer([Buffer]$buffer) {
        # For now, fall back to string-based rendering
        # This ensures compatibility while providing the framework for optimization
        $content = $this.RenderContent()
        $statusBar = $this.RenderStatusBar()
        
        # Simple implementation - write the full screen
        $lines = ($content + $statusBar) -split "`n"
        $y = 0
        foreach ($line in $lines) {
            if ($y -lt $buffer.Height) {
                # Strip ANSI codes for now - proper parsing would be better
                $cleanLine = $line -replace '\x1b\[[0-9;]*m', ''
                for ($x = 0; $x -lt [Math]::Min($cleanLine.Length, $buffer.Width); $x++) {
                    $buffer.SetCell($x, $y, $cleanLine[$x], '#FFFFFF', '#000000')
                }
                $y++
            }
        }
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Handle inline edit mode first
        if ($this.InlineEditMode) {
            $this.HandleInlineEdit($key)
            $this.RequestRender()
            return
        }
        
        # Handle Ctrl for menu mode
        if ($key.Modifiers -eq [ConsoleModifiers]::Control) {
            $this.MenuMode = -not $this.MenuMode
            $this.UpdateStatusBar()
            $this.RequestRender()
            return
        }
        
        # Normal input handling
        ([Screen]$this).HandleInput($key)
    }
    
    [void] HandleInlineEdit([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Enter) {
                # Save edit
                $this.EditingTask.Title = $this.EditBuffer
                $this.TaskService.UpdateTask($this.EditingTask)
                $this.InlineEditMode = $false
                $this.EditingTask = $null
                $this.EditBuffer = ""
                $this.UpdateStatusBar()
                $this.RequestRender()
            }
            ([ConsoleKey]::Escape) {
                # Cancel edit
                $this.InlineEditMode = $false
                $this.EditingTask = $null
                $this.EditBuffer = ""
                $this.UpdateStatusBar()
                $this.RequestRender()
            }
            ([ConsoleKey]::Backspace) {
                if ($this.EditBuffer.Length -gt 0) {
                    $this.EditBuffer = $this.EditBuffer.Substring(0, $this.EditBuffer.Length - 1)
                    $this.UpdateStatusBar()
                    $this.RequestRender()
                }
            }
            default {
                # Add character if printable
                if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                    $key.KeyChar -eq ' ' -or [char]::IsPunctuation($key.KeyChar) -or
                    [char]::IsSymbol($key.KeyChar)) {
                    $this.EditBuffer += $key.KeyChar
                    $this.UpdateStatusBar()
                    $this.RequestRender()
                }
            }
        }
    }
    
    # Navigation methods
    [void] NavigateUp() {
        switch ($this.Layout.FocusedPane) {
            0 { # Filter pane
                if ($this.FilterIndex -gt 0) {
                    $this.FilterIndex--
                    if ($this.Filters[$this.FilterIndex].Name -like "───*") {
                        $this.FilterIndex--
                    }
                    $this.ApplyFilter()
                }
            }
            1 { # Task pane
                if ($this.TaskIndex -gt 0) {
                    $this.TaskIndex--
                }
            }
        }
    }
    
    [void] NavigateDown() {
        switch ($this.Layout.FocusedPane) {
            0 { # Filter pane
                if ($this.FilterIndex -lt $this.Filters.Count - 1) {
                    $this.FilterIndex++
                    if ($this.Filters[$this.FilterIndex].Name -like "───*") {
                        if ($this.FilterIndex -lt $this.Filters.Count - 1) {
                            $this.FilterIndex++
                        }
                    }
                    $this.ApplyFilter()
                }
            }
            1 { # Task pane
                if ($this.TaskIndex -lt $this.FilteredTasks.Count - 1) {
                    $this.TaskIndex++
                }
            }
        }
    }
    
    [void] NavigateLeft() {
        if ($this.Layout.FocusedPane -eq 1) {
            # Move focus to left pane
            $this.Layout.SetFocus(0)
        } elseif ($this.Layout.FocusedPane -eq 0) {
            # In left pane, go back to main menu
            $this.Active = $false
        }
    }
    
    [void] NavigateRight() {
        if ($this.Layout.FocusedPane -eq 0) {
            $this.Layout.SetFocus(1)
        }
    }
    
    [void] HandleEnter() {
        if ($this.Layout.FocusedPane -eq 0) {
            # Apply filter and move to task list
            $this.ApplyFilter()
            $this.Layout.SetFocus(1)
        } elseif ($this.Layout.FocusedPane -eq 1 -and $this.FilteredTasks.Count -gt 0) {
            # Toggle expand/collapse if task has children
            $task = $this.FilteredTasks[$this.TaskIndex]
            if ($task.SubtaskIds.Count -gt 0) {
                $task.IsExpanded = -not $task.IsExpanded
                $this.ApplyFilter()
                
                # Maintain selection
                for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
                    if ($this.FilteredTasks[$i].Id -eq $task.Id) {
                        $this.TaskIndex = $i
                        break
                    }
                }
            }
        }
    }
    
    # Action methods
    [void] AddTask() {
        $newTask = $this.TaskService.AddTask("")
        $this.Tasks.Add($newTask) | Out-Null
        $this.ApplyFilter()
        
        # Find and select
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            if ($this.FilteredTasks[$i].Id -eq $newTask.Id) {
                $this.TaskIndex = $i
                break
            }
        }
        
        # Enter inline edit
        $this.InlineEditMode = $true
        $this.EditingTask = $newTask
        $this.EditBuffer = ""
        $this.Layout.SetFocus(1)
        $this.UpdateStatusBar()
    }
    
    [void] AddTaskFull() {
        # Create new task and open full edit dialog
        $newTask = $this.TaskService.AddTask("New Task")
        $dialog = New-Object -TypeName "EditDialog" -ArgumentList $this, $newTask, $true
        
        # Store reference to task list for adding after dialog
        $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
        $dialog | Add-Member -NotePropertyName NewTask -NotePropertyValue $newTask
        
        # Push dialog to screen manager
        $global:ScreenManager.Push($dialog)
    }
    
    [void] AddSubtask() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $parentTask = $this.FilteredTasks[$this.TaskIndex]
            
            $subtask = New-Object -TypeName "Task" -ArgumentList ""
            $subtask.ParentId = $parentTask.Id
            $this.Tasks.Add($subtask) | Out-Null
            $parentTask.SubtaskIds.Add($subtask.Id) | Out-Null
            $parentTask.IsExpanded = $true
            
            $this.ApplyFilter()
            
            # Find and select
            for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
                if ($this.FilteredTasks[$i].Id -eq $subtask.Id) {
                    $this.TaskIndex = $i
                    break
                }
            }
            
            # Enter inline edit
            $this.InlineEditMode = $true
            $this.EditingTask = $subtask
            $this.EditBuffer = ""
            $this.UpdateStatusBar()
        }
    }
    
    [void] DeleteTask() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $task = $this.FilteredTasks[$this.TaskIndex]
            $dialog = New-Object -TypeName "DeleteConfirmDialog" -ArgumentList $this, $task.Title
            
            # Store reference to task for deletion after dialog
            $dialog | Add-Member -NotePropertyName TaskToDelete -NotePropertyValue $task
            $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
            
            # Push dialog to screen manager
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditTaskInline() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $this.InlineEditMode = $true
            $this.EditingTask = $this.FilteredTasks[$this.TaskIndex]
            $this.EditBuffer = $this.EditingTask.Title
            $this.UpdateStatusBar()
            $this.RequestRender()
        }
    }
    
    [void] EditTaskDetails() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $task = $this.FilteredTasks[$this.TaskIndex]
            $dialog = New-Object -TypeName "EditDialog" -ArgumentList $this, $task, $false
            
            # Store reference to parent for refresh after dialog
            $dialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this
            
            # Push dialog to screen manager
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] ToggleStatus() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $task = $this.FilteredTasks[$this.TaskIndex]
            switch ($task.Status) {
                "Pending" { $task.Status = "InProgress" }
                "InProgress" { $task.Status = "Completed" }
                "Completed" { $task.Status = "Pending" }
            }
            $task.Update()
        }
    }
    
    [void] CyclePriority() {
        if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
            $task = $this.FilteredTasks[$this.TaskIndex]
            switch ($task.Priority) {
                "Low" { $task.Priority = "Medium" }
                "Medium" { $task.Priority = "High" }
                "High" { $task.Priority = "Low" }
            }
            $task.Update()
        }
    }
    
    [void] UpdateMiddlePaneWithViewService() {
        # Use ViewDefinitionService for consistent formatting
        $view = $this.ViewService.GetView("TaskList")
        if (-not $view) { 
            # Fallback to standard rendering
            $this.UpdateMiddlePane()
            return 
        }
        
        # Headers from view definition
        $header = [VT]::TextDim() + " "
        foreach ($col in $view.Columns) {
            $header += $col.Name.PadRight($col.Width) + " "
        }
        $header += [VT]::Reset()
        $this.Layout.MiddlePane.Content.Add($header) | Out-Null
        
        $separatorWidth = [Math]::Max(10, $this.Layout.MiddlePane.Width - 2)
        $this.Layout.MiddlePane.Content.Add([VT]::TextDim() + ("─" * $separatorWidth) + [VT]::Reset()) | Out-Null
        
        # Render tasks using view definition
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            $task = $this.FilteredTasks[$i]
            $line = ""
            
            # Selection highlighting
            if ($i -eq $this.TaskIndex -and $this.Layout.FocusedPane -eq 1) {
                if ($this.InlineEditMode -and $task.Id -eq $this.EditingTask.Id) {
                    $line += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0)
                } else {
                    $line += [VT]::Selected()
                }
            }
            
            # Use view definition to format row
            $line += " " + $view.FormatRow($task)
            $line += [VT]::Reset()
            
            $this.Layout.MiddlePane.Content.Add($line) | Out-Null
        }
    }
    
    [void] ExpandCollapseAll() {
        $allExpanded = $true
        foreach ($task in $this.Tasks) {
            if ($task.SubtaskIds.Count -gt 0 -and -not $task.IsExpanded) {
                $allExpanded = $false
                break
            }
        }
        
        foreach ($task in $this.Tasks) {
            if ($task.SubtaskIds.Count -gt 0) {
                $task.IsExpanded = -not $allExpanded
            }
        }
        
        $this.ApplyFilter()
    }
    
    # Filter and tree methods
    [void] ApplyFilter() {
        $this.UpdateFilterCounts()
        $filter = $this.Filters[$this.FilterIndex]
        
        if ($filter.Filter) {
            $this.FilteredTasks = [System.Collections.ArrayList]@($this.Tasks | Where-Object $filter.Filter)
            $this.CurrentFilter = $filter.Name
        } else {
            $this.FilteredTasks = $this.Tasks
        }
        
        # Build tree if enabled
        if ($this.ShowTree) {
            $this.FilteredTasks = $this.BuildTreeView($this.FilteredTasks)
        }
        
        # Ensure valid index
        if ($this.TaskIndex -ge $this.FilteredTasks.Count) {
            $this.TaskIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
        }
    }
    
    [void] UpdateFilterCounts() {
        foreach ($filter in $this.Filters) {
            if ($filter.Filter) {
                $filter.Count = ($this.Tasks | Where-Object $filter.Filter).Count
            }
        }
    }
    
    [System.Collections.ArrayList] BuildTreeView([System.Collections.ArrayList]$tasks) {
        $tree = [System.Collections.ArrayList]::new()
        $taskDict = @{}
        
        foreach ($task in $tasks) {
            $taskDict[$task.Id] = $task
        }
        
        foreach ($task in $tasks) {
            if (-not $task.ParentId -or -not $taskDict.ContainsKey($task.ParentId)) {
                $task.Level = 0
                $tree.Add($task) | Out-Null
                if ($task.IsExpanded -and $task.SubtaskIds.Count -gt 0) {
                    $this.AddSubtasksToTree($tree, $task, $taskDict, 1)
                }
            }
        }
        
        return $tree
    }
    
    [void] AddSubtasksToTree([System.Collections.ArrayList]$tree, [Task]$parentTask, [hashtable]$taskDict, [int]$level) {
        foreach ($subtaskId in $parentTask.SubtaskIds) {
            if ($taskDict.ContainsKey($subtaskId)) {
                $subtask = $taskDict[$subtaskId]
                $subtask.Level = $level
                $tree.Add($subtask) | Out-Null
                
                if ($subtask.IsExpanded -and $subtask.SubtaskIds.Count -gt 0) {
                    $this.AddSubtasksToTree($tree, $subtask, $taskDict, $level + 1)
                }
            }
        }
    }
    
    # Pane update methods
    [void] UpdateLeftPane() {
        $this.Layout.LeftPane.Content.Clear()
        
        for ($i = 0; $i -lt $this.Filters.Count; $i++) {
            $filter = $this.Filters[$i]
            
            if ($filter.Name -like "───*") {
                $this.Layout.LeftPane.Content.Add([VT]::TextDim() + $filter.Name) | Out-Null
                continue
            }
            
            $line = ""
            if ($i -eq $this.FilterIndex -and $this.Layout.FocusedPane -eq 0) {
                $line += [VT]::Selected() + " > "
            } else {
                $line += "   "
            }
            
            $nameText = $filter.Name
            if ($filter.Count -gt 0) {
                $maxNameWidth = [Math]::Max(10, $this.Layout.LeftPane.Width - 8)
                if ($nameText.Length -gt $maxNameWidth) {
                    $nameText = $nameText.Substring(0, $maxNameWidth - 3) + "..."
                }
                $padding = [Math]::Max(0, $maxNameWidth - $nameText.Length)
                $line += $nameText + (" " * $padding) + [VT]::TextDim() + "($($filter.Count))"
            } else {
                $line += $nameText
            }
            
            $line += [VT]::Reset()
            $this.Layout.LeftPane.Content.Add($line) | Out-Null
        }
    }
    
    [void] UpdateMiddlePane() {
        $this.Layout.MiddlePane.Content.Clear()
        $this.Layout.MiddlePane.Title = "TASKS - $($this.CurrentFilter) ($($this.FilteredTasks.Count))"
        
        # Try to use ViewDefinitionService if available
        if ($this.ViewService) {
            $this.UpdateMiddlePaneWithViewService()
            return
        }
        
        # Calculate widths
        $titleWidth = $this.Layout.MiddlePane.Width - 25
        
        # Headers
        $header = [VT]::TextDim() + " S "
        $titlePadding = [Math]::Max(0, $titleWidth - 5)
        $header += "TITLE" + (" " * $titlePadding)
        $header += "PRI  PROG  DUE" + [VT]::Reset()
        $this.Layout.MiddlePane.Content.Add($header) | Out-Null
        $separatorWidth = [Math]::Max(10, $this.Layout.MiddlePane.Width - 2)
        $this.Layout.MiddlePane.Content.Add([VT]::TextDim() + ("─" * $separatorWidth) + [VT]::Reset()) | Out-Null
        
        # Tasks
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            $task = $this.FilteredTasks[$i]
            $line = ""
            
            # Selection/edit mode
            if ($i -eq $this.TaskIndex -and $this.Layout.FocusedPane -eq 1) {
                if ($this.InlineEditMode -and $task.Id -eq $this.EditingTask.Id) {
                    $line += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0)
                } else {
                    $line += [VT]::Selected()
                }
            }
            
            # Status
            $line += " " + $task.GetStatusColor() + $task.GetStatusSymbol() + "  "
            
            # Title with tree
            $indent = ""
            if ($this.ShowTree -and $task.Level -gt 0) {
                for ($j = 0; $j -lt $task.Level; $j++) {
                    $indent += "  "
                }
                if ($task.SubtaskIds.Count -gt 0) {
                    $indent += if ($task.IsExpanded) { "▼ " } else { "▶ " }
                } else {
                    $indent += "• "
                }
            } elseif ($this.ShowTree -and $task.SubtaskIds.Count -gt 0) {
                $indent = if ($task.IsExpanded) { "▼ " } else { "▶ " }
            }
            
            if ($this.InlineEditMode -and $task.Id -eq $this.EditingTask.Id) {
                $editText = $this.EditBuffer
                if ($editText -eq "") {
                    $editText = "_"
                }
                $displayText = "» " + $editText + " █"
                $fullText = $indent + $displayText
                $paddedText = $fullText.PadRight($titleWidth)
                $line += $paddedText + [VT]::Reset()
            } else {
                $titleText = $indent + $task.Title
                $title = [Measure]::Pad($titleText, $titleWidth, "Left")
                if ($task.IsOverdue()) {
                    $line += [VT]::Error() + $title
                } else {
                    $line += [VT]::TextBright() + $title
                }
            }
            
            # Priority
            $line += " " + $task.GetPriorityColor() + $task.GetPrioritySymbol() + "  "
            
            # Progress
            if ($task.Progress -gt 0) {
                $line += [VT]::Text() + $task.Progress.ToString().PadLeft(3) + "%"
            } else {
                $line += "    "
            }
            
            # Due date
            if ($task.DueDate -and $task.DueDate -ne [datetime]::MinValue) {
                $daysUntil = [int]($task.DueDate.Date - [datetime]::Today).TotalDays
                if ($daysUntil -eq 0) {
                    $line += [VT]::Warning() + " Today"
                } elseif ($daysUntil -lt 0) {
                    $line += [VT]::Error() + " $($daysUntil)d"
                } else {
                    $line += [VT]::Text() + " +$($daysUntil)d"
                }
            } else {
                $line += "      "
            }
            
            $line += [VT]::Reset()
            $this.Layout.MiddlePane.Content.Add($line) | Out-Null
        }
    }
    
    [void] UpdateRightPane() {
        $this.Layout.RightPane.Content.Clear()
        
        if ($this.FilteredTasks.Count -eq 0) {
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " No tasks") | Out-Null
            return
        }
        
        $task = $this.FilteredTasks[$this.TaskIndex]
        
        # Title
        $this.Layout.RightPane.Content.Add([VT]::TextBright() + " " + $task.Title) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " " + ("─" * ($this.Layout.RightPane.Width - 3))) | Out-Null
        $this.Layout.RightPane.Content.Add("") | Out-Null
        
        # Description
        if ($task.Description) {
            $words = $task.Description -split ' '
            $line = " "
            $maxWidth = $this.Layout.RightPane.Width - 3
            
            foreach ($word in $words) {
                if (($line + $word).Length -gt $maxWidth) {
                    $this.Layout.RightPane.Content.Add([VT]::Text() + $line) | Out-Null
                    $line = " $word"
                } else {
                    if ($line -eq " ") {
                        $line = " $word"
                    } else {
                        $line += " $word"
                    }
                }
            }
            if ($line.Trim()) {
                $this.Layout.RightPane.Content.Add([VT]::Text() + $line) | Out-Null
            }
            $this.Layout.RightPane.Content.Add("") | Out-Null
        }
        
        # Details
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Status: " + $task.GetStatusColor() + $task.Status) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Priority: " + $task.GetPriorityColor() + $task.Priority + " " + $task.GetPrioritySymbol()) | Out-Null
        
        if ($task.Progress -gt 0) {
            $bar = "█" * [int]($task.Progress / 10) + "░" * [int]((100 - $task.Progress) / 10)
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Progress: " + [VT]::Accent() + $bar + " " + $task.Progress + "%") | Out-Null
        }
        
        if ($task.DueDate -and $task.DueDate -ne [datetime]::MinValue) {
            $dueText = $task.DueDate.ToString("MMM d, yyyy")
            if ($task.IsOverdue()) {
                $daysOverdue = [int]([datetime]::Today - $task.DueDate.Date).TotalDays
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due: " + [VT]::Error() + $dueText + " ($daysOverdue days overdue)") | Out-Null
            } else {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due: " + [VT]::Text() + $dueText) | Out-Null
            }
        }
    }
}