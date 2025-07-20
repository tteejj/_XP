# Test Views for LazyGit-style panels
# Basic implementations to validate the ILazyGitView interface and panel system

using namespace System.Text

# Load the interface
. "$PSScriptRoot/../Core/ILazyGitView.ps1"

# Simple list view for testing
class TestListView : LazyGitViewBase {
    TestListView([string]$name, [string]$shortName, [string[]]$items) : base($name, $shortName) {
        $this.Items = $items
    }
    
    [string] Render([int]$width, [int]$height) {
        if ($this.Items.Count -eq 0) {
            return "$($this._normalFG)  (no items)$($this._reset)"
        }
        
        $output = [StringBuilder]::new(512)
        $visibleStart = $this.ScrollOffset
        $visibleEnd = [Math]::Min($this.Items.Count, $visibleStart + $height)
        
        for ($i = $visibleStart; $i -lt $visibleEnd; $i++) {
            $item = $this.Items[$i]
            $line = $this.RenderListItem($i, "  $item", $width - 2)
            [void]$output.AppendLine($line)
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [hashtable] GetContextCommands() {
        return @{
            "Enter" = "Select item"
            "↑↓" = "Navigate"
            "Home/End" = "Jump to start/end"
        }
    }
    
    [string] GetStatus() {
        return "$($this.SelectedIndex + 1)/$($this.Items.Count)"
    }
}

# Filter list view (like LazyGit's branches/tags panel)
class FilterListView : TestListView {
    [string]$ActiveFilter = "All"
    
    FilterListView() : base("Filters", "FLT", @()) {
        $this.Items = @(
            "All Tasks",
            "Active", 
            "Completed",
            "High Priority",
            "Due Today",
            "Overdue",
            "No Project",
            "Recent"
        )
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [StringBuilder]::new(512)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $prefix = if ($item -eq $this.ActiveFilter) { "● " } else { "○ " }
            $line = $this.RenderListItem($i, "$prefix$item", $width)
            [void]$output.AppendLine($line)
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $this.ActiveFilter = $this.Items[$this.SelectedIndex]
            $this.IsDirty = $true
            return $true
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
    
    [object] GetSelectedItem() {
        return @{
            Filter = $this.ActiveFilter
            Index = $this.SelectedIndex
        }
    }
}

# Project tree view
class ProjectTreeView : LazyGitViewBase {
    [object[]]$Projects = @()
    
    ProjectTreeView() : base("Projects", "PRJ") {
        $this.LoadTestData()
    }
    
    [void] LoadTestData() {
        $this.Items = @(
            @{ Name = "ALCAR"; Type = "Project"; Level = 0; IsExpanded = $true; TaskCount = 12 },
            @{ Name = "LazyGit Interface"; Type = "Task"; Level = 1; Status = "Active"; Priority = "High" },
            @{ Name = "Command Palette"; Type = "Task"; Level = 1; Status = "Pending"; Priority = "Medium" },
            @{ Name = "Performance Optimization"; Type = "Task"; Level = 1; Status = "Active"; Priority = "High" },
            @{ Name = "Phoenix TUI"; Type = "Project"; Level = 0; IsExpanded = $false; TaskCount = 8 },
            @{ Name = "Personal Tasks"; Type = "Project"; Level = 0; IsExpanded = $true; TaskCount = 3 },
            @{ Name = "Review Documentation"; Type = "Task"; Level = 1; Status = "Completed"; Priority = "Low" },
            @{ Name = "Update README"; Type = "Task"; Level = 1; Status = "Active"; Priority = "Medium" }
        )
    }
    
    [string] Render([int]$width, [int]$height) {
        $output = [StringBuilder]::new(1024)
        
        for ($i = 0; $i -lt [Math]::Min($this.Items.Count, $height); $i++) {
            $item = $this.Items[$i]
            $indent = "  " * $item.Level
            
            # Icon based on type and state
            $icon = switch ($item.Type) {
                "Project" { 
                    if ($item.IsExpanded) { "📂" } else { "📁" }
                }
                "Task" {
                    switch ($item.Status) {
                        "Completed" { "✅" }
                        "Active" { "🔄" }
                        default { "📋" }
                    }
                }
                default { "•" }
            }
            
            # Build display text
            $text = "$indent$icon $($item.Name)"
            if ($item.Type -eq "Project" -and $item.PSObject.Properties.Name -contains "TaskCount") {
                $text += " ($($item.TaskCount))"
            }
            
            $line = $this.RenderListItem($i, $text, $width)
            [void]$output.AppendLine($line)
        }
        
        return $output.ToString().TrimEnd("`r`n")
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if ($key.Key -eq [ConsoleKey]::Enter) {
            $item = $this.Items[$this.SelectedIndex]
            if ($item.Type -eq "Project") {
                $item.IsExpanded = -not $item.IsExpanded
                $this.IsDirty = $true
                return $true
            }
        }
        
        return ([LazyGitViewBase]$this).HandleInput($key)
    }
    
    [hashtable] GetContextCommands() {
        $item = $this.GetSelectedItem()
        if ($item.Type -eq "Project") {
            return @{
                "Enter" = "Toggle expand"
                "n" = "New task"
                "e" = "Edit project"
            }
        } else {
            return @{
                "Enter" = "Open task"
                "e" = "Edit task"
                "d" = "Delete task"
                "Space" = "Toggle status"
            }
        }
    }
}

# Task detail view (for main panel)
class TaskDetailView : LazyGitViewBase {
    [object]$CurrentTask = $null
    
    TaskDetailView() : base("Task Details", "DTL") {
    }
    
    [string] Render([int]$width, [int]$height) {
        if ($this.CurrentTask -eq $null) {
            return "$($this._dimFG)  Select a task to view details$($this._reset)"
        }
        
        $output = [StringBuilder]::new(1024)
        $task = $this.CurrentTask
        
        # Task header
        [void]$output.AppendLine("$($this._normalFG)Task: $($this._reset)$($task.Name)")
        [void]$output.AppendLine()
        
        # Status and priority
        [void]$output.AppendLine("$($this._normalFG)Status: $($this._reset)$($task.Status)")
        if ($task.PSObject.Properties.Name -contains "Priority") {
            [void]$output.AppendLine("$($this._normalFG)Priority: $($this._reset)$($task.Priority)")
        }
        [void]$output.AppendLine()
        
        # Description (if available)
        if ($task.PSObject.Properties.Name -contains "Description") {
            [void]$output.AppendLine("$($this._normalFG)Description:$($this._reset)")
            [void]$output.AppendLine("$($task.Description)")
            [void]$output.AppendLine()
        }
        
        # Available actions
        [void]$output.AppendLine("$($this._dimFG)Actions:$($this._reset)")
        [void]$output.AppendLine("  e - Edit task")
        [void]$output.AppendLine("  d - Delete task")
        [void]$output.AppendLine("  Space - Toggle status")
        [void]$output.AppendLine("  t - Add time entry")
        
        return $output.ToString()
    }
    
    [void] SetSelection([object]$item) {
        $this.CurrentTask = $item
        $this.IsDirty = $true
    }
    
    [hashtable] GetContextCommands() {
        if ($this.CurrentTask -ne $null) {
            return @{
                "e" = "Edit task"
                "d" = "Delete task"
                "Space" = "Toggle status"
                "t" = "Add time entry"
            }
        }
        return @{}
    }
}

# Command palette test view
class TestCommandPalette {
    [string]$CurrentInput = ""
    [string[]]$FilteredCommands = @()
    [int]$SelectedIndex = 0
    [bool]$IsActive = $false
    
    # Available commands
    [hashtable]$Commands = @{
        "new task" = @{ Name = "New Task"; Action = "CreateTask"; ShortKey = "nt" }
        "new project" = @{ Name = "New Project"; Action = "CreateProject"; ShortKey = "np" }
        "find task" = @{ Name = "Find Task"; Action = "SearchTasks"; ShortKey = "ft" }
        "switch panel" = @{ Name = "Switch Panel"; Action = "CyclePanel"; ShortKey = "sp" }
        "toggle view" = @{ Name = "Toggle View"; Action = "ToggleView"; ShortKey = "tv" }
        "export data" = @{ Name = "Export Data"; Action = "ExportData"; ShortKey = "ed" }
        "settings" = @{ Name = "Settings"; Action = "OpenSettings"; ShortKey = "set" }
        "quit" = @{ Name = "Quit Application"; Action = "Quit"; ShortKey = "q" }
    }
    
    TestCommandPalette() {
        $this.FilterCommands()
    }
    
    [void] SetInput([string]$input) {
        $this.CurrentInput = $input
        $this.FilterCommands()
    }
    
    [void] FilterCommands() {
        if ([string]::IsNullOrEmpty($this.CurrentInput)) {
            $this.FilteredCommands = $this.Commands.Keys | Sort-Object
        } else {
            $pattern = [regex]::Escape($this.CurrentInput.ToLower())
            $this.FilteredCommands = $this.Commands.Keys | Where-Object { 
                $_ -match $pattern -or $this.Commands[$_].ShortKey -match $pattern
            } | Sort-Object { $_.IndexOf($this.CurrentInput.ToLower()) }
        }
        $this.SelectedIndex = 0
    }
    
    [string] Render() {
        $output = [StringBuilder]::new(256)
        
        # Command input line
        [void]$output.Append("❯ $($this.CurrentInput)")
        if ($this.IsActive) {
            [void]$output.Append("█")  # Block cursor
        }
        
        # Command suggestions (show up to 3)
        if ($this.FilteredCommands.Count -gt 0) {
            [void]$output.Append("  ")
            for ($i = 0; $i -lt [Math]::Min(3, $this.FilteredCommands.Count); $i++) {
                $cmd = $this.FilteredCommands[$i]
                $cmdInfo = $this.Commands[$cmd]
                
                if ($i -eq $this.SelectedIndex) {
                    [void]$output.Append("`e[48;2;60;80;120m")  # Selected background
                }
                
                [void]$output.Append(" $($cmdInfo.Name) ")
                
                if ($i -eq $this.SelectedIndex) {
                    [void]$output.Append("`e[0m")  # Reset
                }
                
                if ($i -lt [Math]::Min(2, $this.FilteredCommands.Count - 1)) {
                    [void]$output.Append(" │ ")
                }
            }
        }
        
        return $output.ToString()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        switch ($key.Key) {
            ([ConsoleKey]::Tab) {
                if ($this.FilteredCommands.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.FilteredCommands.Count
                    return $true
                }
            }
            ([ConsoleKey]::Enter) {
                if ($this.FilteredCommands.Count -gt 0) {
                    $selectedCmd = $this.FilteredCommands[$this.SelectedIndex]
                    # Execute command (in real implementation)
                    Write-Host "Execute: $($this.Commands[$selectedCmd].Action)" -ForegroundColor Green
                    $this.CurrentInput = ""
                    $this.FilterCommands()
                    return $true
                }
            }
            ([ConsoleKey]::Escape) {
                $this.CurrentInput = ""
                $this.FilterCommands()
                $this.IsActive = $false
                return $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CurrentInput.Length -gt 0) {
                    $this.CurrentInput = $this.CurrentInput.Substring(0, $this.CurrentInput.Length - 1)
                    $this.FilterCommands()
                    return $true
                }
            }
        }
        
        # Handle character input
        if ($key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
            $this.CurrentInput += $key.KeyChar
            $this.FilterCommands()
            return $true
        }
        
        return $false
    }
}