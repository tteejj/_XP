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
        # #Write-Host "DASHBOARD: Constructor called" -ForegroundColor Gray
        $this._navService = $serviceContainer.GetService("NavigationService")
    }

    [void] Initialize() {
        if ($this._isInitialized) { return }
        
        # #Write-Host "DASHBOARD: Initialize starting" -ForegroundColor Gray
        
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
            # #Write-Host "DASHBOARD: Menu selection changed to: $index" -ForegroundColor Gray
        }.GetNewClosure()
        
        # Add components
        $this._mainPanel.AddChild($this._menuListBox)
        $this.AddChild($this._mainPanel)
        
        $this._isInitialized = $true
        # #Write-Host "DASHBOARD: Initialize completed" -ForegroundColor Gray
    }


    [void] OnEnter() {
        # #Write-Host "DASHBOARD: OnEnter - Screen activated" -ForegroundColor Green
        # #Write-Host "DASHBOARD: OnEnter called" -ForegroundColor Green
        
        # Subscribe to theme change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager) {
            $thisScreen = $this
            $handler = {
                param($eventData)
                # #Write-Host "DASHBOARD: Theme changed event received" -ForegroundColor Gray
                $thisScreen.UpdateThemeColors()
                $thisScreen.RequestRedraw()
            }.GetNewClosure()
            
            $this._themeChangeSubscriptionId = $eventManager.Subscribe("Theme.Changed", $handler)
            # #Write-Host "DASHBOARD: Subscribed to Theme.Changed events" -ForegroundColor Gray
        }
        
        # Log ListBox state before calling base
        if ($this._menuListBox) {
            # #Write-Host "DASHBOARD: ListBox state before base call - IsFocusable=$($this._menuListBox.IsFocusable) IsFocused=$($this._menuListBox.IsFocused) TabIndex=$($this._menuListBox.TabIndex)" -ForegroundColor Gray
        } else {
            #Write-Host "DASHBOARD: ERROR - _menuListBox is NULL!" -ForegroundColor Red
        }
        
        # MUST call base to set initial focus
        # #Write-Host "DASHBOARD: Calling base OnEnter" -ForegroundColor Gray
        ([Screen]$this).OnEnter()
        
        # Log ListBox state after calling base
        if ($this._menuListBox) {
            # #Write-Host "DASHBOARD: ListBox state after base call - IsFocusable=$($this._menuListBox.IsFocusable) IsFocused=$($this._menuListBox.IsFocused) TabIndex=$($this._menuListBox.TabIndex)" -ForegroundColor Gray
        }
        
        # Log focused component
        $focused = $this.GetFocusedChild()
        # #Write-Host "DASHBOARD: Focused component after base call = $(if ($focused) { $focused.GetType().Name } else { 'NULL' })" -ForegroundColor Gray
        
        $this.RequestRedraw()
        # #Write-Host "DASHBOARD: OnEnter completed" -ForegroundColor Gray
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
            
            # #Write-Host "DASHBOARD: Updated theme colors" -ForegroundColor Gray
        } catch {
            #Write-Host "DASHBOARD: ERROR updating colors: $_" -ForegroundColor Red
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        "$(Get-Date -Format 'HH:mm:ss.fff') DASHBOARD: HandleInput Key=$($keyInfo.Key)" | Out-File -FilePath "/tmp/arrow-debug.log" -Append
        if ($null -eq $keyInfo) { 
            "$(Get-Date -Format 'HH:mm:ss.fff') DASHBOARD: NULL keyInfo" | Out-File -FilePath "/tmp/arrow-debug.log" -Append
            return $false 
        }
        
        # Get focused component
        $focused = $this.GetFocusedChild()
        # #Write-Host "DASHBOARD: Focused component = $(if ($focused) { $focused.GetType().Name } else { 'NULL' })" -ForegroundColor Gray
        
        # Log ListBox state
        if ($this._menuListBox) {
            # #Write-Host "DASHBOARD: ListBox.SelectedIndex=$($this._menuListBox.SelectedIndex) IsFocused=$($this._menuListBox.IsFocused) IsFocusable=$($this._menuListBox.IsFocusable)" -ForegroundColor Gray
        } else {
            #Write-Host "DASHBOARD: ERROR - _menuListBox is NULL!" -ForegroundColor Red
        }
        
        # Handle screen-level actions based on focused component
        switch ($keyInfo.Key) {
            ([ConsoleKey]::Enter) {
                # #Write-Host "DASHBOARD: Enter key pressed" -ForegroundColor Yellow
                # Execute action when Enter is pressed on ListBox
                if ($focused -eq $this._menuListBox -and $this._menuListBox.SelectedIndex -ge 0) {
                    # #Write-Host "DASHBOARD: Executing menu item via Enter" -ForegroundColor Yellow
                    $this.ExecuteMenuItem($this._menuListBox.SelectedIndex)
                    return $true
                } else {
                    # #Write-Host "DASHBOARD: Enter pressed but conditions not met - focused=$($focused -eq $this._menuListBox) selectedIndex=$($this._menuListBox.SelectedIndex)" -ForegroundColor Yellow
                }
            }
            # Remove arrow key interception - let them pass through to ListBox
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
        "$(Get-Date -Format 'HH:mm:ss.fff') DASHBOARD: Calling base Screen.HandleInput" | Out-File -FilePath "/tmp/arrow-debug.log" -Append
        try {
            $result = ([Screen]$this).HandleInput($keyInfo)
            "$(Get-Date -Format 'HH:mm:ss.fff') DASHBOARD: Base returned $result" | Out-File -FilePath "/tmp/arrow-debug.log" -Append
            return $result
        } catch {
            "$(Get-Date -Format 'HH:mm:ss.fff') DASHBOARD: EXCEPTION: $_" | Out-File -FilePath "/tmp/arrow-debug.log" -Append
            return $false
        }
    }
    
    hidden [void] ExecuteMenuItem([int]$index) {
        if ($index -lt 0 -or $index -ge $this._menuItems.Count) { return }
        
        $menuItem = $this._menuItems[$index]
        $action = $menuItem.Action
        
        # #Write-Host "DASHBOARD: Executing menu item $index - $($menuItem.Text)" -ForegroundColor Yellow
        
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
            #Write-Host "DASHBOARD: ERROR - NavigationService not available" -ForegroundColor Red
            return
        }
        
        try {
            # #Write-Host "DASHBOARD: Creating $screenClassName" -ForegroundColor Gray
            $screen = New-Object $screenClassName -ArgumentList $this.ServiceContainer
            
            # #Write-Host "DASHBOARD: Initializing $screenClassName" -ForegroundColor Gray
            $screen.Initialize()
            
            # #Write-Host "DASHBOARD: Navigating to $screenClassName" -ForegroundColor Gray
            $this._navService.NavigateTo($screen)
        } catch {
            #Write-Host "DASHBOARD: ERROR - Failed to navigate to $screenClassName : $_" -ForegroundColor Red
        }
    }
    
    [void] OnExit() {
        # #Write-Host "DASHBOARD: OnExit cleaning up" -ForegroundColor Gray
        
        # Unsubscribe from theme change events
        $eventManager = $this.ServiceContainer?.GetService("EventManager")
        if ($eventManager -and $this._themeChangeSubscriptionId) {
            $eventManager.Unsubscribe("Theme.Changed", $this._themeChangeSubscriptionId)
            $this._themeChangeSubscriptionId = $null
            # #Write-Host "DASHBOARD: Unsubscribed from Theme.Changed events" -ForegroundColor Gray
        }
        
        # Base class handles cleanup
        ([Screen]$this).OnExit()
    }
}