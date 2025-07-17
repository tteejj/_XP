# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# SIMPLIFIED: Numeric keys only, scrollable list with Enter selection
# ==============================================================================

class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [ListBox] $_menuListBox
    hidden [string] $_themeChangeSubscriptionId = $null
    hidden $_navService
    
    # Menu items with their target screens
    hidden [hashtable[]] $_menuItems = @(
        @{ Text = "1. Dashboard (Current)"; Action = $null },
        @{ Text = "2. Project Dashboard"; Action = "ProjectDashboardScreen" },
        @{ Text = "3. Task List"; Action = "TaskListScreen" },
        @{ Text = "4. Projects"; Action = "ProjectsListScreen" },
        @{ Text = "5. File Browser"; Action = "FileBrowserScreen" },
        @{ Text = "6. Text Editor"; Action = "TextEditScreen" },
        @{ Text = "7. Theme Picker"; Action = "ThemeScreen" },
        @{ Text = "8. Command Palette"; Action = "CommandPaletteScreen" },
        @{ Text = "9. View Timesheet"; Action = "TimesheetScreen" },
        @{ Text = "0. Quit"; Action = "Quit" }
    )
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "DashboardScreen: Constructor called"
        $this._navService = $serviceContainer.GetService("NavigationService")
    }

    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting"
        
        # Create main panel
        $panelWidth = [Math]::Min(60, $this.Width - 4)
        $panelHeight = [Math]::Min(18, $this.Height - 4)
        
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = [Math]::Floor(($this.Width - $panelWidth) / 2)
        $this._mainPanel.Y = [Math]::Floor(($this.Height - $panelHeight) / 2)
        $this._mainPanel.Width = $panelWidth
        $this._mainPanel.Height = $panelHeight
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
        $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
        $this._mainPanel.ForegroundColor = Get-ThemeColor "panel.foreground"
        
        # Create ListBox for menu items
        $this._menuListBox = [ListBox]::new("MenuList")
        $this._menuListBox.IsFocusable = $true
        $this._menuListBox.TabIndex = 0
        $this._menuListBox.X = 2
        $this._menuListBox.Y = 2
        $this._menuListBox.Width = $panelWidth - 4
        $this._menuListBox.Height = $panelHeight - 4
        $this._menuListBox.HasBorder = $false
        
        # Add menu items to ListBox
        foreach ($item in $this._menuItems) {
            $this._menuListBox.AddItem($item.Text)
        }
        
        # Set event handler for selection changes
        $currentScreenRef = $this
        $this._menuListBox.SelectedIndexChanged = {
            param($sender, $index)
            Write-Log -Level Debug -Message "Menu selection changed to: $index"
        }.GetNewClosure()
        
        # Add components
        $this._mainPanel.AddChild($this._menuListBox)
        $this.AddChild($this._mainPanel)
        
        $this._isInitialized = $true
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Completed"
    }


    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        
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
        if ($this._mainPanel -and $this._menuListBox) {
            # Recalculate panel size and position for current screen size
            $panelWidth = [Math]::Min(60, $this.Width - 4)
            $panelHeight = [Math]::Min(18, $this.Height - 4)
            
            $this._mainPanel.X = [Math]::Floor(($this.Width - $panelWidth) / 2)
            $this._mainPanel.Y = [Math]::Floor(($this.Height - $panelHeight) / 2)
            $this._mainPanel.Width = $panelWidth
            $this._mainPanel.Height = $panelHeight
            
            # Update ListBox size
            $this._menuListBox.Width = $panelWidth - 4
            $this._menuListBox.Height = $panelHeight - 4
        }
    }
    
    hidden [void] UpdateThemeColors() {
        try {
            # Update panel colors
            if ($this._mainPanel) {
                $this._mainPanel.BackgroundColor = Get-ThemeColor "panel.background"
                $this._mainPanel.BorderColor = Get-ThemeColor "panel.border"
                $this._mainPanel.ForegroundColor = Get-ThemeColor "panel.foreground"
            }
            
            # Update ListBox colors
            if ($this._menuListBox) {
                $this._menuListBox.BackgroundColor = Get-ThemeColor "list.background"
                $this._menuListBox.ForegroundColor = Get-ThemeColor "list.foreground"
            }
            
            # Update screen colors
            $this.BackgroundColor = Get-ThemeColor "screen.background"
            $this.ForegroundColor = Get-ThemeColor "screen.foreground"
            
            Write-Log -Level Debug -Message "DashboardScreen: Updated theme colors"
        } catch {
            Write-Log -Level Error -Message "DashboardScreen: Error updating colors: $_"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        # Get focused component
        $focused = $this.GetFocusedChild()
        
        # Handle screen-level actions based on focused component
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # Execute action when Enter is pressed on ListBox
                if ($focused -eq $this._menuListBox -and $this._menuListBox.SelectedIndex -ge 0) {
                    $this.ExecuteMenuItem($this._menuListBox.SelectedIndex)
                    return $true
                }
            }
        }
        
        # Handle direct number keys (0-9) for quick navigation
        switch ($keyInfo.KeyChar) {
            '1' { $this.ExecuteMenuItem(0); return $true }
            '2' { $this.ExecuteMenuItem(1); return $true }
            '3' { $this.ExecuteMenuItem(2); return $true }
            '4' { $this.ExecuteMenuItem(3); return $true }
            '5' { $this.ExecuteMenuItem(4); return $true }
            '6' { $this.ExecuteMenuItem(5); return $true }
            '7' { $this.ExecuteMenuItem(6); return $true }
            '8' { $this.ExecuteMenuItem(7); return $true }
            '9' { $this.ExecuteMenuItem(8); return $true }
            '0' { $this.ExecuteMenuItem(9); return $true }
        }
        
        # Let base handle Tab and route to components (ListBox handles arrows)
        return ([Screen]$this).HandleInput($keyInfo)
    }
    
    hidden [void] ExecuteMenuItem([int]$index) {
        if ($index -lt 0 -or $index -ge $this._menuItems.Count) { return }
        
        $menuItem = $this._menuItems[$index]
        $action = $menuItem.Action
        
        Write-Log -Level Debug -Message "DashboardScreen: Executing menu item $index - $($menuItem.Text)"
        
        # Handle special cases
        if ($null -eq $action) {
            # Current screen, do nothing
            return
        }
        elseif ($action -eq "Quit") {
            # Exit application
            $actionService = $this.ServiceContainer?.GetService("ActionService")
            if ($actionService) {
                $actionService.ExecuteAction("app.exit", @{})
            }
        }
        else {
            # Navigate to screen
            $this.NavigateToScreen($action)
        }
    }
    
    hidden [void] NavigateToScreen([string]$screenClassName) {
        if (-not $this._navService) {
            Write-Log -Level Error -Message "DashboardScreen: NavigationService not available"
            return
        }
        
        try {
            Write-Log -Level Debug -Message "DashboardScreen: Creating $screenClassName"
            $screen = New-Object $screenClassName -ArgumentList $this.ServiceContainer
            
            Write-Log -Level Debug -Message "DashboardScreen: Initializing $screenClassName"
            $screen.Initialize()
            
            Write-Log -Level Debug -Message "DashboardScreen: Navigating to $screenClassName"
            $this._navService.NavigateTo($screen)
        } catch {
            Write-Log -Level Error -Message "DashboardScreen: Failed to navigate to $screenClassName : $_"
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
        
        # Base class handles cleanup
        ([Screen]$this).OnExit()
    }
}