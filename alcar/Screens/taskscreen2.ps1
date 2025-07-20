# Improved Task Management Screen

class TaskScreen {
    [ThreePaneLayout]$Layout
    [System.Collections.ArrayList]$Tasks
    [System.Collections.ArrayList]$Filters
    [int]$FilterIndex = 0
    [int]$TaskIndex = 0
    [string]$CurrentFilter = "All"
    [System.Collections.ArrayList]$FilteredTasks
    [bool]$MenuMode = $false
    [int]$MenuIndex = 0
    [System.Collections.ArrayList]$MenuItems
    [bool]$ShouldQuit = $false
    [bool]$EditMode = $false
    [Task]$EditingTask = $null
    [string]$EditBuffer = ""
    [bool]$ShowTree = $true  # Toggle between flat and tree view
    [EditScreen]$EditScreen = $null  # For detailed editing
    [bool]$ConfirmDelete = $false
    [Task]$TaskToDelete = $null
    
    TaskScreen() {
        # Initialize layout with better proportions
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Wider detail pane for better readability
        $leftWidth = 18
        $rightWidth = 35
        
        $this.Layout = [ThreePaneLayout]::new($width, $height, $leftWidth, $rightWidth)
        $this.Layout.LeftPane.Title = "FILTERS"
        $this.Layout.MiddlePane.Title = "TASKS"
        $this.Layout.RightPane.Title = "DETAIL"
        
        # Initialize data
        $this.Tasks = [System.Collections.ArrayList]::new()
        $this.FilteredTasks = [System.Collections.ArrayList]::new()
        $this.InitializeFilters()
        $this.InitializeMenu()
        $this.LoadTasks()
        $this.ApplyFilter()
    }
    
    [void] InitializeFilters() {
        $this.Filters = [System.Collections.ArrayList]@(
            @{Name="All"; Count=0; Filter={$true}},
            @{Name="Today"; Count=0; Filter={$_.DueDate -and $_.DueDate.Date -eq [datetime]::Today}},
            @{Name="This Week"; Count=0; Filter={$_.DueDate -and $_.DueDate -ge [datetime]::Today -and $_.DueDate -le [datetime]::Today.AddDays(7)}},
            @{Name="Overdue"; Count=0; Filter={$_.IsOverdue()}},
            @{Name="────────────"; Count=0; Filter=$null},  # Separator
            @{Name="Pending"; Count=0; Filter={$_.Status -eq "Pending"}},
            @{Name="In Progress"; Count=0; Filter={$_.Status -eq "InProgress"}},
            @{Name="Completed"; Count=0; Filter={$_.Status -eq "Completed"}}
        )
    }
    
    [void] InitializeMenu() {
        $this.MenuItems = [System.Collections.ArrayList]@(
            @{Key='a'; Label='add'; Action='Add'},
            @{Key='s'; Label='subtask'; Action='AddSubtask'},
            @{Key='d'; Label='delete'; Action='Delete'},
            @{Key='e'; Label='edit'; Action='Edit'},
            @{Key='E'; Label='details'; Action='EditDetails'},
            @{Key=' '; Label='toggle'; Action='Toggle'},
            @{Key='p'; Label='priority'; Action='Priority'},
            @{Key='x'; Label='expand'; Action='ExpandAll'},
            @{Key='q'; Label='quit'; Action='Quit'}
        )
    }
    
    [void] LoadTasks() {
        # Load sample tasks with subtasks
        $loginBug = [Task]::new("Fix login bug")
        $loginBug.Status = "InProgress"
        $loginBug.Priority = "High"
        $loginBug.Progress = 75
        $loginBug.Description = "Users report intermittent login failures after the latest deployment."
        $loginBug.DueDate = [datetime]::Today
        $this.Tasks.Add($loginBug) | Out-Null
        
        # Add subtasks for login bug
        $sub1 = [Task]::new("Reproduce the issue locally")
        $sub1.Status = "Completed"
        $sub1.ParentId = $loginBug.Id
        $this.Tasks.Add($sub1) | Out-Null
        $loginBug.SubtaskIds.Add($sub1.Id) | Out-Null
        
        $sub2 = [Task]::new("Debug authentication flow")
        $sub2.Status = "InProgress"
        $sub2.ParentId = $loginBug.Id
        $this.Tasks.Add($sub2) | Out-Null
        $loginBug.SubtaskIds.Add($sub2.Id) | Out-Null
        
        $sub3 = [Task]::new("Write unit tests")
        $sub3.Status = "Pending"
        $sub3.ParentId = $loginBug.Id
        $this.Tasks.Add($sub3) | Out-Null
        $loginBug.SubtaskIds.Add($sub3.Id) | Out-Null
        
        # PR Review task
        $prReview = [Task]::new("Review PR #234")
        $prReview.DueDate = [datetime]::Today.AddDays(-2)
        $this.Tasks.Add($prReview) | Out-Null
        
        # Documentation task with subtasks
        $docs = [Task]::new("Update documentation")
        $docs.Priority = "Low"
        $this.Tasks.Add($docs) | Out-Null
        
        $docSub1 = [Task]::new("Update API docs")
        $docSub1.ParentId = $docs.Id
        $this.Tasks.Add($docSub1) | Out-Null
        $docs.SubtaskIds.Add($docSub1.Id) | Out-Null
        
        $docSub2 = [Task]::new("Update user guide")
        $docSub2.ParentId = $docs.Id
        $this.Tasks.Add($docSub2) | Out-Null
        $docs.SubtaskIds.Add($docSub2.Id) | Out-Null
        
        # Simple tasks
        $this.Tasks.Add([Task]::new("Deploy to staging")) | Out-Null
        $this.Tasks[-1].Status = "Completed"
        
        $this.Tasks.Add([Task]::new("Test new API endpoint")) | Out-Null
        $this.Tasks[-1].DueDate = [datetime]::Today.AddDays(3)
    }
    
    [void] UpdateFilterCounts() {
        foreach ($filter in $this.Filters) {
            if ($filter.Filter) {
                $filter.Count = ($this.Tasks | Where-Object $filter.Filter).Count
            }
        }
    }
    
    [void] ApplyFilter() {
        $this.UpdateFilterCounts()
        $filter = $this.Filters[$this.FilterIndex]
        
        if ($filter.Filter) {
            $this.FilteredTasks = [System.Collections.ArrayList]@($this.Tasks | Where-Object $filter.Filter)
            $this.CurrentFilter = $filter.Name
        } else {
            $this.FilteredTasks = $this.Tasks
        }
        
        # Build tree structure if in tree mode
        if ($this.ShowTree) {
            $this.FilteredTasks = $this.BuildTreeView($this.FilteredTasks)
        }
        
        # Ensure task index is valid
        if ($this.TaskIndex -ge $this.FilteredTasks.Count) {
            $this.TaskIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
        }
    }
    
    [System.Collections.ArrayList] BuildTreeView([System.Collections.ArrayList]$tasks) {
        $tree = [System.Collections.ArrayList]::new()
        $taskDict = @{}
        
        # Build dictionary for quick lookup
        foreach ($task in $tasks) {
            $taskDict[$task.Id] = $task
        }
        
        # Find root tasks and build tree recursively
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
                # Ensure name + count fits in pane width
                $maxNameWidth = $this.Layout.LeftPane.Width - 8  # Leave room for selection indicator and count
                if ($nameText.Length -gt $maxNameWidth) {
                    $nameText = $nameText.Substring(0, $maxNameWidth - 3) + "..."
                }
                $padding = $maxNameWidth - $nameText.Length
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
        
        # Calculate column widths
        $statusWidth = 3
        $titleWidth = $this.Layout.MiddlePane.Width - 25  # Leave room for other columns
        
        # Column headers
        $header = [VT]::TextDim() + " S "
        $titlePadding = [Math]::Max(0, $titleWidth - 5)
        $header += "TITLE" + (" " * $titlePadding)
        $header += "PRI  PROG  DUE" + [VT]::Reset()
        $this.Layout.MiddlePane.Content.Add($header) | Out-Null
        $separatorWidth = [Math]::Max(10, $this.Layout.MiddlePane.Width - 2)
        $this.Layout.MiddlePane.Content.Add([VT]::TextDim() + ("─" * $separatorWidth) + [VT]::Reset()) | Out-Null
        
        # Task list
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            $task = $this.FilteredTasks[$i]
            $line = ""
            
            # Selection indicator
            if ($i -eq $this.TaskIndex -and $this.Layout.FocusedPane -eq 1) {
                if ($this.EditMode -and $task.Id -eq $this.EditingTask.Id) {
                    # Editing - use bright yellow background for entire line
                    $line += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0)
                } else {
                    $line += [VT]::Selected()
                }
            }
            
            # Status
            $line += " " + $task.GetStatusColor() + $task.GetStatusSymbol() + "  "
            
            # Title with tree indentation
            $indent = ""
            if ($this.ShowTree -and $task.Level -gt 0) {
                # Use string concatenation for indentation
                for ($j = 0; $j -lt $task.Level; $j++) {
                    $indent += "  "
                }
                # Add tree connector
                if ($task.SubtaskIds.Count -gt 0) {
                    $indent += if ($task.IsExpanded) { "▼ " } else { "▶ " }
                } else {
                    $indent += "• "
                }
            } elseif ($this.ShowTree -and $task.SubtaskIds.Count -gt 0) {
                # Root level with children
                $indent = if ($task.IsExpanded) { "▼ " } else { "▶ " }
            }
            
            if ($this.EditMode -and $task.Id -eq $this.EditingTask.Id) {
                # Show edit mode with VERY visible feedback
                $editText = $this.EditBuffer
                if ($editText -eq "") {
                    $editText = "_"  # Show placeholder for empty
                }
                
                # Add cursor
                $displayText = "» " + $editText + " █"
                
                # Ensure we don't exceed title width
                $maxLen = $titleWidth - $indent.Length - 4  # Account for markers
                if ($displayText.Length -gt $maxLen) {
                    $displayText = $displayText.Substring(0, $maxLen - 1) + "…"
                }
                
                # Build the full line with indent
                $fullText = $indent + $displayText
                $paddedText = $fullText.PadRight($titleWidth)
                
                # Apply BRIGHT yellow background for edit mode
                $line += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + $paddedText + [VT]::Reset()
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
            
            # Due date (only if set)
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
                $line += "      "  # Empty space for alignment
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
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " " + "─" * ($this.Layout.RightPane.Width - 3)) | Out-Null
        $this.Layout.RightPane.Content.Add("") | Out-Null
        
        # Description (word wrap)
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
        
        # Status
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Status: " + $task.GetStatusColor() + $task.Status) | Out-Null
        
        # Priority
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Priority: " + $task.GetPriorityColor() + $task.Priority + " " + $task.GetPrioritySymbol()) | Out-Null
        
        # Progress
        if ($task.Progress -gt 0) {
            $bar = "█" * [int]($task.Progress / 10) + "░" * [int]((100 - $task.Progress) / 10)
            $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Progress: " + [VT]::Accent() + $bar + " " + $task.Progress + "%") | Out-Null
        }
        
        # Due date
        if ($task.DueDate -and $task.DueDate -ne [datetime]::MinValue) {
            $dueText = $task.DueDate.ToString("MMM d, yyyy")
            if ($task.IsOverdue()) {
                $daysOverdue = [int]([datetime]::Today - $task.DueDate.Date).TotalDays
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due: " + [VT]::Error() + $dueText + " ($daysOverdue days overdue)") | Out-Null
            } else {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due: " + [VT]::Text() + $dueText) | Out-Null
            }
        }
        
        # Actions
        $this.Layout.RightPane.Content.Add("") | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::TextDim() + " " + "─" * ($this.Layout.RightPane.Width - 3)) | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::Text() + " [Enter] edit") | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::Text() + " [t] log time") | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::Text() + " [s] change status") | Out-Null
        $this.Layout.RightPane.Content.Add([VT]::Text() + " [p] change priority") | Out-Null
    }
    
    [void] Render() {
        # Show edit screen if active
        if ($this.EditScreen) {
            $this.EditScreen.Render()
            return
        }
        
        # Show delete confirmation if active
        if ($this.ConfirmDelete -and $this.TaskToDelete) {
            $this.RenderDeleteConfirmation()
            return
        }
        
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        $output = $this.Layout.Render()
        
        # Build status bar with menu highlighting
        $statusText = ""
        if ($this.EditMode) {
            # Edit mode status - VERY VISIBLE
            $editType = if ($this.EditingTask.ParentId) { "SUBTASK" } else { "TASK" }
            $statusText = [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + " >>> EDITING $($editType): " + $this.EditBuffer + " <<< " + [VT]::Reset() + 
                         [VT]::TextBright() + " [Enter]save [Esc]cancel" + [VT]::Reset()
        } elseif ($this.MenuMode) {
            # Show menu with selection
            for ($i = 0; $i -lt $this.MenuItems.Count; $i++) {
                $item = $this.MenuItems[$i]
                if ($i -eq $this.MenuIndex) {
                    $statusText += [VT]::Selected() + " [$($item.Key)]$($item.Label) " + [VT]::Reset()
                } else {
                    $statusText += " [$($item.Key)]$($item.Label) "
                }
            }
            $statusText += [VT]::TextDim() + " [Ctrl]exit menu" + [VT]::Reset()
        } else {
            # Normal status
            foreach ($item in $this.MenuItems) {
                $statusText += "[$($item.Key)]$($item.Label) "
            }
            $statusText += "[Tab]switch [Ctrl]menu"
        }
        
        $output += $this.Layout.DrawStatusBar($statusText)
        
        [Console]::Write($output)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Handle edit screen first
        if ($this.EditScreen) {
            $this.EditScreen.HandleInput($key)
            
            # Check if edit screen is done
            if ($this.EditScreen.ShouldSave -or $this.EditScreen.ShouldCancel) {
                if ($this.EditScreen.ShouldCancel -and $this.EditScreen.IsNew) {
                    # Remove the new task if cancelled
                    $this.Tasks.Remove($this.EditScreen.Task)
                }
                if ($this.EditScreen.ShouldSave -and $this.EditScreen.IsNew) {
                    # For new tasks, refresh the filter
                    $this.ApplyFilter()
                }
                $this.EditScreen = $null
            }
            return
        }
        
        # Handle delete confirmation
        if ($this.ConfirmDelete) {
            switch ($key.KeyChar) {
                'y' {
                    # Confirm delete
                    $this.Tasks.Remove($this.TaskToDelete)
                    $this.ApplyFilter()
                    if ($this.TaskIndex -ge $this.FilteredTasks.Count -and $this.TaskIndex -gt 0) {
                        $this.TaskIndex--
                    }
                    $this.ConfirmDelete = $false
                    $this.TaskToDelete = $null
                }
                'n' {
                    # Cancel delete
                    $this.ConfirmDelete = $false
                    $this.TaskToDelete = $null
                }
            }
            return
        }
        
        # Handle edit mode
        if ($this.EditMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    # Save edit
                    $this.EditingTask.Title = $this.EditBuffer
                    $this.EditingTask.Update()
                    $this.EditMode = $false
                    $this.EditingTask = $null
                    $this.EditBuffer = ""
                    return
                }
                ([ConsoleKey]::Escape) {
                    # Cancel edit
                    $this.EditMode = $false
                    $this.EditingTask = $null
                    $this.EditBuffer = ""
                    return
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.EditBuffer.Length -gt 0) {
                        $this.EditBuffer = $this.EditBuffer.Substring(0, $this.EditBuffer.Length - 1)
                    }
                    return
                }
                default {
                    # Add character if printable
                    if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                        $key.KeyChar -eq ' ' -or [char]::IsPunctuation($key.KeyChar) -or
                        [char]::IsSymbol($key.KeyChar)) {
                        $this.EditBuffer += $key.KeyChar
                    }
                    return
                }
            }
        }
        
        # Simple Ctrl detection - any key with Ctrl modifier toggles menu
        if ($key.Modifiers -eq [ConsoleModifiers]::Control) {
            $this.MenuMode = -not $this.MenuMode
            if ($this.MenuMode) {
                $this.MenuIndex = 0  # Reset to first item
            }
            return
        }
        
        # Handle menu mode navigation
        if ($this.MenuMode) {
            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($this.MenuIndex -gt 0) {
                        $this.MenuIndex--
                    }
                    return
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.MenuIndex -lt $this.MenuItems.Count - 1) {
                        $this.MenuIndex++
                    }
                    return
                }
                ([ConsoleKey]::Enter) {
                    # Execute menu action
                    $this.ExecuteMenuAction($this.MenuItems[$this.MenuIndex].Action)
                    $this.MenuMode = $false
                    return
                }
                ([ConsoleKey]::Escape) {
                    $this.MenuMode = $false
                    return
                }
            }
            
            # Also allow direct key press in menu mode
            foreach ($item in $this.MenuItems) {
                if ($key.KeyChar -ceq $item.Key) {
                    $this.ExecuteMenuAction($item.Action)
                    $this.MenuMode = $false
                    return
                }
            }
            return
        }
        
        # Normal mode navigation
        switch ($key.Key) {
            ([ConsoleKey]::Tab) {
                # Cycle between interactive panes only
                $this.Layout.FocusNext()
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this.Layout.FocusedPane -eq 1) {
                    $this.Layout.SetFocus(0)
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.Layout.FocusedPane -eq 0) {
                    $this.Layout.SetFocus(1)
                }
            }
            ([ConsoleKey]::UpArrow) {
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
            ([ConsoleKey]::DownArrow) {
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
            ([ConsoleKey]::Enter) {
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
                        
                        # Maintain selection on the same task
                        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
                            if ($this.FilteredTasks[$i].Id -eq $task.Id) {
                                $this.TaskIndex = $i
                                break
                            }
                        }
                    }
                }
            }
        }
        
        # Handle character keys in normal mode
        if (-not $this.MenuMode) {
            foreach ($item in $this.MenuItems) {
                # Case-sensitive comparison for menu items
                if ($key.KeyChar -ceq $item.Key) {
                    $this.ExecuteMenuAction($item.Action)
                    return
                }
            }
        }
    }
    
    [void] ExecuteMenuAction([string]$action) {
        switch ($action) {
            'Toggle' {
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
            'ExpandAll' {
                # Toggle expand/collapse all
                $allExpanded = $true
                foreach ($task in $this.Tasks) {
                    if ($task.SubtaskIds.Count -gt 0 -and -not $task.IsExpanded) {
                        $allExpanded = $false
                        break
                    }
                }
                
                # Set opposite state for all
                foreach ($task in $this.Tasks) {
                    if ($task.SubtaskIds.Count -gt 0) {
                        $task.IsExpanded = -not $allExpanded
                    }
                }
                
                $this.ApplyFilter()
            }
            'Priority' {
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
            'Add' {
                # Create new task with inline edit (same as before)
                $newTask = [Task]::new("")
                $this.Tasks.Add($newTask) | Out-Null
                $this.ApplyFilter()
                
                # Find and select the new task
                for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
                    if ($this.FilteredTasks[$i].Id -eq $newTask.Id) {
                        $this.TaskIndex = $i
                        break
                    }
                }
                
                # Enter edit mode with empty buffer
                $this.EditMode = $true
                $this.EditingTask = $newTask
                $this.EditBuffer = ""
                
                # Make sure we're on the task pane
                $this.Layout.SetFocus(1)
            }
            'AddSubtask' {
                if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
                    $parentTask = $this.FilteredTasks[$this.TaskIndex]
                    $this.AddSubtask($parentTask)
                }
            }
            'Delete' {
                if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
                    $this.ConfirmDelete = $true
                    $this.TaskToDelete = $this.FilteredTasks[$this.TaskIndex]
                    # Force immediate re-render to show dialog
                    return
                }
            }
            'Edit' {
                if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
                    $this.EditMode = $true
                    $this.EditingTask = $this.FilteredTasks[$this.TaskIndex]
                    $this.EditBuffer = $this.EditingTask.Title
                }
            }
            'EditDetails' {
                if ($this.FilteredTasks.Count -gt 0 -and $this.Layout.FocusedPane -eq 1) {
                    $task = $this.FilteredTasks[$this.TaskIndex]
                    $this.EditScreen = [EditScreen]::new($task, $false)
                }
            }
            'Search' {
                # TODO: Implement search
            }
            'Quit' {
                $this.ShouldQuit = $true
            }
        }
    }
    
    # Removed AddTask method - now inline in ExecuteMenuAction
    
    [void] AddSubtask([Task]$parentTask) {
        # Create new subtask
        $subtask = [Task]::new("")
        $subtask.ParentId = $parentTask.Id
        
        # Add to tasks collection
        $this.Tasks.Add($subtask) | Out-Null
        
        # Add to parent's subtask list
        $parentTask.SubtaskIds.Add($subtask.Id) | Out-Null
        
        # Ensure parent is expanded
        $parentTask.IsExpanded = $true
        
        # Refresh view
        $this.ApplyFilter()
        
        # Find and select the new subtask
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            if ($this.FilteredTasks[$i].Id -eq $subtask.Id) {
                $this.TaskIndex = $i
                break
            }
        }
        
        # Enter edit mode
        $this.EditMode = $true
        $this.EditingTask = $subtask
        $this.EditBuffer = ""
        
        # Make sure we're on the task pane
        $this.Layout.SetFocus(1)
    }
    
    [void] RenderDeleteConfirmation() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Clear and draw main screen first
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        $output = $this.Layout.Render()
        [Console]::Write($output)
        
        # Draw confirmation dialog over it
        $dialogWidth = 50
        $dialogHeight = 7
        $dialogX = [int](($width - $dialogWidth) / 2)
        $dialogY = [int](($height - $dialogHeight) / 2)
        
        # Draw dialog box
        $dialog = [VT]::MoveTo($dialogX, $dialogY)
        $dialog += [VT]::RGBBG(255, 0, 0) + [VT]::White()
        $dialog += [VT]::TL() + [VT]::H() * ($dialogWidth - 2) + [VT]::TR()
        
        # Title
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 1)
        $dialog += [VT]::V() + " DELETE CONFIRMATION".PadRight($dialogWidth - 2) + [VT]::V()
        
        # Task name
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 2)
        $taskName = $this.TaskToDelete.Title
        if ($taskName.Length -gt $dialogWidth - 4) {
            $taskName = $taskName.Substring(0, $dialogWidth - 7) + "..."
        }
        $dialog += [VT]::V() + " Delete: $taskName".PadRight($dialogWidth - 2) + [VT]::V()
        
        # Warning
        $warning = "This cannot be undone!"
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 3)
        $dialog += [VT]::V() + " $warning".PadRight($dialogWidth - 2) + [VT]::V()
        
        # Prompt
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 4)
        $dialog += [VT]::V() + " ".PadRight($dialogWidth - 2) + [VT]::V()
        
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 5)
        $dialog += [VT]::V() + " [Y]es, delete   [N]o, cancel".PadRight($dialogWidth - 2) + [VT]::V()
        
        # Bottom border
        $dialog += [VT]::MoveTo($dialogX, $dialogY + 6)
        $dialog += [VT]::BL() + [VT]::H() * ($dialogWidth - 2) + [VT]::BR()
        
        $dialog += [VT]::Reset()
        [Console]::Write($dialog)
    }
    
    # Buffer-based render - zero string allocation
    [void] RenderToBuffer([Buffer]$buffer) {
        # Clear background
        $normalBG = "#1E1E23"
        $normalFG = "#C8C8C8"
        for ($y = 0; $y -lt $buffer.Height; $y++) {
            for ($x = 0; $x -lt $buffer.Width; $x++) {
                $buffer.SetCell($x, $y, ' ', $normalFG, $normalBG)
            }
        }
        
        # Legacy fallback - this file is not a proper Screen class
        $this.Render()
    }
}