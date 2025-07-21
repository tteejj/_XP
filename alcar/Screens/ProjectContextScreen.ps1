# ProjectContextScreen - Context-aware project workspace
# Implements the v2 concept with project->tasks->tools flow

class ProjectContextScreen : Screen {
    # Services
    [object]$ProjectService
    [object]$TaskService
    [object]$TimeTrackingService
    
    # Data
    [System.Collections.ArrayList]$Projects
    [System.Collections.ArrayList]$Tasks
    [object]$SelectedProject
    [object]$SelectedTask
    
    # UI State
    [int]$ProjectIndex = 0
    [int]$TaskIndex = 0
    [int]$FocusedPane = 0  # 0=Projects, 1=Details, 2=Tools
    [string]$ActiveTab = "Tasks"  # Tasks, Time, Notes, Files, Commands
    
    # Layout dimensions
    [int]$LeftWidth = 12
    [int]$MiddleWidth = 25
    [int]$RightWidth = 0  # Calculated
    
    # Filter state
    [bool]$ShowActiveOnly = $true
    [bool]$ShowMyWork = $false
    
    ProjectContextScreen() {
        $this.Title = "PROJECT CONTEXT"
        $this.Initialize()
    }
    
    [void] Initialize() {
        # Get services
        $this.ProjectService = $global:ServiceContainer.GetService("ProjectService")
        $this.TaskService = $global:ServiceContainer.GetService("TaskService")
        
        try {
            $this.TimeTrackingService = $global:ServiceContainer.GetService("TimeTrackingService")
        } catch {
            Write-Debug "TimeTrackingService not available"
        }
        
        # Calculate layout
        $this.RightWidth = [Console]::WindowWidth - $this.LeftWidth - $this.MiddleWidth - 4
        
        # Load data
        $this.LoadProjects()
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] LoadProjects() {
        $this.Projects = [System.Collections.ArrayList]::new()
        $projectList = $this.ProjectService.GetAllProjects()
        
        foreach ($project in $projectList) {
            if ($this.ShowActiveOnly -and $project.ClosedDate -ne [DateTime]::MinValue) {
                continue
            }
            $this.Projects.Add($project) | Out-Null
        }
        
        if ($this.Projects.Count -gt 0 -and $this.ProjectIndex -ge 0) {
            $this.SelectProject($this.ProjectIndex)
        }
    }
    
    [void] SelectProject([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Projects.Count) {
            $this.ProjectIndex = $index
            $this.SelectedProject = $this.Projects[$index]
            $this.LoadProjectTasks()
        }
    }
    
    [void] LoadProjectTasks() {
        if (-not $this.SelectedProject) { return }
        
        $this.Tasks = [System.Collections.ArrayList]::new()
        $allTasks = $this.TaskService.GetAllTasks()
        
        foreach ($task in $allTasks) {
            if ($task.ProjectId -eq $this.SelectedProject.Id) {
                $this.Tasks.Add($task) | Out-Null
            }
        }
        
        if ($this.Tasks.Count -gt 0 -and $this.TaskIndex -ge 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
            $this.SelectedTask = $this.Tasks[$this.TaskIndex]
        }
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Tab, { $this.NextTab(); $this.RequestRender() })
        # Note: Shift+Tab handling would need custom input processing
        
        # Actions
        $this.BindKey([ConsoleKey]::Enter, { $this.SelectCurrent(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Escape, { $this.GoBack() })
        $this.BindKey('q', { $this.Active = $false })
        
        # Quick actions
        $this.BindKey('n', { $this.NewTask() })
        $this.BindKey('t', { $this.ToggleTimer() })
        $this.BindKey('e', { $this.EditCurrent() })
        $this.BindKey('f', { $this.ToggleFilter(); $this.RequestRender() })
    }
    
    [void] NavigateUp() {
        switch ($this.FocusedPane) {
            0 { # Projects
                if ($this.ProjectIndex -gt 0) {
                    $this.SelectProject($this.ProjectIndex - 1)
                }
            }
            2 { # Tools/Tasks
                if ($this.ActiveTab -eq "Tasks" -and $this.TaskIndex -gt 0) {
                    $this.TaskIndex--
                    if ($this.TaskIndex -lt $this.Tasks.Count) {
                        $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                    }
                }
            }
        }
    }
    
    [void] NavigateDown() {
        switch ($this.FocusedPane) {
            0 { # Projects
                if ($this.ProjectIndex -lt $this.Projects.Count - 1) {
                    $this.SelectProject($this.ProjectIndex + 1)
                }
            }
            2 { # Tools/Tasks
                if ($this.ActiveTab -eq "Tasks" -and $this.TaskIndex -lt $this.Tasks.Count - 1) {
                    $this.TaskIndex++
                    if ($this.TaskIndex -lt $this.Tasks.Count) {
                        $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                    }
                }
            }
        }
    }
    
    [void] NavigateLeft() {
        if ($this.FocusedPane -gt 0) {
            $this.FocusedPane--
        } else {
            $this.Active = $false  # Go back to main menu
        }
    }
    
    [void] NavigateRight() {
        if ($this.FocusedPane -lt 2) {
            $this.FocusedPane++
        }
    }
    
    [void] NextTab() {
        $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
        $currentIndex = $tabs.IndexOf($this.ActiveTab)
        $nextIndex = ($currentIndex + 1) % $tabs.Count
        $this.ActiveTab = $tabs[$nextIndex]
    }
    
    [void] PrevTab() {
        $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
        $currentIndex = $tabs.IndexOf($this.ActiveTab)
        $prevIndex = if ($currentIndex -eq 0) { $tabs.Count - 1 } else { $currentIndex - 1 }
        $this.ActiveTab = $tabs[$prevIndex]
    }
    
    [void] UpdateStatusBar() {
        $this.StatusBarItems.Clear()
        
        if ($this.SelectedProject) {
            $projectInfo = "$($this.SelectedProject.Nickname) | $($this.Tasks.Count) tasks"
            if ($this.SelectedProject.CumulativeHrs -gt 0) {
                $projectInfo += " | $($this.SelectedProject.CumulativeHrs)h used"
            }
            if ($this.SelectedProject.DateDue -ne [DateTime]::MinValue) {
                $daysLeft = ($this.SelectedProject.DateDue - [DateTime]::Now).Days
                $projectInfo += " | Due in $daysLeft days"
            }
            $this.StatusBarItems.Add($projectInfo)
        } else {
            $this.StatusBarItems.Add("Select a project")
        }
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Command palette bar
        $output += [VT]::MoveTo(0, 0)
        $output += $this.RenderCommandBar()
        
        # Tab bar
        $output += [VT]::MoveTo(0, 1)
        $output += $this.RenderTabBar()
        
        # Main content area
        $output += [VT]::MoveTo(0, 2)
        $output += $this.RenderMainArea()
        
        # Status bar at bottom
        $height = [Console]::WindowHeight
        $output += [VT]::MoveTo(0, $height - 2)
        $output += $this.RenderStatusBar()
        
        # Command input line if in command mode
        if ($this.AsyncInputManager -and $this.AsyncInputManager.IsInCommandMode()) {
            $output += [VT]::MoveTo(0, $height - 1)
            $output += [VT]::Border() + $this.AsyncInputManager.GetCommandBuffer() + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] RenderCommandBar() {
        $width = [Console]::WindowWidth
        $commands = ":task new  :time start  :note add  :file open"
        $menu = "[MainMenu]"
        
        $bar = [VT]::Border() + $commands
        $bar += " " * ($width - $commands.Length - $menu.Length - 1)
        $bar += $menu + [VT]::Reset()
        
        return $bar
    }
    
    [string] RenderTabBar() {
        $tabs = @("Projects", "Tasks", "Time", "Notes", "Files", "Commands")
        $output = ""
        
        foreach ($tab in $tabs) {
            if ($tab -eq "Projects" -or ($this.FocusedPane -eq 2 -and $tab -eq $this.ActiveTab)) {
                $output += [VT]::Selected() + "[*$tab*]" + [VT]::Reset()
            } else {
                $output += "[$tab]"
            }
        }
        
        $output += "          Tab → "
        return $output
    }
    
    [string] RenderMainArea() {
        $output = ""
        $height = [Console]::WindowHeight - 4  # Leave room for command, tab, status bars
        
        # Draw borders
        $output += $this.DrawPaneBorders($height)
        
        # Render each pane
        $output += $this.RenderProjectsPane($height)
        $output += $this.RenderDetailsPane($height)
        $output += $this.RenderToolsPane($height)
        
        return $output
    }
    
    [string] DrawPaneBorders([int]$height) {
        $output = ""
        
        # Top border
        $output += [VT]::MoveTo(0, 2)
        $output += [VT]::Border()
        $output += "├" + ("─" * ($this.LeftWidth)) + "┬" + ("─" * ($this.MiddleWidth)) + "┬" + ("─" * ($this.RightWidth)) + "┤"
        $output += [VT]::Reset()
        
        # Vertical borders
        for ($i = 3; $i -lt $height + 2; $i++) {
            $output += [VT]::MoveTo(0, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 2, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo([Console]::WindowWidth - 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(0, $height + 2)
        $output += [VT]::Border()
        $output += "├" + ("─" * ($this.LeftWidth)) + "┴" + ("─" * ($this.MiddleWidth)) + "┴" + ("─" * ($this.RightWidth)) + "┤"
        $output += [VT]::Reset()
        
        # Pane titles
        $output += [VT]::MoveTo(2, 3) + [VT]::TextBright() + "PROJECTS" + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + 3, 3) + [VT]::TextBright() + "PROJECT DETAILS" + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 4, 3) + [VT]::TextBright() + "PROJECT TOOLS" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderProjectsPane([int]$height) {
        $output = ""
        $startY = 5
        
        # Project list
        for ($i = 0; $i -lt $this.Projects.Count -and $i -lt ($height - 8); $i++) {
            $project = $this.Projects[$i]
            $output += [VT]::MoveTo(2, $startY + $i)
            
            if ($i -eq $this.ProjectIndex) {
                $output += [VT]::Selected()
                if ($this.FocusedPane -eq 0) {
                    $output += "> "
                } else {
                    $output += "  "
                }
            } else {
                $output += "  "
            }
            
            # Truncate nickname to fit
            $name = $project.Nickname
            if ($name.Length -gt ($this.LeftWidth - 4)) {
                $name = $name.Substring(0, $this.LeftWidth - 7) + "..."
            }
            
            $output += $name
            if ($i -eq $this.ProjectIndex) {
                $output += [VT]::Reset()
            }
        }
        
        # Status filter
        $filterY = $startY + $this.Projects.Count + 1
        if ($filterY -lt $height - 3) {
            $output += [VT]::MoveTo(2, $filterY)
            $output += [VT]::TextDim() + "Status" + [VT]::Reset()
            $output += [VT]::MoveTo(2, $filterY + 1)
            $output += if ($this.ShowActiveOnly) { "☑" } else { "☐" }
            $output += " Active"
        }
        
        # New button
        $output += [VT]::MoveTo(2, $height - 1)
        $output += "[+ New]"
        
        return $output
    }
    
    [string] RenderDetailsPane([int]$height) {
        $output = ""
        $startY = 5
        $x = $this.LeftWidth + 3
        
        if (-not $this.SelectedProject) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "Select a project" + [VT]::Reset()
            return $output
        }
        
        $p = $this.SelectedProject
        
        # Project name
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + $p.FullProjectName + [VT]::Reset()
        
        # IDs
        $output += [VT]::MoveTo($x, $startY + 2)
        $output += "ID1: " + $p.ID1
        $output += [VT]::MoveTo($x, $startY + 3)
        $output += "ID2: " + $p.ID2
        
        # Dates
        $output += [VT]::MoveTo($x, $startY + 5)
        $output += "Assigned: " + $p.DateAssigned.ToString("MM/dd")
        $output += [VT]::MoveTo($x, $startY + 6)
        $output += "Due: " + $p.DateDue.ToString("MM/dd")
        $output += [VT]::MoveTo($x, $startY + 7)
        $output += "BF: " + $p.BFDate.ToString("MM/dd")
        
        # Hours and progress
        $output += [VT]::MoveTo($x, $startY + 9)
        $output += "Hours: $($p.CumulativeHrs)/200"
        $output += [VT]::MoveTo($x, $startY + 10)
        $progress = [int]($p.CumulativeHrs / 200 * 10)
        $output += "Progress: " + ("█" * $progress) + ("░" * (10 - $progress))
        
        # Paths
        $output += [VT]::MoveTo($x, $startY + 12)
        $output += "Paths:"
        if ($p.CAAPath) {
            $output += [VT]::MoveTo($x, $startY + 13)
            $output += "CAA: " + $p.CAAPath.Substring(0, [Math]::Min($p.CAAPath.Length, 20))
        }
        
        # Action hint
        $output += [VT]::MoveTo($x, $height - 3)
        if ($this.FocusedPane -eq 1) {
            $output += [VT]::Accent() + "[Enter] Open → " + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] RenderToolsPane([int]$height) {
        $output = ""
        $x = $this.LeftWidth + $this.MiddleWidth + 4
        
        if (-not $this.SelectedProject) {
            return $output
        }
        
        switch ($this.ActiveTab) {
            "Tasks" { $output += $this.RenderTaskList($x, $height) }
            "Time" { $output += $this.RenderTimeEntries($x, $height) }
            "Notes" { $output += $this.RenderNotes($x, $height) }
            "Files" { $output += $this.RenderFiles($x, $height) }
            "Commands" { $output += $this.RenderCommands($x, $height) }
        }
        
        return $output
    }
    
    [string] RenderTaskList([int]$x, [int]$height) {
        $output = ""
        $startY = 5
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Tasks ($($this.Tasks.Count) active):" + [VT]::Reset()
        
        $y = $startY + 1
        for ($i = 0; $i -lt $this.Tasks.Count -and $y -lt $height - 3; $i++) {
            $task = $this.Tasks[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Task status icon
            switch ($task.Priority) {
                "High" { $output += "🔴 " }
                "Medium" { $output += "🟡 " }
                "Low" { $output += "🟢 " }
                default { $output += "⚪ " }
            }
            
            # Task title (truncated)
            $title = $task.Title
            if ($title.Length -gt ($this.RightWidth - 8)) {
                $title = $title.Substring(0, $this.RightWidth - 11) + "..."
            }
            
            $output += $title
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        return $output
    }
    
    [string] RenderTimeEntries([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 5)
        $output += [VT]::TextBright() + "Time This Week:" + [VT]::Reset()
        
        # Mock time data for now
        $output += [VT]::MoveTo($x, 7)
        $output += "Mon ████░ 6.5h"
        $output += [VT]::MoveTo($x, 8)
        $output += "Tue ███░░ 4.2h"
        $output += [VT]::MoveTo($x, 9)
        $output += "Today █░░░ 2.1h"
        
        return $output
    }
    
    [string] RenderNotes([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 5)
        $output += [VT]::TextBright() + "Project Notes:" + [VT]::Reset()
        $output += [VT]::MoveTo($x, 7)
        $output += "[Enter] Open notes.md"
        
        return $output
    }
    
    [string] RenderFiles([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 5)
        $output += [VT]::TextBright() + "Project Files:" + [VT]::Reset()
        $output += [VT]::MoveTo($x, 7)
        $output += "📁 " + ($this.SelectedProject.CAAPath ?? "No path set")
        
        return $output
    }
    
    [string] RenderCommands([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 5)
        $output += [VT]::TextBright() + "Quick Commands:" + [VT]::Reset()
        
        $commands = @(
            "[n] New task",
            "[t] Start timer", 
            "[e] Edit project",
            "[o] Open in explorer",
            "[r] Recent files"
        )
        
        $y = 7
        foreach ($cmd in $commands) {
            $output += [VT]::MoveTo($x, $y)
            $output += $cmd
            $y++
        }
        
        return $output
    }
    
    # Action methods
    [void] SelectCurrent() {
        if ($this.FocusedPane -eq 0) {
            # Move focus to details
            $this.FocusedPane = 1
        } elseif ($this.FocusedPane -eq 1) {
            # Open project workspace
            $this.FocusedPane = 2
            $this.ActiveTab = "Tasks"
        }
    }
    
    [void] GoBack() {
        if ($this.FocusedPane -gt 0) {
            $this.FocusedPane--
        } else {
            $this.Active = $false
        }
    }
    
    [void] NewTask() {
        # TODO: Implement new task dialog
        Write-Host "New task for project: $($this.SelectedProject.Nickname)"
    }
    
    [void] ToggleTimer() {
        # TODO: Implement timer toggle
        Write-Host "Toggle timer for task: $($this.SelectedTask.Title)"
    }
    
    [void] EditCurrent() {
        # TODO: Implement edit dialog
        Write-Host "Edit current item"
    }
    
    [void] ToggleFilter() {
        $this.ShowActiveOnly = -not $this.ShowActiveOnly
        $this.LoadProjects()
    }
}