# Delete Confirmation Dialog

class DeleteConfirmDialog : Dialog {
    [string]$ItemName
    [bool]$Confirmed = $false
    
    DeleteConfirmDialog([Screen]$parent, [string]$itemName) : base($parent) {
        $this.Title = "DELETE CONFIRMATION"
        $this.ItemName = $itemName
        $this.Width = 50
        $this.Height = 7
        
        $this.InitializeKeyBindings()
    }
    
    [void] InitializeKeyBindings() {
        $this.BindKey('y', {
            $this.Confirmed = $true
            $this.Active = $false
            # Handle deletion after dialog closes
            if ($this.TaskToDelete) {
                if ($this.ParentKanbanScreen) {
                    # For KanbanScreen
                    $this.ParentKanbanScreen.OnTaskDeleted($this.TaskToDelete)
                } elseif ($this.ParentTaskScreen) {
                    # For TaskScreen (legacy support)
                    $this.ParentTaskScreen.Tasks.Remove($this.TaskToDelete)
                    $this.ParentTaskScreen.ApplyFilter()
                    if ($this.ParentTaskScreen.TaskIndex -ge $this.ParentTaskScreen.FilteredTasks.Count -and $this.ParentTaskScreen.TaskIndex -gt 0) {
                        $this.ParentTaskScreen.TaskIndex--
                    }
                }
            }
        })
        
        $this.BindKey('n', {
            $this.Confirmed = $false
            $this.Active = $false
        })
        
        $this.BindKey([ConsoleKey]::Escape, {
            $this.Confirmed = $false
            $this.Active = $false
        })
        
        $this.BindKey([ConsoleKey]::LeftArrow, {
            $this.Confirmed = $false
            $this.Active = $false
        })
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
        
        # Render using fallback for now
        $content = $this.RenderContent()
        $lines = $content -split "`n"
        for ($i = 0; $i -lt [Math]::Min($lines.Count, $buffer.Height); $i++) {
            $buffer.WriteString(0, $i, $lines[$i], $normalFG, $normalBG)
        }
    }
    
    [string] RenderContent() {
        # Draw dialog box with red background
        $output = ""
        
        # Draw red box
        $output += [VT]::RGBBG(255, 0, 0) + [VT]::TextBright()
        
        # Top border
        $output += [VT]::MoveTo($this.X, $this.Y)
        $output += [VT]::TL() + [VT]::H() * ($this.Width - 2) + [VT]::TR()
        
        # Title line
        $output += [VT]::MoveTo($this.X, $this.Y + 1)
        $output += [VT]::V() + " DELETE CONFIRMATION".PadRight($this.Width - 2) + [VT]::V()
        
        # Item name
        $itemText = "Delete: " + $this.ItemName
        if ($itemText.Length -gt $this.Width - 4) {
            $itemText = $itemText.Substring(0, $this.Width - 7) + "..."
        }
        $output += [VT]::MoveTo($this.X, $this.Y + 2)
        $output += [VT]::V() + " $itemText".PadRight($this.Width - 2) + [VT]::V()
        
        # Warning
        $output += [VT]::MoveTo($this.X, $this.Y + 3)
        $output += [VT]::V() + " This cannot be undone!".PadRight($this.Width - 2) + [VT]::V()
        
        # Empty line
        $output += [VT]::MoveTo($this.X, $this.Y + 4)
        $output += [VT]::V() + " ".PadRight($this.Width - 2) + [VT]::V()
        
        # Prompt
        $output += [VT]::MoveTo($this.X, $this.Y + 5)
        $output += [VT]::V() + " [Y]es, delete   [N]o, cancel".PadRight($this.Width - 2) + [VT]::V()
        
        # Bottom border
        $output += [VT]::MoveTo($this.X, $this.Y + 6)
        $output += [VT]::BL() + [VT]::H() * ($this.Width - 2) + [VT]::BR()
        
        $output += [VT]::Reset()
        
        return $output
    }
}