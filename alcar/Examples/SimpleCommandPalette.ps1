# Simple Command Palette Example
# This is the original command palette from ALCARLazyGitScreen
# Demonstrates a basic implementation with simple filtering

class SimpleCommandPalette {
    [string]$CurrentInput = ""
    [string[]]$FilteredCommands = @()
    [int]$SelectedIndex = 0
    [bool]$IsActive = $false
    [string]$Mode = "Command" # Command or Search
    [object]$ParentScreen = $null
    
    # Available commands
    [object[]]$Commands = @(
        @{ Key = "nt"; Name = "New Task"; Action = "CreateTask"; Description = "Create a new task" },
        @{ Key = "np"; Name = "New Project"; Action = "CreateProject"; Description = "Create a new project" },
        @{ Key = "ft"; Name = "Find Task"; Action = "SearchTasks"; Description = "Search for tasks" },
        @{ Key = "fp"; Name = "Find Project"; Action = "SearchProjects"; Description = "Search for projects" },
        @{ Key = "sw"; Name = "Switch Panel"; Action = "CyclePanel"; Description = "Switch to next panel" },
        @{ Key = "ex"; Name = "Export Data"; Action = "ExportData"; Description = "Export tasks/projects" },
        @{ Key = "rf"; Name = "Refresh"; Action = "RefreshData"; Description = "Refresh all data" },
        @{ Key = "hp"; Name = "Toggle Help"; Action = "ToggleHelp"; Description = "Show/hide help" }
    )
    
    SimpleCommandPalette() {
        $this.FilterCommands()
    }
    
    [void] FilterCommands() {
        if ([string]::IsNullOrEmpty($this.CurrentInput)) {
            $this.FilteredCommands = $this.Commands | ForEach-Object { $_.Name }
        } else {
            # Simple filtering - matches if input is contained in name or key
            $searchLower = $this.CurrentInput.ToLower()
            $this.FilteredCommands = @($this.Commands | Where-Object {
                $_.Name.ToLower().Contains($searchLower) -or
                $_.Key.ToLower().Contains($searchLower) -or
                $_.Description.ToLower().Contains($searchLower)
            } | ForEach-Object { $_.Name })
        }
        
        # Reset selection if needed
        if ($this.SelectedIndex -ge $this.FilteredCommands.Count) {
            $this.SelectedIndex = [Math]::Max(0, $this.FilteredCommands.Count - 1)
        }
    }
    
    [string] Render([int]$x, [int]$y, [int]$width) {
        if (-not $this.IsActive) {
            return ""
        }
        
        $output = [System.Text.StringBuilder]::new()
        
        # Command input line
        $prefix = if ($this.Mode -eq "Search") { "/" } else { ":" }
        $prompt = "$prefix$($this.CurrentInput)"
        
        # Position at x,y
        $output.Append("`e[${y};${x}H") | Out-Null
        $output.Append($prompt) | Out-Null
        
        if ($this.IsActive) {
            $output.Append("█") | Out-Null  # Cursor
        }
        
        # Show command suggestions
        if ($this.FilteredCommands.Count -gt 0 -and $this.IsActive) {
            $output.Append("  ") | Out-Null
            
            $maxDisplay = [Math]::Min(3, $this.FilteredCommands.Count)
            for ($i = 0; $i -lt $maxDisplay; $i++) {
                $cmdName = $this.FilteredCommands[$i]
                $cmd = $this.Commands | Where-Object { $_.Name -eq $cmdName } | Select-Object -First 1
                
                if ($i -eq $this.SelectedIndex) {
                    $output.Append("`e[7m") | Out-Null  # Reverse video
                }
                
                $output.Append("[$($cmd.Key)] $cmdName") | Out-Null
                
                if ($i -eq $this.SelectedIndex) {
                    $output.Append("`e[27m") | Out-Null  # Normal video
                }
                
                if ($i -lt $maxDisplay - 1) {
                    $output.Append("  ") | Out-Null
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
                    $cmd = $this.Commands | Where-Object { $_.Name -eq $selectedCmd } | Select-Object -First 1
                    
                    # Execute command
                    if ($this.ParentScreen) {
                        $this.ExecuteCommand($selectedCmd)
                    }
                    
                    # Clear input
                    $this.CurrentInput = ""
                    $this.FilterCommands()
                    $this.IsActive = $false
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
            ([ConsoleKey]::UpArrow) {
                if ($this.FilteredCommands.Count -gt 0 -and $this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    return $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.FilteredCommands.Count -gt 0 -and $this.SelectedIndex -lt $this.FilteredCommands.Count - 1) {
                    $this.SelectedIndex++
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
    
    [void] SetMode([string]$mode) {
        $this.Mode = $mode
        $this.CurrentInput = ""
        $this.FilterCommands()
        $this.IsActive = $true
    }
    
    [void] ExecuteCommand([string]$commandName) {
        $cmd = $this.Commands | Where-Object { $_.Name -eq $commandName } | Select-Object -First 1
        if (-not $cmd -or -not $this.ParentScreen) { return }
        
        switch ($cmd.Action) {
            "CreateTask" { $this.ParentScreen.CreateNewTask() }
            "CreateProject" { $this.ParentScreen.CreateNewProject() }
            "SearchTasks" { 
                $this.Mode = "Search"
                $this.CurrentInput = ""
                $this.IsActive = $true
            }
            "SearchProjects" {
                $this.Mode = "Search"
                $this.CurrentInput = ""
                $this.IsActive = $true
            }
            "CyclePanel" { $this.ParentScreen.FocusManager.NextPanel() }
            "RefreshData" { $this.ParentScreen.RefreshAll() }
            "ToggleHelp" { $this.ParentScreen.ToggleHelp() }
            default { Write-Debug "Unknown command: $($cmd.Action)" }
        }
    }
}

# Usage Example:
# $palette = [SimpleCommandPalette]::new()
# $palette.ParentScreen = $myScreen
# $palette.IsActive = $true
#
# # In your render loop:
# $paletteOutput = $palette.Render(10, 5, 60)
#
# # In your input handler:
# if ($palette.HandleInput($key)) {
#     # Input was handled by palette
# }