# Edit Screen for detailed task editing

class EditScreen {
    [Task]$Task
    [bool]$IsNew
    [int]$FieldIndex = 0
    [System.Collections.ArrayList]$Fields
    [bool]$EditMode = $false
    [string]$EditBuffer = ""
    [bool]$ShouldSave = $false
    [bool]$ShouldCancel = $false
    
    EditScreen([Task]$task, [bool]$isNew) {
        $this.Task = $task
        $this.IsNew = $isNew
        $this.InitializeFields()
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
    
    # Buffer-based render for compatibility
    [void] RenderToBuffer([Buffer]$buffer) {
        # Legacy fallback
        $this.Render()
    }
    
    [void] Render() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Position at home and draw frame
        $output = [VT]::Home()
        $output += [VT]::MoveTo(1, 1)
        $output += [VT]::Border()
        
        # Draw border
        $output += [VT]::TL() + [VT]::H() * ($width - 2) + [VT]::TR()
        
        for ($y = 2; $y -lt $height - 1; $y++) {
            $output += [VT]::MoveTo(1, $y) + [VT]::V()
            $output += [VT]::MoveTo($width, $y) + [VT]::V()
        }
        
        $output += [VT]::MoveTo(1, $height - 1)
        $output += [VT]::BL() + [VT]::H() * ($width - 2) + [VT]::BR()
        
        # Title
        $title = if ($this.IsNew) { " NEW TASK " } else { " EDIT TASK " }
        $titleX = [int](($width - $title.Length) / 2)
        $output += [VT]::MoveTo($titleX, 1) + [VT]::TextBright() + $title
        
        # Fields
        $y = 3
        for ($i = 0; $i -lt $this.Fields.Count; $i++) {
            $field = $this.Fields[$i]
            $isSelected = $i -eq $this.FieldIndex
            
            # Field label
            $output += [VT]::MoveTo(5, $y)
            if ($isSelected) {
                $output += [VT]::Selected() + " > " + $field.Name + ":"
            } else {
                $output += [VT]::TextDim() + "   " + $field.Name + ":"
            }
            
            # Field value
            $output += [VT]::MoveTo(20, $y)
            
            if ($this.EditMode -and $isSelected) {
                # Edit mode
                $value = $this.EditBuffer + "▌"
                $output += [VT]::RGBBG(255, 255, 0) + [VT]::RGB(0, 0, 0) + " " + $value.PadRight(40) + " " + [VT]::Reset()
            } else {
                # Display mode
                $value = switch ($field.Type) {
                    "Date" {
                        if ($field.Value -and $field.Value -ne [datetime]::MinValue) {
                            [DateParser]::Format($field.Value)
                        } else {
                            "(not set) - use yyyymmdd or +days"
                        }
                    }
                    "Number" {
                        if ($field.Value) { $field.Value.ToString() } else { "0" }
                    }
                    default {
                        if ($field.Value) { $field.Value } else { "(empty)" }
                    }
                }
                
                if ($isSelected) {
                    $output += [VT]::TextBright() + "[" + $value + "]"
                } else {
                    $output += [VT]::Text() + " " + $value
                }
            }
            
            $output += [VT]::Reset()
            $y += 2
        }
        
        # Instructions
        $output += [VT]::MoveTo(5, $height - 3)
        $output += [VT]::TextDim()
        if ($this.EditMode) {
            $output += "[Enter] save field  [Esc] cancel edit"
        } else {
            $output += "[↑/↓] navigate  [Enter] edit field  [F2] save task  [Esc] cancel"
        }
        
        $output += [VT]::Reset()
        [Console]::Write($output)
    }
    
    [void] HandleInput([ConsoleKeyInfo]$key) {
        if ($this.EditMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    # Save field
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
                    $this.EditMode = $false
                    $this.EditBuffer = ""
                }
                ([ConsoleKey]::Escape) {
                    # Cancel edit
                    $this.EditMode = $false
                    $this.EditBuffer = ""
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.EditBuffer.Length -gt 0) {
                        $this.EditBuffer = $this.EditBuffer.Substring(0, $this.EditBuffer.Length - 1)
                    }
                }
                default {
                    # Add character
                    if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or 
                        $key.KeyChar -eq ' ' -or [char]::IsPunctuation($key.KeyChar) -or
                        [char]::IsSymbol($key.KeyChar) -or $key.KeyChar -eq '-') {
                        $this.EditBuffer += $key.KeyChar
                    }
                }
            }
        } else {
            # Navigation mode
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.FieldIndex -gt 0) {
                        $this.FieldIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.FieldIndex -lt $this.Fields.Count - 1) {
                        $this.FieldIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    # Enter edit mode
                    $this.EditMode = $true
                    $field = $this.Fields[$this.FieldIndex]
                    $this.EditBuffer = if ($field.Value -and $field.Value -ne [datetime]::MinValue) {
                        switch ($field.Type) {
                            "Date" { $field.Value.ToString("yyyy-MM-dd") }
                            "Number" { $field.Value.ToString() }
                            default { $field.Value }
                        }
                    } else { "" }
                }
                ([ConsoleKey]::F2) {
                    # Save task
                    $this.SaveToTask()
                    $this.ShouldSave = $true
                }
                ([ConsoleKey]::Escape) {
                    # Cancel
                    $this.ShouldCancel = $true
                }
            }
            
            # Handle choice fields with left/right
            if ($key.Key -eq [ConsoleKey]::LeftArrow -or $key.Key -eq [ConsoleKey]::RightArrow) {
                $field = $this.Fields[$this.FieldIndex]
                if ($field.Type -eq "Choice") {
                    $currentIndex = $field.Options.IndexOf($field.Value)
                    if ($key.Key -eq [ConsoleKey]::LeftArrow -and $currentIndex -gt 0) {
                        $field.Value = $field.Options[$currentIndex - 1]
                    } elseif ($key.Key -eq [ConsoleKey]::RightArrow -and $currentIndex -lt $field.Options.Count - 1) {
                        $field.Value = $field.Options[$currentIndex + 1]
                    }
                }
            }
        }
    }
    
    [void] SaveToTask() {
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
    
    # Buffer-based render compatibility
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