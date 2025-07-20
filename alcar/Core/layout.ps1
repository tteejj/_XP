# Three-Pane Layout Engine with Perfect Alignment

class Pane {
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [string]$Title
    [bool]$Active
    [System.Collections.ArrayList]$Content
    
    Pane([int]$x, [int]$y, [int]$w, [int]$h, [string]$title) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $w
        $this.Height = $h
        $this.Title = $title
        $this.Active = $false
        $this.Content = [System.Collections.ArrayList]::new()
    }
    
    # Buffer-based border rendering - zero allocation
    [void] DrawBorderToBuffer([Buffer]$buffer) {
        $borderColor = if ($this.Active) { "#64C8FF" } else { "#646464" }
        $normalBG = "#1E1E23"
        
        # Top border
        $buffer.SetCell($this.X, $this.Y, '┌', $borderColor, $normalBG)
        
        if ($this.Title) {
            $titleText = " $($this.Title) "
            $titleWidth = $titleText.Length
            $borderWidth = $this.Width - 2
            $leftPad = [int](($borderWidth - $titleWidth) / 2)
            
            # Left padding
            for ($i = 0; $i -lt $leftPad; $i++) {
                $buffer.SetCell($this.X + 1 + $i, $this.Y, '─', $borderColor, $normalBG)
            }
            
            # Title
            for ($i = 0; $i -lt $titleText.Length; $i++) {
                $buffer.SetCell($this.X + 1 + $leftPad + $i, $this.Y, $titleText[$i], "#FFFFFF", $normalBG)
            }
            
            # Right padding
            $rightPadStart = 1 + $leftPad + $titleWidth
            for ($i = $rightPadStart; $i -lt $this.Width - 1; $i++) {
                $buffer.SetCell($this.X + $i, $this.Y, '─', $borderColor, $normalBG)
            }
        } else {
            for ($i = 1; $i -lt $this.Width - 1; $i++) {
                $buffer.SetCell($this.X + $i, $this.Y, '─', $borderColor, $normalBG)
            }
        }
        
        $buffer.SetCell($this.X + $this.Width - 1, $this.Y, '┐', $borderColor, $normalBG)
        
        # Side borders
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            $buffer.SetCell($this.X, $this.Y + $i, '│', $borderColor, $normalBG)
            $buffer.SetCell($this.X + $this.Width - 1, $this.Y + $i, '│', $borderColor, $normalBG)
        }
        
        # Bottom border
        $buffer.SetCell($this.X, $this.Y + $this.Height - 1, '└', $borderColor, $normalBG)
        for ($i = 1; $i -lt $this.Width - 1; $i++) {
            $buffer.SetCell($this.X + $i, $this.Y + $this.Height - 1, '─', $borderColor, $normalBG)
        }
        $buffer.SetCell($this.X + $this.Width - 1, $this.Y + $this.Height - 1, '┘', $borderColor, $normalBG)
    }
    
    # Legacy string method kept for backward compatibility
    [string] DrawBorder() {
        $sb = [System.Text.StringBuilder]::new()
        $color = if ($this.Active) { [VT]::BorderActive() } else { [VT]::Border() }
        
        # Top border with title
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y))
        [void]$sb.Append($color)
        [void]$sb.Append([VT]::TL())
        
        if ($this.Title) {
            $titleText = " $($this.Title) "
            $titleWidth = $titleText.Length
            $borderWidth = $this.Width - 2
            $leftPad = [int](($borderWidth - $titleWidth) / 2)
            
            if ($leftPad -gt 0) {
                [void]$sb.Append([VT]::H() * $leftPad)
            }
            [void]$sb.Append([VT]::TextBright() + $titleText + $color)
            [void]$sb.Append([VT]::H() * ($borderWidth - $leftPad - $titleWidth))
        } else {
            [void]$sb.Append([VT]::H() * ($this.Width - 2))
        }
        
        [void]$sb.Append([VT]::TR())
        
        # Side borders
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $i))
            [void]$sb.Append($color + [VT]::V())
            [void]$sb.Append([VT]::MoveTo($this.X + $this.Width - 1, $this.Y + $i))
            [void]$sb.Append([VT]::V())
        }
        
        # Bottom border
        [void]$sb.Append([VT]::MoveTo($this.X, $this.Y + $this.Height - 1))
        [void]$sb.Append([VT]::BL())
        [void]$sb.Append([VT]::H() * ($this.Width - 2))
        [void]$sb.Append([VT]::BR())
        
        [void]$sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    # Buffer-based content rendering - zero allocation
    [void] DrawContentToBuffer([Buffer]$buffer) {
        $contentY = $this.Y + 1
        $maxLines = $this.Height - 2
        $normalBG = "#1E1E23"
        $normalFG = "#C8C8C8"
        
        for ($i = 0; $i -lt [Math]::Min($this.Content.Count, $maxLines); $i++) {
            $content = $this.Content[$i]
            if ($content) {
                $buffer.WriteString($this.X + 1, $contentY + $i, $content, $normalFG, $normalBG)
            }
        }
    }
    
    # Legacy string method
    [string] DrawContent() {
        $sb = [System.Text.StringBuilder]::new()
        $contentY = $this.Y + 1
        $maxLines = $this.Height - 2
        
        for ($i = 0; $i -lt [Math]::Min($this.Content.Count, $maxLines); $i++) {
            [void]$sb.Append([VT]::MoveTo($this.X + 1, $contentY + $i))
            [void]$sb.Append($this.Content[$i])
        }
        
        return $sb.ToString()
    }
}

class ThreePaneLayout {
    [Pane]$LeftPane
    [Pane]$MiddlePane
    [Pane]$RightPane
    [int]$FocusedPane  # 0=left, 1=middle, 2=right
    [int]$Width
    [int]$Height
    
    ThreePaneLayout([int]$width, [int]$height, [int]$leftWidth, [int]$middleWidth) {
        $this.Width = $width
        $this.Height = $height
        $this.FocusedPane = 1  # Start with middle pane focused
        
        # Calculate positions ensuring perfect alignment
        $rightWidth = $width - $leftWidth - $middleWidth
        
        $this.LeftPane = [Pane]::new(1, 1, $leftWidth, $height - 2, "")
        $this.MiddlePane = [Pane]::new($leftWidth, 1, $middleWidth + 1, $height - 2, "")
        $this.RightPane = [Pane]::new($leftWidth + $middleWidth, 1, $rightWidth, $height - 2, "")
        
        # Set initial focus
        $this.MiddlePane.Active = $true
    }
    
    [void] SetFocus([int]$paneIndex) {
        $this.LeftPane.Active = $false
        $this.MiddlePane.Active = $false
        $this.RightPane.Active = $false
        
        switch ($paneIndex) {
            0 { $this.LeftPane.Active = $true }
            1 { $this.MiddlePane.Active = $true }
            2 { $this.RightPane.Active = $true }
        }
        $this.FocusedPane = $paneIndex
    }
    
    [string] DrawStatusBar([string]$content) {
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append([VT]::MoveTo(1, $this.Height - 1))
        [void]$sb.Append([VT]::Border())
        
        # Draw connected status bar
        [void]$sb.Append([VT]::L())
        [void]$sb.Append([VT]::H() * ($this.LeftPane.Width - 2))
        [void]$sb.Append([VT]::B())
        [void]$sb.Append([VT]::H() * ($this.MiddlePane.Width - 1))
        [void]$sb.Append([VT]::B())
        [void]$sb.Append([VT]::H() * ($this.RightPane.Width - 2))
        [void]$sb.Append([VT]::R())
        
        # Status content
        [void]$sb.Append([VT]::MoveTo(3, $this.Height - 1))
        [void]$sb.Append([VT]::TextDim() + $content)
        [void]$sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
    
    # Buffer-based render - zero string allocation
    [void] RenderToBuffer([Buffer]$buffer) {
        # Draw panes directly to buffer
        $this.LeftPane.DrawBorderToBuffer($buffer)
        $this.MiddlePane.DrawBorderToBuffer($buffer)
        $this.RightPane.DrawBorderToBuffer($buffer)
        
        # Draw content directly to buffer
        $this.LeftPane.DrawContentToBuffer($buffer)
        $this.MiddlePane.DrawContentToBuffer($buffer)
        $this.RightPane.DrawContentToBuffer($buffer)
    }
    
    # Legacy string method
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new()
        
        # Position at home (no clear)
        [void]$sb.Append([VT]::Home())
        
        # Draw panes
        [void]$sb.Append($this.LeftPane.DrawBorder())
        [void]$sb.Append($this.MiddlePane.DrawBorder())
        [void]$sb.Append($this.RightPane.DrawBorder())
        
        # Draw content
        [void]$sb.Append($this.LeftPane.DrawContent())
        [void]$sb.Append($this.MiddlePane.DrawContent())
        [void]$sb.Append($this.RightPane.DrawContent())
        
        return $sb.ToString()
    }
}