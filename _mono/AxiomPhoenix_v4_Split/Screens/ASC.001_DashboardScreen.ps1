# ==============================================================================
# Axiom-Phoenix v4.0 - All Screens (Load After Components)
# Application screens that extend Screen base class
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ASC.###" to find specific sections.
# Each section ends with "END_PAGE: ASC.###"
# ==============================================================================

using namespace System.Collections.Generic

#region Screen Classes

# ==============================================================================
# CLASS: DashboardScreen (Data-Driven Dashboard with DataGridComponent)
#
# INHERITS:
#   - Screen (ABC.006)
#
# DEPENDENCIES:
#   Services:
#     - NavigationService (ASE.004)
#     - FocusManager (ASE.009)
#     - DataManager (ASE.003)
#     - ViewDefinitionService (ASE.011)
#   Components:
#     - Panel (ACO.011)
#     - DataGridComponent (ACO.022)
#     - LabelComponent (ACO.001)
#
# PURPOSE:
#   Data-driven dashboard showing task statistics, recent tasks, and quick actions
#   using the ViewDefinitionService pattern for consistent formatting.
# ==============================================================================
class DashboardScreen : Screen {
    hidden [Panel] $_mainPanel
    hidden [Panel] $_menuPanel
    hidden [List[LabelComponent]] $_menuItems
    hidden [int] $_selectedIndex = 0
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        Write-Log -Level Debug -Message "DashboardScreen.Initialize: Starting initialization"
        if (-not $this.ServiceContainer) { 
            Write-Log -Level Error -Message "DashboardScreen.Initialize: ServiceContainer is null!"
            return 
        }

        # Main panel takes full screen
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        $this._mainPanel.HasBorder = $true
        $this._mainPanel.BorderStyle = "Double"
        $this.AddChild($this._mainPanel)

        # Menu panel
        $this._menuPanel = [Panel]::new("MenuPanel")
        $this._menuPanel.X = [Math]::Floor(($this.Width - 40) / 2)
        $this._menuPanel.Y = 5
        $this._menuPanel.Width = 40
        $this._menuPanel.Height = 14 # Menu height to fit all items
        $this._menuPanel.HasBorder = $true
        $this._menuPanel.BorderStyle = "Double"
        $this._menuPanel.Title = " Navigation "
        $this._mainPanel.AddChild($this._menuPanel)
        
        # Create menu items as labels
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
            $label = [LabelComponent]::new("MenuItem_$yPos")
            $label.Text = $text
            $label.X = 2
            $label.Y = $yPos
            $label.ForegroundColor = Get-ThemeColor("component.text")
            $this._menuPanel.AddChild($label)
            $this._menuItems.Add($label)
            $yPos++
        }
        
        # Highlight first item
        if ($this._menuItems.Count -gt 0) {
            $this._menuItems[0].ForegroundColor = Get-ThemeColor("Primary")
        }
        
        # Instructions
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Press the number/letter key to select an option"
        $instructions.X = [Math]::Floor(($this.Width - 42) / 2)
        $instructions.Y = 21 # Adjusted for menu size
        $instructions.ForegroundColor = Get-ThemeColor("Subtle")
        $this._mainPanel.AddChild($instructions)
    }

    [void] OnEnter() {
        Write-Log -Level Debug -Message "DashboardScreen.OnEnter: Screen activated"
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        Write-Log -Level Debug -Message "DashboardScreen.HandleInput: Received key - Key: $($keyInfo.Key), KeyChar: '$($keyInfo.KeyChar)', Modifiers: $($keyInfo.Modifiers)"
        
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if (-not $actionService) { 
            Write-Log -Level Error -Message "DashboardScreen: ActionService not found!"
            return $false 
        }
        
        $handled = $false
        
        # Check both KeyChar and Key enum for number keys
        $char = $keyInfo.KeyChar
        $key = $keyInfo.Key
        
        # Direct character check
        switch ($char) {
            '1' { $handled = $true }
            '2' { $actionService.ExecuteAction("navigation.taskList", @{}); $handled = $true }
            '3' { 
                $navService = $this.ServiceContainer.GetService("NavigationService")
                if ($navService) {
                    $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                    $projectsScreen.Initialize()
                    $navService.NavigateTo($projectsScreen)
                }
                $handled = $true 
            }
            '4' { $actionService.ExecuteAction("tools.fileCommander", @{}); $handled = $true }
            '5' { $actionService.ExecuteAction("tools.textEditor", @{}); $handled = $true }
            '6' { $actionService.ExecuteAction("navigation.themePicker", @{}); $handled = $true }
            '7' { $actionService.ExecuteAction("app.commandPalette", @{}); $handled = $true }
            'q' { $actionService.ExecuteAction("app.exit", @{}); $handled = $true }
            'Q' { $actionService.ExecuteAction("app.exit", @{}); $handled = $true }
        }
        
        # If not handled by character, try Key enum
        if (-not $handled) {
            switch ($key) {
                ([ConsoleKey]::D1) { $handled = $true }
                ([ConsoleKey]::D2) { $actionService.ExecuteAction("navigation.taskList", @{}); $handled = $true }
                ([ConsoleKey]::D3) { 
                    $navService = $this.ServiceContainer.GetService("NavigationService")
                    if ($navService) {
                        $projectsScreen = New-Object -TypeName "ProjectsListScreen" -ArgumentList $this.ServiceContainer
                        $projectsScreen.Initialize()
                        $navService.NavigateTo($projectsScreen)
                    }
                    $handled = $true 
                }
                ([ConsoleKey]::D4) { $actionService.ExecuteAction("tools.fileCommander", @{}); $handled = $true }
                ([ConsoleKey]::D5) { $actionService.ExecuteAction("tools.textEditor", @{}); $handled = $true }
                ([ConsoleKey]::D6) { $actionService.ExecuteAction("navigation.themePicker", @{}); $handled = $true }
                ([ConsoleKey]::D7) { $actionService.ExecuteAction("app.commandPalette", @{}); $handled = $true }
                ([ConsoleKey]::Q) { $actionService.ExecuteAction("app.exit", @{}); $handled = $true }
            }
        }
        
        # Arrow key navigation
        switch ($key) {
            ([ConsoleKey]::UpArrow) {
                if ($this._selectedIndex -gt 0) {
                    # Reset previous item color
                    $this._menuItems[$this._selectedIndex].ForegroundColor = Get-ThemeColor("component.text")
                    $this._selectedIndex--
                    # Skip empty items
                    while ($this._selectedIndex -gt 0 -and [string]::IsNullOrWhiteSpace($this._menuItems[$this._selectedIndex].Text)) {
                        $this._selectedIndex--
                    }
                    # Highlight new item
                    $this._menuItems[$this._selectedIndex].ForegroundColor = Get-ThemeColor("Primary")
                    $this.RequestRedraw()
                }
                $handled = $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this._selectedIndex -lt $this._menuItems.Count - 1) {
                    # Reset previous item color
                    $this._menuItems[$this._selectedIndex].ForegroundColor = Get-ThemeColor("component.text")
                    $this._selectedIndex++
                    # Skip empty items
                    while ($this._selectedIndex -lt $this._menuItems.Count - 1 -and [string]::IsNullOrWhiteSpace($this._menuItems[$this._selectedIndex].Text)) {
                        $this._selectedIndex++
                    }
                    # Highlight new item
                    $this._menuItems[$this._selectedIndex].ForegroundColor = Get-ThemeColor("Primary")
                    $this.RequestRedraw()
                }
                $handled = $true
            }
            ([ConsoleKey]::Enter) {
                # Execute selected item
                switch ($this._selectedIndex) {
                    0 { $handled = $true } # Already on dashboard
                    1 { $actionService.ExecuteAction("navigation.taskList", @{}); $handled = $true }
                    2 { 
                        $navService = $this.ServiceContainer.GetService("NavigationService")
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
                    8 { $actionService.ExecuteAction("app.exit", @{}); $handled = $true }
                }
            }
        }
        
        # If not handled, let base class check global keybindings
        if (-not $handled) {
            return ([Screen]$this).HandleInput($keyInfo)
        }
        
        return $handled
    }
}

#endregion
#<!-- END_PAGE: ASC.001 -->
