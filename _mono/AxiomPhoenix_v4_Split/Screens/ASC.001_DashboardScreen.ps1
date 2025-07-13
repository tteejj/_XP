# ==============================================================================
# Axiom-Phoenix v4.0 - Dashboard Screen
# PROPERLY FIXED: Uses correct focus management and color properties
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
        $this.Enabled = $true  # Make sure it's enabled
        $this.Visible = $true  # Make sure it's visible
        Write-Log -Level Debug -Message "MenuListComponent constructor: IsFocusable=$($this.IsFocusable), TabIndex=$($this.TabIndex)"
    }
    
    [void] AddMenuItem([string]$text) {
        $this._menuItems.Add($text)
        $this.RequestRedraw()
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
        if (-not $this.IsFocused) { 
            Write-Log -Level Debug -Message "MenuListComponent.HandleInput: Not focused, returning false"
            return $false 
        }
        
        Write-Log -Level Debug -Message "MenuListComponent.HandleInput: Key=$($keyInfo.Key), IsFocused=$($this.IsFocused), SelectedIndex=$($this._selectedIndex)"
        
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
                Write-Log -Level Debug -Message "MenuListComponent: Enter pressed, selectedIndex=$($this._selectedIndex)"
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
    
    # REMOVED: OnFocus() and OnBlur() methods - these will be overridden with Add-Member
    
    [void] OnRender() {
        if ($null -eq $this._private_buffer) { 
            Write-Log -Level Debug -Message "MenuListComponent.OnRender: _private_buffer is null!"
            return 
        }
        
        Write-Log -Level Debug -Message "MenuListComponent.OnRender: IsFocused=$($this.IsFocused), SelectedIndex=$($this._selectedIndex)"
        
        $buffer = $this._private_buffer
        
        # Clear the component area
        $bgColor = $this.GetEffectiveBackgroundColor()
        $fgColor = $this.GetEffectiveForegroundColor()
        
        $buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
        
        # Render menu items
        for ($i = 0; $i -lt $this._menuItems.Count -and $i -lt $this.Height; $i++) {
            $text = $this._menuItems[$i]
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $itemFg = if ($i -eq $this._selectedIndex -and $this.IsFocused) { 
                    Get-ThemeColor "Panel.Title" "#007acc"
                } else { 
                    Get-ThemeColor "Label.Foreground" "#d4d4d4"
                }
                $itemBg = if ($i -eq $this._selectedIndex -and $this.IsFocused) { 
                    Get-ThemeColor "List.ItemFocusedBackground" "#3a3a3a"
                } else { 
                    $bgColor
                }
                
                # Truncate text if too long
                $displayText = if ($text.Length -gt $this.Width - 4) { 
                    $text.Substring(0, [Math]::Max(0, $this.Width - 7)) + "..."
                } else { 
                    $text
                }
                
                $xPos = 2
                # Fill the background for the selected line
                if ($i -eq $this._selectedIndex -and $this.IsFocused) {
                    for ($x = 0; $x -lt $this.Width; $x++) {
                        $buffer.SetCell($x, $i, [TuiCell]::new(' ', $itemFg, $itemBg))
                    }
                }

                $buffer.WriteString($xPos, $i, $displayText, @{ FG = $itemFg; BG = $itemBg })
            }
        }
    }
}

class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_menuPanel
    hidden [MenuListComponent] $_menuList
    hidden [bool] $_isInitialized = $false
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {
        Write-Log -Level Debug -Message "DashboardScreen: Constructor called"
    }

    [void] Initialize() {
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting initialization"
        
        # Guard against multiple initialization calls
        if ($this._isInitialized) {
            Write-Log -Level Debug -Message "DashboardScreen.Initialize: Already initialized, skipping"
            return
        }
        
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
        
        # Set colors with PROPERTIES
        $this._mainPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._mainPanel.ForegroundColor = Get-ThemeColor "Panel.Foreground" "#d4d4d4"
        $this._mainPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
        
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
        
        # Set colors with PROPERTIES
        $this._menuPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
        $this._menuPanel.ForegroundColor = Get-ThemeColor "Panel.Foreground" "#d4d4d4"
        $this._menuPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
        
        $this._mainPanel.AddChild($this._menuPanel)
        
        # === CREATE FOCUSABLE MENU LIST ===
        $this._menuList = [MenuListComponent]::new("MainMenu")
        $this._menuList.X = 1
        $this._menuList.Y = 1
        $this._menuList.Width = 38
        $this._menuList.Height = 12
        $this._menuList.IsFocusable = $true
        $this._menuList.TabIndex = 0
        $this._menuList.Visible = $true
        $this._menuList.Enabled = $true  # Ensure it's enabled
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Created MenuList - IsFocusable=$($this._menuList.IsFocusable), Visible=$($this._menuList.Visible), Enabled=$($this._menuList.Enabled)"
        
        # Set colors with PROPERTIES
        $this._menuList.BackgroundColor = Get-ThemeColor "Input.Background" "#262626"
        $this._menuList.ForegroundColor = Get-ThemeColor "Input.Foreground" "#d4d4d4"
        $this._menuList.BorderColor = Get-ThemeColor "Input.Border" "#404040"
        
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
        $screenRef = $this
        $this._menuList.SetOnItemSelected({
            param($index)
            $screenRef.ExecuteMenuItem($index)
        }.GetNewClosure())
        
        # PROPER FOCUS HANDLING: Store colors before closure
        $menuFocusBorder = Get-ThemeColor "primary.accent" "#0078d4"
        $menuBlurBorder = Get-ThemeColor "border" "#404040"
        
        $this._menuList | Add-Member -MemberType ScriptMethod -Name OnFocus -Value {
            $this.BorderColor = $menuFocusBorder
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        $this._menuList | Add-Member -MemberType ScriptMethod -Name OnBlur -Value {
            $this.BorderColor = $menuBlurBorder
            $this.RequestRedraw()
        }.GetNewClosure() -Force
        
        $this._menuPanel.AddChild($this._menuList)
        
        # === CREATE INSTRUCTIONS ===
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Use number keys or arrow keys + Enter to select"
        $instructions.X = [Math]::Floor(($this.Width - 42) / 2)
        $instructions.Y = 21
        $instructions.IsFocusable = $false
        $instructions.ForegroundColor = Get-ThemeColor "Label.Foreground" "#9ca3af"
        $instructions.BackgroundColor = Get-ThemeColor "Label.Background" "#1e1e1e"
        $this._mainPanel.AddChild($instructions)
        
        $this._menuList.RequestRedraw()
        
        # Mark as initialized
        $this._isInitialized = $true
        
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Completed"
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        
        # MUST call base to set initial focus
        ([Screen]$this).OnEnter()
        
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Base OnEnter called"
        
        # Explicitly focus the menu list if nothing is focused
        $focusedChild = $this.GetFocusedChild()
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Current focused child: $(if ($focusedChild) { $focusedChild.Name } else { 'none' })"
        
        if ($null -eq $focusedChild -and $this._menuList) {
            Write-Log -Level Debug -Message "DashboardScreen.OnEnter: No focused child, setting focus to menu list"
            $result = $this.SetChildFocus($this._menuList)
            Write-Log -Level Debug -Message "DashboardScreen.OnEnter: SetChildFocus result: $result"
            
            # Verify focus was set
            $newFocusedChild = $this.GetFocusedChild()
            Write-Log -Level Debug -Message "DashboardScreen.OnEnter: New focused child: $(if ($newFocusedChild) { $newFocusedChild.Name } else { 'none' })"
        } else {
            Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Focused child is $(if ($focusedChild) { $focusedChild.Name } else { 'none' })"
        }
        
        $this.RefreshThemeColors()
        $this.RequestRedraw()
    }
    
    hidden [void] RefreshThemeColors() {
        try {
            if ($this._mainPanel) {
                $this._mainPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
                $this._mainPanel.ForegroundColor = Get-ThemeColor "Panel.Foreground" "#d4d4d4"
                $this._mainPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
            }
            
            if ($this._menuPanel) {
                $this._menuPanel.BackgroundColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
                $this._menuPanel.ForegroundColor = Get-ThemeColor "Panel.Foreground" "#d4d4d4"
                $this._menuPanel.BorderColor = Get-ThemeColor "Panel.Border" "#404040"
            }
            
            if ($this._menuList) {
                $this._menuList.BackgroundColor = Get-ThemeColor "Input.Background" "#262626"
                $this._menuList.ForegroundColor = Get-ThemeColor "Input.Foreground" "#d4d4d4"
                $this._menuList.BorderColor = Get-ThemeColor "Input.Border" "#404040"
            }
            
            if ($this._mainPanel -and $this._mainPanel.Children) {
                $instructions = $this._mainPanel.Children | Where-Object { $_.Name -eq "Instructions" }
                if ($instructions -is [LabelComponent]) {
                    $instructions.ForegroundColor = Get-ThemeColor "Label.Foreground" "#9ca3af"
                    $instructions.BackgroundColor = Get-ThemeColor "Label.Background" "#1e1e1e"
                }
            }
        }
        catch {
            Write-Log -Level Error -Message "DashboardScreen.RefreshThemeColors: Error updating colors: $_"
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        if ($null -eq $keyInfo) { return $false }
        
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Key=$($keyInfo.Key), Char='$($keyInfo.KeyChar)', Modifiers=$($keyInfo.Modifiers)"
        
        # Check current focus state
        $focusedChild = $this.GetFocusedChild()
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Current focused child: $(if ($focusedChild) { $focusedChild.Name } else { 'none' })"
        
        # ALWAYS FIRST - Let base handle Tab and component routing
        if (([Screen]$this).HandleInput($keyInfo)) {
            Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Base class handled input"
            return $true
        }
        
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Base class did not handle, checking screen shortcuts"
        
        # ONLY screen-level shortcuts here
        # Handle direct number key shortcuts (global shortcuts)
        $char = $keyInfo.KeyChar
        switch ($char) {
            '1' { Write-Log -Level Debug -Message "Number key 1 pressed"; $this.ExecuteMenuItem(0); return $true }
            '2' { Write-Log -Level Debug -Message "Number key 2 pressed"; $this.ExecuteMenuItem(1); return $true }
            '3' { Write-Log -Level Debug -Message "Number key 3 pressed"; $this.ExecuteMenuItem(2); return $true }
            '4' { Write-Log -Level Debug -Message "Number key 4 pressed"; $this.ExecuteMenuItem(3); return $true }
            '5' { Write-Log -Level Debug -Message "Number key 5 pressed"; $this.ExecuteMenuItem(4); return $true }
            '6' { Write-Log -Level Debug -Message "Number key 6 pressed"; $this.ExecuteMenuItem(5); return $true }
            '7' { Write-Log -Level Debug -Message "Number key 7 pressed"; $this.ExecuteMenuItem(6); return $true }
            { $_ -eq 'q' -or $_ -eq 'Q' } { Write-Log -Level Debug -Message "Q pressed"; $this.ExecuteMenuItem(8); return $true }
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
            Write-Log -Level Debug -Message "DashboardScreen: Ctrl+P detected"
            $this.ExecuteMenuItem(6)
            return $true
        }
        
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: No handler found for input"
        return $false
    }
    
    hidden [void] ExecuteMenuItem([int]$index) {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        
        if (-not $actionService) { 
            Write-Log -Level Error -Message "DashboardScreen: ActionService not found!"
            return
        }
        
        Write-Log -Level Debug -Message "DashboardScreen: Executing menu item $index"
        
        # Use ActionService for ALL navigation - NO direct screen instantiation
        switch ($index) {
            0 { 
                Write-Log -Level Debug -Message "Dashboard (current screen)"
            }
            1 { 
                $actionService.ExecuteAction("navigation.taskList", @{})
            }
            2 { 
                $actionService.ExecuteAction("navigation.projects", @{})
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
