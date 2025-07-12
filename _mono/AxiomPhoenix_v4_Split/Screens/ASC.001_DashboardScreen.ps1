# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# REFACTORED: Uses hybrid window model with focusable menu component
# ==============================================================================

# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# REFACTORED: Uses hybrid window model with focusable menu component
# ==============================================================================

using namespace System.Collections.Generic

# ==============================================================================
# CLASS: MenuListComponent - Focusable menu component
# ==============================================================================
class MenuListComponent : Component {
    hidden [List[string]] $_menuItems
    hidden [int] $_selectedIndex = 0
    hidden [scriptblock] $_onItemSelected
    
    MenuListComponent([string]$name) : base($name) {
        $this._menuItems = [List[string]]::new()
        $this.IsFocusable = $true
        $this.TabIndex = 0
    }
    
    [void] AddMenuItem([string]$text) {
        $this._menuItems.Add($text)
    }
    
    [void] SetOnItemSelected([scriptblock]$callback) {
        $this._onItemSelected = $callback
    }
    
    [int] GetSelectedIndex() {
        return $this._selectedIndex
    }
    
    [void] SetSelectedIndex([int]$index) {
        if ($index -ge 0 -and $index -lt $this._menuItems.Count) {
            $this._selectedIndex = $index
            $this.RequestRedraw()
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if (-not $this.IsFocused) { return $false }
        
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                $newIndex = $this._selectedIndex
                do {
                    $newIndex--
                    if ($newIndex -lt 0) { $newIndex = $this._menuItems.Count - 1 }
                } while (
                    $newIndex -ne $this._selectedIndex -and 
                    [string]::IsNullOrWhiteSpace($this._menuItems[$newIndex])
                )
                
                if ($newIndex -ne $this._selectedIndex) {
                    $this._selectedIndex = $newIndex
                    $this.RequestRedraw()
                }
                return $true
            }
            
            ([ConsoleKey]::DownArrow) {
                $newIndex = $this._selectedIndex
                do {
                    $newIndex++
                    if ($newIndex -ge $this._menuItems.Count) { $newIndex = 0 }
                } while (
                    $newIndex -ne $this._selectedIndex -and 
                    [string]::IsNullOrWhiteSpace($this._menuItems[$newIndex])
                )
                
                if ($newIndex -ne $this._selectedIndex) {
                    $this._selectedIndex = $newIndex
                    $this.RequestRedraw()
                }
                return $true
            }
            
            ([ConsoleKey]::Enter) {
                if ($this._onItemSelected) {
                    & $this._onItemSelected $this._selectedIndex
                }
                return $true
            }
            
            ([ConsoleKey]::Home) {
                $this._selectedIndex = 0
                $this.RequestRedraw()
                return $true
            }
            
            ([ConsoleKey]::End) {
                $this._selectedIndex = $this._menuItems.Count - 1
                $this.RequestRedraw()
                return $true
            }
        }
        
        return $false
    }
    
    [void] OnFocus() {
        $this.BorderColor = Get-ThemeColor "Panel.Title" "#007acc"
        $this.RequestRedraw()
    }
    
    [void] OnBlur() {
        $this.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
        $this.RequestRedraw()
    }
    
    [void] OnRender([TuiBuffer]$buffer) {
        # Clear the component area
        $bgColor = $this.GetEffectiveBackgroundColor()
        $fgColor = $this.GetEffectiveForegroundColor()
        
        for ($y = 0; $y -lt $this.Height; $y++) {
            for ($x = 0; $x -lt $this.Width; $x++) {
                $buffer.SetCell($this.X + $x, $this.Y + $y, ' ', $fgColor, $bgColor)
            }
        }
        
        # Render menu items
        for ($i = 0; $i -lt $this._menuItems.Count -and $i -lt $this.Height; $i++) {
            $text = $this._menuItems[$i]
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $fg = if ($i -eq $this._selectedIndex) { 
                    Get-ThemeColor "Panel.Title" "#007acc"
                } else { 
                    Get-ThemeColor "Label.Foreground" "#d4d4d4"
                }
                $bg = if ($i -eq $this._selectedIndex) { 
                    Get-ThemeColor "List.ItemFocusedBackground" "#3a3a3a"
                } else { 
                    $bgColor
                }
                
                # Truncate text if too long
                $displayText = if ($text.Length -gt $this.Width - 4) { 
                    $text.Substring(0, $this.Width - 7) + "..." 
                } else { 
                    $text.PadRight($this.Width - 4) 
                }
                
                $xPos = $this.X + 2
                for ($j = 0; $j -lt $displayText.Length -and $j -lt $this.Width - 4; $j++) {
                    $buffer.SetCell($xPos + $j, $this.Y + $i, $displayText[$j], $fg, $bg)
                }
            }
        }
    }
}
class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_menuPanel
    hidden [MenuListComponent] $_menuList
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "DashboardScreen: Constructor called"
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting initialization"
        
        if (-not $this.ServiceContainer) { 
            Write-Log -Level Error -Message "DashboardScreen.Initialize: ServiceContainer is null!"
            throw "ServiceContainer is required"
        }

        # === CREATE MAIN PANEL ===
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BorderStyle = "Double"
        $this._mainPanel.IsFocusable = $false
        $this.AddChild($this._mainPanel)

        # === CREATE MENU PANEL ===
        $this._menuPanel = [Panel]::new("MenuPanel")
        $this._menuPanel.X = [Math]::Floor(($this.Width - 40) / 2)
        $this._menuPanel.Y = 5
        $this._menuPanel.Width = 40
        $this._menuPanel.Height = 14
        $this._menuPanel.HasBorder = $true
        $this._menuPanel.BorderStyle = "Double"
        $this._menuPanel.Title = " Navigation "
        $this._menuPanel.IsFocusable = $false
        $this._mainPanel.AddChild($this._menuPanel)
        
        # === CREATE FOCUSABLE MENU LIST ===
        $this._menuList = [MenuListComponent]::new("MainMenu")
        $this._menuList.X = 1
        $this._menuList.Y = 1
        $this._menuList.Width = 38
        $this._menuList.Height = 12
        $this._menuList.IsFocusable = $true
        $this._menuList.TabIndex = 0
        
        # Add menu items
        $this._menuList.AddMenuItem("[1] Dashboard (Current)")
        $this._menuList.AddMenuItem("[2] Task List")
        $this._menuList.AddMenuItem("[3] Projects")
        $this._menuList.AddMenuItem("[4] File Browser")
        $this._menuList.AddMenuItem("[5] Text Editor")
        $this._menuList.AddMenuItem("[6] Theme Picker")
        $this._menuList.AddMenuItem("[7] Command Palette (Ctrl+P)")
        $this._menuList.AddMenuItem("")
        $this._menuList.AddMenuItem("[Q] Quit")
        
        # Set selection handler
        $this._menuList.SetOnItemSelected({
            param($index)
            $this.ExecuteMenuItem($index)
        })
        
        $this._menuPanel.AddChild($this._menuList)
        
        # === CREATE INSTRUCTIONS ===
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Use number keys or arrow keys + Enter to select"
        $instructions.X = [Math]::Floor(($this.Width - 42) / 2)
        $instructions.Y = 21
        $instructions.IsFocusable = $false
        $instructions.ForegroundColor = Get-ThemeColor "Label.Foreground" "#9ca3af"
        $this._mainPanel.AddChild($instructions)
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        
        # Call base to set up focus management
        ([Screen]$this).OnEnter()
        
        # Refresh colors in case theme changed
        $this.RefreshThemeColors()
        
        # Request redraw
        $this.RequestRedraw()
    }
    
    hidden [void] RefreshThemeColors() {
        try {
            if ($this._mainPanel) {
                $this._mainPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
                $this._mainPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
            }
            
            if ($this._menuPanel) {
                $this._menuPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
                $this._menuPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
            }
            
            $instructions = $this._mainPanel.Children | Where-Object { $_.Name -eq "Instructions" }
            if ($instructions) {
                $instructions.ForegroundColor = Get-ThemeColor "Label.Foreground" "#9ca3af"
            }
        }
        catch {
            Write-Log -Level Error -Message "DashboardScreen.RefreshThemeColors: Error updating colors: $_"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # HYBRID MODEL: Call base first for Tab navigation and component input
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle direct number key shortcuts (global shortcuts)
        $char = $keyInfo.KeyChar
        switch ($char) {
            '1' { $this.ExecuteMenuItem(0); return $true }
            '2' { $this.ExecuteMenuItem(1); return $true }
            '3' { $this.ExecuteMenuItem(2); return $true }
            '4' { $this.ExecuteMenuItem(3); return $true }
            '5' { $this.ExecuteMenuItem(4); return $true }
            '6' { $this.ExecuteMenuItem(5); return $true }
            '7' { $this.ExecuteMenuItem(6); return $true }
            { $_ -eq 'q' -or $_ -eq 'Q' } { $this.ExecuteMenuItem(8); return $true }
        }
        
        # Handle console number keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::D1) { $this.ExecuteMenuItem(0); return $true }
            ([ConsoleKey]::D2) { $this.ExecuteMenuItem(1); return $true }
            ([ConsoleKey]::D3) { $this.ExecuteMenuItem(2); return $true }
            ([ConsoleKey]::D4) { $this.ExecuteMenuItem(3); return $true }
            ([ConsoleKey]::D5) { $this.ExecuteMenuItem(4); return $true }
            ([ConsoleKey]::D6) { $this.ExecuteMenuItem(5); return $true }
            ([ConsoleKey]::D7) { $this.ExecuteMenuItem(6); return $true }
            ([ConsoleKey]::Q) { $this.ExecuteMenuItem(8); return $true }
            ([ConsoleKey]::Escape) { $this.ExecuteMenuItem(8); return $true }
        }
        
        # Check for Ctrl+P (Command Palette)
        if ($keyInfo.Key -eq [ConsoleKey]::P -and ($keyInfo.Modifiers -band [ConsoleModifiers]::Control)) {
            $this.ExecuteMenuItem(6)
            return $true
        }
        
        return $false
    }
    
    hidden [void] ExecuteMenuItem([int]$index) {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        $navService = $this.ServiceContainer?.GetService("NavigationService")
        
        if (-not $actionService) { 
            Write-Log -Level Error -Message "DashboardScreen: ActionService not found!"
            return
        }
        
        Write-Log -Level Debug -Message "DashboardScreen: Executing menu item $index"
        
        switch ($index) {
            0 { 
                Write-Log -Level Debug -Message "Dashboard (current screen)"
            }
            1 { 
                $actionService.ExecuteAction("navigation.taskList", @{})
            }
            2 { 
                if ($navService) {
                    $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                    $projectsScreen.Initialize()
                    $navService.NavigateTo($projectsScreen)
                }
            }
            3 { 
                $actionService.ExecuteAction("tools.fileCommander", @{})
            }
            4 { 
                $actionService.ExecuteAction("tools.textEditor", @{})
            }
            5 { 
                $actionService.ExecuteAction("navigation.themePicker", @{})
            }
            6 { 
                $actionService.ExecuteAction("app.commandPalette", @{})
            }
            8 { 
                $actionService.ExecuteAction("app.exit", @{})
            }
        }
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "DashboardScreen.OnExit: Cleaning up"
    }
}

# ==============================================================================
# END OF DASHBOARD SCREEN
# ==============================================================================
