# LazyGitLayout - Multi-panel layout calculations for LazyGit-style interface
# Handles responsive panel sizing and positioning

class LazyGitLayout {
    # Terminal dimensions
    [int]$TerminalWidth
    [int]$TerminalHeight
    
    # Layout configuration
    [int]$LeftPanelCount = 6        # Number of vertical panels on left
    [int]$MinPanelWidth = 15        # Minimum width for left panels
    [int]$MaxPanelWidth = 30        # Maximum width for left panels
    [int]$CommandPaletteHeight = 2  # Height for bottom command palette
    [int]$PanelSpacing = 1          # Space between panels (for borders)
    
    # Calculated dimensions
    [int]$LeftPanelWidth
    [int]$MainPanelWidth
    [int]$MainPanelHeight
    [int]$LeftPanelHeight
    [int]$ContentHeight
    
    # Panel positions (calculated)
    [hashtable]$PanelPositions = @{}
    [hashtable]$PanelDimensions = @{}
    
    # Layout modes
    [string]$LayoutMode = "Standard"  # Standard, Compact, Wide
    [bool]$ShowBorders = $false       # LazyGit style = no borders
    [bool]$AdaptiveWidth = $true      # Adjust panel width based on terminal size
    
    LazyGitLayout() {
        $this.UpdateTerminalSize()
        $this.CalculateLayout()
    }
    
    LazyGitLayout([int]$terminalWidth, [int]$terminalHeight) {
        $this.TerminalWidth = $terminalWidth
        $this.TerminalHeight = $terminalHeight
        $this.CalculateLayout()
    }
    
    # Update terminal dimensions and recalculate
    [void] UpdateTerminalSize() {
        $this.TerminalWidth = [Console]::WindowWidth
        $this.TerminalHeight = [Console]::WindowHeight
        $this.CalculateLayout()
    }
    
    # Main layout calculation method
    [void] CalculateLayout() {
        $this.CalculatePanelDimensions()
        $this.CalculatePanelPositions()
    }
    
    # Calculate panel dimensions based on terminal size
    [void] CalculatePanelDimensions() {
        # Content height (terminal minus command palette)
        $this.ContentHeight = $this.TerminalHeight - $this.CommandPaletteHeight
        
        # Calculate optimal left panel width
        if ($this.AdaptiveWidth) {
            # Adaptive width based on terminal size
            $availableWidth = $this.TerminalWidth - ($this.LeftPanelCount * $this.PanelSpacing)
            $idealLeftWidth = [Math]::Floor($availableWidth * 0.6 / $this.LeftPanelCount)  # 60% for left panels
            
            $this.LeftPanelWidth = [Math]::Max(
                $this.MinPanelWidth,
                [Math]::Min($this.MaxPanelWidth, $idealLeftWidth)
            )
        } else {
            $this.LeftPanelWidth = $this.MinPanelWidth
        }
        
        # Calculate main panel width (remaining space)
        $totalLeftWidth = ($this.LeftPanelWidth * $this.LeftPanelCount) + ($this.PanelSpacing * ($this.LeftPanelCount + 1))
        $this.MainPanelWidth = $this.TerminalWidth - $totalLeftWidth
        
        # Panel heights
        $this.LeftPanelHeight = [Math]::Floor($this.ContentHeight / $this.LeftPanelCount)
        $this.MainPanelHeight = $this.ContentHeight
        
        # Ensure minimum dimensions
        if ($this.MainPanelWidth -lt 30) {
            # Terminal too narrow - switch to compact mode
            $this.SwitchToCompactMode()
        }
    }
    
    # Calculate exact panel positions
    [void] CalculatePanelPositions() {
        $this.PanelPositions.Clear()
        $this.PanelDimensions.Clear()
        
        # Left panels (vertical stack)
        for ($i = 0; $i -lt $this.LeftPanelCount; $i++) {
            $panelId = "LeftPanel$i"
            $x = $this.PanelSpacing
            # Panels start after command palette space
            $y = $this.CommandPaletteHeight + ($i * $this.LeftPanelHeight)
            $width = $this.LeftPanelWidth
            $height = $this.LeftPanelHeight
            
            # Last panel gets any remaining height
            if ($i -eq ($this.LeftPanelCount - 1)) {
                $height = ($this.ContentHeight + $this.CommandPaletteHeight) - $y
            }
            
            $this.PanelPositions[$panelId] = @{ X = $x; Y = $y }
            $this.PanelDimensions[$panelId] = @{ Width = $width; Height = $height }
        }
        
        # Main panel (right side)
        $mainX = $this.LeftPanelWidth + ($this.PanelSpacing * 2)
        $this.PanelPositions["MainPanel"] = @{ X = $mainX; Y = $this.CommandPaletteHeight }
        $this.PanelDimensions["MainPanel"] = @{ 
            Width = $this.MainPanelWidth - $this.PanelSpacing
            Height = $this.MainPanelHeight 
        }
        
        # Command palette (top for ALCAR)
        $this.PanelPositions["CommandPalette"] = @{ 
            X = 0; 
            Y = 0 
        }
        $this.PanelDimensions["CommandPalette"] = @{ 
            Width = $this.TerminalWidth
            Height = $this.CommandPaletteHeight 
        }
    }
    
    # Switch to compact mode for narrow terminals
    [void] SwitchToCompactMode() {
        $this.LayoutMode = "Compact"
        $this.LeftPanelCount = 3  # Reduce panel count
        $this.LeftPanelWidth = $this.MinPanelWidth
        
        # Recalculate with new settings
        $totalLeftWidth = ($this.LeftPanelWidth * $this.LeftPanelCount) + ($this.PanelSpacing * ($this.LeftPanelCount + 1))
        $this.MainPanelWidth = $this.TerminalWidth - $totalLeftWidth
        $this.LeftPanelHeight = [Math]::Floor($this.ContentHeight / $this.LeftPanelCount)
    }
    
    # Switch to wide mode for large terminals
    [void] SwitchToWideMode() {
        $this.LayoutMode = "Wide"
        $this.LeftPanelCount = 8  # More panels on wide screens
        $this.MaxPanelWidth = 35
    }
    
    # Get position for a specific panel
    [hashtable] GetPanelPosition([string]$panelId) {
        if ($this.PanelPositions.ContainsKey($panelId)) {
            return $this.PanelPositions[$panelId]
        }
        return @{ X = 0; Y = 0 }
    }
    
    # Get dimensions for a specific panel
    [hashtable] GetPanelDimensions([string]$panelId) {
        if ($this.PanelDimensions.ContainsKey($panelId)) {
            return $this.PanelDimensions[$panelId]
        }
        return @{ Width = 10; Height = 5 }
    }
    
    # Get left panel configuration
    [object[]] GetLeftPanelConfigs() {
        $configs = @()
        for ($i = 0; $i -lt $this.LeftPanelCount; $i++) {
            $panelId = "LeftPanel$i"
            $pos = $this.GetPanelPosition($panelId)
            $dim = $this.GetPanelDimensions($panelId)
            
            $configs += @{
                Id = $panelId
                Index = $i
                X = $pos.X
                Y = $pos.Y
                Width = $dim.Width
                Height = $dim.Height
            }
        }
        return $configs
    }
    
    # Get main panel configuration
    [hashtable] GetMainPanelConfig() {
        $pos = $this.GetPanelPosition("MainPanel")
        $dim = $this.GetPanelDimensions("MainPanel")
        
        return @{
            Id = "MainPanel"
            X = $pos.X
            Y = $pos.Y
            Width = $dim.Width
            Height = $dim.Height
        }
    }
    
    # Get command palette configuration
    [hashtable] GetCommandPaletteConfig() {
        $pos = $this.GetPanelPosition("CommandPalette")
        $dim = $this.GetPanelDimensions("CommandPalette")
        
        return @{
            Id = "CommandPalette"
            X = $pos.X
            Y = $pos.Y
            Width = $dim.Width
            Height = $dim.Height
        }
    }
    
    # Check if layout needs recalculation (terminal size changed)
    [bool] NeedsRecalculation() {
        return ($this.TerminalWidth -ne [Console]::WindowWidth) -or 
               ($this.TerminalHeight -ne [Console]::WindowHeight)
    }
    
    # Force layout recalculation on next render
    [void] MarkDirty() {
        # Set terminal size to 0 to force recalculation
        $this.TerminalWidth = 0
        $this.TerminalHeight = 0
    }
    
    # Get layout statistics
    [hashtable] GetLayoutStats() {
        return @{
            TerminalSize = "$($this.TerminalWidth)x$($this.TerminalHeight)"
            LayoutMode = $this.LayoutMode
            LeftPanelCount = $this.LeftPanelCount
            LeftPanelWidth = $this.LeftPanelWidth
            MainPanelWidth = $this.MainPanelWidth
            ContentHeight = $this.ContentHeight
            LeftPanelUtilization = [Math]::Round(($this.LeftPanelWidth * $this.LeftPanelCount) / $this.TerminalWidth * 100, 1)
            MainPanelUtilization = [Math]::Round($this.MainPanelWidth / $this.TerminalWidth * 100, 1)
        }
    }
    
    # Auto-adjust layout based on terminal size
    [void] AutoAdjust() {
        if ($this.TerminalWidth -lt 100) {
            $this.SwitchToCompactMode()
        } elseif ($this.TerminalWidth -gt 160) {
            $this.SwitchToWideMode()
        } else {
            $this.LayoutMode = "Standard"
            $this.LeftPanelCount = 6
        }
        $this.CalculateLayout()
    }
    
    # Get visual separator characters for LazyGit style
    [hashtable] GetSeparators() {
        if ($this.ShowBorders) {
            return @{
                Vertical = "│"
                Horizontal = "─"
                Corner = "┌┐└┘"
                Junction = "┬┴├┤┼"
            }
        } else {
            # LazyGit style - minimal separators
            return @{
                Vertical = "│"
                Horizontal = ""
                Corner = ""
                Junction = ""
            }
        }
    }
    
    # Export layout for debugging
    [string] ExportLayout() {
        $output = @()
        $output += "=== LazyGit Layout Configuration ==="
        $output += "Terminal: $($this.TerminalWidth)x$($this.TerminalHeight)"
        $output += "Mode: $($this.LayoutMode)"
        $output += "Left Panels: $($this.LeftPanelCount)"
        $output += ""
        
        # Left panels
        $output += "Left Panels:"
        for ($i = 0; $i -lt $this.LeftPanelCount; $i++) {
            $panelId = "LeftPanel$i"
            $pos = $this.GetPanelPosition($panelId)
            $dim = $this.GetPanelDimensions($panelId)
            $output += "  Panel $i`: $($pos.X),$($pos.Y) $($dim.Width)x$($dim.Height)"
        }
        
        # Main panel
        $mainPos = $this.GetPanelPosition("MainPanel")
        $mainDim = $this.GetPanelDimensions("MainPanel")
        $output += ""
        $output += "Main Panel: $($mainPos.X),$($mainPos.Y) $($mainDim.Width)x$($mainDim.Height)"
        
        # Command palette
        $cmdPos = $this.GetPanelPosition("CommandPalette")
        $cmdDim = $this.GetPanelDimensions("CommandPalette")
        $output += "Command Palette: $($cmdPos.X),$($cmdPos.Y) $($cmdDim.Width)x$($cmdDim.Height)"
        
        return $output -join "`n"
    }
}