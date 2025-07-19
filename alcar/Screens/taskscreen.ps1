# Task Management Screen with Three-Pane Layout

class TaskScreen {
    [ThreePaneLayout]$Layout
    [System.Collections.ArrayList]$Tasks
    [System.Collections.ArrayList]$Filters
    [int]$FilterIndex = 0
    [int]$TaskIndex = 0
    [string]$CurrentFilter = "All"
    [System.Collections.ArrayList]$FilteredTasks
    
    TaskScreen() {
        # Initialize layout with perfect column alignment
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Calculate pane widths for perfect alignment
        $leftWidth = 20
        $rightWidth = 30
        $middleWidth = $width - $leftWidth - $rightWidth
        
        $this.Layout = [ThreePaneLayout]::new($width, $height, $leftWidth, $middleWidth)
        $this.Layout.LeftPane.Title = "FILTERS"
        $this.Layout.MiddlePane.Title = "TASKS"
        $this.Layout.RightPane.Title = "DETAIL"
        
        # Initialize data
        $this.Tasks = [System.Collections.ArrayList]::new()
        $this.FilteredTasks = [System.Collections.ArrayList]::new()
        $this.InitializeFilters()
        $this.LoadTasks()
        $this.ApplyFilter()
    }
    
    [void] InitializeFilters() {
        $this.Filters = [System.Collections.ArrayList]@(
            @{Name="All"; Count=0; Filter={$true}},
            @{Name="Today"; Count=0; Filter={$_.DueDate.Date -eq [datetime]::Today}},
            @{Name="This Week"; Count=0; Filter={$_.DueDate -ge [datetime]::Today -and $_.DueDate -le [datetime]::Today.AddDays(7)}},
            @{Name="Overdue"; Count=0; Filter={$_.IsOverdue()}},
            @{Name="──────────"; Count=0; Filter=$null},  # Separator
            @{Name="Pending"; Count=0; Filter={$_.Status -eq "Pending"}},
            @{Name="In Progress"; Count=0; Filter={$_.Status -eq "InProgress"}},
            @{Name="Completed"; Count=0; Filter={$_.Status -eq "Completed"}}
        )
    }
    
    [void] LoadTasks() {
        # Load sample tasks for now
        $this.Tasks.Add([Task]::new("Fix login bug")) | Out-Null
        $this.Tasks[0].Status = "InProgress"
        $this.Tasks[0].Priority = "High"
        $this.Tasks[0].Progress = 75
        $this.Tasks[0].Description = "Users report intermittent login failures after the latest deployment."
        $this.Tasks[0].DueDate = [datetime]::Today
        
        $this.Tasks.Add([Task]::new("Review PR #234")) | Out-Null
        $this.Tasks[1].DueDate = [datetime]::Today.AddDays(-2)
        
        $this.Tasks.Add([Task]::new("Update documentation")) | Out-Null
        $this.Tasks[2].Priority = "Low"
        
        $this.Tasks.Add([Task]::new("Deploy to staging")) | Out-Null
        $this.Tasks[3].Status = "Completed"
        
        $this.Tasks.Add([Task]::new("Test new API endpoint")) | Out-Null
        $this.Tasks[4].DueDate = [datetime]::Today.AddDays(3)
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
        
        # Ensure task index is valid
        if ($this.TaskIndex -ge $this.FilteredTasks.Count) {
            $this.TaskIndex = [Math]::Max(0, $this.FilteredTasks.Count - 1)
        }
    }
    
    [void] UpdateLeftPane() {
        $this.Layout.LeftPane.Content.Clear()
        
        for ($i = 0; $i -lt $this.Filters.Count; $i++) {
            $filter = $this.Filters[$i]
            
            if ($filter.Name -eq "──────────") {
                $this.Layout.LeftPane.Content.Add([VT]::TextDim() + "─" * 18) | Out-Null
                continue
            }
            
            $line = ""
            if ($i -eq $this.FilterIndex -and $this.Layout.FocusedPane -eq 0) {
                $line += [VT]::Selected() + " > "
            } else {
                $line += "   "
            }
            
            $line += $filter.Name
            if ($filter.Count -gt 0) {
                $countText = " ($($filter.Count))"
                $padding = 15 - $filter.Name.Length
                if ($padding -gt 0) {
                    $line += " " * $padding
                }
                $line += [VT]::TextDim() + $countText
            }
            
            $line += [VT]::Reset()
            $this.Layout.LeftPane.Content.Add($line) | Out-Null
        }
    }
    
    [void] UpdateMiddlePane() {
        $this.Layout.MiddlePane.Content.Clear()
        $this.Layout.MiddlePane.Title = "TASKS - $($this.CurrentFilter) ($($this.FilteredTasks.Count))"
        
        # Column headers
        $header = [VT]::TextDim() + " S  TITLE" + " " * 20 + "PRI  PROG  DUE" + [VT]::Reset()
        $this.Layout.MiddlePane.Content.Add($header) | Out-Null
        $this.Layout.MiddlePane.Content.Add([VT]::TextDim() + "─" * ($this.Layout.MiddlePane.Width - 2) + [VT]::Reset()) | Out-Null
        
        # Task list
        for ($i = 0; $i -lt $this.FilteredTasks.Count; $i++) {
            $task = $this.FilteredTasks[$i]
            $line = ""
            
            # Selection indicator
            if ($i -eq $this.TaskIndex -and $this.Layout.FocusedPane -eq 1) {
                $line += [VT]::Selected()
            }
            
            # Status
            $line += " " + $task.GetStatusColor() + $task.GetStatusSymbol() + "  "
            
            # Title (truncated to fit)
            $titleWidth = $this.Layout.MiddlePane.Width - 20
            $title = [Measure]::Pad($task.Title, $titleWidth, "Left")
            if ($task.IsOverdue()) {
                $line += [VT]::Error() + $title
            } else {
                $line += [VT]::TextBright() + $title
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
            if ($task.DueDate) {
                $daysUntil = ($task.DueDate.Date - [datetime]::Today).Days
                if ($daysUntil -eq 0) {
                    $line += [VT]::Warning() + " Today"
                } elseif ($daysUntil -lt 0) {
                    $line += [VT]::Error() + " -$(-$daysUntil)d"
                } else {
                    $line += [VT]::Text() + " +${daysUntil}d"
                }
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
        if ($task.DueDate) {
            $dueText = $task.DueDate.ToString("MMM d, yyyy")
            if ($task.IsOverdue()) {
                $this.Layout.RightPane.Content.Add([VT]::TextDim() + " Due: " + [VT]::Error() + $dueText + " (OVERDUE)") | Out-Null
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
        $this.UpdateLeftPane()
        $this.UpdateMiddlePane()
        $this.UpdateRightPane()
        
        $output = $this.Layout.Render()
        $status = " [a]dd [d]elete [e]dit [space]toggle [p]riority [/]search [tab]switch pane [q]uit"
        $output += $this.Layout.DrawStatusBar($status)
        
        [Console]::Write($output)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Tab) {
                # Cycle through panes
                $this.Layout.SetFocus(($this.Layout.FocusedPane + 1) % 3)
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this.Layout.FocusedPane -gt 0) {
                    $this.Layout.SetFocus($this.Layout.FocusedPane - 1)
                }
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.Layout.FocusedPane -lt 2) {
                    $this.Layout.SetFocus($this.Layout.FocusedPane + 1)
                }
            }
            ([ConsoleKey]::UpArrow) {
                switch ($this.Layout.FocusedPane) {
                    0 { # Filter pane
                        if ($this.FilterIndex -gt 0) {
                            $this.FilterIndex--
                            if ($this.Filters[$this.FilterIndex].Name -eq "──────────") {
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
                            if ($this.Filters[$this.FilterIndex].Name -eq "──────────") {
                                $this.FilterIndex++
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
                    # Apply filter
                    $this.ApplyFilter()
                    $this.Layout.SetFocus(1)  # Move to task list
                }
            }
        }
        
        # Handle character keys
        switch ($key.KeyChar) {
            ' ' { # Toggle task status
                if ($this.FilteredTasks.Count -gt 0) {
                    $task = $this.FilteredTasks[$this.TaskIndex]
                    switch ($task.Status) {
                        "Pending" { $task.Status = "InProgress" }
                        "InProgress" { $task.Status = "Completed" }
                        "Completed" { $task.Status = "Pending" }
                    }
                    $task.Update()
                }
            }
            'p' { # Change priority
                if ($this.FilteredTasks.Count -gt 0) {
                    $task = $this.FilteredTasks[$this.TaskIndex]
                    switch ($task.Priority) {
                        "Low" { $task.Priority = "Medium" }
                        "Medium" { $task.Priority = "High" }
                        "High" { $task.Priority = "Low" }
                    }
                    $task.Update()
                }
            }
        }
    }
}