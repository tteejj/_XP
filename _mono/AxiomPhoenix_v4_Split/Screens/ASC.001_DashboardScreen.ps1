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
    hidden [ListBox] $_menuList
    
    DashboardScreen([object]$serviceContainer) : base("DashboardScreen", $serviceContainer) {}

    [void] Initialize() {
        if (-not $this.ServiceContainer) { return }

        # Main panel takes full screen
        $this._mainPanel = [Panel]::new("MainPanel")
        $this._mainPanel.X = 0
        $this._mainPanel.Y = 0
        $this._mainPanel.Width = $this.Width
        $this._mainPanel.Height = $this.Height
        $this._mainPanel.Title = " Axiom-Phoenix v4.0 - Main Menu "
        $this.AddChild($this._mainPanel)

        # Menu list in center
        $this._menuList = [ListBox]::new("MenuList")
        $this._menuList.X = [Math]::Floor(($this.Width - 40) / 2)
        $this._menuList.Y = 5
        $this._menuList.Width = 40
        $this._menuList.Height = 10
        $this._menuList.BorderStyle = "Double"
        $this._menuList.Title = " Navigation "
        
        # Add menu items
        $this._menuList.AddItem("[1] Dashboard")
        $this._menuList.AddItem("[2] Task List")
        $this._menuList.AddItem("[3] New Task")
        $this._menuList.AddItem("[4] Command Palette")
        $this._menuList.AddItem("")
        $this._menuList.AddItem("[Q] Quit")
        
        $this._mainPanel.AddChild($this._menuList)
        
        # Instructions
        $instructions = [LabelComponent]::new("Instructions")
        $instructions.Text = "Press the number/letter key to select an option"
        $instructions.X = [Math]::Floor(($this.Width - 42) / 2)
        $instructions.Y = 17
        $instructions.ForegroundColor = Get-ThemeColor -ColorName "Subtle"
        $this._mainPanel.AddChild($instructions)
    }

    [void] OnEnter() {
        # Set focus to menu list
        $focusManager = $this.ServiceContainer?.GetService("FocusManager")
        if ($focusManager -and $this._menuList) {
            $focusManager.SetFocus($this._menuList)
        }
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$keyInfo) {
        $actionService = $this.ServiceContainer?.GetService("ActionService")
        if (-not $actionService) { return $false }
        
        switch ($keyInfo.KeyChar) {
            '1' {
                # Already on dashboard
                return $true
            }
            '2' {
                $actionService.ExecuteAction("navigation.taskList")
                return $true
            }
            '3' {
                $actionService.ExecuteAction("navigation.newTask")
                return $true
            }
            '4' {
                $actionService.ExecuteAction("navigation.commandPalette")
                return $true
            }
            'q' {
                $actionService.ExecuteAction("app.exit")
                return $true
            }
            'Q' {
                $actionService.ExecuteAction("app.exit")
                return $true
            }
        }
        
        # Let focused component handle other keys
        return $false
    }
}

#endregion
#<!-- END_PAGE: ASC.001 -->
