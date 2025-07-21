# ProjectContextScreenV2 - Enhanced context-aware project workspace
# Full integration with project details, task management, file browser, and command palette

class ProjectContextScreenV2 : Screen {
    # Services
    [object]$ProjectService
    [object]$TaskService
    [object]$TimeTrackingService
    
    # Data
    [System.Collections.ArrayList]$Projects
    [System.Collections.ArrayList]$Tasks
    [System.Collections.ArrayList]$Commands  # Project-specific commands
    [object]$SelectedProject
    [object]$SelectedTask
    
    # UI State
    [int]$ProjectIndex = 0
    [int]$TaskIndex = 0
    [int]$CommandIndex = 0
    [int]$FileIndex = 0
    [int]$FocusedPane = 0  # 0=Projects, 1=Details, 2=Tools
    [string]$ActiveTab = "Tasks"  # Tasks, Time, Notes, Files, Commands
    [bool]$InCommandMode = $false
    [string]$CommandBuffer = ""
    [bool]$ShowTaskDetails = $false  # When true, shows task details instead of list
    [object]$ViewedTask = $null  # Task being viewed in detail
    
    # Scrolling for project details
    [int]$DetailScrollOffset = 0
    [int]$MaxDetailScroll = 0
    
    # File browser state
    [string]$CurrentPath = ""
    [System.Collections.ArrayList]$Files
    [object]$FileBrowser  # Embedded FileBrowserScreen instance
    
    # Layout dimensions
    [int]$LeftWidth = 15
    [int]$MiddleWidth = 30
    [int]$RightWidth = 0  # Calculated
    
    # Filter state
    [bool]$ShowActiveOnly = $true
    [bool]$ShowMyWork = $false
    
    # Command palette
    [bool]$ShowCommandPalette = $false
    [string]$CommandSearch = ""
    [System.Collections.ArrayList]$FilteredCommands
    
    ProjectContextScreenV2() {
        $this.Title = "PROJECT CONTEXT V2"
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
        
        # Initialize collections
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.Files = [System.Collections.ArrayList]::new()
        $this.FilteredCommands = [System.Collections.ArrayList]::new()
        
        # Load initial commands (these would be loaded from a file or service)
        $this.LoadDefaultCommands()
        
        # Load data
        $this.LoadProjects()
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Status bar
        $this.UpdateStatusBar()
    }
    
    [void] LoadDefaultCommands() {
        # Sample commands - these would be loaded from project-specific config
        $defaultCommands = @(
            @{Name="@auth_check_user"; Tags=@("auth", "user"); Description="Check user authentication"},
            @{Name="@auth_validate_token"; Tags=@("auth", "token"); Description="Validate auth token"},
            @{Name="@auth_reset_password"; Tags=@("auth", "password"); Description="Reset user password"},
            @{Name="@db_migrate"; Tags=@("database", "migration"); Description="Run database migrations"},
            @{Name="@test_unit"; Tags=@("test", "unit"); Description="Run unit tests"},
            @{Name="@deploy_staging"; Tags=@("deploy", "staging"); Description="Deploy to staging"}
        )
        
        foreach ($cmd in $defaultCommands) {
            $this.Commands.Add($cmd) | Out-Null
        }
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
            $this.LoadProjectFiles()
            $this.DetailScrollOffset = 0  # Reset scroll when changing projects
            $this.CalculateMaxDetailScroll()
        }
    }
    
    [void] LoadProjectTasks() {
        if (-not $this.SelectedProject) { return }
        
        $this.Tasks = [System.Collections.ArrayList]::new()
        $allTasks = $this.TaskService.GetAllTasks()
        
        foreach ($task in $allTasks) {
            if ($task.ProjectId -eq $this.SelectedProject.Id -or 
                $task.Project -eq $this.SelectedProject.Nickname) {
                $this.Tasks.Add($task) | Out-Null
            }
        }
        
        if ($this.Tasks.Count -gt 0 -and $this.TaskIndex -ge 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
            $this.SelectedTask = $this.Tasks[$this.TaskIndex]
        }
    }
    
    [void] LoadProjectFiles() {
        if (-not $this.SelectedProject) { return }
        
        # Set current path to project path or default
        if ($this.SelectedProject.CAAPath -and $this.SelectedProject.CAAPath -ne "" -and (Test-Path $this.SelectedProject.CAAPath)) {
            $this.CurrentPath = $this.SelectedProject.CAAPath
        } else {
            # Default to home or C:\
            $this.CurrentPath = if ([System.Environment]::OSVersion.Platform -eq 'Unix') { 
                [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            } else { 
                "C:\" 
            }
        }
        
        # Create embedded file browser if needed
        if (-not $this.FileBrowser) {
            $this.FileBrowser = [FileBrowserScreen]::new()
            $this.FileBrowser.CurrentPath = $this.CurrentPath
        } else {
            $this.FileBrowser.CurrentPath = $this.CurrentPath
            $this.FileBrowser.LoadDirectory($this.CurrentPath)
        }
    }
    
    [void] CalculateMaxDetailScroll() {
        # Calculate how many lines of detail we have vs display space
        $displayHeight = [Console]::WindowHeight - 10  # Account for borders, headers, etc.
        $detailLines = 20  # Approximate number of detail lines (adjust based on actual content)
        $this.MaxDetailScroll = [Math]::Max(0, $detailLines - $displayHeight)
    }
    
    [void] InitializeKeyBindings() {
        # Navigation
        $this.BindKey([ConsoleKey]::UpArrow, { $this.NavigateUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::DownArrow, { $this.NavigateDown(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::LeftArrow, { $this.NavigateLeft(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::RightArrow, { $this.NavigateRight(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Tab, { $this.NextTab(); $this.RequestRender() })
        $this.BindKey('[', { $this.PrevTab(); $this.RequestRender() })
        $this.BindKey(']', { $this.NextTab(); $this.RequestRender() })
        
        # Actions
        $this.BindKey([ConsoleKey]::Enter, { $this.SelectCurrent(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::Escape, { $this.GoBack(); $this.RequestRender() })
        $this.BindKey('q', { $this.Active = $false })
        
        # Commands
        $this.BindKey('/', { $this.StartCommand(); $this.RequestRender() })
        
        # Command Palette
        $this.BindKey([ConsoleKey]::P, { 
            if ([Console]::KeyAvailable) {
                $nextKey = [Console]::ReadKey($true)
                if ($nextKey.Modifiers -band [ConsoleModifiers]::Control) {
                    $this.ToggleCommandPalette()
                    $this.RequestRender()
                }
            }
        })
        
        # Quick actions (context-aware)
        $this.BindKey('n', { $this.NewItem(); $this.RequestRender() })
        $this.BindKey('e', { $this.EditCurrent(); $this.RequestRender() })
        $this.BindKey('d', { $this.DeleteCurrent(); $this.RequestRender() })
        $this.BindKey('f', { $this.ToggleFilter(); $this.RequestRender() })
        
        # Scrolling for details pane
        $this.BindKey([ConsoleKey]::PageUp, { $this.ScrollUp(); $this.RequestRender() })
        $this.BindKey([ConsoleKey]::PageDown, { $this.ScrollDown(); $this.RequestRender() })
    }
    
    [void] NavigateUp() {
        if ($this.ShowCommandPalette) {
            if ($this.CommandIndex -gt 0) {
                $this.CommandIndex--
            }
            return
        }
        
        switch ($this.FocusedPane) {
            0 { # Projects
                if ($this.ProjectIndex -gt 0) {
                    $this.SelectProject($this.ProjectIndex - 1)
                }
            }
            1 { # Details - scroll up
                $this.ScrollUp()
            }
            2 { # Tools
                switch ($this.ActiveTab) {
                    "Tasks" {
                        if (-not $this.ShowTaskDetails -and $this.TaskIndex -gt 0) {
                            $this.TaskIndex--
                            if ($this.TaskIndex -lt $this.Tasks.Count) {
                                $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                            }
                        }
                    }
                    "Files" {
                        if ($this.FileBrowser) {
                            $this.FileBrowser.NavigateUp()
                        }
                    }
                    "Commands" {
                        if ($this.CommandIndex -gt 0) {
                            $this.CommandIndex--
                        }
                    }
                }
            }
        }
    }
    
    [void] NavigateDown() {
        if ($this.ShowCommandPalette) {
            if ($this.CommandIndex -lt $this.FilteredCommands.Count - 1) {
                $this.CommandIndex++
            }
            return
        }
        
        switch ($this.FocusedPane) {
            0 { # Projects
                if ($this.ProjectIndex -lt $this.Projects.Count - 1) {
                    $this.SelectProject($this.ProjectIndex + 1)
                }
            }
            1 { # Details - scroll down
                $this.ScrollDown()
            }
            2 { # Tools
                switch ($this.ActiveTab) {
                    "Tasks" {
                        if (-not $this.ShowTaskDetails -and $this.TaskIndex -lt $this.Tasks.Count - 1) {
                            $this.TaskIndex++
                            if ($this.TaskIndex -lt $this.Tasks.Count) {
                                $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                            }
                        }
                    }
                    "Files" {
                        if ($this.FileBrowser) {
                            $this.FileBrowser.NavigateDown()
                        }
                    }
                    "Commands" {
                        if ($this.CommandIndex -lt $this.Commands.Count - 1) {
                            $this.CommandIndex++
                        }
                    }
                }
            }
        }
    }
    
    [void] ScrollUp() {
        if ($this.DetailScrollOffset -gt 0) {
            $this.DetailScrollOffset--
        }
    }
    
    [void] ScrollDown() {
        if ($this.DetailScrollOffset -lt $this.MaxDetailScroll) {
            $this.DetailScrollOffset++
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
        $this.ShowTaskDetails = $false  # Reset to list view when changing tabs
    }
    
    [void] PrevTab() {
        $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
        $currentIndex = $tabs.IndexOf($this.ActiveTab)
        $prevIndex = if ($currentIndex -eq 0) { $tabs.Count - 1 } else { $currentIndex - 1 }
        $this.ActiveTab = $tabs[$prevIndex]
        $this.ShowTaskDetails = $false  # Reset to list view when changing tabs
    }
    
    [void] StartCommand() {
        $this.InCommandMode = $true
        $this.CommandBuffer = "/"
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
        $this.FilteredCommands.Clear()
        
        if ([string]::IsNullOrEmpty($this.CommandSearch)) {
            $this.FilteredCommands.AddRange($this.Commands)
        } else {
            foreach ($cmd in $this.Commands) {
                if ($cmd.Name -like "*$($this.CommandSearch)*" -or 
                    $cmd.Description -like "*$($this.CommandSearch)*" -or
                    ($cmd.Tags | Where-Object { $_ -like "*$($this.CommandSearch)*" })) {
                    $this.FilteredCommands.Add($cmd) | Out-Null
                }
            }
        }
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
                $this.StatusBarItems.Add("[PgUp/Dn] Scroll")
                $this.StatusBarItems.Add("[→] Tools")
                $this.StatusBarItems.Add("[Esc] Back")
            }
            2 { # Tools pane
                switch ($this.ActiveTab) {
                    "Tasks" {
                        if ($this.ShowTaskDetails) {
                            $this.StatusBarItems.Add("[E]dit")
                            $this.StatusBarItems.Add("[D]elete")
                            $this.StatusBarItems.Add("[Esc] Back to list")
                        } else {
                            $this.StatusBarItems.Add("[N]ew Task")
                            $this.StatusBarItems.Add("[Enter] Details")
                            $this.StatusBarItems.Add("[E]dit")
                        }
                    }
                    "Files" {
                        $this.StatusBarItems.Add("[Enter] Open")
                        $this.StatusBarItems.Add("[N]ew")
                        $this.StatusBarItems.Add("[D]elete")
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
        $this.StatusBarItems.Add("[\[] Prev")
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Command palette overlay (if active)
        if ($this.ShowCommandPalette) {
            return $this.RenderCommandPalette()
        }
        
        # Main layout
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
        
        # Command input line if in command mode
        if ($this.InCommandMode) {
            $output += [VT]::MoveTo(0, $height - 1)
            $output += [VT]::TextBright() + $this.CommandBuffer + [VT]::Reset()
        }
        
        return $output
    }
    
    [string] RenderCommandPalette() {
        $output = [VT]::Clear()
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Calculate palette dimensions
        $paletteWidth = [Math]::Min(60, $width - 20)
        $paletteHeight = [Math]::Min(20, $height - 10)
        $startX = ($width - $paletteWidth) / 2
        $startY = 5
        
        # Draw palette border
        $output += [VT]::MoveTo($startX, $startY)
        $output += [VT]::Border() + "┌" + ("─" * ($paletteWidth - 2)) + "┐" + [VT]::Reset()
        
        # Title
        $output += [VT]::MoveTo($startX, $startY + 1)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        $title = " Command Palette (Ctrl+P to close) "
        $titlePadding = ($paletteWidth - $title.Length - 2) / 2
        $output += " " * $titlePadding + [VT]::TextBright() + $title + [VT]::Reset()
        $output += " " * ($paletteWidth - $title.Length - $titlePadding - 2)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        
        # Search box
        $output += [VT]::MoveTo($startX, $startY + 2)
        $output += [VT]::Border() + "│ " + [VT]::Reset()
        $output += [VT]::TextDim() + "Search: " + [VT]::Reset()
        $output += $this.CommandSearch + "_"
        $remainingSpace = $paletteWidth - $this.CommandSearch.Length - 11
        $output += " " * $remainingSpace
        $output += [VT]::Border() + "│" + [VT]::Reset()
        
        # Separator
        $output += [VT]::MoveTo($startX, $startY + 3)
        $output += [VT]::Border() + "├" + ("─" * ($paletteWidth - 2)) + "┤" + [VT]::Reset()
        
        # Commands list
        $listStart = $startY + 4
        $maxItems = $paletteHeight - 6
        
        for ($i = 0; $i -lt [Math]::Min($this.FilteredCommands.Count, $maxItems); $i++) {
            $cmd = $this.FilteredCommands[$i]
            $output += [VT]::MoveTo($startX, $listStart + $i)
            $output += [VT]::Border() + "│ " + [VT]::Reset()
            
            if ($i -eq $this.CommandIndex) {
                $output += [VT]::Selected()
            }
            
            # Command name
            $cmdText = $cmd.Name.PadRight(20)
            $output += $cmdText
            
            # Description
            $desc = $cmd.Description
            if ($desc.Length -gt ($paletteWidth - 25)) {
                $desc = $desc.Substring(0, $paletteWidth - 28) + "..."
            }
            $output += [VT]::TextDim() + " " + $desc + [VT]::Reset()
            
            # Padding
            $totalLength = $cmdText.Length + $desc.Length + 1
            $padding = $paletteWidth - $totalLength - 4
            $output += " " * $padding
            
            if ($i -eq $this.CommandIndex) {
                $output += [VT]::Reset()
            }
            
            $output += [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Fill remaining space
        for ($i = $this.FilteredCommands.Count; $i -lt $maxItems; $i++) {
            $output += [VT]::MoveTo($startX, $listStart + $i)
            $output += [VT]::Border() + "│" + (" " * ($paletteWidth - 2)) + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo($startX, $startY + $paletteHeight - 1)
        $output += [VT]::Border() + "└" + ("─" * ($paletteWidth - 2)) + "┘" + [VT]::Reset()
        
        # Instructions
        $output += [VT]::MoveTo($startX + 2, $startY + $paletteHeight)
        $output += [VT]::TextDim() + "[Enter] Copy to clipboard  [Esc] Cancel" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderTabBar() {
        $tabs = @("Projects", "Tasks", "Time", "Notes", "Files", "Commands")
        $output = ""
        
        foreach ($tab in $tabs) {
            if ($tab -eq "Projects" -or ($this.FocusedPane -eq 2 -and $tab -eq $this.ActiveTab)) {
                $output += [VT]::Accent() + "[*$tab*]" + [VT]::Reset()
            } else {
                $output += "[$tab]"
            }
        }
        
        $output += "          Tab → or ] Next | [ Prev"
        return $output
    }
    
    [string] RenderMainArea() {
        $output = ""
        $height = [Console]::WindowHeight - 3  # Leave room for tab and status bars
        
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
        $output += "├" + ("─" * ($this.LeftWidth)) + "┬" + ("─" * ($this.MiddleWidth)) + "┬" + ("─" * ($this.RightWidth)) + "┤"
        $output += [VT]::Reset()
        
        # Vertical borders
        for ($i = 2; $i -lt $height + 1; $i++) {
            $output += [VT]::MoveTo(0, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 2, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo([Console]::WindowWidth - 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(0, $height + 1)
        $output += [VT]::Border()
        $output += "├" + ("─" * ($this.LeftWidth)) + "┴" + ("─" * ($this.MiddleWidth)) + "┴" + ("─" * ($this.RightWidth)) + "┤"
        $output += [VT]::Reset()
        
        # Pane titles
        $output += [VT]::MoveTo(2, 2) + [VT]::TextBright() + "PROJECTS" + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + 3, 2) + [VT]::TextBright() + "PROJECT DETAILS" + [VT]::Reset()
        
        # Tools pane title changes based on active tab
        $toolsTitle = "PROJECT TOOLS: " + $this.ActiveTab.ToUpper()
        $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth + 4, 2) + [VT]::TextBright() + $toolsTitle + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderProjectsPane([int]$height) {
        $output = ""
        $startY = 4
        
        # Quick filters
        $output += [VT]::MoveTo(2, $startY)
        $output += [VT]::TextDim() + "Filter:" + [VT]::Reset()
        $output += [VT]::MoveTo(2, $startY + 1)
        $output += if ($this.ShowActiveOnly) { [VT]::Accent() + "☑" + [VT]::Reset() } else { "☐" }
        $output += " Active"
        
        # Project list
        $listStartY = $startY + 3
        $maxItems = $height - 8
        
        for ($i = 0; $i -lt [Math]::Min($this.Projects.Count, $maxItems); $i++) {
            $project = $this.Projects[$i]
            $output += [VT]::MoveTo(2, $listStartY + $i)
            
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
            if ($name.Length -gt ($this.LeftWidth - 6)) {
                $name = $name.Substring(0, $this.LeftWidth - 9) + "..."
            }
            
            $output += $name
            if ($i -eq $this.ProjectIndex) {
                $output += [VT]::Reset()
            }
        }
        
        # New button
        $output += [VT]::MoveTo(2, $height - 1)
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
        $x = $this.LeftWidth + 3
        
        if (-not $this.SelectedProject) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "Select a project" + [VT]::Reset()
            return $output
        }
        
        $p = $this.SelectedProject
        $y = $startY - $this.DetailScrollOffset
        
        # Helper function to add a detail line
        $addDetail = {
            param($label, $value, $highlight = $false)
            if ($y -ge $startY -and $y -lt ($height - 2)) {
                $script:output += [VT]::MoveTo($x, $y)
                if ($highlight) {
                    $script:output += [VT]::TextBright() + $label + [VT]::Reset() + $value
                } else {
                    $script:output += [VT]::TextDim() + $label + [VT]::Reset() + $value
                }
            }
            $script:y++
        }
        
        # Project name (always visible at top)
        $output += [VT]::MoveTo($x, $startY - 1)
        $output += [VT]::Accent() + $p.FullProjectName + [VT]::Reset()
        
        # All project details (scrollable)
        & $addDetail "Nickname: " $p.Nickname $true
        & $addDetail "ID1: " $p.ID1
        & $addDetail "ID2: " $p.ID2
        $y++  # Blank line
        
        & $addDetail "Dates:" "" $true
        & $addDetail "  Assigned: " $p.DateAssigned.ToString("yyyy-MM-dd")
        & $addDetail "  BF Date: " $p.BFDate.ToString("yyyy-MM-dd")
        & $addDetail "  Due Date: " $p.DateDue.ToString("yyyy-MM-dd")
        
        # Calculate days remaining
        $daysLeft = ($p.DateDue - [DateTime]::Now).Days
        $daysColor = if ($daysLeft -lt 7) { [VT]::Error() } elseif ($daysLeft -lt 14) { [VT]::Warning() } else { "" }
        & $addDetail "  Days Left: " ($daysColor + $daysLeft + " days" + [VT]::Reset())
        $y++
        
        & $addDetail "Progress:" "" $true
        & $addDetail "  Hours Used: " "$($p.CumulativeHrs) hrs"
        
        # Progress bar
        if ($y -ge $startY -and $y -lt ($height - 2)) {
            $output += [VT]::MoveTo($x, $y)
            $progress = [int]($p.CumulativeHrs / 200 * 10)
            $output += "  Progress: " + [VT]::Accent() + ("█" * $progress) + [VT]::TextDim() + ("░" * (10 - $progress)) + [VT]::Reset()
        }
        $y += 2
        
        & $addDetail "Paths:" "" $true
        if ($p.CAAPath) { & $addDetail "  CAA: " $p.CAAPath }
        if ($p.RequestPath) { & $addDetail "  REQ: " $p.RequestPath }
        if ($p.T2020Path) { & $addDetail "  T20: " $p.T2020Path }
        $y++
        
        if ($p.Note) {
            & $addDetail "Notes:" "" $true
            # Word wrap notes
            $words = $p.Note -split ' '
            $line = "  "
            $maxLineLength = $this.MiddleWidth - 5
            
            foreach ($word in $words) {
                if (($line + $word).Length -gt $maxLineLength) {
                    & $addDetail "" $line
                    $line = "  $word "
                } else {
                    $line += "$word "
                }
            }
            if ($line.Trim()) {
                & $addDetail "" $line
            }
        }
        
        # Scroll indicator
        if ($this.MaxDetailScroll -gt 0) {
            $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth - 2, $startY)
            $output += [VT]::TextDim()
            
            # Calculate scroll position
            $scrollHeight = $height - 6
            $scrollPos = [int]($this.DetailScrollOffset / $this.MaxDetailScroll * $scrollHeight)
            
            for ($i = 0; $i -lt $scrollHeight; $i++) {
                $output += [VT]::MoveTo($this.LeftWidth + $this.MiddleWidth - 2, $startY + $i)
                if ($i -eq $scrollPos) {
                    $output += "█"
                } else {
                    $output += "│"
                }
            }
            $output += [VT]::Reset()
        }
        
        # Focus indicator
        if ($this.FocusedPane -eq 1) {
            $output += [VT]::MoveTo($x, $height - 2)
            $output += [VT]::TextDim() + "[PgUp/PgDn to scroll]" + [VT]::Reset()
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
            "Tasks" { 
                if ($this.ShowTaskDetails) {
                    $output += $this.RenderTaskDetails($x, $height)
                } else {
                    $output += $this.RenderTaskList($x, $height)
                }
            }
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
        
        if ($this.Tasks.Count -eq 0) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "No tasks for this project" + [VT]::Reset()
            return $output
        }
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Tasks ($($this.Tasks.Count)):" + [VT]::Reset()
        
        $y = $startY + 2
        $maxItems = $height - 6
        
        for ($i = 0; $i -lt [Math]::Min($this.Tasks.Count, $maxItems); $i++) {
            $task = $this.Tasks[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Task status
            switch ($task.Status) {
                "Completed" { $output += [VT]::Success() + "✓ " + [VT]::Reset() }
                "InProgress" { $output += [VT]::Warning() + "⚡ " + [VT]::Reset() }
                default { $output += "○ " }
            }
            
            # Priority indicator
            switch ($task.Priority) {
                "High" { $output += [VT]::Error() + "!" + [VT]::Reset() }
                "Medium" { $output += [VT]::Warning() + "-" + [VT]::Reset() }
                default { $output += " " }
            }
            
            # Task title (truncated)
            $title = " " + $task.Title
            if ($title.Length -gt ($this.RightWidth - 8)) {
                $title = $title.Substring(0, $this.RightWidth - 11) + "..."
            }
            
            $output += $title
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        # Quick stats
        $output += [VT]::MoveTo($x, $height - 3)
        $completed = ($this.Tasks | Where-Object { $_.Status -eq "Completed" }).Count
        $output += [VT]::TextDim() + "$completed completed, $($this.Tasks.Count - $completed) remaining" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderTaskDetails([int]$x, [int]$height) {
        $output = ""
        $startY = 4
        
        if (-not $this.ViewedTask) {
            return $this.RenderTaskList($x, $height)
        }
        
        $task = $this.ViewedTask
        
        # Back navigation hint
        $output += [VT]::MoveTo($x, $startY - 1)
        $output += [VT]::TextDim() + "← Tasks" + [VT]::Reset()
        
        # Task title
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + $task.Title + [VT]::Reset()
        
        $y = $startY + 2
        
        # Status and Priority
        $output += [VT]::MoveTo($x, $y++)
        $output += "Status: " + [VT]::Accent() + $task.Status + [VT]::Reset()
        
        $output += [VT]::MoveTo($x, $y++)
        $priorityColor = switch($task.Priority) {
            "High" { [VT]::Error() }
            "Medium" { [VT]::Warning() }
            default { "" }
        }
        $output += "Priority: " + $priorityColor + $task.Priority + [VT]::Reset()
        
        $y++
        
        # Description
        if ($task.Description) {
            $output += [VT]::MoveTo($x, $y++)
            $output += [VT]::TextDim() + "Description:" + [VT]::Reset()
            
            # Word wrap description
            $words = $task.Description -split ' '
            $line = ""
            $maxLineLength = $this.RightWidth - 4
            
            foreach ($word in $words) {
                if (($line + $word).Length -gt $maxLineLength) {
                    $output += [VT]::MoveTo($x, $y++)
                    $output += $line
                    $line = "$word "
                } else {
                    $line += "$word "
                }
            }
            if ($line.Trim()) {
                $output += [VT]::MoveTo($x, $y++)
                $output += $line
            }
        }
        
        $y++
        
        # Subtasks
        if ($task.Subtasks -and $task.Subtasks.Count -gt 0) {
            $output += [VT]::MoveTo($x, $y++)
            $output += [VT]::TextDim() + "Subtasks:" + [VT]::Reset()
            
            foreach ($subtask in $task.Subtasks) {
                $output += [VT]::MoveTo($x, $y++)
                $check = if ($subtask.Completed) { "☑" } else { "☐" }
                $output += "  $check $($subtask.Title)"
            }
        }
        
        # Time tracking
        if ($task.TimeSpent -gt 0) {
            $y++
            $output += [VT]::MoveTo($x, $y++)
            $hours = [Math]::Round($task.TimeSpent / 3600, 1)
            $output += "Time Spent: " + [VT]::Accent() + "$hours hours" + [VT]::Reset()
        }
        
        # Actions hint
        $output += [VT]::MoveTo($x, $height - 2)
        $output += [VT]::TextDim() + "[E]dit [D]elete [Esc] Back" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderTimeEntries([int]$x, [int]$height) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Time Tracking:" + [VT]::Reset()
        
        if ($this.TimeTrackingService) {
            # Get actual time entries
            $entries = $this.TimeTrackingService.GetEntriesByProject($this.SelectedProject.Nickname)
            
            if ($entries.Count -gt 0) {
                $y = $startY + 2
                
                # Group by date
                $grouped = $entries | Group-Object { $_.StartTime.Date } | Sort-Object Name -Descending
                
                foreach ($group in $grouped | Select-Object -First 5) {
                    $output += [VT]::MoveTo($x, $y++)
                    $date = [DateTime]::Parse($group.Name)
                    $output += [VT]::TextDim() + $date.ToString("MMM dd") + [VT]::Reset()
                    
                    $totalHours = 0
                    foreach ($entry in $group.Group) {
                        $hours = ($entry.EndTime - $entry.StartTime).TotalHours
                        $totalHours += $hours
                    }
                    
                    $output += [VT]::MoveTo($x + 10, $y - 1)
                    $barLength = [int]($totalHours / 8 * 10)
                    $output += [VT]::Accent() + ("█" * $barLength) + [VT]::TextDim() + ("░" * (10 - $barLength)) + [VT]::Reset()
                    $output += " " + [Math]::Round($totalHours, 1) + "h"
                    
                    $y++
                }
                
                # Weekly total
                $y++
                $output += [VT]::MoveTo($x, $y)
                $weekTotal = ($entries | Where-Object { $_.StartTime -gt [DateTime]::Now.AddDays(-7) } | 
                             ForEach-Object { ($_.EndTime - $_.StartTime).TotalHours } | 
                             Measure-Object -Sum).Sum
                $output += [VT]::TextBright() + "Week Total: " + [Math]::Round($weekTotal, 1) + " hours" + [VT]::Reset()
            } else {
                $output += [VT]::MoveTo($x, $startY + 2)
                $output += [VT]::TextDim() + "No time entries yet" + [VT]::Reset()
            }
        } else {
            # Mock data fallback
            $output += [VT]::MoveTo($x, $startY + 2)
            $output += "Mon ████░ 6.5h"
            $output += [VT]::MoveTo($x, $startY + 3)
            $output += "Tue ███░░ 4.2h"
            $output += [VT]::MoveTo($x, $startY + 4)
            $output += "Today █░░░ 2.1h"
        }
        
        return $output
    }
    
    [string] RenderNotes([int]$x, [int]$height) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Project Notes:" + [VT]::Reset()
        
        # Check if project has a valid path
        if (-not $this.SelectedProject.CAAPath -or $this.SelectedProject.CAAPath -eq "") {
            $output += [VT]::MoveTo($x, $startY + 2)
            $output += [VT]::TextDim() + "No project path set" + [VT]::Reset()
            $output += [VT]::MoveTo($x, $startY + 4)
            $output += [VT]::TextDim() + "Set CAAPath in project" + [VT]::Reset()
            $output += [VT]::MoveTo($x, $startY + 5)
            $output += [VT]::TextDim() + "settings to enable notes" + [VT]::Reset()
            return $output
        }
        
        $notesPath = Join-Path $this.SelectedProject.CAAPath "notes.md"
        
        $output += [VT]::MoveTo($x, $startY + 2)
        if (Test-Path $notesPath) {
            $output += [VT]::Success() + "✓ " + [VT]::Reset() + "notes.md exists"
            
            # Show preview
            try {
                $content = Get-Content $notesPath -First 10
                $y = $startY + 4
                $output += [VT]::MoveTo($x, $y++)
                $output += [VT]::TextDim() + "Preview:" + [VT]::Reset()
                
                foreach ($line in $content) {
                    if ($y -ge $height - 3) { break }
                    $output += [VT]::MoveTo($x, $y++)
                    if ($line.Length -gt ($this.RightWidth - 4)) {
                        $line = $line.Substring(0, $this.RightWidth - 7) + "..."
                    }
                    $output += [VT]::TextDim() + $line + [VT]::Reset()
                }
            } catch {
                # Ignore read errors
            }
        } else {
            $output += [VT]::TextDim() + "No notes file" + [VT]::Reset()
        }
        
        $output += [VT]::MoveTo($x, $height - 3)
        $output += "[Enter] Open in editor"
        
        return $output
    }
    
    [string] RenderFiles([int]$x, [int]$height) {
        $output = ""
        $startY = 4
        
        if (-not $this.FileBrowser) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "File browser not initialized" + [VT]::Reset()
            return $output
        }
        
        # Current path
        $output += [VT]::MoveTo($x, $startY)
        $path = $this.FileBrowser.CurrentPath
        if ($path.Length -gt ($this.RightWidth - 4)) {
            $path = "..." + $path.Substring($path.Length - ($this.RightWidth - 7))
        }
        $output += [VT]::TextDim() + "📁 " + $path + [VT]::Reset()
        
        # File list
        $y = $startY + 2
        $maxItems = $height - 7
        $fileList = $this.FileBrowser.CurrentFiles
        
        for ($i = 0; $i -lt [Math]::Min($fileList.Count, $maxItems); $i++) {
            $item = $fileList[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.FileBrowser.SelectedIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Handle different item types
            $name = ""
            if ($item -eq "..") {
                $output += "📁 "
                $name = ".."
            } elseif ($item -is [System.IO.DirectoryInfo]) {
                $output += "📁 "
                $name = $item.Name
            } elseif ($item -is [System.IO.FileInfo]) {
                $output += "📄 "
                $name = $item.Name
            } else {
                $name = $item.ToString()
            }
            if ($name.Length -gt ($this.RightWidth - 8)) {
                $name = $name.Substring(0, $this.RightWidth - 11) + "..."
            }
            
            $output += $name
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.FileBrowser.SelectedIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        # Quick stats
        $output += [VT]::MoveTo($x, $height - 3)
        $dirCount = ($fileList | Where-Object { $_ -is [System.IO.DirectoryInfo] -or $_ -eq ".." }).Count
        $fileCount = ($fileList | Where-Object { $_ -is [System.IO.FileInfo] }).Count
        $output += [VT]::TextDim() + "$dirCount folders, $fileCount files" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderCommands([int]$x, [int]$height) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Quick Commands:" + [VT]::Reset()
        
        $y = $startY + 2
        $maxItems = $height - 6
        
        for ($i = 0; $i -lt [Math]::Min($this.Commands.Count, $maxItems); $i++) {
            $cmd = $this.Commands[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.CommandIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Command name
            $name = $cmd.Name
            if ($name.Length -gt 20) {
                $name = $name.Substring(0, 17) + "..."
            }
            $output += $name.PadRight(20)
            
            # Tags
            if ($cmd.Tags -and $cmd.Tags.Count -gt 0) {
                $output += [VT]::TextDim() + " #" + ($cmd.Tags -join " #") + [VT]::Reset()
            }
            
            if ($this.FocusedPane -eq 2 -and $i -eq $this.CommandIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        # Selected command description
        if ($this.Commands.Count -gt 0 -and $this.CommandIndex -lt $this.Commands.Count) {
            $output += [VT]::MoveTo($x, $height - 4)
            $desc = $this.Commands[$this.CommandIndex].Description
            if ($desc.Length -gt ($this.RightWidth - 4)) {
                $desc = $desc.Substring(0, $this.RightWidth - 7) + "..."
            }
            $output += [VT]::TextDim() + $desc + [VT]::Reset()
        }
        
        $output += [VT]::MoveTo($x, $height - 2)
        $output += "[Ctrl+P] Command Palette"
        
        return $output
    }
    
    # Action methods
    [void] SelectCurrent() {
        if ($this.ShowCommandPalette) {
            # Copy selected command to clipboard
            if ($this.FilteredCommands.Count -gt 0 -and $this.CommandIndex -lt $this.FilteredCommands.Count) {
                $cmd = $this.FilteredCommands[$this.CommandIndex]
                # Copy to clipboard - platform specific
                if ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                    $cmd.Name | & xclip -selection clipboard 2>$null || Write-Host "Command copied: $($cmd.Name)"
                } else {
                    Set-Clipboard -Value $cmd.Name 2>$null || Write-Host "Command copied: $($cmd.Name)"
                }
                $this.ShowCommandPalette = $false
            }
            return
        }
        
        switch ($this.FocusedPane) {
            0 { # Projects
                # Move focus to details
                $this.FocusedPane = 1
            }
            1 { # Details
                # Move to tools
                $this.FocusedPane = 2
                $this.ActiveTab = "Tasks"
            }
            2 { # Tools
                switch ($this.ActiveTab) {
                    "Tasks" {
                        if ($this.ShowTaskDetails) {
                            # Already in details, do nothing
                        } else {
                            # Show task details
                            if ($this.Tasks.Count -gt 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
                                $this.ViewedTask = $this.Tasks[$this.TaskIndex]
                                $this.ShowTaskDetails = $true
                            }
                        }
                    }
                    "Notes" {
                        # Open notes in editor
                        if ($this.SelectedProject) {
                            if (-not $this.SelectedProject.CAAPath -or $this.SelectedProject.CAAPath -eq "") {
                                Write-Host "Cannot open notes: Project has no CAAPath set"
                                return
                            }
                            
                            $notesPath = Join-Path $this.SelectedProject.CAAPath "notes.md"
                            
                            # Create notes file if it doesn't exist
                            if (-not (Test-Path $notesPath)) {
                                New-Item -Path $notesPath -ItemType File -Force | Out-Null
                                Set-Content -Path $notesPath -Value "# $($this.SelectedProject.FullProjectName) Notes`n`n"
                            }
                            
                            # Open in text editor screen
                            $editor = New-Object TextEditorScreen
                            $editor.LoadFile($notesPath)
                            $global:ScreenManager.Push($editor)
                        }
                    }
                    "Files" {
                        if ($this.FileBrowser) {
                            $this.FileBrowser.OpenSelected()
                        }
                    }
                    "Commands" {
                        # Copy command to clipboard
                        if ($this.Commands.Count -gt 0 -and $this.CommandIndex -lt $this.Commands.Count) {
                            $cmd = $this.Commands[$this.CommandIndex]
                            # Copy to clipboard - platform specific
                if ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                    $cmd.Name | & xclip -selection clipboard 2>$null || Write-Host "Command copied: $($cmd.Name)"
                } else {
                    Set-Clipboard -Value $cmd.Name 2>$null || Write-Host "Command copied: $($cmd.Name)"
                }
                        }
                    }
                }
            }
        }
        $this.UpdateStatusBar()
    }
    
    [void] GoBack() {
        if ($this.ShowCommandPalette) {
            $this.ShowCommandPalette = $false
            return
        }
        
        if ($this.ShowTaskDetails) {
            $this.ShowTaskDetails = $false
            $this.ViewedTask = $null
        } elseif ($this.FocusedPane -gt 0) {
            $this.FocusedPane--
        } else {
            $this.Active = $false
        }
        $this.UpdateStatusBar()
    }
    
    [void] NewItem() {
        switch ($this.FocusedPane) {
            0 { # Projects
                # TODO: Launch new project dialog
                Write-Host "New project dialog not yet implemented"
            }
            2 { # Tools
                if ($this.ActiveTab -eq "Tasks" -and $this.SelectedProject) {
                    # Create new task for current project
                    $newTask = $this.TaskService.AddTask("New Task")
                    $newTask.Project = $this.SelectedProject.Nickname
                    $newTask.ProjectId = $this.SelectedProject.Id
                    
                    # Create and push edit dialog
                    $dialog = New-Object EditDialog -ArgumentList $this, $newTask, $true
                    $dialog | Add-Member -NotePropertyName ParentScreen -NotePropertyValue $this
                    $dialog | Add-Member -NotePropertyName IsNewTask -NotePropertyValue $true
                    
                    $global:ScreenManager.Push($dialog)
                }
            }
        }
    }
    
    [void] EditCurrent() {
        switch ($this.FocusedPane) {
            0 { # Projects
                # TODO: Edit project dialog
                Write-Host "Edit project dialog not yet implemented"
            }
            1 { # Details
                # TODO: Edit project dialog
                Write-Host "Edit project dialog not yet implemented"
            }
            2 { # Tools
                if ($this.ActiveTab -eq "Tasks") {
                    $taskToEdit = $null
                    
                    if ($this.ShowTaskDetails -and $this.ViewedTask) {
                        $taskToEdit = $this.ViewedTask
                    } elseif ($this.Tasks.Count -gt 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
                        $taskToEdit = $this.Tasks[$this.TaskIndex]
                    }
                    
                    if ($taskToEdit) {
                        # Create and push edit dialog
                        $dialog = New-Object EditDialog -ArgumentList $this, $taskToEdit, $false
                        $dialog | Add-Member -NotePropertyName ParentScreen -NotePropertyValue $this
                        
                        $global:ScreenManager.Push($dialog)
                    }
                }
            }
        }
    }
    
    [void] DeleteCurrent() {
        if ($this.FocusedPane -eq 2 -and $this.ActiveTab -eq "Tasks") {
            $taskToDelete = $null
            
            if ($this.ShowTaskDetails -and $this.ViewedTask) {
                $taskToDelete = $this.ViewedTask
            } elseif ($this.Tasks.Count -gt 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
                $taskToDelete = $this.Tasks[$this.TaskIndex]
            }
            
            if ($taskToDelete) {
                # Create and push delete confirmation dialog
                $dialog = New-Object DeleteConfirmDialog -ArgumentList $this, $taskToDelete
                $dialog | Add-Member -NotePropertyName ParentScreen -NotePropertyValue $this
                
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] ToggleFilter() {
        $this.ShowActiveOnly = -not $this.ShowActiveOnly
        $this.LoadProjects()
    }
    
    # Called when screen regains focus (e.g., after dialog closes)
    [void] OnFocus() {
        # Refresh task list in case tasks were added/edited/deleted
        if ($this.SelectedProject) {
            $this.LoadProjectTasks()
        }
        $this.RequestRender()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Handle command palette input
        if ($this.ShowCommandPalette) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.ShowCommandPalette = $false
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    $this.SelectCurrent()
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CommandSearch.Length -gt 0) {
                        $this.CommandSearch = $this.CommandSearch.Substring(0, $this.CommandSearch.Length - 1)
                        $this.CommandIndex = 0
                        $this.UpdateFilteredCommands()
                        $this.RequestRender()
                    }
                    return $true
                }
                default {
                    if ($key.KeyChar -and [char]::IsLetterOrDigit($key.KeyChar)) {
                        $this.CommandSearch += $key.KeyChar
                        $this.CommandIndex = 0
                        $this.UpdateFilteredCommands()
                        $this.RequestRender()
                        return $true
                    }
                }
            }
        }
        
        # Handle command mode input
        if ($this.InCommandMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.InCommandMode = $false
                    $this.CommandBuffer = ""
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    # Process command
                    $cmd = $this.CommandBuffer.Substring(1)  # Remove leading /
                    $this.ProcessCommand($cmd)
                    $this.InCommandMode = $false
                    $this.CommandBuffer = ""
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CommandBuffer.Length -gt 1) {
                        $this.CommandBuffer = $this.CommandBuffer.Substring(0, $this.CommandBuffer.Length - 1)
                    } else {
                        $this.InCommandMode = $false
                        $this.CommandBuffer = ""
                    }
                    $this.RequestRender()
                    return $true
                }
                default {
                    if ($key.KeyChar) {
                        $this.CommandBuffer += $key.KeyChar
                        $this.RequestRender()
                        return $true
                    }
                }
            }
        }
        
        # Ctrl+P check for command palette
        if ($key.Key -eq [ConsoleKey]::P -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.ToggleCommandPalette()
            $this.RequestRender()
            return $true
        }
        
        # Let base class handle standard navigation
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] ProcessCommand([string]$command) {
        # Parse and execute commands
        $parts = $command -split ' ', 2
        $verb = $parts[0].ToLower()
        $args = if ($parts.Count -gt 1) { $parts[1] } else { "" }
        
        switch ($verb) {
            "new" {
                switch ($args) {
                    "project" { $this.NewItem() }
                    "task" { $this.NewItem() }
                    default { Write-Host "Unknown target: $args" }
                }
            }
            "edit" { $this.EditCurrent() }
            "delete" { $this.DeleteCurrent() }
            "filter" { $this.ToggleFilter() }
            "search" {
                # TODO: Implement search
            }
            default {
                Write-Host "Unknown command: $verb"
            }
        }
    }
}