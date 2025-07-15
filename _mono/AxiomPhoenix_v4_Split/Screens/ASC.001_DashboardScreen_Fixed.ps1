# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# FIXED: Properly responds to theme changes and uses Get-ThemeColor
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
        
        # Add Panel to screen
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
            
            # Get theme colors
            $normalFg = Get-ThemeColor "foreground"
            $normalBg = Get-ThemeColor "palette.background"
            $selectedFg = Get-ThemeColor "listbox.selectedforeground"
            $selectedBg = Get-ThemeColor "listbox.selectedbackground"
            $separatorFg = Get-ThemeColor "palette.muted"
            
            # Draw menu items
            for ($i = 0; $i -lt $this._menuItems.Count -and $i -lt $contentHeight; $i++) {
                $item = $this._menuItems[$i]
                $y = $contentY + $i
                
                if ($i -eq $this._selectedIndex) {
                    # Highlighted item
                    # Fill selection background
                    for ($xx = $contentX; $xx -lt ($contentX + $contentWidth); $xx++) {
                        $this._private_buffer.SetCell($xx, $y, [TuiCell]::new(' ', $selectedFg, $selectedBg))
                    }
                    
                    # Write highlighted text
                    if ($item -ne "────────────────") {
                        Write-TuiText -Buffer $this._private_buffer -X $contentX -Y $y -Text $item -Style @{ FG = $selectedFg; BG = $selectedBg }
                    }
                } else {
                    # Normal item
                    $itemFg = if ($item -eq "────────────────") { $separatorFg } else { $normalFg }
                    Write-TuiText -Buffer $this._private_buffer -X $contentX -Y $y -Text $item -Style @{ FG = $itemFg; BG = $normalBg }
                }
            }
        }
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        $this.UpdateThemeColors()
        $this.UpdatePanelLayout()
        
        # Subscribe to theme change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $thisScreen = $this
            $handler = {
                param($eventData)
                Write-Log -Level Debug -Message "DashboardScreen: Theme changed event received"
                $thisScreen.UpdateThemeColors()
                $thisScreen.RequestRedraw()
            }.GetNewClosure()
            
            $this._themeChangeSubscriptionId = $eventManager.Subscribe("Theme.Changed", $handler)
            Write-Log -Level Debug -Message "DashboardScreen: Subscribed to Theme.Changed events"
        }
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        $this.RequestRedraw()
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
            # Update panel colors using Get-ThemeColor
            if ($this._panel) {
                $this._panel.BackgroundColor = Get-ThemeColor "palette.background"
                $this._panel.BorderColor = Get-ThemeColor "palette.border"
                $this._panel.ForegroundColor = Get-ThemeColor "foreground"
                
                # Update focus colors
                $this._panel | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
                    $this.BorderColor = Get-ThemeColor "palette.primary"
                    $this.RequestRedraw()
                } -Force
                
                $this._panel | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
                    $this.BorderColor = Get-ThemeColor "palette.border"
                    $this.RequestRedraw()
                } -Force
            }
            
            # Update screen colors
            $this.BackgroundColor = Get-ThemeColor "palette.background"
            $this.ForegroundColor = Get-ThemeColor "foreground"
            
            Write-Log -Level Info -Message "DashboardScreen: Updated theme colors"
        } catch {
            Write-Log -Level Error -Message "DashboardScreen: Error updating colors: $_"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # ALWAYS FIRST - Let base handle Tab and component routing  
        if (([Screen]$this).HandleInput($keyInfo)) {
            return $true
        }
        
        # Handle navigation
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
                $this.ExecuteMenuItem($this._selectedIndex)
                return $true
            }
        }
        
        # Handle direct number keys
        switch ($keyInfo.Key) {
            ([ConsoleKey]::D1) { $this.ExecuteMenuItem(0); return $true }
            ([ConsoleKey]::D2) { $this.ExecuteMenuItem(1); return $true }
            ([ConsoleKey]::D3) { $this.ExecuteMenuItem(2); return $true }
            ([ConsoleKey]::D4) { $this.ExecuteMenuItem(3); return $true }
            ([ConsoleKey]::D5) { $this.ExecuteMenuItem(4); return $true }
            ([ConsoleKey]::D6) { $this.ExecuteMenuItem(5); return $true }
            ([ConsoleKey]::D7) { $this.ExecuteMenuItem(6); return $true }
            ([ConsoleKey]::Q) { $this.ExecuteMenuItem(8); return $true }
        }
        
        # Handle character keys
        switch ($keyInfo.KeyChar) {
            '1' { $this.ExecuteMenuItem(0); return $true }
            '2' { $this.ExecuteMenuItem(1); return $true }
            '3' { $this.ExecuteMenuItem(2); return $true }
            '4' { $this.ExecuteMenuItem(3); return $true }
            '5' { $this.ExecuteMenuItem(4); return $true }
            '6' { $this.ExecuteMenuItem(5); return $true }
            '7' { $this.ExecuteMenuItem(6); return $true }
            { $_ -eq 'q' -or $_ -eq 'Q' } { $this.ExecuteMenuItem(8); return $true }
        }
        
        return $false
    }
    
    hidden [void] ExecuteMenuItem([int]$index) {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if (-not $actionService) { 
            Write-Log -Level Error -Message "DashboardScreen: ActionService not found!"
            return
        }
        
        Write-Log -Level Debug -Message "DashboardScreen: Executing menu item $index"
        
        switch ($index) {
            0 { Write-Log -Level Debug -Message "Dashboard (current)" }
            1 { $actionService.ExecuteAction("navigation.taskList", @{}) }
            2 { $actionService.ExecuteAction("navigation.projects", @{}) }
            3 { $actionService.ExecuteAction("tools.fileCommander", @{}) }
            4 { $actionService.ExecuteAction("tools.textEditor", @{}) }
            5 { $actionService.ExecuteAction("navigation.themePicker", @{}) }
            6 { $actionService.ExecuteAction("app.commandPalette", @{}) }
            8 { $actionService.ExecuteAction("app.exit", @{}) }
        }
    }
    
    [void] OnExit() {
        Write-Log -Level Debug -Message "DashboardScreen.OnExit: Cleaning up"
        
        # Unsubscribe from theme change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._themeChangeSubscriptionId) {
            $eventManager.Unsubscribe("Theme.Changed", $this._themeChangeSubscriptionId)
            $this._themeChangeSubscriptionId = $null
            Write-Log -Level Debug -Message "DashboardScreen: Unsubscribed from Theme.Changed events"
        }
    }
}
