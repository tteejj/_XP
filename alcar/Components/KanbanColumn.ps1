# KanbanColumn Component - Individual column for Kanban board
# Displays tasks in a scrollable list with selection and movement capabilities

class KanbanColumn : Component {
    [string]$ColumnTitle
    [string]$Status  # Pending, InProgress, Completed
    [System.Collections.ArrayList]$Tasks
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [int]$MaxVisibleTasks = 10
    [bool]$IsActive = $false
    [bool]$HasBorder = $true
    [scriptblock]$OnTaskSelected = $null
    [scriptblock]$OnTaskMoved = $null
    
    KanbanColumn([string]$title, [string]$status) : base($title) {
        $this.ColumnTitle = $title
        $this.Status = $status
        $this.Tasks = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
        $this.HasBorder = $true
    }
    
    # Set tasks for this column
    [void] SetTasks([array]$tasks) {
        $this.Tasks.Clear()
        if ($tasks) {
            $this.Tasks.AddRange($tasks)
        }
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    # Add task to column
    [void] AddTask([hashtable]$task) {
        $this.Tasks.Add($task) | Out-Null
        $this.Invalidate()
    }
    
    # Remove task from column
    [bool] RemoveTask([string]$taskId) {
        $taskToRemove = $this.Tasks | Where-Object { $_.ID -eq $taskId } | Select-Object -First 1
        if ($taskToRemove) {
            $this.Tasks.Remove($taskToRemove)
            # Adjust selection if needed
            if ($this.SelectedIndex -ge $this.Tasks.Count) {
                $this.SelectedIndex = [Math]::Max(0, $this.Tasks.Count - 1)
            }
            $this.EnsureVisible()
            $this.Invalidate()
            return $true
        }
        return $false
    }
    
    # Get currently selected task
    [hashtable] GetSelectedTask() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Tasks.Count) {
            return $this.Tasks[$this.SelectedIndex]
        }
        return $null
    }
    
    # Navigation methods
    [void] NavigateDown() {
        if ($this.SelectedIndex -lt $this.Tasks.Count - 1) {
            $this.SelectedIndex++
            $this.EnsureVisible()
            $this.Invalidate()
            
            if ($this.OnTaskSelected) {
                & $this.OnTaskSelected $this.GetSelectedTask()
            }
        }
    }
    
    [void] NavigateUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.EnsureVisible()
            $this.Invalidate()
            
            if ($this.OnTaskSelected) {
                & $this.OnTaskSelected $this.GetSelectedTask()
            }
        }
    }
    
    # Ensure selected item is visible
    [void] EnsureVisible() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this.MaxVisibleTasks) {
            $this.ScrollOffset = $this.SelectedIndex - $this.MaxVisibleTasks + 1
        }
        
        # Ensure scroll offset is valid
        $maxScroll = [Math]::Max(0, $this.Tasks.Count - $this.MaxVisibleTasks)
        if ($this.ScrollOffset -gt $maxScroll) {
            $this.ScrollOffset = $maxScroll
        }
        if ($this.ScrollOffset -lt 0) {
            $this.ScrollOffset = 0
        }
    }
    
    # Handle input (arrow keys and task movement)
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                $this.NavigateUp()
                $handled = $true
            }
            ([ConsoleKey]::DownArrow) {
                $this.NavigateDown()
                $handled = $true
            }
            ([ConsoleKey]::LeftArrow) {
                # Move task to previous column (if Ctrl is held)
                if ($key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
                    if ($this.OnTaskMoved) {
                        $task = $this.GetSelectedTask()
                        if ($task) {
                            & $this.OnTaskMoved $task "left"
                            $handled = $true
                        }
                    }
                }
            }
            ([ConsoleKey]::RightArrow) {
                # Move task to next column (if Ctrl is held)
                if ($key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
                    if ($this.OnTaskMoved) {
                        $task = $this.GetSelectedTask()
                        if ($task) {
                            & $this.OnTaskMoved $task "right"
                            $handled = $true
                        }
                    }
                }
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.EnsureVisible()
                $this.Invalidate()
                $handled = $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = [Math]::Max(0, $this.Tasks.Count - 1)
                $this.EnsureVisible()
                $this.Invalidate()
                $handled = $true
            }
        }
        
        return $handled
    }
    
    # Render the column
    [string] Render() {
        $output = ""
        
        # Calculate visible area
        $this.MaxVisibleTasks = $this.Height - 3  # Account for header and border
        
        # Column header with title and task count
        $headerText = "$($this.ColumnTitle) ($($this.Tasks.Count))"
        $headerPadding = [Math]::Max(0, ($this.Width - 2 - $headerText.Length) / 2)
        
        # Top border
        $output += [VT]::MoveTo($this.X, $this.Y)
        if ($this.IsActive) {
            $output += [VT]::BorderActive() + [VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR() + [VT]::Reset()
        } else {
            $output += [VT]::Border() + [VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR() + [VT]::Reset()
        }
        
        # Header with title
        $output += [VT]::MoveTo($this.X, $this.Y + 1)
        if ($this.IsActive) {
            $output += [VT]::BorderActive() + [VT]::V() + [VT]::Reset()
            $output += [VT]::TextBright() + (" " * $headerPadding) + $headerText + (" " * ($this.Width - 2 - $headerPadding - $headerText.Length)) + [VT]::Reset()
            $output += [VT]::BorderActive() + [VT]::V() + [VT]::Reset()
        } else {
            $output += [VT]::Border() + [VT]::V() + [VT]::Reset()
            $output += [VT]::Text() + (" " * $headerPadding) + $headerText + (" " * ($this.Width - 2 - $headerPadding - $headerText.Length)) + [VT]::Reset()
            $output += [VT]::Border() + [VT]::V() + [VT]::Reset()
        }
        
        # Separator line
        $output += [VT]::MoveTo($this.X, $this.Y + 2)
        if ($this.IsActive) {
            $output += [VT]::BorderActive() + [VT]::V() + ([VT]::H() * ($this.Width - 2)) + [VT]::V() + [VT]::Reset()
        } else {
            $output += [VT]::Border() + [VT]::V() + ([VT]::H() * ($this.Width - 2)) + [VT]::V() + [VT]::Reset()
        }
        
        # Render tasks
        $this.EnsureVisible()
        
        for ($i = 0; $i -lt $this.MaxVisibleTasks; $i++) {
            $taskIndex = $i + $this.ScrollOffset
            $y = $this.Y + 3 + $i
            
            $output += [VT]::MoveTo($this.X, $y)
            
            if ($this.IsActive) {
                $output += [VT]::BorderActive() + [VT]::V() + [VT]::Reset()
            } else {
                $output += [VT]::Border() + [VT]::V() + [VT]::Reset()
            }
            
            if ($taskIndex -lt $this.Tasks.Count) {
                $task = $this.Tasks[$taskIndex]
                
                # Handle hierarchical indentation
                $indent = ""
                $level = if ($task.Level) { $task.Level } else { 0 }
                if ($level -gt 0) {
                    $indent = "  " * $level + "└ "  # Indentation for subtasks
                }
                
                $taskText = $indent + $task.Title
                
                # Truncate if too long
                $maxTextWidth = $this.Width - 4
                if ($taskText.Length -gt $maxTextWidth) {
                    $taskText = $taskText.Substring(0, $maxTextWidth - 3) + "..."
                }
                
                # Highlight selected task
                if ($taskIndex -eq $this.SelectedIndex -and $this.IsActive) {
                    $output += [VT]::Selected() + " " + $taskText.PadRight($this.Width - 3) + [VT]::Reset()
                } else {
                    # Dim subtasks slightly to show hierarchy
                    if ($level -gt 0) {
                        $output += [VT]::TextDim() + " " + $taskText.PadRight($this.Width - 3) + [VT]::Reset()
                    } else {
                        $output += [VT]::Text() + " " + $taskText.PadRight($this.Width - 3) + [VT]::Reset()
                    }
                }
            } else {
                # Empty space
                $output += " " * ($this.Width - 2)
            }
            
            if ($this.IsActive) {
                $output += [VT]::BorderActive() + [VT]::V() + [VT]::Reset()
            } else {
                $output += [VT]::Border() + [VT]::V() + [VT]::Reset()
            }
        }
        
        # Bottom border
        $output += [VT]::MoveTo($this.X, $this.Y + $this.Height - 1)
        if ($this.IsActive) {
            $output += [VT]::BorderActive() + [VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR() + [VT]::Reset()
        } else {
            $output += [VT]::Border() + [VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR() + [VT]::Reset()
        }
        
        return $output
    }
    
    # Set active state
    [void] SetActive([bool]$active) {
        $this.IsActive = $active
        $this.Invalidate()
    }
    
    # Get task count
    [int] GetTaskCount() {
        return $this.Tasks.Count
    }
}