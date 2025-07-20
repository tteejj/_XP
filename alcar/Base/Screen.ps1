# Base Screen Class for BOLT-AXIOM

class Screen {
    [string]$Title = "SCREEN"
    [bool]$Active = $true
    [hashtable]$KeyBindings = @{}
    [System.Collections.ArrayList]$StatusBarItems
    [bool]$NeedsRender = $true
    [Buffer]$Buffer  # Screen's own buffer
    static [Buffer]$CurrentBuffer  # Current frame buffer
    static [Buffer]$PreviousBuffer  # Previous frame buffer
    
    Screen() {
        $this.StatusBarItems = [System.Collections.ArrayList]::new()
        $this.InitializeKeyBindings()
    }
    
    # Override in derived classes
    [void] Initialize() { }
    [void] InitializeKeyBindings() { }
    [void] OnActivate() { }
    [void] OnDeactivate() { }
    
    # Main render - hybrid approach for best performance
    [void] Render() {
        # Check if screen has fast string rendering
        $legacyContent = $this.RenderContent()
        if ($legacyContent) {
            # Use fast string rendering
            [Console]::Write("`e[?25l`e[H")
            [Console]::Write($legacyContent)
            
            # Render status bar (if any) 
            $statusBar = $this.RenderStatusBar()
            if ($statusBar) {
                [Console]::Write($statusBar)
            }
        } else {
            # Use buffer rendering for complex screens
            $width = [Console]::WindowWidth
            $height = [Console]::WindowHeight
            $screenBuffer = [Buffer]::new($width, $height)
            
            # Render to buffer
            $this.RenderToBuffer($screenBuffer)
            
            # Hide cursor and position at home
            [Console]::Write("`e[?25l`e[H")
            
            # Convert buffer to string and write
            [Console]::Write($screenBuffer.ToString())
            
            # Render status bar (if any) 
            $statusBar = $this.RenderStatusBar()
            if ($statusBar) {
                [Console]::Write($statusBar)
            }
        }
        
        # Mark as rendered
        $this.NeedsRender = $false
    }
    
    # Render content to buffer - override in derived classes
    [void] RenderToBuffer([Buffer]$buffer) {
        # Default implementation - derived classes should override
        $content = $this.RenderContent()
        $statusBar = $this.RenderStatusBar()
        
        # This is a simple fallback - better to override in derived classes
        $lines = $content -split "`n"
        $y = 0
        foreach ($line in $lines) {
            if ($y -lt $buffer.Height - 1) {
                $buffer.WriteString(0, $y, $line, '#FFFFFF', '#000000')
                $y++
            }
        }
        
        # Status bar at bottom
        if ($statusBar) {
            $statusLines = $statusBar -split "`n"
            $buffer.WriteString(0, $buffer.Height - 1, $statusLines[0], '#FFFFFF', '#000000')
        }
    }
    
    # Differential rendering
    [void] RenderDifferential([Buffer]$current, [Buffer]$previous) {
        $sb = [System.Text.StringBuilder]::new(8192)
        $lastFG = ""
        $lastBG = ""
        
        # Hide cursor first
        [void]$sb.Append("`e[?25l")
        
        for ($y = 0; $y -lt $current.Height; $y++) {
            for ($x = 0; $x -lt $current.Width; $x++) {
                $currentCell = $current.GetCell($x, $y)
                $previousCell = $previous.GetCell($x, $y)
                
                if (-not $currentCell.Equals($previousCell)) {
                    # Move cursor if needed
                    [void]$sb.Append("`e[$($y + 1);$($x + 1)H")
                    
                    # Set colors if changed
                    if ($currentCell.FG -ne $lastFG -or $currentCell.BG -ne $lastBG) {
                        # Convert hex to RGB
                        $fg = $currentCell.FG
                        $bg = $currentCell.BG
                        if ($fg -match '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') {
                            $r = [Convert]::ToInt32($Matches[1], 16)
                            $g = [Convert]::ToInt32($Matches[2], 16)
                            $b = [Convert]::ToInt32($Matches[3], 16)
                            [void]$sb.Append("`e[38;2;$r;$g;${b}m")
                        }
                        if ($bg -match '^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$') {
                            $r = [Convert]::ToInt32($Matches[1], 16)
                            $g = [Convert]::ToInt32($Matches[2], 16)
                            $b = [Convert]::ToInt32($Matches[3], 16)
                            [void]$sb.Append("`e[48;2;$r;$g;${b}m")
                        }
                        $lastFG = $currentCell.FG
                        $lastBG = $currentCell.BG
                    }
                    
                    # Write character
                    [void]$sb.Append($currentCell.Char)
                }
            }
        }
        
        # Reset and write
        if ($sb.Length -gt 0) {
            [void]$sb.Append("`e[0m")
            [Console]::Write($sb.ToString())
        }
    }
    
    # Request a render on next loop iteration
    [void] RequestRender() {
        $this.NeedsRender = $true
    }
    
    # Override to provide screen content
    [string] RenderContent() {
        return ""
    }
    
    # Standard status bar
    [string] RenderStatusBar() {
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        $statusText = ""
        foreach ($item in $this.StatusBarItems) {
            if ($item.Key) {
                $statusText += "[$($item.Key)]$($item.Label) "
            } else {
                $statusText += "$($item.Label) "
            }
        }
        
        $output = [VT]::MoveTo(3, $height - 1)
        $output += [VT]::TextDim() + $statusText + [VT]::Reset()
        
        return $output
    }
    
    # Standard input handling
    [void] HandleInput([ConsoleKeyInfo]$key) {
        # Check key bindings first
        $binding = $null
        
        # Try special keys
        if ($key.Key -ne [ConsoleKey]::None) {
            $binding = $this.KeyBindings[$key.Key.ToString()]
        }
        
        # Try character keys
        if (-not $binding -and $key.KeyChar) {
            $binding = $this.KeyBindings[[string]$key.KeyChar]
        }
        
        # Execute binding
        if ($binding) {
            if ($binding -is [scriptblock]) {
                & $binding
            } else {
                $this.ExecuteAction($binding)
            }
            # Note: Render requests should be made by the action handlers
            # only when they actually change something
        }
    }
    
    # Override to handle named actions
    [void] ExecuteAction([string]$action) { }
    
    # Helper to add key binding
    [void] BindKey([object]$key, [object]$action) {
        if ($key -is [ConsoleKey]) {
            $this.KeyBindings[$key.ToString()] = $action
        } else {
            $this.KeyBindings[[string]$key] = $action
        }
    }
    
    # Helper to add status bar item
    [void] AddStatusItem([string]$key, [string]$label) {
        $this.StatusBarItems.Add(@{Key=$key; Label=$label}) | Out-Null
    }
}

# Dialog base class
class Dialog : Screen {
    [Screen]$ParentScreen
    [bool]$Modal = $true
    [int]$Width = 60
    [int]$Height = 10
    [int]$X
    [int]$Y
    
    Dialog([Screen]$parent) {
        $this.ParentScreen = $parent
        
        # Center dialog
        $screenWidth = [Console]::WindowWidth
        $screenHeight = [Console]::WindowHeight
        $this.X = [int](($screenWidth - $this.Width) / 2)
        $this.Y = [int](($screenHeight - $this.Height) / 2)
    }
    
    [string] RenderContent() {
        # Build complete dialog in memory
        $output = ""
        
        # First render parent screen if exists
        if ($this.ParentScreen) {
            $output += $this.ParentScreen.RenderContent()
        }
        
        # Draw dialog box on top
        $output += $this.DrawBox()
        return $output
    }
    
    # Override RenderToBuffer to handle parent screen properly
    [void] RenderToBuffer([Buffer]$buffer) {
        # First render parent screen if exists
        if ($this.ParentScreen) {
            $this.ParentScreen.RenderToBuffer($buffer)
        }
        
        # Now render dialog on top
        # Draw dialog box background
        $dialogY = $this.Y
        $dialogHeight = $this.Height
        $dialogX = $this.X
        $dialogWidth = $this.Width
        
        foreach ($yOffset in 0..($dialogHeight - 1)) {
            $currentY = $dialogY + $yOffset
            foreach ($xOffset in 0..($dialogWidth - 1)) {
                $currentX = $dialogX + $xOffset
                $buffer.SetCell($currentX, $currentY, ' ', '#FFFFFF', '#333333')
            }
        }
        
        # Draw borders
        # Top border
        $buffer.SetCell($this.X, $this.Y, '┌', '#FFFFFF', '#333333')
        foreach ($xOffset in 1..($this.Width - 2)) {
            $buffer.SetCell($this.X + $xOffset, $this.Y, '─', '#FFFFFF', '#333333')
        }
        $buffer.SetCell($this.X + $this.Width - 1, $this.Y, '┐', '#FFFFFF', '#333333')
        
        # Side borders
        foreach ($yOffset in 1..($this.Height - 2)) {
            $currentY = $this.Y + $yOffset
            $buffer.SetCell($this.X, $currentY, '│', '#FFFFFF', '#333333')
            $buffer.SetCell($this.X + $this.Width - 1, $currentY, '│', '#FFFFFF', '#333333')
        }
        
        # Bottom border
        $bottomY = $this.Y + $this.Height - 1
        $buffer.SetCell($this.X, $bottomY, '└', '#FFFFFF', '#333333')
        foreach ($xOffset in 1..($this.Width - 2)) {
            $buffer.SetCell($this.X + $xOffset, $bottomY, '─', '#FFFFFF', '#333333')
        }
        $buffer.SetCell($this.X + $this.Width - 1, $this.Y + $this.Height - 1, '┘', '#FFFFFF', '#333333')
        
        # Title
        if ($this.Title) {
            $titleX = $this.X + [int](($this.Width - $this.Title.Length - 2) / 2)
            $buffer.WriteString($titleX, $this.Y, " $($this.Title) ", '#FFFF00', '#333333')
        }
    }
    
    [string] DrawBox() {
        $output = ""
        
        # Clear the dialog area with background
        for ($i = 0; $i -lt $this.Height; $i++) {
            $output += [VT]::MoveTo($this.X, $this.Y + $i)
            $output += [VT]::RGBBG(51, 51, 51)  # Dark gray background
            $output += " " * $this.Width
        }
        
        # Top border
        $output += [VT]::MoveTo($this.X, $this.Y)
        $output += [VT]::Border()
        $output += [VT]::TL() + [VT]::H() * ($this.Width - 2) + [VT]::TR()
        
        # Sides and content
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            $output += [VT]::MoveTo($this.X, $this.Y + $i)
            $output += [VT]::V()
            $output += [VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i)
            $output += [VT]::V()
        }
        
        # Bottom border
        $output += [VT]::MoveTo($this.X, $this.Y + $this.Height - 1)
        $output += [VT]::BL() + [VT]::H() * ($this.Width - 2) + [VT]::BR()
        
        # Title
        if ($this.Title) {
            $titleX = $this.X + [int](($this.Width - $this.Title.Length - 2) / 2)
            $output += [VT]::MoveTo($titleX, $this.Y)
            $output += [VT]::TextBright() + " $($this.Title) " + [VT]::Reset()
        }
        
        $output += [VT]::Reset()  # Ensure colors are reset
        return $output
    }
}