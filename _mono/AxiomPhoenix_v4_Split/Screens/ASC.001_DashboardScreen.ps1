# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# FIXED: Removed FocusManager dependency, uses ncurses-style window focus model
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: DashboardScreen
#
# PURPOSE:
#   Main menu screen with keyboard navigation
#   Uses built-in Screen focus management (ncurses model)
#
# FOCUS MODEL:
#   - Screen tracks its own focused child (ncurses window model)
#   - Tab/Shift+Tab cycles through focusable components
#   - Each screen manages its own focus independently
#   - NO EXTERNAL FOCUS MANAGER SERVICE
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (for screen transitions)
#     - ActionService (for executing commands)
#     - DataManager (for data access - if needed)
#   Components:
#     - Panel (container)
#     - LabelComponent (menu items)
# ==============================================================================
class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_menuPanel
    hidden [List[LabelComponent]] $_menuItems
    hidden [int] $_selectedIndex = 0
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "DashboardScreen: Constructor called"
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting initialization"
        
        # Validate ServiceContainer
        if (-not $this.ServiceContainer) { 
            Write-Log -Level Error -Message "DashboardScreen.Initialize: ServiceContainer is null!"
            throw "ServiceContainer is required"
        }

        # === CREATE MAIN PANEL ===
        # Main panel takes full screen with border
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.IsFocusable = $false  # Panel itself isn't focusable
        $this.AddChild($this._mainPanel)

        # === CREATE MENU PANEL ===
        # Centered menu panel
        $this._menuPanel = [Panel]::new("MenuPanel")
        $this._menuPanel.X = [Math]::Floor(($this.Width - 40) / 2)
        $this._menuPanel.Y = 5
        $this._menuPanel.Width = 40
        $this._menuPanel.Height = 14
        $this._menuPanel.HasBorder = $true
        $this._menuPanel.BorderStyle = "Double"
        $this._menuPanel.Title = " Navigation "
        $this._menuPanel.IsFocusable = $false  # Panel itself isn't focusable
        $this._mainPanel.AddChild($this._menuPanel)
        
        # === CREATE MENU ITEMS ===
        # Menu items as non-focusable labels (handled by screen directly)
        $this._menuItems = [List[LabelComponent]]::new()
        $menuTexts = @(
            "[1] Dashboard (Current)",
            "[2] Task List",
            "[3] Projects",
            "[4] File Browser",
            "[5] Text Editor",
            "[6] Theme Picker", 
            "[7] Command Palette (Ctrl+P)",
            "",
            "[Q] Quit"
        )
        
        $yPos = 1
        foreach ($text in $menuTexts) {
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $label = [LabelComponent]::new("MenuItem_$yPos")
                $label.Text = $text
                $label.X = 2
                $label.Y = $yPos
                $label.IsFocusable = $false  # We handle navigation manually
                $label.ForegroundColor = Get-ThemeColor("component.text")
                $this._menuPanel.AddChild($label)
                $this._menuItems.Add($label)
            }
            $yPos++
        }
        
        # === HIGHLIGHT FIRST ITEM ===
        if ($this._menuItems.Count -gt 0) {
            $this._menuItems[0].ForegroundColor = Get-ThemeColor("Primary")
        }
        
        # === CREATE INSTRUCTIONS ===
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Use number keys or arrow keys + Enter to select"
        $instructions.X = [Math]::Floor(($this.Width - 42) / 2)
        $instructions.Y = 21
        $instructions.IsFocusable = $false
        $instructions.ForegroundColor = Get-ThemeColor("Subtle")
        $this._mainPanel.AddChild($instructions)
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        
        # Don't call base OnEnter - we don't want automatic focus management
        # We handle all input directly in this screen
        
        # Refresh colors in case theme changed
        $this.RefreshThemeColors()
        
        # Request redraw
        $this.RequestRedraw()
    }
    
    # === THEME COLOR MANAGEMENT ===
    hidden [void] RefreshThemeColors() {
        try {
            # Update panel colors
            if ($this._mainPanel) {
                $this._mainPanel.BorderColor = Get-ThemeColor("component.border")
                $this._mainPanel.BackgroundColor = Get-ThemeColor("component.background")
            }
            
            if ($this._menuPanel) {
                $this._menuPanel.BorderColor = Get-ThemeColor("component.border")
                $this._menuPanel.BackgroundColor = Get-ThemeColor("component.background")
            }
            
            # Update menu item colors based on selection
            if ($this._menuItems) {
                for ($i = 0; $i -lt $this._menuItems.Count; $i++) {
                    if ($this._menuItems[$i]) {
                        if ($i -eq $this._selectedIndex) {
                            # Highlighted item
                            $this._menuItems[$i].ForegroundColor = Get-ThemeColor("Primary")
                            $this._menuItems[$i].BackgroundColor = Get-ThemeColor("component.background.hover")
                        } else {
                            # Normal item
                            $this._menuItems[$i].ForegroundColor = Get-ThemeColor("component.text")
                            $this._menuItems[$i].BackgroundColor = Get-ThemeColor("component.background")
                        }
                    }
                }
            }
            
            # Update instructions color
            $instructions = $this._mainPanel.Children | Where-Object { $_.Name -eq "Instructions" }
            if ($instructions) {
                $instructions.ForegroundColor = Get-ThemeColor("Subtle")
            }
        }
        catch {
            Write-Log -Level Error -Message "DashboardScreen.RefreshThemeColors: Error updating colors: $_"
        }
    }

    # === INPUT HANDLING (DIRECT, NO FOCUS MANAGER) ===
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        # IMPORTANT: This screen handles ALL input directly
        # We do NOT use focus manager or route to child components
        
        if ($null -eq $keyInfo) {
            Write-Log -Level Warning -Message "DashboardScreen.HandleInput: Null keyInfo received"
            return $false
        }
        
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Modifiers=$($keyInfo.Modifiers)"
        
        # Get services we need
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        
        if (-not $actionService) { 
            Write-Log -Level Error -Message "DashboardScreen: ActionService not found!"
            return $false 
        }
        
        $handled = $false
        
        # === HANDLE NUMBER/LETTER KEYS (DIRECT SELECTION) ===
        $char = $keyInfo.KeyChar
        switch ($char) {
            '1' { 
                Write-Log -Level Debug -Message "DashboardScreen: Selected Dashboard (current screen)"
                $handled = $true 
            }
            '2' { 
                Write-Log -Level Debug -Message "DashboardScreen: Navigating to Task List"
                $actionService.ExecuteAction("navigation.taskList", @{})
                $handled = $true 
            }
            '3' { 
                Write-Log -Level Debug -Message "DashboardScreen: Navigating to Projects"
                if ($navService) {
                    $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                    $projectsScreen.Initialize()
                    $navService.NavigateTo($projectsScreen)
                }
                $handled = $true 
            }
            '4' { 
                Write-Log -Level Debug -Message "DashboardScreen: Opening File Browser"
                $actionService.ExecuteAction("tools.fileCommander", @{})
                $handled = $true 
            }
            '5' { 
                Write-Log -Level Debug -Message "DashboardScreen: Opening Text Editor"
                $actionService.ExecuteAction("tools.textEditor", @{})
                $handled = $true 
            }
            '6' { 
                Write-Log -Level Debug -Message "DashboardScreen: Opening Theme Picker"
                $actionService.ExecuteAction("navigation.themePicker", @{})
                $handled = $true 
            }
            '7' { 
                Write-Log -Level Debug -Message "DashboardScreen: Opening Command Palette"
                $actionService.ExecuteAction("app.commandPalette", @{})
                $handled = $true 
            }
            { $_ -eq 'q' -or $_ -eq 'Q' } { 
                Write-Log -Level Debug -Message "DashboardScreen: Exiting application"
                $actionService.ExecuteAction("app.exit", @{})
                $handled = $true 
            }
        }
        
        # === HANDLE ARROW KEY NAVIGATION ===
        if (-not $handled) {
            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    # Find previous non-empty menu item
                    $newIndex = $this._selectedIndex
                    do {
                        $newIndex--
                        if ($newIndex -lt 0) { $newIndex = $this._menuItems.Count - 1 }
                    } while (
                        $newIndex -ne $this._selectedIndex -and 
                        [string]::IsNullOrWhiteSpace($this._menuItems[$newIndex].Text)
                    )
                    
                    if ($newIndex -ne $this._selectedIndex) {
                        $this._selectedIndex = $newIndex
                        $this.RefreshThemeColors()
                        $this.RequestRedraw()
                        Write-Log -Level Debug -Message "DashboardScreen: Selected index changed to $($this._selectedIndex)"
                    }
                    $handled = $true
                }
                
                ([ConsoleKey]::DownArrow) {
                    # Find next non-empty menu item
                    $newIndex = $this._selectedIndex
                    do {
                        $newIndex++
                        if ($newIndex -ge $this._menuItems.Count) { $newIndex = 0 }
                    } while (
                        $newIndex -ne $this._selectedIndex -and 
                        [string]::IsNullOrWhiteSpace($this._menuItems[$newIndex].Text)
                    )
                    
                    if ($newIndex -ne $this._selectedIndex) {
                        $this._selectedIndex = $newIndex
                        $this.RefreshThemeColors()
                        $this.RequestRedraw()
                        Write-Log -Level Debug -Message "DashboardScreen: Selected index changed to $($this._selectedIndex)"
                    }
                    $handled = $true
                }
                
                ([ConsoleKey]::Enter) {
                    Write-Log -Level Debug -Message "DashboardScreen: Enter pressed on index $($this._selectedIndex)"
                    # Execute action based on selected index
                    switch ($this._selectedIndex) {
                        0 { $handled = $true } # Dashboard - already here
                        1 { $actionService.ExecuteAction("navigation.taskList", @{}); $handled = $true }
                        2 { 
                            if ($navService) {
                                $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                                $projectsScreen.Initialize()
                                $navService.NavigateTo($projectsScreen)
                            }
                            $handled = $true 
                        }
                        3 { $actionService.ExecuteAction("tools.fileCommander", @{}); $handled = $true }
                        4 { $actionService.ExecuteAction("tools.textEditor", @{}); $handled = $true }
                        5 { $actionService.ExecuteAction("navigation.themePicker", @{}); $handled = $true }
                        6 { $actionService.ExecuteAction("app.commandPalette", @{}); $handled = $true }
                        8 { $actionService.ExecuteAction("app.exit", @{}); $handled = $true } # Quit
                    }
                }
                
                # === ALSO CHECK D1-D7 CONSOLE KEYS ===
                ([ConsoleKey]::D1) { 
                    Write-Log -Level Debug -Message "DashboardScreen: D1 key pressed"
                    $handled = $true 
                }
                ([ConsoleKey]::D2) { 
                    $actionService.ExecuteAction("navigation.taskList", @{})
                    $handled = $true 
                }
                ([ConsoleKey]::D3) { 
                    if ($navService) {
                        $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                        $projectsScreen.Initialize()
                        $navService.NavigateTo($projectsScreen)
                    }
                    $handled = $true 
                }
                ([ConsoleKey]::D4) { 
                    $actionService.ExecuteAction("tools.fileCommander", @{})
                    $handled = $true 
                }
                ([ConsoleKey]::D5) { 
                    $actionService.ExecuteAction("tools.textEditor", @{})
                    $handled = $true 
                }
                ([ConsoleKey]::D6) { 
                    $actionService.ExecuteAction("navigation.themePicker", @{})
                    $handled = $true 
                }
                ([ConsoleKey]::D7) { 
                    $actionService.ExecuteAction("app.commandPalette", @{})
                    $handled = $true 
                }
                ([ConsoleKey]::Q) { 
                    $actionService.ExecuteAction("app.exit", @{})
                    $handled = $true 
                }
                
                # === ESCAPE TO EXIT ===
                ([ConsoleKey]::Escape) {
                    Write-Log -Level Debug -Message "DashboardScreen: Escape pressed - exiting"
                    $actionService.ExecuteAction("app.exit", @{})
                    $handled = $true
                }
            }
        }
        
        # === CHECK GLOBAL KEYBINDINGS (Ctrl+P, etc) ===
        if (-not $handled) {
            # Check for Ctrl+P (Command Palette)
            if ($keyInfo.Key -eq [ConsoleKey]::P -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
                Write-Log -Level Debug -Message "DashboardScreen: Ctrl+P pressed - opening command palette"
                $actionService.ExecuteAction("app.commandPalette", @{})
                $handled = $true
            }
        }
        
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Returning handled=$handled"
        return $handled
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "DashboardScreen.OnExit: Cleaning up"
        # No special cleanup needed for this screen
    }
}

# ==============================================================================
# END OF DASHBOARD SCREEN
# ==============================================================================
