# Edit Dialog - Full task editor

class EditDialog : Dialog {
    [Task]$Task
    [bool]$IsNew
    [int]$FieldIndex = 0
    [System.Collections.ArrayList]$Fields
    [bool]$EditMode = $false
    [string]$EditBuffer = ""
    [bool]$Saved = $false
    
    EditDialog([Screen]$parent, [Task]$task, [bool]$isNew) : base($parent) {
        $this.Task = $task
        $this.IsNew = $isNew
        $this.Title = if ($isNew) { "NEW TASK" } else { "EDIT TASK" }
        $this.Width = 70
        $this.Height = 20
        
        $this.InitializeFields()
        $this.InitializeKeyBindings()
        
        # Auto-focus title field for new tasks
        if ($this.IsNew) {
            $this.EditMode = $true
            $this.EditBuffer = $this.Task.Title
        }
    }
    
    [void] InitializeFields() {
        $this.Fields = [System.Collections.ArrayList]@(
            @{Name="Title"; Value=$this.Task.Title; Type="Text"},
            @{Name="Description"; Value=$this.Task.Description; Type="Multiline"},
            @{Name="Status"; Value=$this.Task.Status; Type="Choice"; Options=@("Pending", "InProgress", "Completed", "Cancelled")},
            @{Name="Priority"; Value=$this.Task.Priority; Type="Choice"; Options=@("Low", "Medium", "High")},
            @{Name="Progress"; Value=$this.Task.Progress; Type="Number"; Min=0; Max=100},
            @{Name="Due Date"; Value=$this.Task.DueDate; Type="Date"}
        )
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, {
            if (-not $this.EditMode -and $this.FieldIndex -gt 0) {
                $this.FieldIndex--
            }
        })
        
        $this.BindKey([ConsoleKey]::DownArrow, {
            if (-not $this.EditMode -and $this.FieldIndex -lt $this.Fields.Count - 1) {
                $this.FieldIndex++
            }
        })
        
        # Edit mode
        $this.BindKey([ConsoleKey]::Enter, {
            if ($this.EditMode) {
                $this.SaveField()
                $this.EditMode = $false
            } else {
                $this.StartEdit()
                $this.EditMode = $true
            }
        })
        
        # Add subtask option for new tasks
        $this.BindKey('S', {
            if ($this.IsNew -and -not $this.EditMode) {
                # Save current task first
                $this.SaveTask()
                
                # Add to parent's task list if new
                if ($this.ParentTaskScreen -and $this.NewTask) {
                    $this.ParentTaskScreen.Tasks.Add($this.NewTask) | Out-Null
                }
                
                # Create subtask
                $subtask = New-Object -TypeName "Task" -ArgumentList "New Subtask"
                $subtask.ParentId = $this.Task.Id
                $this.Task.SubtaskIds.Add($subtask.Id) | Out-Null
                
                # Open new dialog for subtask
                $subtaskDialog = New-Object -TypeName "EditDialog" -ArgumentList $this.ParentScreen, $subtask, $true
                $subtaskDialog | Add-Member -NotePropertyName ParentTaskScreen -NotePropertyValue $this.ParentTaskScreen
                $subtaskDialog | Add-Member -NotePropertyName NewTask -NotePropertyValue $subtask
                $subtaskDialog | Add-Member -NotePropertyName ParentTask -NotePropertyValue $this.Task
                
                # Close this dialog and open subtask dialog
                $this.Saved = $true
                $this.Active = $false
                
                if ($this.ParentTaskScreen) {
                    $this.ParentTaskScreen.ApplyFilter()
                }
                
                $global:ScreenManager.Push($subtaskDialog)
            }
        })
        
        # Save/Cancel
        $this.BindKey([ConsoleKey]::F2, {
            $this.SaveTask()
            $this.Saved = $true
            $this.Active = $false
            
            # If this is a new task, add it to the parent's task list
            if ($this.IsNew -and $this.ParentTaskScreen -and $this.NewTask) {
                $this.ParentTaskScreen.Tasks.Add($this.NewTask) | Out-Null
            }
            
            # Refresh parent after save
            if ($this.ParentTaskScreen) {
                $this.ParentTaskScreen.ApplyFilter()
            }
        })
        
        $this.BindKey([ConsoleKey]::Escape, {
            if ($this.EditMode) {
                $this.EditMode = $false
                $this.EditBuffer = ""
            } else {
                $this.Active = $false
            }
        })
        
        # Choice field navigation or cancel
        $this.BindKey([ConsoleKey]::LeftArrow, {
            if (-not $this.EditMode) {
                $field = $this.Fields[$this.FieldIndex]
                if ($field.Type -eq "Choice") {
                    $this.ChangeChoice(-1)
                } else {
                    # Cancel dialog for non-choice fields
                    $this.Active = $false
                }
            }
        })
        
        $this.BindKey([ConsoleKey]::RightArrow, {
            if (-not $this.EditMode) {
                $this.ChangeChoice(1)
            }
        })
    }
    
    [string] RenderContent() {
        # Draw dialog
        $output = $this.DrawBox()
        
        # Draw fields
        $fieldY = $this.Y + 2
        $fieldCount = $this.Fields.Count
        for ($i = 0; $i -lt $fieldCount; $i++) {
            $y = $fieldY + ($i * 2)
            $field = $this.Fields[$i]
            $isSelected = $i -eq $this.FieldIndex
            
            # Label
            $output += [VT]::MoveTo($this.X + 3, $y)
            if ($isSelected) {
                $output += [VT]::Selected() + " > " + $field.Name + ":"
            } else {
                $output += [VT]::TextDim() + "   " + $field.Name + ":"
            }
            
            # Value
            $output += [VT]::MoveTo($this.X + 20, $y)
            
            if ($this.EditMode -and $isSelected) {
                # Edit mode
                $value = $this.EditBuffer + "▌"
                $output += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + " " + $value.PadRight(40) + " " + [VT]::Reset()
            } else {
                # Display mode
                $value = $this.FormatFieldValue($field)
                
                if ($isSelected) {
                    $output += [VT]::TextBright() + "[" + $value + "]"
                } else {
                    $output += [VT]::Text() + " " + $value
                }
            }
            
            $output += [VT]::Reset()
        }
        
        # Instructions
        $output += [VT]::MoveTo($this.X + 3, $this.Y + $this.Height - 2)
        $output += [VT]::TextDim()
        if ($this.EditMode) {
            $output += "[Enter] save field  [Esc] cancel edit"
        } else {
            $output += "[↑/↓] navigate  [Enter] edit  [F2] save all"
            if ($this.IsNew) {
                $output += "  [S] save & add subtask"
            }
            $output += "  [Esc/←] cancel"
        }
        
        $output += [VT]::Reset()
        return $output
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Handle edit mode typing
        if ($this.EditMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Backspace) {
                    if ($this.EditBuffer.Length -gt 0) {
                        $this.EditBuffer = $this.EditBuffer.Substring(0, $this.EditBuffer.Length - 1)
                    }
                    return
                }
            }
            
            # Add character if printable
            if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                $key.KeyChar -eq ' ' -or [char]::IsPunctuation($key.KeyChar) -or
                [char]::IsSymbol($key.KeyChar) -or $key.KeyChar -eq '-' -or
                $key.KeyChar -eq '+') {
                $this.EditBuffer += $key.KeyChar
                return
            }
        }
        
        # Normal key handling
        ([Screen]$this).HandleInput($key)
    }
    
    [string] FormatFieldValue([hashtable]$field) {
        switch ($field.Type) {
            "Date" {
                if ($field.Value -and $field.Value -ne [datetime]::MinValue) {
                    return [DateParser]::Format($field.Value)
                } else {
                    return "(not set) - use yyyymmdd or +days"
                }
            }
            "Number" {
                if ($field.Value) { return $field.Value.ToString() } else { return "0" }
            }
            default {
                if ($field.Value) { return $field.Value } else { return "(empty)" }
            }
        }
        return ""  # Ensure all paths return a value
    }
    
    [void] StartEdit() {
        $field = $this.Fields[$this.FieldIndex]
        $this.EditBuffer = if ($field.Value -and $field.Value -ne [datetime]::MinValue) {
            switch ($field.Type) {
                "Date" { $field.Value.ToString("yyyyMMdd") }
                "Number" { $field.Value.ToString() }
                default { $field.Value }
            }
        } else { "" }
    }
    
    [void] SaveField() {
        $field = $this.Fields[$this.FieldIndex]
        switch ($field.Type) {
            "Number" {
                $num = 0
                if ([int]::TryParse($this.EditBuffer, [ref]$num)) {
                    $field.Value = [Math]::Max($field.Min, [Math]::Min($field.Max, $num))
                }
            }
            "Date" {
                $field.Value = [DateParser]::Parse($this.EditBuffer)
            }
            default {
                $field.Value = $this.EditBuffer
            }
        }
        $this.EditBuffer = ""
    }
    
    [void] ChangeChoice([int]$direction) {
        $field = $this.Fields[$this.FieldIndex]
        if ($field.Type -eq "Choice") {
            $currentIndex = $field.Options.IndexOf($field.Value)
            $newIndex = $currentIndex + $direction
            if ($newIndex -ge 0 -and $newIndex -lt $field.Options.Count) {
                $field.Value = $field.Options[$newIndex]
            }
        }
    }
    
    [void] SaveTask() {
        foreach ($field in $this.Fields) {
            switch ($field.Name) {
                "Title" { $this.Task.Title = $field.Value }
                "Description" { $this.Task.Description = $field.Value }
                "Status" { $this.Task.Status = $field.Value }
                "Priority" { $this.Task.Priority = $field.Value }
                "Progress" { $this.Task.Progress = $field.Value }
                "Due Date" { $this.Task.DueDate = $field.Value }
            }
        }
        $this.Task.Update()
    }
}