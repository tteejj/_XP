# LazyGitFocusManager - Panel focus management for LazyGit-style interface
# Handles keyboard navigation between panels and view switching

class LazyGitFocusManager {
    # Panel references
    [object[]]$LeftPanels = @()
    [object]$MainPanel = $null
    [object]$CommandPalette = $null
    
    # Focus state
    [int]$FocusedPanelIndex = 0  # Index into LeftPanels, -1 for MainPanel, -2 for CommandPalette
    [string]$FocusMode = "Panel"  # Panel, Command, Search
    [object]$PreviousFocus = $null
    
    # Navigation settings
    [bool]$EnableWrapAround = $true     # Tab wraps from last to first panel
    [bool]$EnableMouseSupport = $false  # Future: mouse focus switching
    [bool]$AutoFocusMainPanel = $true   # Auto-focus main panel on selection changes
    
    # Focus history for smart navigation
    [System.Collections.ArrayList]$FocusHistory = @()
    [int]$MaxFocusHistory = 10
    
    # Panel index constants
    hidden [int]$MAIN_PANEL_INDEX = -1
    hidden [int]$COMMAND_PALETTE_INDEX = -2
    
    LazyGitFocusManager() {
        $this.FocusHistory = [System.Collections.ArrayList]::new()
    }
    
    # Initialize with panel references
    [void] Initialize([object[]]$leftPanels, [object]$mainPanel, [object]$commandPalette) {
        $this.LeftPanels = $leftPanels
        $this.MainPanel = $mainPanel
        $this.CommandPalette = $commandPalette
        
        # Set initial focus to first left panel
        if ($this.LeftPanels.Count -gt 0) {
            $this.SetFocus(0)
        }
    }
    
    # Set focus to specific panel by index
    [void] SetFocus([int]$panelIndex) {
        # Save current focus to history
        $this.AddToFocusHistory($this.FocusedPanelIndex)
        
        # Deactivate current panel
        $this.DeactivateCurrentPanel()
        
        # Update focus index
        $this.FocusedPanelIndex = $panelIndex
        
        # Activate new panel
        $this.ActivateCurrentPanel()
        
        # Update focus mode
        if ($panelIndex -eq $this.COMMAND_PALETTE_INDEX) {
            $this.FocusMode = "Command"
        } else {
            $this.FocusMode = "Panel"
        }
    }
    
    # Navigate to next panel
    [void] NextPanel() {
        $totalPanels = $this.LeftPanels.Count + 1  # +1 for main panel
        
        if ($this.FocusedPanelIndex -eq $this.MAIN_PANEL_INDEX) {
            # From main panel, go to first left panel or wrap around
            if ($this.EnableWrapAround) {
                $this.SetFocus(0)
            }
        } elseif ($this.FocusedPanelIndex -eq ($this.LeftPanels.Count - 1)) {
            # From last left panel, go to main panel
            $this.SetFocus($this.MAIN_PANEL_INDEX)
        } else {
            # Go to next left panel
            $this.SetFocus($this.FocusedPanelIndex + 1)
        }
    }
    
    # Navigate to previous panel
    [void] PrevPanel() {
        if ($this.FocusedPanelIndex -eq $this.MAIN_PANEL_INDEX) {
            # From main panel, go to last left panel
            $this.SetFocus($this.LeftPanels.Count - 1)
        } elseif ($this.FocusedPanelIndex -eq 0) {
            # From first left panel, go to main panel or wrap
            if ($this.EnableWrapAround) {
                $this.SetFocus($this.MAIN_PANEL_INDEX)
            }
        } else {
            # Go to previous left panel
            $this.SetFocus($this.FocusedPanelIndex - 1)
        }
    }
    
    # Jump directly to main panel
    [void] FocusMainPanel() {
        $this.SetFocus($this.MAIN_PANEL_INDEX)
    }
    
    # Jump to specific left panel by index
    [void] FocusLeftPanel([int]$index) {
        if ($index -ge 0 -and $index -lt $this.LeftPanels.Count) {
            $this.SetFocus($index)
        }
    }
    
    # Toggle command palette focus
    [void] ToggleCommandPalette() {
        if ($this.FocusedPanelIndex -eq $this.COMMAND_PALETTE_INDEX) {
            # Return to previous panel focus
            $this.RestorePreviousFocus()
        } else {
            # Focus command palette
            $this.SetFocus($this.COMMAND_PALETTE_INDEX)
        }
    }
    
    # Activate command palette
    [void] ActivateCommandPalette() {
        if ($this.CommandPalette -ne $null) {
            $this.SetFocus($this.COMMAND_PALETTE_INDEX)
            $this.CommandPalette.IsActive = $true
        }
    }
    
    # Deactivate command palette and return focus
    [void] DeactivateCommandPalette() {
        if ($this.CommandPalette -ne $null) {
            $this.CommandPalette.IsActive = $false
        }
        $this.RestorePreviousFocus()
    }
    
    # Get currently focused panel
    [object] GetFocusedPanel() {
        if ($this.FocusedPanelIndex -eq $this.MAIN_PANEL_INDEX) {
            return $this.MainPanel
        } elseif ($this.FocusedPanelIndex -ge 0 -and $this.FocusedPanelIndex -lt $this.LeftPanels.Count) {
            return $this.LeftPanels[$this.FocusedPanelIndex]
        }
        return $null
    }
    
    # Handle input routing to focused component
    [bool] HandleInput([ConsoleKeyInfo]$key) {
        # Global hotkeys (processed regardless of focus)
        if ($this.HandleGlobalHotkeys($key)) {
            return $true
        }
        
        # Route based on focus mode
        switch ($this.FocusMode) {
            "Command" {
                if ($this.CommandPalette -ne $null) {
                    return $this.CommandPalette.HandleInput($key)
                }
            }
            "Panel" {
                $focusedPanel = $this.GetFocusedPanel()
                if ($focusedPanel -ne $null) {
                    return $focusedPanel.HandleInput($key)
                }
            }
        }
        
        return $false
    }
    
    # Handle global hotkeys (work from any focus state)
    [bool] HandleGlobalHotkeys([ConsoleKeyInfo]$key) {
        # Tab navigation between panels
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
            $this.NextPanel()
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq ([ConsoleModifiers]::Control -bor [ConsoleModifiers]::Shift)) {
            $this.PrevPanel()
            return $true
        }
        
        # Command palette toggle
        if ($key.Key -eq [ConsoleKey]::P -and $key.Modifiers -eq [ConsoleModifiers]::Control) {
            $this.ToggleCommandPalette()
            return $true
        }
        
        # Escape handling
        if ($key.Key -eq [ConsoleKey]::Escape) {
            if ($this.FocusMode -eq "Command") {
                $this.DeactivateCommandPalette()
                return $true
            }
        }
        
        # Alt+Tab for next panel (alternative to Ctrl+Tab)
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq [ConsoleModifiers]::Alt) {
            $this.NextPanel()
            return $true
        }
        
        # Alt+Shift+Tab for previous panel
        if ($key.Key -eq [ConsoleKey]::Tab -and $key.Modifiers -eq ([ConsoleModifiers]::Alt -bor [ConsoleModifiers]::Shift)) {
            $this.PrevPanel()
            return $true
        }
        
        # Number keys for direct panel access (Alt+1-9)
        if ($key.Modifiers -eq [ConsoleModifiers]::Alt) {
            # Check for number keys 1-9
            if ($key.Key -ge [ConsoleKey]::D1 -and $key.Key -le [ConsoleKey]::D9) {
                $panelIndex = [int]($key.Key - [ConsoleKey]::D1)
                if ($panelIndex -lt $this.LeftPanels.Count) {
                    $this.FocusLeftPanel($panelIndex)
                    return $true
                }
            }
            # Alt+0 for main panel
            elseif ($key.Key -eq [ConsoleKey]::D0) {
                $this.FocusMainPanel()
                return $true
            }
        }
        
        return $false
    }
    
    # Activate currently focused panel
    [void] ActivateCurrentPanel() {
        if ($this.FocusedPanelIndex -eq $this.MAIN_PANEL_INDEX) {
            if ($this.MainPanel -ne $null) {
                $this.MainPanel.SetActive($true)
            }
        } elseif ($this.FocusedPanelIndex -eq $this.COMMAND_PALETTE_INDEX) {
            if ($this.CommandPalette -ne $null) {
                $this.CommandPalette.IsActive = $true
            }
        } elseif ($this.FocusedPanelIndex -ge 0 -and $this.FocusedPanelIndex -lt $this.LeftPanels.Count) {
            $this.LeftPanels[$this.FocusedPanelIndex].SetActive($true)
        }
    }
    
    # Deactivate currently focused panel
    [void] DeactivateCurrentPanel() {
        if ($this.FocusedPanelIndex -eq $this.MAIN_PANEL_INDEX) {
            if ($this.MainPanel -ne $null) {
                $this.MainPanel.SetActive($false)
            }
        } elseif ($this.FocusedPanelIndex -eq $this.COMMAND_PALETTE_INDEX) {
            if ($this.CommandPalette -ne $null) {
                $this.CommandPalette.IsActive = $false
            }
        } elseif ($this.FocusedPanelIndex -ge 0 -and $this.FocusedPanelIndex -lt $this.LeftPanels.Count) {
            $this.LeftPanels[$this.FocusedPanelIndex].SetActive($false)
        }
    }
    
    # Add to focus history
    [void] AddToFocusHistory([int]$panelIndex) {
        # Don't add duplicates of current focus
        if ($this.FocusHistory.Count -gt 0 -and $this.FocusHistory[-1] -eq $panelIndex) {
            return
        }
        
        # Add to history
        [void]$this.FocusHistory.Add($panelIndex)
        
        # Trim history if too long
        while ($this.FocusHistory.Count -gt $this.MaxFocusHistory) {
            $this.FocusHistory.RemoveAt(0)
        }
    }
    
    # Restore previous focus from history
    [void] RestorePreviousFocus() {
        if ($this.FocusHistory.Count -gt 0) {
            $previousIndex = $this.FocusHistory[-1]
            $this.FocusHistory.RemoveAt($this.FocusHistory.Count - 1)
            $this.SetFocus($previousIndex)
        } else {
            # Default to first left panel
            $this.SetFocus(0)
        }
    }
    
    # Handle cross-panel selection changes
    [void] OnSelectionChanged([object]$sourcePanel, [object]$selectedItem) {
        if ($this.AutoFocusMainPanel -and $sourcePanel -ne $this.MainPanel) {
            # Update main panel with selection
            if ($this.MainPanel -ne $null -and $this.MainPanel.CurrentView -ne $null) {
                $this.MainPanel.CurrentView.SetSelection($selectedItem)
            }
        }
        
        # Notify other panels of selection change for potential updates
        foreach ($panel in $this.LeftPanels) {
            if ($panel -ne $sourcePanel -and $panel.CurrentView -ne $null) {
                # Allow views to respond to cross-panel selection changes
                if ($panel.CurrentView.PSObject.Methods["OnCrossPanelSelection"]) {
                    $panel.CurrentView.OnCrossPanelSelection($sourcePanel, $selectedItem)
                }
            }
        }
    }
    
    # Get focus state for display
    [hashtable] GetFocusState() {
        $focusedPanel = $this.GetFocusedPanel()
        $focusedPanelName = if ($focusedPanel) { $focusedPanel.Title } else { "Command Palette" }
        
        return @{
            FocusedPanelIndex = $this.FocusedPanelIndex
            FocusedPanelName = $focusedPanelName
            FocusMode = $this.FocusMode
            HistoryDepth = $this.FocusHistory.Count
            TotalPanels = $this.LeftPanels.Count + 1  # +1 for main panel
        }
    }
    
    # Get navigation help text
    [string[]] GetNavigationHelp() {
        $help = @()
        $help += "Panel Navigation:"
        $help += "  Ctrl+Tab / Ctrl+Shift+Tab - Next/Previous panel"
        $help += "  Alt+1-9 - Jump to panel 1-9"
        $help += "  Alt+0 - Jump to main panel"
        $help += "  Ctrl+P - Toggle command palette"
        $help += "  Esc - Exit command palette"
        $help += ""
        $help += "Within Panels:"
        $help += "  Tab/Shift+Tab - Switch tabs within panel"
        $help += "  ↑↓ - Navigate items"
        $help += "  Enter - Select/Activate"
        $help += "  Space - Toggle (where applicable)"
        
        return $help
    }
    
    # Reset focus to default state
    [void] Reset() {
        $this.DeactivateCurrentPanel()
        $this.FocusHistory.Clear()
        $this.FocusMode = "Panel"
        $this.FocusedPanelIndex = 0
        $this.ActivateCurrentPanel()
    }
    
    # Enable/disable features
    [void] SetWrapAround([bool]$enabled) {
        $this.EnableWrapAround = $enabled
    }
    
    [void] SetAutoFocusMainPanel([bool]$enabled) {
        $this.AutoFocusMainPanel = $enabled
    }
    
    # Get focused panel's context commands for command palette
    [hashtable] GetContextCommands() {
        $focusedPanel = $this.GetFocusedPanel()
        if ($focusedPanel -ne $null) {
            return $focusedPanel.GetContextCommands()
        }
        return @{}
    }
}