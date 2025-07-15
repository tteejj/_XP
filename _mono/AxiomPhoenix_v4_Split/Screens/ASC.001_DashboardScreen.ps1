# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# FIXED: Proper theme handling and color consistency
# ==============================================================================

class DashboardScreen : Screen {
    hidden [Panel] $_panel
    hidden [int] $_selectedIndex = 0
    hidden [string[]] $_menuItems
    hidden [bool] $_isInitialized = $false
    hidden [string] $_themeChangeSubscriptionId = $null
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "DashboardScreen: Constructor called"
        $this._menuItems = @(
            "[1] Dashboard (Current)",
            "[2] Task List", 
            "[3] Projects",
            "[4] File Browser",
            "[5] Text Editor",
            "[6] Theme Picker",
            "[7] Command Palette",
            "────────────────",
            "[Q] Quit"
        )
        # Start on first valid menu item (skip separators)
        $this._selectedIndex = 0
        while ($this._selectedIndex -lt $this._menuItems.Count -and $this._menuItems[$this._selectedIndex] -eq "────────────────") {
            $this._selectedIndex++
        }
    }

    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting"
        
        # Subscribe to theme changes
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $thisScreen = $this
            $handler = {
                param($eventData)
                Write-Log -Level Debug -Message "DashboardScreen: Theme changed, updating colors"
                $thisScreen.UpdateThemeColors()
                $thisScreen.RequestRedraw()
            }.GetNewClosure()
            
            $this._themeChangeSubscriptionId = $eventManager.Subscribe("Theme.Changed", $handler)
        }
        
        # Create simple Panel container following the guide
        $panelWidth = [Math]::Min(60, $this.Width - 4)
        $panelHeight = [Math]::Min(16, $this.Height - 4)
        
        $this._panel = [Panel]::new("MainPanel")
        $this._panel.IsFocusable = $true
        $this._panel.TabIndex = 0
        $this._panel.X = [Math]::Floor(($this.Width - $panelWidth) / 2)
        $this._panel.Y = [Math]::Floor(($this.Height - $panelHeight) / 2)
        $this._panel.Width = $panelWidth
        $this._panel.Height = $panelHeight
        $this._panel.HasBorder = $true
        $this._panel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        
        # Set colors with PROPERTIES (following guide) - use theme colors
        $this._panel.BackgroundColor = Get-ThemeColor "panel.background" "#1e1e1e"
        $this._panel.BorderColor = Get-ThemeColor "panel.border" "#007acc"
        $this._panel.ForegroundColor = Get-ThemeColor "panel.foreground" "#d4d4d4"
        
        # Add focus behavior with Add-Member (following guide) - WITH theme caching
        $this._panel | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = Get-ThemeColor "palette.primary" "#0078d4"
            $this.RequestRedraw()
        } -Force
        
        $this._panel | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = Get-ThemeColor "panel.border" "#007acc"
            $this.RequestRedraw()
        } -Force
        
        # Add Panel to screen - NO custom OnRender on Panel
        $this.AddChild($this._panel)
        $this.UpdateThemeColors()
        
        $this._isInitialized = $true
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Completed"
    }

    # Override _RenderContent to draw menu items AFTER Panel renders
    hidden [void] _RenderContent() {
        # First let base render all children (including Panel)
        ([UIElement]$this)._RenderContent()
        
        # Then draw menu items on top of Panel's content area
        if ($this._panel -and $this._private_buffer) {
            $panelX = $this._panel.X
            $panelY = $this._panel.Y
            $panelWidth = $this._panel.Width
            $panelHeight = $this._panel.Height
            
            # Calculate content area inside Panel border
            $contentX = $panelX + 2
            $contentY = $panelY + 1
            $contentWidth = $panelWidth - 4
            $contentHeight = $panelHeight - 2
            
            # Draw menu items
            for ($i = 0; $i -lt $this._menuItems.Count -and $i -lt $contentHeight; $i++) {
                $item = $this._menuItems[$i]
                $y = $contentY + $i
                
                if ($i -eq $this._selectedIndex) {
                    # Highlighted item
                    $selFg = Get-ThemeColor "list.selected.foreground" "#ffffff"
                    $selBg = Get-ThemeColor "list.selected.background" "#007acc"
                    
                    # Fill selection background
                    for ($xx = $contentX; $xx -lt ($contentX + $contentWidth); $xx++) {
                        $this._private_buffer.SetCell($xx, $y, [TuiCell]::new(' ', $selFg, $selBg))
                    }
                    
                    # Write highlighted text
                    if ($item -ne "────────────────") {
                        Write-TuiText -Buffer $this._private_buffer -X $contentX -Y $y -Text $item -Style @{ FG = $selFg; BG = $selBg }
                    }
                } else {
                    # Normal item
                    $itemFg = Get-ThemeColor "foreground" "#d4d4d4"
                    if ($item -eq "────────────────") { $itemFg = Get-ThemeColor "text.muted" "#666666" }
                    $itemBg = Get-ThemeColor "palette.background" "#1e1e1e"
                    Write-TuiText -Buffer $this._private_buffer -X $contentX -Y $y -Text $item -Style @{ FG = $itemFg; BG = $itemBg }
                }
            }
        }
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        $this.UpdateThemeColors()
        $this.UpdatePanelLayout()
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
    }
    
    [void] OnExit() {
        # Unsubscribe from theme changes
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._themeChangeSubscriptionId) {
            $eventManager.Unsubscribe("Theme.Changed", $this._themeChangeSubscriptionId)
            $this._themeChangeSubscriptionId = $null
        }
    }
    
    [void] OnResize() {
        ([Screen]$this).OnResize()
        $this.UpdatePanelLayout()
    }
    
    hidden [void] UpdatePanelLayout() {
        if ($this._panel) {
            # Recalculate panel size and position for current screen size
            $panelWidth = [Math]::Min(60, $this.Width - 4)
            $panelHeight = [Math]::Min(16, $this.Height - 4)
            
            $this._panel.X = [Math]::Floor(($this.Width - $panelWidth) / 2)
            $this._panel.Y = [Math]::Floor(($this.Height - $panelHeight) / 2)
            $this._panel.Width = $panelWidth
            $this._panel.Height = $panelHeight
        }
    }
    
    hidden [void] UpdateThemeColors() {
        try {
            # Update panel with theme colors
            if ($this._panel) {
                $this._panel.BackgroundColor = Get-ThemeColor "panel.background" "#1e1e1e"
                $this._panel.BorderColor = Get-ThemeColor "panel.border" "#007acc"
                $this._panel.ForegroundColor = Get-ThemeColor "panel.foreground" "#d4d4d4"
                
                # Update focus colors in the closures
                $focusBorder = Get-ThemeColor "palette.primary" "#0078d4"
                $normalBorder = Get-ThemeColor "panel.border" "#007acc"
                
                $this._panel | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                    $this.BorderColor = $focusBorder
                    $this.RequestRedraw()
                }.GetNewClosure() -Force
                
                $this._panel | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                    $this.BorderColor = $normalBorder
                    $this.RequestRedraw()
                }.GetNewClosure() -Force
            }
            
            # Update screen background
            $this.BackgroundColor = Get-ThemeColor "palette.background" "#1e1e1e"
            $this.ForegroundColor = Get-ThemeColor "foreground" "#d4d4d4"
            
            $themeManager = $this.ServiceContainer?.GetService("ThemeManager")
            if ($themeManager) {
                Write-Log -Level Info -Message "DashboardScreen: Updated colors for '$($themeManager.ThemeName)'"
            }
        } catch {
            Write-Log -Level Error -Message "DashboardScreen: Error updating colors: $_"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Handle screen-level actions FIRST - GUIDE PATTERN
        switch ($keyInfo.Key) {
            ([ConsoleKey]::UpArrow) {
                do {
                    $this._selectedIndex--
                    if ($this._selectedIndex -lt 0) { $this._selectedIndex = $this._menuItems.Count - 1 }
                } while ($this._menuItems[$this._selectedIndex] -eq "────────────────")
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                do {
                    $this._selectedIndex++
                    if ($this._selectedIndex -ge $this._menuItems.Count) { $this._selectedIndex = 0 }
                } while ($this._menuItems[$this._selectedIndex] -eq "────────────────")
                $this.RequestRedraw()
                return $true
            }
            ([ConsoleKey]::Enter) {
                $this.ExecuteSelectedItem()
                return $true
            }
            ([ConsoleKey]::Escape) {
                # Back/Exit
                $actionService = $this.ServiceContainer?.GetService("ActionService")
                if ($actionService) {
                    $actionService.ExecuteAction("app.exit", @{})
                }
                return $true
            }
        }
        
        # Handle number key shortcuts
        if ($keyInfo.KeyChar -ge '1' -and $keyInfo.KeyChar -le '7') {
            $index = [int]($keyInfo.KeyChar.ToString()) - 1
            if ($index -ge 0 -and $index -lt $this._menuItems.Count) {
                $this._selectedIndex = $index
                $this.ExecuteSelectedItem()
                return $true
            }
        }
        
        # Handle Q for quit
        if ($keyInfo.KeyChar -eq 'q' -or $keyInfo.KeyChar -eq 'Q') {
            $actionService = $this.ServiceContainer?.GetService("ActionService")
            if ($actionService) {
                $actionService.ExecuteAction("app.exit", @{})
            }
            return $true
        }
        
        # Let base handle Tab and route to components - GUIDE PATTERN
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] ExecuteSelectedItem() {
        Write-Log -Level Debug -Message "DashboardScreen: Executing menu item $($this._selectedIndex)"
        
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if (-not $actionService) { return }
        
        switch ($this._selectedIndex) {
            0 { } # Already on dashboard
            1 { $actionService.ExecuteAction("navigation.taskList", @{}) }
            2 { $actionService.ExecuteAction("navigation.projects", @{}) }
            3 { $actionService.ExecuteAction("tools.fileCommander", @{}) }
            4 { $actionService.ExecuteAction("tools.textEditor", @{}) }
            5 { $actionService.ExecuteAction("navigation.themePicker", @{}) }
            6 { $actionService.ExecuteAction("app.commandPalette", @{}) }
            8 { $actionService.ExecuteAction("app.exit", @{}) } # Quit option
        }
    }
}

# ==============================================================================
# END OF DASHBOARD SCREEN
# ==============================================================================