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
    
    # Command mode
    [bool]$InCommandMode = $false
    [string]$CommandBuffer = ""
    [bool]$ShowCommandPalette = $false
    [string]$CommandSearch = ""
    [System.Collections.ArrayList]$FilteredCommands
    [int]$CommandIndex = 0
    
    # Layout dimensions - Fixed for proper alignment
    [int]$LeftWidth = 15
    [int]$MiddleWidth = 30
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
        
        # Calculate layout - ensure proper alignment
        $totalWidth = [Console]::WindowWidth
        $borders = 4  # 2 outer borders + 2 inner borders
        $this.RightWidth = $totalWidth - $this.LeftWidth - $this.MiddleWidth - $borders
        
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
        
        # Command mode
        $this.BindKey('/', { $this.StartCommand(); $this.RequestRender() })
        $this.BindKey('p', [System.ConsoleModifiers]::Control, { $this.ToggleCommandPalette(); $this.RequestRender() })
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
        
        # Context-aware status items based on focused pane and tab
        switch ($this.FocusedPane) {
            0 { # Projects list
                $this.StatusBarItems.Add("[N]ew")
                $this.StatusBarItems.Add("[E]dit")
                $this.StatusBarItems.Add("[F]ilter")
                $this.StatusBarItems.Add("[Enter] Select")
            }
            1 { # Project details
                $this.StatusBarItems.Add("[E]dit")
                $this.StatusBarItems.Add("[→] Tools")
                $this.StatusBarItems.Add("[Esc] Back")
            }
            2 { # Tools pane
                switch ($this.ActiveTab) {
                    "Tasks" {
                        $this.StatusBarItems.Add("[N]ew Task")
                        $this.StatusBarItems.Add("[Enter] Details")
                        $this.StatusBarItems.Add("[E]dit")
                    }
                    "Time" {
                        $this.StatusBarItems.Add("[N]ew Entry")
                        $this.StatusBarItems.Add("[E]xport")
                    }
                    "Notes" {
                        $this.StatusBarItems.Add("[Enter] Edit Notes")
                        $this.StatusBarItems.Add("[N]ew Note")
                    }
                    "Files" {
                        $this.StatusBarItems.Add("[F] Browse Files")
                        $this.StatusBarItems.Add("[Enter] Open")
                    }
                    "Commands" {
                        $this.StatusBarItems.Add("[Enter] Copy")
                        $this.StatusBarItems.Add("[Ctrl+P] Palette")
                    }
                }
            }
        }
        
        # Always show these
        $this.StatusBarItems.Add("[/] Command")
        $this.StatusBarItems.Add("[Tab] Next")
        $this.StatusBarItems.Add("[Q] Quit")
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Command palette overlay (if active)
        if ($this.ShowCommandPalette) {
            return $this.RenderCommandPalette()
        }
        
        # Tab bar at top
        $output += [VT]::MoveTo(0, 0)
        $output += $this.RenderTabBar()
        
        # Main content area
        $output += [VT]::MoveTo(0, 1)
        $output += $this.RenderMainArea()
        
        # Status bar at bottom
        $height = [Console]::WindowHeight
        $output += [VT]::MoveTo(0, $height - 2)
        $output += $this.RenderStatusBar()
        
        # Command input line - dedicated row
        $output += [VT]::MoveTo(0, $height - 1)
        $output += $this.RenderCommandLine()
        
        return $output
    }
    
    [string] RenderCommandBar() {
        $width = [Console]::WindowWidth
        $commands = "/task new  /time start  /note add  /file open"
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
        $height = [Console]::WindowHeight - 3  # Leave room for tab, status, command bars
        
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
        $output += [VT]::MoveTo(0, 1)
        $output += [VT]::Border()
        $output += "├" + ("─" * $this.LeftWidth) + "┬" + ("─" * $this.MiddleWidth) + "┬" + ("─" * $this.RightWidth) + "┤"
        $output += [VT]::Reset()
        
        # Vertical borders with correct spacing
        for ($i = 2; $i -lt $height + 1; $i++) {
            $output += [VT]::MoveTo(0, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 2, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo([Console]::WindowWidth - 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(0, $height + 1)
        $output += [VT]::Border()
        $output += "├" + ("─" * $this.LeftWidth) + "┴" + ("─" * $this.MiddleWidth) + "┴" + ("─" * $this.RightWidth) + "┤"
        $output += [VT]::Reset()
        
        # Pane titles with focus indicator
        $projectTitle = if ($this.FocusedPane -eq 0) { "▶ PROJECTS" } else { "PROJECTS" }
        $detailTitle = if ($this.FocusedPane -eq 1) { "▶ PROJECT DETAILS" } else { "PROJECT DETAILS" }
        $toolsTitle = if ($this.FocusedPane -eq 2) { "▶ " } else { "" }
        $toolsTitle += "PROJECT TOOLS: " + $this.ActiveTab.ToUpper()
        
        $output += [VT]::MoveTo(1, 2) + [VT]::TextBright() + $projectTitle + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + 2, 2) + [VT]::TextBright() + $detailTitle + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 3, 2) + [VT]::TextBright() + $toolsTitle + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderProjectsPane([int]$height) {
        $output = ""
        $startY = 4
        
        # Quick filters
        $output += [VT]::MoveTo(1, $startY)
        $output += [VT]::TextDim() + "Filter:" + [VT]::Reset()
        $output += [VT]::MoveTo(1, $startY + 1)
        $output += if ($this.ShowActiveOnly) { [VT]::Accent() + "☑" + [VT]::Reset() } else { "☐" }
        $output += " Active"
        
        # Project list
        $listStartY = $startY + 3
        $maxItems = $height - 8
        
        for ($i = 0; $i -lt [Math]::Min($this.Projects.Count, $maxItems); $i++) {
            $project = $this.Projects[$i]
            $output += [VT]::MoveTo(1, $listStartY + $i)
            
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
            
            # Status indicator
            if ($project.ClosedDate -ne [DateTime]::MinValue) {
                $output += [VT]::TextDim() + "✓ " + [VT]::Reset()
            } elseif ($project.DateDue -lt [DateTime]::Now) {
                $output += [VT]::Error() + "! " + [VT]::Reset()
            } else {
                $output += "  "
            }
            
            # Truncate nickname to fit
            $name = $project.Nickname
            if ($name.Length -gt ($this.LeftWidth - 5)) {
                $name = $name.Substring(0, $this.LeftWidth - 8) + "..."
            }
            
            $output += $name
            if ($i -eq $this.ProjectIndex) {
                $output += [VT]::Reset()
            }
        }
        
        # New button
        $output += [VT]::MoveTo(1, $height - 1)
        if ($this.FocusedPane -eq 0) {
            $output += [VT]::Accent() + "[+ New]" + [VT]::Reset()
        } else {
            $output += "[+ New]"
        }
        
        return $output
    }
    
    [string] RenderDetailsPane([int]$height) {
        $output = ""
        $startY = 4
        $x = $this.LeftWidth + 2
        
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
        $startY = 4
        
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
        $output += [VT]::MoveTo($x, 4)
        $output += [VT]::TextBright() + "Time This Week:" + [VT]::Reset()
        
        # Mock time data for now
        $output += [VT]::MoveTo($x, 6)
        $output += "Mon ████░ 6.5h"
        $output += [VT]::MoveTo($x, 7)
        $output += "Tue ███░░ 4.2h"
        $output += [VT]::MoveTo($x, 8)
        $output += "Today █░░░ 2.1h"
        
        return $output
    }
    
    [string] RenderNotes([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 4)
        $output += [VT]::TextBright() + "Project Notes:" + [VT]::Reset()
        $output += [VT]::MoveTo($x, 6)
        $output += "[Enter] Open notes.md"
        
        return $output
    }
    
    [string] RenderFiles([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 4)
        $output += [VT]::TextBright() + "Project Files:" + [VT]::Reset()
        $output += [VT]::MoveTo($x, 6)
        $output += "📁 " + ($this.SelectedProject.CAAPath ?? "No path set")
        
        return $output
    }
    
    [string] RenderCommands([int]$x, [int]$height) {
        $output = ""
        $output += [VT]::MoveTo($x, 4)
        $output += [VT]::TextBright() + "Quick Commands:" + [VT]::Reset()
        
        $commands = @(
            "[n] New task",
            "[t] Start timer", 
            "[e] Edit project",
            "[o] Open in explorer",
            "[r] Recent files"
        )
        
        $y = 6
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
    
    [void] StartCommand() {
        $this.InCommandMode = $true
        $this.CommandBuffer = "/"
        $this.FocusedPane = -1  # Special focus state for command line
    }
    
    [void] ToggleCommandPalette() {
        $this.ShowCommandPalette = -not $this.ShowCommandPalette
        if ($this.ShowCommandPalette) {
            $this.CommandSearch = ""
            $this.CommandIndex = 0
            $this.UpdateFilteredCommands()
        }
    }
    
    [void] UpdateFilteredCommands() {
        if (-not $this.FilteredCommands) {
            $this.FilteredCommands = [System.Collections.ArrayList]::new()
        }
        $this.FilteredCommands.Clear()
        
        # Sample commands
        $commands = @(
            @{Name="task new"; Description="Create a new task"},
            @{Name="time start"; Description="Start time tracking"},
            @{Name="note add"; Description="Add a note"},
            @{Name="file open"; Description="Open project files"}
        )
        
        if ([string]::IsNullOrEmpty($this.CommandSearch)) {
            $this.FilteredCommands.AddRange($commands)
        } else {
            foreach ($cmd in $commands) {
                if ($cmd.Name -like "*$($this.CommandSearch)*" -or 
                    $cmd.Description -like "*$($this.CommandSearch)*") {
                    $this.FilteredCommands.Add($cmd) | Out-Null
                }
            }
        }
    }
    
    [string] RenderCommandLine() {
        $output = ""
        
        if ($this.InCommandMode) {
            # Command entry line with cursor
            $output += $this.CommandBuffer
            if ($this.FocusedPane -eq -1) {
                $output += "_"  # Show cursor
            }
        } else {
            # Empty line when not in command mode
            $output += " " * [Console]::WindowWidth
        }
        
        return $output
    }
    
    [string] RenderCommandPalette() {
        $output = [VT]::Clear()
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Calculate palette dimensions
        $paletteWidth = [Math]::Min(60, $width - 10)
        $paletteHeight = [Math]::Min(20, $height - 10)
        $startX = ($width - $paletteWidth) / 2
        $startY = ($height - $paletteHeight) / 2
        
        # Draw palette border
        $output += [VT]::MoveTo($startX, $startY)
        $output += [VT]::Border() + "┌" + ("─" * ($paletteWidth - 2)) + "┐" + [VT]::Reset()
        
        for ($i = 1; $i -lt $paletteHeight - 1; $i++) {
            $output += [VT]::MoveTo($startX, $startY + $i)
            $output += [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($startX + $paletteWidth - 1, $startY + $i)
            $output += [VT]::Border() + "│" + [VT]::Reset()
        }
        
        $output += [VT]::MoveTo($startX, $startY + $paletteHeight - 1)
        $output += [VT]::Border() + "└" + ("─" * ($paletteWidth - 2)) + "┘" + [VT]::Reset()
        
        # Title
        $output += [VT]::MoveTo($startX + 2, $startY + 1)
        $output += [VT]::TextBright() + "Command Palette" + [VT]::Reset()
        
        # Search box
        $output += [VT]::MoveTo($startX + 2, $startY + 3)
        $output += "Search: " + $this.CommandSearch + "_"
        
        # Command list
        $listStart = $startY + 5
        $maxItems = $paletteHeight - 7
        
        for ($i = 0; $i -lt [Math]::Min($this.FilteredCommands.Count, $maxItems); $i++) {
            $cmd = $this.FilteredCommands[$i]
            $output += [VT]::MoveTo($startX + 2, $listStart + $i)
            
            if ($i -eq $this.CommandIndex) {
                $output += [VT]::Selected() + "> " + $cmd.Name + [VT]::Reset()
            } else {
                $output += "  " + $cmd.Name
            }
            
            # Description
            $output += [VT]::TextDim() + " - " + $cmd.Description + [VT]::Reset()
        }
        
        # Instructions
        $output += [VT]::MoveTo($startX + 2, $startY + $paletteHeight - 2)
        $output += [VT]::TextDim() + "[Enter] Execute  [Esc] Cancel" + [VT]::Reset()
        
        return $output
    }
    
    [void] ProcessKeyPress([ConsoleKeyInfo]$key) {
        # Handle command mode input
        if ($this.InCommandMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.InCommandMode = $false
                    $this.CommandBuffer = ""
                    $this.FocusedPane = 0
                    $this.RequestRender()
                    return
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteCommand()
                    $this.InCommandMode = $false
                    $this.CommandBuffer = ""
                    $this.FocusedPane = 0
                    $this.RequestRender()
                    return
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CommandBuffer.Length -gt 1) {
                        $this.CommandBuffer = $this.CommandBuffer.Substring(0, $this.CommandBuffer.Length - 1)
                    }
                    $this.RequestRender()
                    return
                }
                default {
                    if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -eq ' ') {
                        $this.CommandBuffer += $key.KeyChar
                        $this.RequestRender()
                    }
                    return
                }
            }
        }
        
        # Handle command palette input
        if ($this.ShowCommandPalette) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.ShowCommandPalette = $false
                    $this.RequestRender()
                    return
                }
                ([ConsoleKey]::Enter) {
                    if ($this.FilteredCommands.Count -gt 0) {
                        $cmd = $this.FilteredCommands[$this.CommandIndex]
                        # Execute the selected command
                        $this.CommandBuffer = "/" + $cmd.Name
                        $this.ShowCommandPalette = $false
                        $this.ExecuteCommand()
                        $this.CommandBuffer = ""
                        $this.RequestRender()
                    }
                    return
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this.CommandIndex -gt 0) {
                        $this.CommandIndex--
                    }
                    $this.RequestRender()
                    return
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.CommandIndex -lt $this.FilteredCommands.Count - 1) {
                        $this.CommandIndex++
                    }
                    $this.RequestRender()
                    return
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CommandSearch.Length -gt 0) {
                        $this.CommandSearch = $this.CommandSearch.Substring(0, $this.CommandSearch.Length - 1)
                        $this.UpdateFilteredCommands()
                        $this.CommandIndex = 0
                    }
                    $this.RequestRender()
                    return
                }
                default {
                    if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar) -or $key.KeyChar -eq ' ') {
                        $this.CommandSearch += $key.KeyChar
                        $this.UpdateFilteredCommands()
                        $this.CommandIndex = 0
                        $this.RequestRender()
                    }
                    return
                }
            }
        }
        
        # Normal key processing
        ([Screen]$this).ProcessKeyPress($key)
    }
    
    [void] ExecuteCommand() {
        $cmd = $this.CommandBuffer.Substring(1).Trim()  # Remove leading /
        
        switch -Wildcard ($cmd) {
            "task new*" { $this.NewTask() }
            "time start*" { $this.ToggleTimer() }
            "note add*" { Write-Host "Adding note..." }
            "file open*" { Write-Host "Opening files..." }
            default { Write-Host "Unknown command: $cmd" }
        }
    }
}