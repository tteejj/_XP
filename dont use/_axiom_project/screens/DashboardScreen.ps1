class DashboardScreen : Screen {
    # --- Core Architecture ---
    [Panel] $MainPanel
    [Panel] $SummaryPanel
    [Panel] $MenuPanel
    [Panel] $StatusPanel
    [NavigationMenu] $MainMenu
    [System.Collections.Generic.List[UIElement]] $Components

    # --- State Management ---
    [object[]] $Tasks = @()
    [int] $TotalTasks = 0
    [int] $CompletedTasks = 0
    [int] $PendingTasks = 0

    # --- Constructor ---
    DashboardScreen([hashtable]$services) : base("DashboardScreen", $services) {
        $this.Name = "DashboardScreen"
        $this.Components = [System.Collections.Generic.List[UIElement]]::new()
        $this.IsFocusable = $true
        $this.Enabled = $true
        $this.Visible = $true
        $this.Tasks = @()
        
        Write-Log -Level Info -Message "Creating DashboardScreen with NCurses architecture"
    }

    # --- Initialization ---
    [void] Initialize() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "Initialize" -ScriptBlock {
            $this.Width = $global:TuiState.BufferWidth
            $this.Height = $global:TuiState.BufferHeight
            
            if ($null -ne $this.{_private_buffer}) {
                $this.{_private_buffer}.Resize($this.Width, $this.Height)
            }
            
            $this.MainPanel = [Panel]::new(0, 0, $this.Width, $this.Height, "PMC Terminal v5 - Dashboard")
            $this.MainPanel.HasBorder = $true
            $this.MainPanel.BorderStyle = "Double"
            $this.MainPanel.BorderColor = [ConsoleColor]::Cyan
            $this.MainPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MainPanel.TitleColor = [ConsoleColor]::White
            $this.MainPanel.Name = "MainDashboardPanel"
            $this.AddChild($this.MainPanel)
            
            $summaryWidth = [Math]::Floor($this.Width * 0.4)
            $this.SummaryPanel = [Panel]::new(2, 2, $summaryWidth, 12, "Task Summary")
            $this.SummaryPanel.HasBorder = $true
            $this.SummaryPanel.BorderStyle = "Single"
            $this.SummaryPanel.BorderColor = [ConsoleColor]::Green
            $this.SummaryPanel.BackgroundColor = [ConsoleColor]::Black
            $this.SummaryPanel.Name = "SummaryPanel"
            $this.MainPanel.AddChild($this.SummaryPanel)
            
            $menuX = $summaryWidth + 4
            $menuWidth = $this.Width - $menuX - 2
            $this.MenuPanel = [Panel]::new($menuX, 2, $menuWidth, 15, "Main Menu")
            $this.MenuPanel.HasBorder = $true
            $this.MenuPanel.BorderStyle = "Single"
            $this.MenuPanel.BorderColor = [ConsoleColor]::Yellow
            $this.MenuPanel.BackgroundColor = [ConsoleColor]::Black
            $this.MenuPanel.Name = "MenuPanel"
            $this.MainPanel.AddChild($this.MenuPanel)
            
            $this.StatusPanel = [Panel]::new(2, 19, $this.Width - 4, $this.Height - 21, "System Status")
            $this.StatusPanel.HasBorder = $true
            $this.StatusPanel.BorderStyle = "Single"
            $this.StatusPanel.BorderColor = [ConsoleColor]::Magenta
            $this.StatusPanel.BackgroundColor = [ConsoleColor]::Black
            $this.StatusPanel.Name = "StatusPanel"
            $this.MainPanel.AddChild($this.StatusPanel)
            
            $this.MainMenu = [NavigationMenu]::new("MainMenu")
            $this.MainMenu.Move(0, 0)
            $this.MainMenu.Resize($this.MenuPanel.ContentWidth, $this.MenuPanel.ContentHeight)
            $this.BuildMainMenu()
            $this.MenuPanel.AddChild($this.MainMenu)
            
            $this.RefreshData()
            $this.UpdateDisplay()
            
            $this.RequestRedraw()
            $this.Render()
            
            Write-Log -Level Info -Message "DashboardScreen initialized with NCurses architecture"
        }
    }

    # --- Menu Building ---
        hidden [void] BuildMainMenu() {
        try {
            # Capture the screen instance ($this) into a local variable. The scriptblocks
            # below will form a closure over this variable, giving them access to the screen's services.
            $screen_this = $this
            
            $this.MainMenu.AddItem([NavigationItem]::new("1", "Task Management", {
                $screen_this.Services.Navigation.GoTo("/tasks", @{})
            }))
            $this.MainMenu.AddItem([NavigationItem]::new("2", "Project Management", {
                # This action is not yet implemented, so we'll show a dialog.
                Show-AlertDialog -Title "Not Implemented" -Message "Project Management screen is coming soon!"
            }))
            $this.MainMenu.AddItem([NavigationItem]::new("3", "Settings", {
                # This action is not yet implemented, so we'll show a dialog.
                Show-AlertDialog -Title "Not Implemented" -Message "Settings screen is coming soon!"
            }))
            $this.MainMenu.AddSeparator()
            $this.MainMenu.AddItem([NavigationItem]::new("Q", "Quit Application", {
                 $screen_this.Services.Navigation.RequestExit()
            }))
            
            Write-Log -Level Debug -Message "Main menu built with $($this.MainMenu.Items.Count) items"
        } catch {
            Write-Log -Level Error -Message "Failed to build main menu: $_"
        }
    }

    # --- Data Management ---
    hidden [void] RefreshData() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "RefreshData" -ScriptBlock {
            $this.Tasks = @()
            $this.TotalTasks = 0
            $this.CompletedTasks = 0
            $this.PendingTasks = 0
            
            if ($null -eq $this.Services.DataManager) {
                Write-Log -Level Warning -Message "DataManager service not available"
                return
            }
            
            try {
                $this.Tasks = @($this.Services.DataManager.GetTasks())
                $this.TotalTasks = $this.Tasks.Count
                
                if ($this.TotalTasks -gt 0) {
                    $completedTasks = @($this.Tasks | Where-Object { $_.Status -eq [TaskStatus]::Completed })
                    $this.CompletedTasks = $completedTasks.Count
                    $this.PendingTasks = $this.TotalTasks - $this.CompletedTasks
                }
                
                Write-Log -Level Debug -Message "Dashboard data refreshed - $($this.TotalTasks) tasks loaded"
            } catch {
                Write-Log -Level Warning -Message "Failed to load tasks: $_"
                $this.Tasks = @()
            }
        }
    }

    hidden [void] UpdateDisplay() {
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "UpdateDisplay" -ScriptBlock {
            $this.UpdateSummaryPanel()
            $this.SummaryPanel.RequestRedraw()
            
            $this.UpdateStatusPanel()
            $this.StatusPanel.RequestRedraw()
            
            $this.MenuPanel.RequestRedraw()
            
            $this.RequestRedraw()
        }
    }

    hidden [void] UpdateSummaryPanel() {
        if ($null -eq $this.SummaryPanel) { return }
        
        $this.ClearPanelContent($this.SummaryPanel)
        
        $summaryLines = @(
            "Task Overview",
            "═══════════════",
            "",
            "Total Tasks:    $($this.TotalTasks)",
            "Completed:      $($this.CompletedTasks)",
            "Pending:        $($this.PendingTasks)",
            "",
            "Progress: $($this.GetProgressBar())",
            "",
            "Use number keys or",
            "arrow keys + Enter"
        )
        
        for ($i = 0; $i -lt $summaryLines.Count; $i++) {
            $color = if ($i -eq 0) { [ConsoleColor]::White } elseif ($i -eq 1) { [ConsoleColor]::Gray } else { [ConsoleColor]::Cyan }
            $this.WriteTextToPanel($this.SummaryPanel, $summaryLines[$i], 1, $i, $color)
        }
        
        $this.SummaryPanel.RequestRedraw()
    }

    hidden [void] UpdateStatusPanel() {
        if ($null -eq $this.StatusPanel) { return }
        
        $this.ClearPanelContent($this.StatusPanel)
        
        $statusLines = @(
            "System Information",
            "════════════════════",
            "",
            "PowerShell Version: $($global:PSVersionTable.PSVersion)",
            "Platform:           $($global:PSVersionTable.Platform)",
            "Memory Usage:       $($this.GetMemoryUsage())",
            "Current Time:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        )
        
        for ($i = 0; $i -lt $statusLines.Count; $i++) {
            $color = if ($i -eq 0) { [ConsoleColor]::White } elseif ($i -eq 1) { [ConsoleColor]::Gray } else { [ConsoleColor]::Green }
            $this.WriteTextToPanel($this.StatusPanel, $statusLines[$i], 1, $i, $color)
        }
        
        $this.StatusPanel.RequestRedraw()
    }

    # --- Helper Methods ---
    hidden [string] GetProgressBar() {
        if ($this.TotalTasks -eq 0) { return "No tasks" }
        
        $percentage = [Math]::Round(($this.CompletedTasks / $this.TotalTasks) * 100)
        $barLength = 20
        $filledLength = [Math]::Round(($percentage / 100) * $barLength)
        $bar = "█" * $filledLength + "░" * ($barLength - $filledLength)
        return "$bar $percentage%"
    }

    hidden [string] GetMemoryUsage() {
        try {
            $process = Get-Process -Id $global:PID
            $memoryMB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
            return "$memoryMB MB"
        } catch {
            return "Unknown"
        }
    }

    hidden [void] ClearPanelContent([Panel]$panel) {
        if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
        
        $clearCell = [TuiCell]::new(' ', [ConsoleColor]::White, $panel.BackgroundColor)
        for ($y = $panel.ContentY; $y -lt ($panel.ContentY + $panel.ContentHeight); $y++) {
            for ($x = $panel.ContentX; $x -lt ($panel.ContentX + $panel.ContentWidth); $x++) {
                $panel.{_private_buffer}.SetCell($x, $y, $clearCell)
            }
        }
    }

    hidden [void] WriteTextToPanel([Panel]$panel, [string]$text, [int]$x, [int]$y, [ConsoleColor]$color) {
        if ($null -eq $panel -or $null -eq $panel.{_private_buffer}) { return }
        if ($y -ge $panel.ContentHeight) { return }
        
        $chars = $text.ToCharArray()
        for ($i = 0; $i -lt $chars.Length -and ($x + $i) -lt $panel.ContentWidth; $i++) {
            $cell = [TuiCell]::new($chars[$i], $color, $panel.BackgroundColor)
            $panel.{_private_buffer}.SetCell($panel.ContentX + $x + $i, $panel.ContentY + $y, $cell)
        }
    }

    # --- Input Handling ---
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # This handler is now simplified. The TUI engine will automatically
        # route arrow keys/enter to the focused component (the MainMenu).
        # This handler only needs to process screen-specific shortcuts.
        $self = $this
        Invoke-WithErrorHandling -Component "DashboardScreen" -Context "HandleInput" -ScriptBlock {
            $keyChar = $keyInfo.KeyChar.ToString().ToUpper()
            
            # Screen-level shortcuts for convenience
            if ($keyChar -match '^[123Q]$') {
                $self.MainMenu.ExecuteAction($keyChar)
                return $true
            }
            
            switch ($keyInfo.Key) {
                ([ConsoleKey]::Escape) {
                    $self.Services.Navigation.RequestExit()
                    return $true
                }
                ([ConsoleKey]::F5) {
                    $self.RefreshData()
                    $self.UpdateDisplay()
                    return $true
                }
            }
        }
        # Return $false because this screen-level handler did not consume the key.
        # This allows the TUI engine to know the key is available for other layers if needed.
        return $false
    }

    # --- Lifecycle Methods ---
    [void] OnEnter() {
        $this.RefreshData()
        $this.UpdateDisplay()
        
        # Set the initial focus to the MainMenu. This is critical for
        # allowing the menu to receive and handle arrow key/enter input.
        Set-ComponentFocus -Component $this.MainMenu
    }

    [void] OnExit() { }

    [void] OnDeactivate() {
        $this.Cleanup()
    }

    [void] Cleanup() {
        $this.Components.Clear()
        $this.Children.Clear()
    }
}
