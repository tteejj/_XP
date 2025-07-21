# Enhanced Command Bar with Fuzzy Search
# Persistent top bar with dropdown results and context-aware ranking

class EnhancedCommandBar {
    # Core properties
    [string]$CurrentInput = ""
    [object[]]$AllCommands = @()
    [object[]]$FilteredResults = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$IsActive = $false
    [bool]$ShowDropdown = $false
    [int]$MaxDropdownItems = 8
    
    # UI positioning
    [int]$X = 0
    [int]$Y = 0
    [int]$Width = 80
    [int]$Height = 3  # Bar height including borders
    
    # Context for ranking
    [object]$CurrentProject = $null
    [object]$CurrentTask = $null
    [object]$CurrentPanel = $null
    [string]$LastCommand = ""
    [System.Collections.ArrayList]$CommandHistory = @()
    
    # Parent screen reference
    [object]$ParentScreen = $null
    
    # Visual settings
    hidden [string]$_borderColor = "`e[38;2;100;100;100m"
    hidden [string]$_bgColor = "`e[48;2;30;30;40m"
    hidden [string]$_fgColor = "`e[38;2;220;220;220m"
    hidden [string]$_selectedBg = "`e[48;2;60;80;120m"
    hidden [string]$_matchColor = "`e[38;2;100;200;255m"
    hidden [string]$_dimColor = "`e[38;2;150;150;150m"
    hidden [string]$_dropdownBg = "`e[48;2;10;10;20m"  # Very dark background for dropdown
    hidden [string]$_dropdownBorder = "`e[38;2;80;80;100m"  # Slightly dimmer border for dropdown
    hidden [string]$_reset = "`e[0m"
    
    EnhancedCommandBar() {
        $this.InitializeCommands()
    }
    
    [void] InitializeCommands() {
        $this.AllCommands = @(
            # Task commands
            @{ 
                Name = "Create New Task"
                Keywords = @("new", "task", "create", "add", "nt")
                Action = "CreateTask"
                Category = "Task"
                Shortcut = "Ctrl+N"
                Context = @("*")
            },
            @{
                Name = "Edit Current Task"
                Keywords = @("edit", "task", "modify", "change", "et")
                Action = "EditTask"
                Category = "Task"
                Shortcut = "E"
                Context = @("task")
            },
            @{
                Name = "Delete Current Task"
                Keywords = @("delete", "task", "remove", "dt")
                Action = "DeleteTask"
                Category = "Task"
                Shortcut = "D"
                Context = @("task")
            },
            @{
                Name = "Toggle Task Status"
                Keywords = @("toggle", "status", "complete", "done", "ts")
                Action = "ToggleTaskStatus"
                Category = "Task"
                Shortcut = "Space"
                Context = @("task")
            },
            
            # Project commands
            @{
                Name = "Create New Project"
                Keywords = @("new", "project", "create", "np")
                Action = "CreateProject"
                Category = "Project"
                Shortcut = "Ctrl+Shift+N"
                Context = @("*")
            },
            @{
                Name = "Switch to Project"
                Keywords = @("switch", "project", "go", "open", "sp")
                Action = "SwitchProject"
                Category = "Project"
                Context = @("*")
            },
            
            # Navigation commands
            @{
                Name = "Go to Tasks Panel"
                Keywords = @("tasks", "panel", "go", "switch", "gt")
                Action = "GoToTasks"
                Category = "Navigation"
                Shortcut = "Alt+3"
                Context = @("*")
            },
            @{
                Name = "Go to Projects Panel"
                Keywords = @("projects", "panel", "go", "switch", "gp")
                Action = "GoToProjects"
                Category = "Navigation"
                Shortcut = "Alt+2"
                Context = @("*")
            },
            @{
                Name = "Go to Filters Panel"
                Keywords = @("filters", "panel", "go", "switch", "gf")
                Action = "GoToFilters"
                Category = "Navigation"
                Shortcut = "Alt+1"
                Context = @("*")
            },
            @{
                Name = "Go to Details Panel"
                Keywords = @("details", "main", "panel", "go", "gd")
                Action = "GoToDetails"
                Category = "Navigation"
                Shortcut = "Alt+0"
                Context = @("*")
            },
            
            # Filter commands
            @{
                Name = "Show Active Tasks"
                Keywords = @("active", "tasks", "filter", "fa")
                Action = "FilterActive"
                Category = "Filter"
                Context = @("*")
            },
            @{
                Name = "Show All Tasks"
                Keywords = @("all", "tasks", "filter", "clear", "fa")
                Action = "FilterAll"
                Category = "Filter"
                Context = @("*")
            },
            @{
                Name = "Show Completed Tasks"
                Keywords = @("completed", "done", "tasks", "filter", "fc")
                Action = "FilterCompleted"
                Category = "Filter"
                Context = @("*")
            },
            
            # Screen commands
            @{
                Name = "Return to Main Menu"
                Keywords = @("menu", "main", "back", "quit", "q")
                Action = "ReturnToMenu"
                Category = "Screen"
                Shortcut = "Q"
                Context = @("*")
            },
            @{
                Name = "Refresh All Data"
                Keywords = @("refresh", "reload", "update", "rf")
                Action = "RefreshAll"
                Category = "Screen"
                Shortcut = "F5"
                Context = @("*")
            },
            @{
                Name = "Toggle Help"
                Keywords = @("help", "?", "guide", "th")
                Action = "ToggleHelp"
                Category = "Screen"
                Shortcut = "?"
                Context = @("*")
            }
        )
    }
    
    # Fuzzy search algorithm with scoring
    [hashtable] CalculateFuzzyScore([string]$query, [object]$command) {
        $query = $query.ToLower()
        $score = 0
        $matched = $false
        
        # Exact match on name
        if ($command.Name.ToLower() -eq $query) {
            return @{ Score = 1000; Matched = $true }
        }
        
        # Check shortcuts (highest priority)
        foreach ($keyword in $command.Keywords) {
            if ($keyword -eq $query) {
                return @{ Score = 900; Matched = $true }
            }
        }
        
        # Starts with query
        if ($command.Name.ToLower().StartsWith($query)) {
            $score += 500
            $matched = $true
        }
        
        # Contains query
        elseif ($command.Name.ToLower().Contains($query)) {
            $score += 300
            $matched = $true
        }
        
        # Fuzzy character matching
        $queryChars = $query.ToCharArray()
        $nameChars = $command.Name.ToLower().ToCharArray()
        $lastMatchIndex = -1
        $consecutiveMatches = 0
        
        foreach ($qChar in $queryChars) {
            $found = $false
            for ($i = $lastMatchIndex + 1; $i -lt $nameChars.Length; $i++) {
                if ($nameChars[$i] -eq $qChar) {
                    $found = $true
                    $matched = $true
                    
                    # Bonus for consecutive matches
                    if ($i -eq $lastMatchIndex + 1) {
                        $consecutiveMatches++
                        $score += 50 * $consecutiveMatches
                    } else {
                        $consecutiveMatches = 0
                        $score += 10
                    }
                    
                    # Bonus for match at word boundary
                    if ($i -eq 0 -or $nameChars[$i-1] -eq ' ') {
                        $score += 30
                    }
                    
                    $lastMatchIndex = $i
                    break
                }
            }
            
            if (-not $found) {
                # Check keywords
                foreach ($keyword in $command.Keywords) {
                    if ($keyword.Contains($qChar)) {
                        $score += 5
                        $matched = $true
                        break
                    }
                }
            }
        }
        
        # Context bonus
        if ($matched -and $command.Context -contains "*") {
            $score += 10
        } elseif ($matched -and $this.CurrentPanel -and $command.Context -contains $this.CurrentPanel) {
            $score += 100
        }
        
        # History bonus
        if ($matched -and $this.CommandHistory -contains $command.Name) {
            $historyIndex = $this.CommandHistory.IndexOf($command.Name)
            $score += 50 + (10 * ([Math]::Max(0, 10 - $historyIndex)))
        }
        
        # Category bonus for current context
        if ($matched -and $this.CurrentTask -and $command.Category -eq "Task") {
            $score += 80
        } elseif ($matched -and $this.CurrentProject -and $command.Category -eq "Project") {
            $score += 80
        }
        
        return @{ Score = $score; Matched = $matched }
    }
    
    [void] FilterCommands() {
        $this.FilteredResults = @()
        
        if ([string]::IsNullOrWhiteSpace($this.CurrentInput)) {
            # Show recent/contextual commands when empty
            $contextCommands = $this.AllCommands | Where-Object {
                $_.Context -contains "*" -or 
                ($this.CurrentPanel -and $_.Context -contains $this.CurrentPanel)
            } | Select-Object -First $this.MaxDropdownItems
            
            $this.FilteredResults = $contextCommands
        } else {
            # Fuzzy search with scoring
            $results = @()
            
            foreach ($cmd in $this.AllCommands) {
                $scoreResult = $this.CalculateFuzzyScore($this.CurrentInput, $cmd)
                if ($scoreResult.Matched) {
                    $results += [PSCustomObject]@{
                        Command = $cmd
                        Score = $scoreResult.Score
                    }
                }
            }
            
            # Sort by score (no limit on results for scrolling)
            $this.FilteredResults = $results | 
                Sort-Object -Property Score -Descending | 
                Select-Object -ExpandProperty Command
        }
        
        # Reset selection and scroll
        $this.SelectedIndex = 0
        $this.ScrollOffset = 0
        $this.ShowDropdown = $this.FilteredResults.Count -gt 0
    }
    
    [string] Render() {
        $output = [System.Text.StringBuilder]::new(2048)
        
        # Always render command bar
        $this.RenderBar($output)
        
        return $output.ToString()
    }
    
    [string] RenderDropdownOverlay() {
        if (-not $this.IsActive -or -not $this.ShowDropdown) {
            return ""
        }
        
        $output = [System.Text.StringBuilder]::new(2048)
        $this.RenderDropdown($output)
        return $output.ToString()
    }
    
    [void] ClearDropdownArea([System.Text.StringBuilder]$output) {
        $dropY = $this.Y + 3
        # Clear up to max dropdown items + borders
        $maxHeight = $this.MaxDropdownItems + 2
        
        for ($line = 0; $line -lt $maxHeight; $line++) {
            $output.Append("`e[$($dropY + $line);$($this.X)H") | Out-Null
            $output.Append($this._reset) | Out-Null
            $output.Append(" " * 80) | Out-Null
        }
    }
    
    [void] RenderBar([System.Text.StringBuilder]$output) {
        # Position at top
        $output.Append("`e[$($this.Y);$($this.X)H") | Out-Null
        
        # Bar background
        $output.Append($this._bgColor) | Out-Null
        $output.Append($this._borderColor) | Out-Null
        
        # Left border
        $output.Append("┌") | Out-Null
        $output.Append("─" * ($this.Width - 2)) | Out-Null
        $output.Append("┐") | Out-Null
        
        # Command input line
        $output.Append("`e[$($this.Y + 1);$($this.X)H") | Out-Null
        $output.Append("│") | Out-Null
        $output.Append($this._fgColor) | Out-Null
        
        # Prompt
        $prompt = if ($this.IsActive) { "> " } else { "  " }
        $output.Append($prompt) | Out-Null
        
        # Input text
        $inputText = if ($this.CurrentInput.Length -gt 0) {
            $this.CurrentInput
        } else {
            if (-not $this.IsActive) {
                $output.Append($this._dimColor) | Out-Null
            }
            "Search commands..."
        }
        $output.Append($inputText) | Out-Null
        
        # Cursor
        if ($this.IsActive) {
            $output.Append("█") | Out-Null
        }
        
        # Calculate space for right-aligned text
        $currentPos = 3 + $inputText.Length + ($this.IsActive ? 1 : 0)  # prompt + text + cursor
        
        # Right side info
        $rightText = if ($this.IsActive -and $this.FilteredResults.Count -gt 0) {
            "[$($this.FilteredResults.Count) results]"
        } else {
            "[Ctrl+P to focus]"
        }
        
        # Pad middle with dashes
        $paddingLength = $this.Width - $currentPos - $rightText.Length - 4  # -4 for borders and spaces
        if ($paddingLength -gt 0) {
            $output.Append($this._borderColor) | Out-Null
            $output.Append("─" * $paddingLength) | Out-Null
        }
        
        $output.Append($this._dimColor) | Out-Null
        $output.Append($rightText) | Out-Null
        $output.Append(" ") | Out-Null
        $output.Append($this._borderColor) | Out-Null
        $output.Append("│") | Out-Null
        
        # Bottom border
        $output.Append("`e[$($this.Y + 2);$($this.X)H") | Out-Null
        $output.Append("└") | Out-Null
        $output.Append("─" * ($this.Width - 2)) | Out-Null
        $output.Append("┘") | Out-Null
        
        $output.Append($this._reset) | Out-Null
    }
    
    [void] RenderDropdown([System.Text.StringBuilder]$output) {
        # Position dropdown below command bar, over the panels
        $dropY = 4  # Just below the 3-line command bar
        $dropX = 2  # Slight indent from left edge
        
        # Calculate actual dropdown dimensions
        $dropdownHeight = [Math]::Min($this.FilteredResults.Count, $this.MaxDropdownItems) + 2  # +2 for borders
        $dropWidth = 60  # Narrower dropdown width
        
        # Clear dropdown area with solid background
        for ($line = 0; $line -lt $dropdownHeight; $line++) {
            $output.Append("`e[$($dropY + $line);${dropX}H") | Out-Null
            $output.Append($this._dropdownBg) | Out-Null
            $output.Append(" " * $dropWidth) | Out-Null
            $output.Append($this._reset) | Out-Null
        }
        
        # Top border of dropdown with scroll indicator
        $output.Append("`e[${dropY};${dropX}H") | Out-Null
        $output.Append($this._dropdownBg) | Out-Null
        $output.Append($this._dropdownBorder) | Out-Null
        $output.Append("╭") | Out-Null
        
        # Show scroll indicator if scrolled
        if ($this.ScrollOffset -gt 0) {
            $leftPadding = [Math]::Floor(($dropWidth - 4) / 2)
            $output.Append("─" * $leftPadding) | Out-Null
            $output.Append(" ▲ ") | Out-Null
            $output.Append("─" * ($dropWidth - $leftPadding - 4)) | Out-Null
        } else {
            $output.Append("─" * ($dropWidth - 2)) | Out-Null
        }
        
        $output.Append("╮") | Out-Null
        $output.Append($this._reset) | Out-Null
        
        # Render each result (up to MaxDropdownItems)
        $itemsToShow = [Math]::Min($this.FilteredResults.Count - $this.ScrollOffset, $this.MaxDropdownItems)
        for ($i = 0; $i -lt $itemsToShow; $i++) {
            $actualIndex = $i + $this.ScrollOffset
            $cmd = $this.FilteredResults[$actualIndex]
            $isSelected = $actualIndex -eq $this.SelectedIndex
            
            $output.Append("`e[$($dropY + $i + 1);${dropX}H") | Out-Null
            $output.Append($this._dropdownBg) | Out-Null
            $output.Append($this._dropdownBorder) | Out-Null
            $output.Append("│") | Out-Null
            
            if ($isSelected) {
                $output.Append($this._selectedBg) | Out-Null
                $output.Append(" ▶ ") | Out-Null
            } else {
                $output.Append($this._dropdownBg) | Out-Null
                $output.Append("   ") | Out-Null
            }
            
            # Command name with highlighted matches
            $displayName = $this.HighlightMatches($cmd.Name, $this.CurrentInput)
            $output.Append($displayName) | Out-Null
            
            # Category
            $output.Append($this._dimColor) | Out-Null
            $output.Append(" [$($cmd.Category)]") | Out-Null
            
            # Pad to fill width (accounting for borders and content)
            $currentLength = 3 + $cmd.Name.Length + 3 + $cmd.Category.Length  # 3 for arrow/space, 3 for " []"
            $padding = $dropWidth - $currentLength - 2  # -2 for borders
            if ($cmd.Shortcut) {
                $padding -= ($cmd.Shortcut.Length + 2)  # Account for shortcut space
            }
            if ($padding -gt 0) {
                $output.Append(" " * $padding) | Out-Null
            }
            
            # Shortcut if available
            if ($cmd.Shortcut) {
                $output.Append($this._dimColor) | Out-Null
                $output.Append($cmd.Shortcut) | Out-Null
                $output.Append(" ") | Out-Null
            }
            
            # Right border
            $output.Append($this._dropdownBorder) | Out-Null
            $output.Append("│") | Out-Null
            $output.Append($this._reset) | Out-Null
        }
        
        # Bottom border with scroll indicator
        $bottomY = $dropY + $itemsToShow + 1
        $output.Append("`e[${bottomY};${dropX}H") | Out-Null
        $output.Append($this._dropdownBg) | Out-Null
        $output.Append($this._dropdownBorder) | Out-Null
        $output.Append("╰") | Out-Null
        
        # Show scroll indicator if more items below
        $hasMoreItems = ($this.ScrollOffset + $itemsToShow) -lt $this.FilteredResults.Count
        if ($hasMoreItems) {
            $leftPadding = [Math]::Floor(($dropWidth - 4) / 2)
            $output.Append("─" * $leftPadding) | Out-Null
            $output.Append(" ▼ ") | Out-Null
            $output.Append("─" * ($dropWidth - $leftPadding - 4)) | Out-Null
        } else {
            $output.Append("─" * ($dropWidth - 2)) | Out-Null
        }
        
        $output.Append("╯") | Out-Null
        $output.Append($this._reset) | Out-Null
    }
    
    [string] HighlightMatches([string]$text, [string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            return $text
        }
        
        $result = [System.Text.StringBuilder]::new()
        $queryLower = $query.ToLower()
        $textLower = $text.ToLower()
        $queryIndex = 0
        
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($queryIndex -lt $queryLower.Length -and 
                $textLower[$i] -eq $queryLower[$queryIndex]) {
                $result.Append($this._matchColor) | Out-Null
                $result.Append($text[$i]) | Out-Null
                $result.Append($this._fgColor) | Out-Null
                $queryIndex++
            } else {
                $result.Append($text[$i]) | Out-Null
            }
        }
        
        return $result.ToString()
    }
    
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        if (-not $this.IsActive) {
            return $false
        }
        
        switch ($key.Key) {
            ([ConsoleKey]::Escape) {
                $this.Cancel()
                return $true
            }
            ([ConsoleKey]::Enter) {
                if ($this.FilteredResults.Count -gt 0) {
                    $this.ExecuteCommand($this.FilteredResults[$this.SelectedIndex])
                    return $true
                }
            }
            ([ConsoleKey]::Tab) {
                # Tab through results
                if ($this.FilteredResults.Count -gt 0) {
                    $this.SelectedIndex = ($this.SelectedIndex + 1) % $this.FilteredResults.Count
                    return $true
                }
            }
            ([ConsoleKey]::UpArrow) {
                if ($this.FilteredResults.Count -gt 0 -and $this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    # Adjust scroll if needed
                    if ($this.SelectedIndex -lt $this.ScrollOffset) {
                        $this.ScrollOffset = $this.SelectedIndex
                    }
                    return $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.FilteredResults.Count -gt 0 -and 
                    $this.SelectedIndex -lt $this.FilteredResults.Count - 1) {
                    $this.SelectedIndex++
                    # Adjust scroll if needed
                    if ($this.SelectedIndex -ge $this.ScrollOffset + $this.MaxDropdownItems) {
                        $this.ScrollOffset = $this.SelectedIndex - $this.MaxDropdownItems + 1
                    }
                    return $true
                }
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CurrentInput.Length -gt 0) {
                    $this.CurrentInput = $this.CurrentInput.Substring(0, $this.CurrentInput.Length - 1)
                    $this.FilterCommands()
                    return $true
                }
            }
            ([ConsoleKey]::Delete) {
                $this.CurrentInput = ""
                $this.FilterCommands()
                return $true
            }
        }
        
        # Character input
        if ($key.KeyChar -and -not [char]::IsControl($key.KeyChar)) {
            $this.CurrentInput += $key.KeyChar
            $this.FilterCommands()
            return $true
        }
        
        return $false
    }
    
    [void] Activate() {
        $this.IsActive = $true
        $this.CurrentInput = ""
        $this.FilterCommands()
    }
    
    [void] Cancel() {
        $this.IsActive = $false
        $this.CurrentInput = ""
        $this.ShowDropdown = $false
        $this.SelectedIndex = 0
    }
    
    [void] ExecuteCommand([object]$command) {
        # Add to history
        if ($this.CommandHistory -notcontains $command.Name) {
            $this.CommandHistory.Insert(0, $command.Name)
            if ($this.CommandHistory.Count -gt 20) {
                $this.CommandHistory.RemoveAt(20)
            }
        }
        
        # Execute action
        if ($this.ParentScreen) {
            switch ($command.Action) {
                # Task actions
                "CreateTask" { $this.ParentScreen.CreateNewTask() }
                "EditTask" { 
                    if ($this.CurrentTask) {
                        $this.ParentScreen.EditTask($this.CurrentTask)
                    }
                }
                "DeleteTask" {
                    if ($this.CurrentTask) {
                        $this.ParentScreen.DeleteTask($this.CurrentTask)
                    }
                }
                "ToggleTaskStatus" {
                    if ($this.CurrentTask) {
                        $this.ParentScreen.ToggleTaskStatus($this.CurrentTask)
                    }
                }
                
                # Project actions
                "CreateProject" { $this.ParentScreen.CreateNewProject() }
                
                # Navigation
                "GoToTasks" { $this.ParentScreen.FocusManager.FocusLeftPanel(2) }
                "GoToProjects" { $this.ParentScreen.FocusManager.FocusLeftPanel(1) }
                "GoToFilters" { $this.ParentScreen.FocusManager.FocusLeftPanel(0) }
                "GoToDetails" { $this.ParentScreen.FocusManager.FocusMainPanel() }
                
                # Filters
                "FilterActive" { $this.ParentScreen.ApplyFilter("Active") }
                "FilterAll" { $this.ParentScreen.ApplyFilter("All") }
                "FilterCompleted" { $this.ParentScreen.ApplyFilter("Completed") }
                
                # Screen
                "ReturnToMenu" { $this.ParentScreen.Quit() }
                "RefreshAll" { $this.ParentScreen.RefreshAll() }
                "ToggleHelp" { $this.ParentScreen.ToggleHelp() }
                
                default { Write-Debug "Unknown command action: $($command.Action)" }
            }
        }
        
        # Clear after execution
        $this.Cancel()
    }
    
    [void] SetContext([object]$project, [object]$task, [string]$panel) {
        $this.CurrentProject = $project
        $this.CurrentTask = $task
        $this.CurrentPanel = $panel
    }
}