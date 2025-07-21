# ProjectContextScreenV3_Final - DEFINITIVE VERSION
# Two-pane Ranger-style with visual command box, full command palette, NO STATUS BAR

class ProjectContextScreenV3_Final : Screen {
    # Services
    [object]$ProjectService
    [object]$TaskService
    [object]$TimeTrackingService
    
    # Data
    [System.Collections.ArrayList]$Projects
    [System.Collections.ArrayList]$Tasks
    [System.Collections.ArrayList]$Commands
    [object]$SelectedProject
    [object]$SelectedTask
    
    # UI State
    [int]$ProjectIndex = 0
    [int]$TaskIndex = 0
    [int]$CommandIndex = 0
    [int]$FileIndex = 0
    [int]$FocusedPane = 0  # 0=Left, 1=Right
    [string]$ActiveTab = "Tasks"
    [bool]$InCommandMode = $false
    [string]$CommandLine = ""
    [int]$CommandCursorPos = 0
    [bool]$ShowTaskDetails = $false
    [object]$ViewedTask = $null
    [bool]$InFileBrowser = $false
    
    # View State
    [string]$ViewState = "ProjectSelection"  # ProjectSelection or ProjectWorking
    [double]$SplitRatio = 0.35  # 35% for left pane
    
    # Scrolling
    [int]$DetailScrollOffset = 0
    [int]$MaxDetailScroll = 0
    
    # File browser
    [string]$CurrentPath = ""
    [System.Collections.ArrayList]$Files
    [object]$FileBrowser
    
    # Layout dimensions
    [int]$LeftWidth = 0
    [int]$RightWidth = 0
    
    # Filters
    [bool]$ShowActiveOnly = $true
    [bool]$ShowMyWork = $false
    
    # Command palette
    [bool]$ShowCommandPalette = $false
    [string]$CommandSearch = ""
    [System.Collections.ArrayList]$FilteredCommands
    
    # Command system
    [System.Collections.ArrayList]$CommandHistory
    [int]$HistoryIndex = -1
    [bool]$ShowSuggestions = $false
    [System.Collections.ArrayList]$CommandSuggestions
    [int]$SuggestionIndex = 0
    
    ProjectContextScreenV3_Final() {
        $this.Title = "PROJECT CONTEXT V3"
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
        
        # Initialize collections
        $this.Commands = [System.Collections.ArrayList]::new()
        $this.Files = [System.Collections.ArrayList]::new()
        $this.FilteredCommands = [System.Collections.ArrayList]::new()
        $this.CommandHistory = [System.Collections.ArrayList]::new()
        $this.CommandSuggestions = [System.Collections.ArrayList]::new()
        
        # Load default commands
        $this.LoadDefaultCommands()
        
        # Load data
        $this.LoadProjects()
        
        # Key bindings
        $this.InitializeKeyBindings()
        
        # Calculate initial layout
        $this.CalculateLayout()
    }
    
    [void] CalculateLayout() {
        $totalWidth = [Console]::WindowWidth
        
        # 35/65 split - proper calculation
        # Total width minus 3 for borders (left|middle|right)
        $availableWidth = $totalWidth - 3
        $this.LeftWidth = [int]($availableWidth * $this.SplitRatio)
        $this.RightWidth = $availableWidth - $this.LeftWidth
    }
    
    [void] LoadDefaultCommands() {
        $defaultCommands = @(
            @{Name="@auth_check_user"; Tags=@("auth", "user"); Description="Check user authentication"},
            @{Name="@auth_validate_token"; Tags=@("auth", "token"); Description="Validate auth token"},
            @{Name="@auth_reset_password"; Tags=@("auth", "password"); Description="Reset user password"},
            @{Name="@db_migrate"; Tags=@("database", "migration"); Description="Run database migrations"},
            @{Name="@db_backup"; Tags=@("database", "backup"); Description="Backup database"},
            @{Name="@db_restore"; Tags=@("database", "restore"); Description="Restore database"},
            @{Name="@test_unit"; Tags=@("test", "unit"); Description="Run unit tests"},
            @{Name="@test_integration"; Tags=@("test", "integration"); Description="Run integration tests"},
            @{Name="@test_coverage"; Tags=@("test", "coverage"); Description="Generate test coverage"},
            @{Name="@deploy_staging"; Tags=@("deploy", "staging"); Description="Deploy to staging"},
            @{Name="@deploy_production"; Tags=@("deploy", "production"); Description="Deploy to production"},
            @{Name="@logs_view"; Tags=@("logs", "view"); Description="View application logs"},
            @{Name="@logs_clear"; Tags=@("logs", "clear"); Description="Clear log files"},
            @{Name="@cache_clear"; Tags=@("cache", "clear"); Description="Clear application cache"},
            @{Name="@service_restart"; Tags=@("service", "restart"); Description="Restart application service"}
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
            $this.DetailScrollOffset = 0
            $this.CalculateMaxDetailScroll()
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
        
        $this.TaskIndex = 0
        if ($this.Tasks.Count -gt 0) {
            $this.SelectedTask = $this.Tasks[0]
        }
    }
    
    [void] LoadProjectFiles() {
        if (-not $this.SelectedProject) { return }
        
        # Set current path
        if ($this.SelectedProject.CAAPath -and $this.SelectedProject.CAAPath -ne "" -and (Test-Path $this.SelectedProject.CAAPath)) {
            $this.CurrentPath = $this.SelectedProject.CAAPath
        } else {
            $this.CurrentPath = if ([System.Environment]::OSVersion.Platform -eq 'Unix') { 
                [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            } else { 
                "C:\" 
            }
        }
        
        # Create embedded file browser
        if (-not $this.FileBrowser) {
            $this.FileBrowser = [FileBrowserScreen]::new()
            $this.FileBrowser.CurrentPath = $this.CurrentPath
        } else {
            $this.FileBrowser.CurrentPath = $this.CurrentPath
            $this.FileBrowser.LoadDirectory($this.CurrentPath)
        }
    }
    
    [void] CalculateMaxDetailScroll() {
        $displayHeight = [Console]::WindowHeight - 10
        $detailLines = 20
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
        
        # Quick actions
        $this.BindKey('n', { $this.NewItem(); $this.RequestRender() })
        $this.BindKey('e', { $this.EditCurrent(); $this.RequestRender() })
        $this.BindKey('d', { $this.DeleteCurrent(); $this.RequestRender() })
        $this.BindKey('f', { 
            if ($this.ViewState -eq "ProjectSelection") {
                $this.ToggleFilter()
            } elseif ($this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Files") {
                $this.InFileBrowser = -not $this.InFileBrowser
            }
            $this.RequestRender() 
        })
        
        # Scrolling
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
        
        if ($this.ShowSuggestions -and $this.InCommandMode) {
            if ($this.SuggestionIndex -gt 0) {
                $this.SuggestionIndex--
            }
            return
        }
        
        # In file browser mode
        if ($this.InFileBrowser -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Files") {
            $this.FileBrowser.NavigateUp()
            return
        }
        
        switch ($this.ViewState) {
            "ProjectSelection" {
                if ($this.FocusedPane -eq 0) {
                    # Navigate project list
                    if ($this.ProjectIndex -gt 0) {
                        $this.SelectProject($this.ProjectIndex - 1)
                    }
                } else {
                    # Scroll details
                    $this.ScrollUp()
                }
            }
            "ProjectWorking" {
                if ($this.FocusedPane -eq 0) {
                    # Scroll details
                    $this.ScrollUp()
                } else {
                    # Navigate in tools pane
                    switch ($this.ActiveTab) {
                        "Tasks" {
                            if (-not $this.ShowTaskDetails -and $this.TaskIndex -gt 0) {
                                $this.TaskIndex--
                                if ($this.TaskIndex -lt $this.Tasks.Count) {
                                    $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                                }
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
    }
    
    [void] NavigateDown() {
        if ($this.ShowCommandPalette) {
            if ($this.CommandIndex -lt $this.FilteredCommands.Count - 1) {
                $this.CommandIndex++
            }
            return
        }
        
        if ($this.ShowSuggestions -and $this.InCommandMode) {
            if ($this.SuggestionIndex -lt $this.CommandSuggestions.Count - 1) {
                $this.SuggestionIndex++
            }
            return
        }
        
        # In file browser mode
        if ($this.InFileBrowser -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Files") {
            $this.FileBrowser.NavigateDown()
            return
        }
        
        switch ($this.ViewState) {
            "ProjectSelection" {
                if ($this.FocusedPane -eq 0) {
                    # Navigate project list
                    if ($this.ProjectIndex -lt $this.Projects.Count - 1) {
                        $this.SelectProject($this.ProjectIndex + 1)
                    }
                } else {
                    # Scroll details
                    $this.ScrollDown()
                }
            }
            "ProjectWorking" {
                if ($this.FocusedPane -eq 0) {
                    # Scroll details
                    $this.ScrollDown()
                } else {
                    # Navigate in tools pane
                    switch ($this.ActiveTab) {
                        "Tasks" {
                            if (-not $this.ShowTaskDetails -and $this.TaskIndex -lt $this.Tasks.Count - 1) {
                                $this.TaskIndex++
                                if ($this.TaskIndex -lt $this.Tasks.Count) {
                                    $this.SelectedTask = $this.Tasks[$this.TaskIndex]
                                }
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
        # Exit file browser mode if active
        if ($this.InFileBrowser) {
            $this.InFileBrowser = $false
            return
        }
        
        switch ($this.ViewState) {
            "ProjectSelection" {
                if ($this.FocusedPane -eq 1) {
                    $this.FocusedPane = 0
                } else {
                    # Already at leftmost, go back to main menu
                    $this.Active = $false
                }
            }
            "ProjectWorking" {
                if ($this.FocusedPane -eq 1) {
                    # Focus project details first
                    $this.FocusedPane = 0
                } else {
                    # Go back to project selection
                    $this.ViewState = "ProjectSelection"
                    $this.FocusedPane = 0
                    $this.CalculateLayout()
                }
            }
        }
    }
    
    [void] NavigateRight() {
        # In file browser mode
        if ($this.InFileBrowser -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Files") {
            $this.FileBrowser.OpenSelected()
            return
        }
        
        switch ($this.ViewState) {
            "ProjectSelection" {
                if ($this.FocusedPane -eq 0) {
                    $this.FocusedPane = 1
                }
            }
            "ProjectWorking" {
                if ($this.FocusedPane -eq 0) {
                    $this.FocusedPane = 1
                }
            }
        }
    }
    
    [void] NextTab() {
        if ($this.ViewState -eq "ProjectWorking" -or ($this.ViewState -eq "ProjectSelection" -and $this.FocusedPane -eq 1)) {
            $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
            $currentIndex = $tabs.IndexOf($this.ActiveTab)
            $nextIndex = ($currentIndex + 1) % $tabs.Count
            $this.ActiveTab = $tabs[$nextIndex]
            $this.ShowTaskDetails = $false
            $this.InFileBrowser = $false
        }
    }
    
    [void] PrevTab() {
        if ($this.ViewState -eq "ProjectWorking" -or ($this.ViewState -eq "ProjectSelection" -and $this.FocusedPane -eq 1)) {
            $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
            $currentIndex = $tabs.IndexOf($this.ActiveTab)
            $prevIndex = if ($currentIndex -eq 0) { $tabs.Count - 1 } else { $currentIndex - 1 }
            $this.ActiveTab = $tabs[$prevIndex]
            $this.ShowTaskDetails = $false
            $this.InFileBrowser = $false
        }
    }
    
    [void] StartCommand() {
        $this.InCommandMode = $true
        $this.CommandLine = ""
        $this.CommandCursorPos = 0
        $this.ShowSuggestions = $false
        $this.UpdateCommandSuggestions()
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
    
    [void] UpdateCommandSuggestions() {
        $this.CommandSuggestions.Clear()
        
        if ([string]::IsNullOrEmpty($this.CommandLine)) {
            # Show common commands
            $this.CommandSuggestions.Add("new task") | Out-Null
            $this.CommandSuggestions.Add("new project") | Out-Null
            $this.CommandSuggestions.Add("edit") | Out-Null
            $this.CommandSuggestions.Add("delete") | Out-Null
            $this.CommandSuggestions.Add("filter active") | Out-Null
        } else {
            # Filter based on input
            $possibleCommands = @("new", "edit", "delete", "filter", "search", "export", "import")
            foreach ($cmd in $possibleCommands) {
                if ($cmd.StartsWith($this.CommandLine.ToLower())) {
                    $this.CommandSuggestions.Add($cmd) | Out-Null
                }
            }
        }
        
        $this.ShowSuggestions = $this.CommandSuggestions.Count -gt 0
        $this.SuggestionIndex = 0
    }
    
    [string] RenderContent() {
        $output = ""
        $output += [VT]::Clear()
        
        # Command palette overlay - highest priority
        if ($this.ShowCommandPalette) {
            return $this.RenderCommandPalette()
        }
        
        # Calculate layout
        $windowHeight = [Console]::WindowHeight
        $contentHeight = $windowHeight - 1  # Only tab bar at top
        
        # If command mode is active, reserve space for command box
        if ($this.InCommandMode) {
            $contentHeight -= 3  # Command box takes 3 lines
        }
        
        # Tab bar at top
        $output += [VT]::MoveTo(0, 0)
        $output += $this.RenderTabBar()
        
        # Draw borders and content
        if ($this.ViewState -eq "ProjectSelection") {
            $output += $this.DrawTwoPaneBorders($contentHeight, "PROJECTS", "PROJECT DETAILS")
            $output += $this.RenderProjectsList($contentHeight)
            $output += $this.RenderProjectDetails($contentHeight, $this.LeftWidth + 2)
        } else {
            # ProjectWorking state
            $output += $this.DrawTwoPaneBorders($contentHeight, "PROJECT DETAILS", $this.GetToolsPaneTitle())
            $output += $this.RenderProjectDetails($contentHeight, 1)
            $output += $this.RenderToolsPane($contentHeight)
        }
        
        # Command box overlay (if active)
        if ($this.InCommandMode) {
            $output += $this.DrawCommandBox()
        }
        
        return $output
    }
    
    [string] DrawCommandBox() {
        $output = ""
        $width = [Console]::WindowWidth
        $windowHeight = [Console]::WindowHeight
        
        # Command box at the very bottom
        $y = $windowHeight - 3
        
        # Clear area for command box
        for ($i = 0; $i -lt 3; $i++) {
            $output += [VT]::MoveTo(0, $y + $i)
            $output += " " * $width
        }
        
        # Draw command box borders
        $output += [VT]::MoveTo(0, $y)
        $output += [VT]::Border() + "┌" + ("─" * ($width - 2)) + "┐" + [VT]::Reset()
        
        # Command input line
        $output += [VT]::MoveTo(0, $y + 1)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        $output += [VT]::TextBright() + " / " + [VT]::Reset()
        $output += $this.CommandLine
        
        # Cursor
        $cursorX = 4 + $this.CommandCursorPos
        $output += [VT]::MoveTo($cursorX, $y + 1)
        $output += [VT]::TextBright() + "_" + [VT]::Reset()
        
        # Right border
        $output += [VT]::MoveTo($width - 1, $y + 1)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        
        # Bottom border with hints
        $output += [VT]::MoveTo(0, $y + 2)
        $output += [VT]::Border() + "└" + [VT]::Reset()
        $hint = " Enter: execute | Esc: cancel | Tab: complete | ↑↓: history | Ctrl+P: palette "
        $hintStart = [int](($width - $hint.Length - 2) / 2)
        $output += [VT]::Border() + ("─" * $hintStart) + [VT]::Reset()
        $output += [VT]::TextDim() + $hint + [VT]::Reset()
        $output += [VT]::Border() + ("─" * ($width - $hintStart - $hint.Length - 2)) + "┘" + [VT]::Reset()
        
        # Command suggestions (above command box)
        if ($this.ShowSuggestions -and $this.CommandSuggestions.Count -gt 0) {
            $suggestY = $y - [Math]::Min($this.CommandSuggestions.Count, 5) - 2
            $output += $this.RenderSuggestions($suggestY)
        }
        
        return $output
    }
    
    [string] RenderSuggestions([int]$y) {
        $output = ""
        $maxSuggestions = [Math]::Min($this.CommandSuggestions.Count, 5)
        
        # Draw suggestion box
        $boxWidth = 40
        $boxX = 4
        
        # Top border
        $output += [VT]::MoveTo($boxX, $y)
        $output += [VT]::Border() + "┌" + ("─" * ($boxWidth - 2)) + "┐" + [VT]::Reset()
        
        # Suggestions
        for ($i = 0; $i -lt $maxSuggestions; $i++) {
            $output += [VT]::MoveTo($boxX, $y + $i + 1)
            $output += [VT]::Border() + "│" + [VT]::Reset()
            
            if ($i -eq $this.SuggestionIndex) {
                $output += [VT]::Selected()
            }
            
            $suggestion = $this.CommandSuggestions[$i]
            if ($suggestion.Length -gt ($boxWidth - 4)) {
                $suggestion = $suggestion.Substring(0, $boxWidth - 7) + "..."
            }
            
            $output += " " + $suggestion.PadRight($boxWidth - 3)
            
            if ($i -eq $this.SuggestionIndex) {
                $output += [VT]::Reset()
            }
            
            $output += [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo($boxX, $y + $maxSuggestions + 1)
        $output += [VT]::Border() + "└" + ("─" * ($boxWidth - 2)) + "┘" + [VT]::Reset()
        
        return $output
    }
    
    [string] GetToolsPaneTitle() {
        return "PROJECT TOOLS: " + $this.ActiveTab.ToUpper()
    }
    
    [string] DrawTwoPaneBorders([int]$contentHeight, [string]$leftTitle, [string]$rightTitle) {
        $output = ""
        $windowWidth = [Console]::WindowWidth
        
        # Top border at line 1 (after tab bar)
        $output += [VT]::MoveTo(0, 1)
        $output += [VT]::Border()
        $output += "┌" + ("─" * $this.LeftWidth) + "┬" + ("─" * $this.RightWidth) + "┐"
        $output += [VT]::Reset()
        
        # Vertical borders - from line 2 to contentHeight-1
        $bottomRow = $contentHeight
        for ($i = 2; $i -lt $bottomRow; $i++) {
            $output += [VT]::MoveTo(0, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($this.LeftWidth + 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
            $output += [VT]::MoveTo($windowWidth - 1, $i) + [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Bottom border
        $output += [VT]::MoveTo(0, $bottomRow)
        $output += [VT]::Border()
        $output += "└" + ("─" * $this.LeftWidth) + "┴" + ("─" * $this.RightWidth) + "┘"
        $output += [VT]::Reset()
        
        # Pane titles with focus indicators
        $leftTitleText = if ($this.FocusedPane -eq 0) { "▶ $leftTitle" } else { $leftTitle }
        $rightTitleText = if ($this.FocusedPane -eq 1) { "▶ $rightTitle" } else { $rightTitle }
        
        $output += [VT]::MoveTo(1, 2) + [VT]::TextBright() + $leftTitleText + [VT]::Reset()
        $output += [VT]::MoveTo($this.LeftWidth + 2, 2) + [VT]::TextBright() + $rightTitleText + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderTabBar() {
        $output = ""
        
        # Show different tabs based on view state
        if ($this.ViewState -eq "ProjectSelection") {
            $output += "[*Projects*] "
        } else {
            $output += "[Projects] "
        }
        
        # Tool tabs
        $tabs = @("Tasks", "Time", "Notes", "Files", "Commands")
        foreach ($tab in $tabs) {
            if ($tab -eq $this.ActiveTab -and ($this.ViewState -eq "ProjectWorking" -or $this.FocusedPane -eq 1)) {
                $output += "[*$tab*] "
            } else {
                $output += "[$tab] "
            }
        }
        
        $output += "    Tab/] Next | [ Prev | / Command | Q Quit"
        return $output
    }
    
    [string] RenderProjectsList([int]$contentHeight) {
        $output = ""
        $startY = 4
        
        # Filter
        $output += [VT]::MoveTo(1, $startY)
        $output += [VT]::TextDim() + "Filter:" + [VT]::Reset()
        $output += [VT]::MoveTo(1, $startY + 1)
        $output += if ($this.ShowActiveOnly) { [VT]::Accent() + "☑" + [VT]::Reset() } else { "☐" }
        $output += " Active"
        
        # Project list
        $listStartY = $startY + 3
        $maxItems = $contentHeight - 10  # Adjusted for proper spacing
        
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
            
            # Project name
            $name = $project.Nickname
            if ($name.Length -gt ($this.LeftWidth - 6)) {
                $name = $name.Substring(0, $this.LeftWidth - 9) + "..."
            }
            
            $output += $name
            if ($i -eq $this.ProjectIndex) {
                $output += [VT]::Reset()
            }
        }
        
        # New button - position above bottom border
        $output += [VT]::MoveTo(1, $contentHeight - 2)
        if ($this.FocusedPane -eq 0) {
            $output += [VT]::Accent() + "[+ New]" + [VT]::Reset()
        } else {
            $output += "[+ New]"
        }
        
        return $output
    }
    
    [string] RenderProjectDetails([int]$contentHeight, [int]$x) {
        $output = ""
        $startY = 4
        
        if (-not $this.SelectedProject) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "Select a project" + [VT]::Reset()
            return $output
        }
        
        $p = $this.SelectedProject
        $y = $startY - $this.DetailScrollOffset
        
        # Helper to add detail line
        $addDetail = {
            param($label, $value, $highlight = $false)
            if ($y -ge $startY -and $y -lt ($contentHeight - 2)) {  # Adjusted for border
                $script:output += [VT]::MoveTo($x, $y)
                if ($highlight) {
                    $script:output += [VT]::TextBright() + $label + [VT]::Reset() + $value
                } else {
                    $script:output += [VT]::TextDim() + $label + [VT]::Reset() + $value
                }
            }
            $script:y++
        }
        
        # Project name
        $output += [VT]::MoveTo($x, $startY - 1)
        $output += [VT]::Accent() + $p.FullProjectName + [VT]::Reset()
        
        # Details
        & $addDetail "Nickname: " $p.Nickname $true
        & $addDetail "ID1: " $p.ID1
        & $addDetail "ID2: " $p.ID2
        $y++
        
        & $addDetail "Dates:" "" $true
        & $addDetail "  Assigned: " $p.DateAssigned.ToString("yyyy-MM-dd")
        & $addDetail "  BF Date: " $p.BFDate.ToString("yyyy-MM-dd")
        & $addDetail "  Due Date: " $p.DateDue.ToString("yyyy-MM-dd")
        
        $daysLeft = ($p.DateDue - [DateTime]::Now).Days
        $daysColor = if ($daysLeft -lt 7) { [VT]::Error() } elseif ($daysLeft -lt 14) { [VT]::Warning() } else { "" }
        & $addDetail "  Days Left: " ($daysColor + $daysLeft + " days" + [VT]::Reset())
        $y++
        
        & $addDetail "Progress:" "" $true
        & $addDetail "  Hours Used: " "$($p.CumulativeHrs) hrs"
        
        # Progress bar
        if ($y -ge $startY -and $y -lt ($contentHeight - 2)) {
            $output += [VT]::MoveTo($x, $y)
            $progress = [int]($p.CumulativeHrs / 200 * 10)
            $output += "  Progress: " + [VT]::Accent() + ("█" * $progress) + [VT]::TextDim() + ("░" * (10 - $progress)) + [VT]::Reset()
        }
        $y += 2
        
        & $addDetail "Paths:" "" $true
        if ($p.CAAPath) { & $addDetail "  CAA: " $p.CAAPath }
        if ($p.RequestPath) { & $addDetail "  REQ: " $p.RequestPath }
        if ($p.T2020Path) { & $addDetail "  T20: " $p.T2020Path }
        
        return $output
    }
    
    [string] RenderToolsPane([int]$contentHeight) {
        $output = ""
        $x = $this.LeftWidth + 2
        
        if (-not $this.SelectedProject) {
            return $output
        }
        
        switch ($this.ActiveTab) {
            "Tasks" { 
                if ($this.ShowTaskDetails) {
                    $output += $this.RenderTaskDetails($x, $contentHeight)
                } else {
                    $output += $this.RenderTaskList($x, $contentHeight)
                }
            }
            "Time" { $output += $this.RenderTimeEntries($x, $contentHeight) }
            "Notes" { $output += $this.RenderNotes($x, $contentHeight) }
            "Files" { $output += $this.RenderFiles($x, $contentHeight) }
            "Commands" { $output += $this.RenderCommands($x, $contentHeight) }
        }
        
        return $output
    }
    
    [string] RenderTaskList([int]$x, [int]$contentHeight) {
        $output = ""
        $startY = 4
        
        if ($this.Tasks.Count -eq 0) {
            $output += [VT]::MoveTo($x, $startY)
            $output += [VT]::TextDim() + "No tasks for this project" + [VT]::Reset()
            $output += [VT]::MoveTo($x, $startY + 2)
            $output += "[N] to create a new task"
            return $output
        }
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Tasks ($($this.Tasks.Count)):" + [VT]::Reset()
        
        $y = $startY + 2
        $maxItems = $contentHeight - 8
        
        for ($i = 0; $i -lt [Math]::Min($this.Tasks.Count, $maxItems); $i++) {
            $task = $this.Tasks[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 1 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Status
            switch ($task.Status) {
                "Completed" { $output += [VT]::Success() + "✓ " + [VT]::Reset() }
                "InProgress" { $output += [VT]::Warning() + "⚡ " + [VT]::Reset() }
                default { $output += "○ " }
            }
            
            # Priority
            switch ($task.Priority) {
                "High" { $output += [VT]::Error() + "!" + [VT]::Reset() }
                "Medium" { $output += [VT]::Warning() + "-" + [VT]::Reset() }
                default { $output += " " }
            }
            
            # Title
            $title = " " + $task.Title
            if ($title.Length -gt ($this.RightWidth - 8)) {
                $title = $title.Substring(0, $this.RightWidth - 11) + "..."
            }
            
            $output += $title
            
            if ($this.FocusedPane -eq 1 -and $i -eq $this.TaskIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        # Stats
        $output += [VT]::MoveTo($x, $contentHeight - 4)
        $completed = ($this.Tasks | Where-Object { $_.Status -eq "Completed" }).Count
        $output += [VT]::TextDim() + "$completed completed, $($this.Tasks.Count - $completed) remaining" + [VT]::Reset()
        
        return $output
    }
    
    [string] RenderTaskDetails([int]$x, [int]$contentHeight) {
        $output = ""
        $startY = 4
        
        if (-not $this.ViewedTask) {
            return $this.RenderTaskList($x, $contentHeight)
        }
        
        $task = $this.ViewedTask
        
        # Back hint
        $output += [VT]::MoveTo($x, $startY - 1)
        $output += [VT]::TextDim() + "← Tasks" + [VT]::Reset()
        
        # Title
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
        
        return $output
    }
    
    [string] RenderTimeEntries([int]$x, [int]$contentHeight) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Time Tracking:" + [VT]::Reset()
        
        # Mock data for now
        $output += [VT]::MoveTo($x, $startY + 2)
        $output += "Mon ████░ 6.5h"
        $output += [VT]::MoveTo($x, $startY + 3)
        $output += "Tue ███░░ 4.2h"
        $output += [VT]::MoveTo($x, $startY + 4)
        $output += "Today █░░░ 2.1h"
        
        return $output
    }
    
    [string] RenderNotes([int]$x, [int]$contentHeight) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Project Notes:" + [VT]::Reset()
        
        if (-not $this.SelectedProject.CAAPath -or $this.SelectedProject.CAAPath -eq "") {
            $output += [VT]::MoveTo($x, $startY + 2)
            $output += [VT]::TextDim() + "No project path set" + [VT]::Reset()
            return $output
        }
        
        $notesPath = Join-Path $this.SelectedProject.CAAPath "notes.md"
        
        $output += [VT]::MoveTo($x, $startY + 2)
        if (Test-Path $notesPath) {
            $output += [VT]::Success() + "✓ " + [VT]::Reset() + "notes.md exists"
            $output += [VT]::MoveTo($x, $startY + 4)
            $output += "[Enter] to edit"
        } else {
            $output += [VT]::TextDim() + "No notes file" + [VT]::Reset()
            $output += [VT]::MoveTo($x, $startY + 4)
            $output += "[Enter] to create"
        }
        
        return $output
    }
    
    [string] RenderFiles([int]$x, [int]$contentHeight) {
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
        
        # Mode indicator
        if ($this.InFileBrowser) {
            $output += [VT]::MoveTo($x, $startY + 1)
            $output += [VT]::Accent() + "Browse Mode (← to exit)" + [VT]::Reset()
        }
        
        # File list
        $y = $startY + 2
        $maxItems = $contentHeight - 9
        $fileList = $this.FileBrowser.CurrentFiles
        
        for ($i = 0; $i -lt [Math]::Min($fileList.Count, $maxItems); $i++) {
            $item = $fileList[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.InFileBrowser -and $i -eq $this.FileBrowser.SelectedIndex) {
                $output += [VT]::Selected() + "> "
            } elseif ($this.FocusedPane -eq 1 -and -not $this.InFileBrowser -and $i -eq 0) {
                # Show focus indicator on first item when not in browse mode
                $output += [VT]::TextDim() + "> " + [VT]::Reset()
            } else {
                $output += "  "
            }
            
            # Item type
            $name = ""
            if ($item -eq "..") {
                $output += "📁 .."
            } elseif ($item -is [System.IO.DirectoryInfo]) {
                $output += "📁 " + $item.Name
            } elseif ($item -is [System.IO.FileInfo]) {
                $output += "📄 " + $item.Name
            } else {
                $output += $item.ToString()
            }
            
            if ($name.Length -gt ($this.RightWidth - 8)) {
                $name = $name.Substring(0, $this.RightWidth - 11) + "..."
            }
            
            if ($this.InFileBrowser -and $i -eq $this.FileBrowser.SelectedIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        return $output
    }
    
    [string] RenderCommands([int]$x, [int]$contentHeight) {
        $output = ""
        $startY = 4
        
        $output += [VT]::MoveTo($x, $startY)
        $output += [VT]::TextBright() + "Quick Commands:" + [VT]::Reset()
        
        $y = $startY + 2
        $maxItems = $contentHeight - 8
        
        for ($i = 0; $i -lt [Math]::Min($this.Commands.Count, $maxItems); $i++) {
            $cmd = $this.Commands[$i]
            $output += [VT]::MoveTo($x, $y)
            
            if ($this.FocusedPane -eq 1 -and $i -eq $this.CommandIndex) {
                $output += [VT]::Selected() + "> "
            } else {
                $output += "  "
            }
            
            # Command name
            $name = $cmd.Name
            if ($name.Length -gt 25) {
                $name = $name.Substring(0, 22) + "..."
            }
            $output += $name.PadRight(25)
            
            # Tags
            if ($cmd.Tags -and $cmd.Tags.Count -gt 0) {
                $output += [VT]::TextDim() + " #" + ($cmd.Tags -join " #") + [VT]::Reset()
            }
            
            if ($this.FocusedPane -eq 1 -and $i -eq $this.CommandIndex) {
                $output += [VT]::Reset()
            }
            
            $y++
        }
        
        return $output
    }
    
    [string] RenderCommandPalette() {
        $output = [VT]::Clear()
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $paletteWidth = [Math]::Min(80, $width - 20)
        $paletteHeight = [Math]::Min(25, $height - 10)
        $startX = [int](($width - $paletteWidth) / 2)
        $startY = 5
        
        # Draw border
        $output += [VT]::MoveTo($startX, $startY)
        $output += [VT]::Border() + "┌" + ("─" * ($paletteWidth - 2)) + "┐" + [VT]::Reset()
        
        # Title bar
        $output += [VT]::MoveTo($startX, $startY + 1)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        $title = " Command Palette (Ctrl+P to close) "
        $titlePadding = [int](($paletteWidth - $title.Length - 2) / 2)
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
        
        # Command list
        $listStartY = $startY + 4
        $maxCommands = $paletteHeight - 6
        $visibleCommands = [Math]::Min($this.FilteredCommands.Count, $maxCommands)
        
        for ($i = 0; $i -lt $visibleCommands; $i++) {
            $cmd = $this.FilteredCommands[$i]
            $y = $listStartY + $i
            
            # Left border
            $output += [VT]::MoveTo($startX, $y)
            $output += [VT]::Border() + "│" + [VT]::Reset()
            
            # Selection indicator
            if ($i -eq $this.CommandIndex) {
                $output += [VT]::Selected() + " > "
            } else {
                $output += "   "
            }
            
            # Command name
            $cmdText = $cmd.Name
            if ($cmdText.Length -gt 30) {
                $cmdText = $cmdText.Substring(0, 27) + "..."
            }
            $output += $cmdText.PadRight(30)
            
            # Description
            $desc = $cmd.Description
            $maxDescLen = $paletteWidth - 38
            if ($desc.Length -gt $maxDescLen) {
                $desc = $desc.Substring(0, $maxDescLen - 3) + "..."
            }
            $output += [VT]::TextDim() + " " + $desc + [VT]::Reset()
            
            # Right padding and border
            $totalContent = 33 + $desc.Length + 1
            $padding = $paletteWidth - $totalContent - 2
            $output += " " * $padding
            $output += [VT]::Border() + "│" + [VT]::Reset()
            
            if ($i -eq $this.CommandIndex) {
                $output += [VT]::Reset()
            }
        }
        
        # Fill empty lines
        for ($i = $visibleCommands; $i -lt $maxCommands; $i++) {
            $y = $listStartY + $i
            $output += [VT]::MoveTo($startX, $y)
            $output += [VT]::Border() + "│" + [VT]::Reset()
            $output += " " * ($paletteWidth - 2)
            $output += [VT]::Border() + "│" + [VT]::Reset()
        }
        
        # Status line
        $output += [VT]::MoveTo($startX, $startY + $paletteHeight - 2)
        $output += [VT]::Border() + "├" + ("─" * ($paletteWidth - 2)) + "┤" + [VT]::Reset()
        
        # Help text
        $output += [VT]::MoveTo($startX, $startY + $paletteHeight - 1)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        $helpText = " ↑↓ Navigate | Enter: Copy | Esc: Close "
        $helpPadding = [int](($paletteWidth - $helpText.Length - 2) / 2)
        $output += " " * $helpPadding + [VT]::TextDim() + $helpText + [VT]::Reset()
        $output += " " * ($paletteWidth - $helpText.Length - $helpPadding - 2)
        $output += [VT]::Border() + "│" + [VT]::Reset()
        
        # Bottom border
        $output += [VT]::MoveTo($startX, $startY + $paletteHeight)
        $output += [VT]::Border() + "└" + ("─" * ($paletteWidth - 2)) + "┘" + [VT]::Reset()
        
        return $output
    }
    
    # Action methods
    [void] SelectCurrent() {
        if ($this.ShowCommandPalette) {
            # Copy command to clipboard
            if ($this.FilteredCommands.Count -gt 0 -and $this.CommandIndex -lt $this.FilteredCommands.Count) {
                $cmd = $this.FilteredCommands[$this.CommandIndex]
                try {
                    if ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                        $cmd.Name | & xclip -selection clipboard 2>$null
                    } else {
                        Set-Clipboard -Value $cmd.Name 2>$null
                    }
                    Write-Host "Command copied: $($cmd.Name)"
                } catch {
                    Write-Host "Command: $($cmd.Name)"
                }
                $this.ShowCommandPalette = $false
            }
            return
        }
        
        # Handle based on view state
        if ($this.ViewState -eq "ProjectSelection" -and $this.FocusedPane -eq 0) {
            # Enter project working mode
            $this.ViewState = "ProjectWorking"
            $this.FocusedPane = 1  # Focus on tools
            $this.CalculateLayout()
        } elseif ($this.ViewState -eq "ProjectWorking" -and $this.FocusedPane -eq 1) {
            # Handle tool-specific actions
            switch ($this.ActiveTab) {
                "Tasks" {
                    if (-not $this.ShowTaskDetails -and $this.Tasks.Count -gt 0) {
                        $this.ViewedTask = $this.Tasks[$this.TaskIndex]
                        $this.ShowTaskDetails = $true
                    }
                }
                "Notes" {
                    # Open notes editor
                    if ($this.SelectedProject -and $this.SelectedProject.CAAPath) {
                        $notesPath = Join-Path $this.SelectedProject.CAAPath "notes.md"
                        if (-not (Test-Path $notesPath)) {
                            New-Item -Path $notesPath -ItemType File -Force | Out-Null
                            Set-Content -Path $notesPath -Value "# $($this.SelectedProject.FullProjectName) Notes`n`n"
                        }
                        $editor = New-Object TextEditorScreen
                        $editor.LoadFile($notesPath)
                        $global:ScreenManager.Push($editor)
                    }
                }
                "Files" {
                    if ($this.InFileBrowser) {
                        $this.FileBrowser.OpenSelected()
                    } else {
                        $this.InFileBrowser = $true
                    }
                }
                "Commands" {
                    # Copy command
                    if ($this.Commands.Count -gt 0) {
                        $cmd = $this.Commands[$this.CommandIndex]
                        try {
                            if ([System.Environment]::OSVersion.Platform -eq 'Unix') {
                                $cmd.Name | & xclip -selection clipboard 2>$null
                            } else {
                                Set-Clipboard -Value $cmd.Name 2>$null
                            }
                            Write-Host "Command copied: $($cmd.Name)"
                        } catch {
                            Write-Host "Command: $($cmd.Name)"
                        }
                    }
                }
            }
        }
    }
    
    [void] GoBack() {
        if ($this.ShowCommandPalette) {
            $this.ShowCommandPalette = $false
            return
        }
        
        if ($this.InFileBrowser) {
            $this.InFileBrowser = $false
        } elseif ($this.ShowTaskDetails) {
            $this.ShowTaskDetails = $false
            $this.ViewedTask = $null
        } elseif ($this.ViewState -eq "ProjectWorking") {
            # Go back to project selection
            $this.ViewState = "ProjectSelection"
            $this.FocusedPane = 0
            $this.CalculateLayout()
        } else {
            $this.Active = $false
        }
    }
    
    [void] NewItem() {
        if ($this.ViewState -eq "ProjectSelection" -and $this.FocusedPane -eq 0) {
            Write-Host "New project dialog not yet implemented"
        } elseif ($this.ViewState -eq "ProjectWorking" -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Tasks") {
            # Create new task
            $newTask = $this.TaskService.AddTask("New Task")
            $newTask.ProjectId = $this.SelectedProject.Id
            
            $dialog = New-Object EditDialog -ArgumentList $this, $newTask, $true
            $dialog | Add-Member -NotePropertyName ParentScreen -NotePropertyValue $this
            $global:ScreenManager.Push($dialog)
        }
    }
    
    [void] EditCurrent() {
        if ($this.ViewState -eq "ProjectWorking" -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Tasks") {
            $taskToEdit = $null
            
            if ($this.ShowTaskDetails -and $this.ViewedTask) {
                $taskToEdit = $this.ViewedTask
            } elseif ($this.Tasks.Count -gt 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
                $taskToEdit = $this.Tasks[$this.TaskIndex]
            }
            
            if ($taskToEdit) {
                $dialog = New-Object EditDialog -ArgumentList $this, $taskToEdit, $false
                $dialog | Add-Member -NotePropertyName ParentScreen -NotePropertyValue $this
                $global:ScreenManager.Push($dialog)
            }
        }
    }
    
    [void] DeleteCurrent() {
        if ($this.ViewState -eq "ProjectWorking" -and $this.FocusedPane -eq 1 -and $this.ActiveTab -eq "Tasks") {
            $taskToDelete = $null
            
            if ($this.ShowTaskDetails -and $this.ViewedTask) {
                $taskToDelete = $this.ViewedTask
            } elseif ($this.Tasks.Count -gt 0 -and $this.TaskIndex -lt $this.Tasks.Count) {
                $taskToDelete = $this.Tasks[$this.TaskIndex]
            }
            
            if ($taskToDelete) {
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
    
    [void] OnFocus() {
        if ($this.SelectedProject) {
            $this.LoadProjectTasks()
        }
        $this.RequestRender()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Handle command palette
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
                ([ConsoleKey]::UpArrow) {
                    $this.NavigateUp()
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    $this.NavigateDown()
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
            return $true
        }
        
        # Handle command mode
        if ($this.InCommandMode) {
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.InCommandMode = $false
                    $this.CommandLine = ""
                    $this.ShowSuggestions = $false
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this.ShowSuggestions -and $this.SuggestionIndex -lt $this.CommandSuggestions.Count) {
                        # Use selected suggestion
                        $this.CommandLine = $this.CommandSuggestions[$this.SuggestionIndex]
                        $this.CommandCursorPos = $this.CommandLine.Length
                        $this.ShowSuggestions = $false
                        $this.UpdateCommandSuggestions()
                    } else {
                        # Execute command
                        $this.ProcessCommand($this.CommandLine)
                        $this.CommandHistory.Add($this.CommandLine) | Out-Null
                        $this.InCommandMode = $false
                        $this.CommandLine = ""
                        $this.ShowSuggestions = $false
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Tab) {
                    if ($this.ShowSuggestions -and $this.CommandSuggestions.Count -gt 0) {
                        $this.CommandLine = $this.CommandSuggestions[$this.SuggestionIndex]
                        $this.CommandCursorPos = $this.CommandLine.Length
                        $this.UpdateCommandSuggestions()
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this.ShowSuggestions) {
                        $this.NavigateUp()
                    } else {
                        # Command history
                        if ($this.CommandHistory.Count -gt 0 -and $this.HistoryIndex -lt $this.CommandHistory.Count - 1) {
                            $this.HistoryIndex++
                            $this.CommandLine = $this.CommandHistory[$this.CommandHistory.Count - 1 - $this.HistoryIndex]
                            $this.CommandCursorPos = $this.CommandLine.Length
                            $this.UpdateCommandSuggestions()
                        }
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.ShowSuggestions) {
                        $this.NavigateDown()
                    } else {
                        # Command history
                        if ($this.HistoryIndex -gt 0) {
                            $this.HistoryIndex--
                            $this.CommandLine = $this.CommandHistory[$this.CommandHistory.Count - 1 - $this.HistoryIndex]
                            $this.CommandCursorPos = $this.CommandLine.Length
                            $this.UpdateCommandSuggestions()
                        } elseif ($this.HistoryIndex -eq 0) {
                            $this.HistoryIndex = -1
                            $this.CommandLine = ""
                            $this.CommandCursorPos = 0
                            $this.UpdateCommandSuggestions()
                        }
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::LeftArrow) {
                    if ($this.CommandCursorPos -gt 0) {
                        $this.CommandCursorPos--
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.CommandCursorPos -lt $this.CommandLine.Length) {
                        $this.CommandCursorPos++
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this.CommandCursorPos = 0
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this.CommandCursorPos = $this.CommandLine.Length
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.CommandCursorPos -gt 0) {
                        $this.CommandLine = $this.CommandLine.Remove($this.CommandCursorPos - 1, 1)
                        $this.CommandCursorPos--
                        $this.UpdateCommandSuggestions()
                    }
                    $this.RequestRender()
                    return $true
                }
                ([ConsoleKey]::Delete) {
                    if ($this.CommandCursorPos -lt $this.CommandLine.Length) {
                        $this.CommandLine = $this.CommandLine.Remove($this.CommandCursorPos, 1)
                        $this.UpdateCommandSuggestions()
                    }
                    $this.RequestRender()
                    return $true
                }
                default {
                    if ($key.KeyChar -and $key.KeyChar -ne "`0") {
                        $this.CommandLine = $this.CommandLine.Insert($this.CommandCursorPos, $key.KeyChar)
                        $this.CommandCursorPos++
                        $this.UpdateCommandSuggestions()
                        $this.RequestRender()
                        return $true
                    }
                }
            }
            return $true
        }
        
        # Ctrl+P for command palette
        if ($key.Key -eq [ConsoleKey]::P -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.ToggleCommandPalette()
            $this.RequestRender()
            return $true
        }
        
        # Let base class handle standard navigation
        return ([Screen]$this).HandleInput($key)
    }
    
    [void] ProcessCommand([string]$command) {
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
            default {
                Write-Host "Unknown command: $verb"
            }
        }
    }
}