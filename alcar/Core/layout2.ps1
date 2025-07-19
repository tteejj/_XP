# Improved Three-Pane Layout Engine with Perfect Alignment

class Pane {
    [int]$X
    [int]$Y
    [int]$Width
    [int]$Height
    [string]$Title
    [bool]$Active
    [bool]$Interactive = $true  # Can this pane receive focus?
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
}

class ThreePaneLayout {
    [Pane]$LeftPane
    [Pane]$MiddlePane
    [Pane]$RightPane
    [int]$FocusedPane  # 0=left, 1=middle, 2=right
    [int]$Width
    [int]$Height
    
    ThreePaneLayout([int]$width, [int]$height, [int]$leftWidth, [int]$rightWidth) {
        $this.Width = $width
        $this.Height = $height
        $this.FocusedPane = 1  # Start with middle pane focused
        
        # Calculate middle width from remaining space
        $middleWidth = $width - $leftWidth - $rightWidth - 2  # -2 for borders
        
        # Create panes with exact positioning
        $this.LeftPane = [Pane]::new(1, 1, $leftWidth, $height - 3, "FILTERS")
        $this.MiddlePane = [Pane]::new($leftWidth + 1, 1, $middleWidth, $height - 3, "TASKS")
        $this.RightPane = [Pane]::new($leftWidth + $middleWidth + 1, 1, $rightWidth, $height - 3, "DETAIL")
        
        # Right pane is view-only
        $this.RightPane.Interactive = $false
        
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
    
    [void] FocusNext() {
        # Only cycle between interactive panes
        if ($this.FocusedPane -eq 0) {
            $this.SetFocus(1)  # Left -> Middle
        } else {
            $this.SetFocus(0)  # Middle -> Left
        }
    }
    
    [void] FocusPrev() {
        # Same as next for 2 panes
        $this.FocusNext()
    }
    
    [string] Render() {
        $sb = [System.Text.StringBuilder]::new(8192)
        
        # Don't clear - parent screen handles that
        # Just draw the layout
        
        # Draw main frame
        [void]$sb.Append([VT]::MoveTo(1, 1))
        [void]$sb.Append([VT]::Border())
        [void]$sb.Append([VT]::TL())
        [void]$sb.Append([VT]::H() * ($this.Width - 2))
        [void]$sb.Append([VT]::TR())
        
        # Draw sides
        for ($y = 2; $y -lt $this.Height - 2; $y++) {
            [void]$sb.Append([VT]::MoveTo(1, $y))
            [void]$sb.Append([VT]::V())
            [void]$sb.Append([VT]::MoveTo($this.Width, $y))
            [void]$sb.Append([VT]::V())
        }
        
        # Draw bottom (leave space for status)
        [void]$sb.Append([VT]::MoveTo(1, $this.Height - 2))
        [void]$sb.Append([VT]::BL())
        [void]$sb.Append([VT]::H() * ($this.Width - 2))
        [void]$sb.Append([VT]::BR())
        
        # Draw pane dividers with proper connections
        # Left divider
        [void]$sb.Append([VT]::MoveTo($this.LeftPane.Width + 1, 1))
        [void]$sb.Append([VT]::T())  # Top connection
        
        for ($y = 2; $y -lt $this.Height - 2; $y++) {
            [void]$sb.Append([VT]::MoveTo($this.LeftPane.Width + 1, $y))
            [void]$sb.Append([VT]::V())
        }
        
        [void]$sb.Append([VT]::MoveTo($this.LeftPane.Width + 1, $this.Height - 2))
        [void]$sb.Append([VT]::B())  # Bottom connection
        
        # Right divider
        $rightDividerX = $this.LeftPane.Width + $this.MiddlePane.Width + 1
        [void]$sb.Append([VT]::MoveTo($rightDividerX, 1))
        [void]$sb.Append([VT]::T())  # Top connection
        
        for ($y = 2; $y -lt $this.Height - 2; $y++) {
            [void]$sb.Append([VT]::MoveTo($rightDividerX, $y))
            [void]$sb.Append([VT]::V())
        }
        
        [void]$sb.Append([VT]::MoveTo($rightDividerX, $this.Height - 2))
        [void]$sb.Append([VT]::B())  # Bottom connection
        
        # Draw pane titles
        $this.DrawPaneTitle($sb, $this.LeftPane)
        $this.DrawPaneTitle($sb, $this.MiddlePane)
        $this.DrawPaneTitle($sb, $this.RightPane)
        
        # Draw content
        $this.DrawPaneContent($sb, $this.LeftPane)
        $this.DrawPaneContent($sb, $this.MiddlePane)
        $this.DrawPaneContent($sb, $this.RightPane)
        
        [void]$sb.Append([VT]::Reset())
        return $sb.ToString()
    }
    
    [void] DrawPaneTitle([System.Text.StringBuilder]$sb, [Pane]$pane) {
        if (-not $pane.Title) { return }
        
        $color = if ($pane.Active) { [VT]::BorderActive() } else { [VT]::Border() }
        $titleText = " $($pane.Title) "
        $titleStart = $pane.X + [int](($pane.Width - $titleText.Length) / 2)
        
        [void]$sb.Append([VT]::MoveTo($titleStart, 1))
        [void]$sb.Append($color + [VT]::TextBright() + $titleText)
    }
    
    [void] DrawPaneContent([System.Text.StringBuilder]$sb, [Pane]$pane) {
        $contentY = 2
        $maxLines = $pane.Height - 1
        
        for ($i = 0; $i -lt [Math]::Min($pane.Content.Count, $maxLines); $i++) {
            [void]$sb.Append([VT]::MoveTo($pane.X + 1, $contentY + $i))
            [void]$sb.Append($pane.Content[$i])
        }
    }
    
    [string] DrawStatusBar([string]$content) {
        $sb = [System.Text.StringBuilder]::new()
        
        # Draw status inside the frame
        [void]$sb.Append([VT]::MoveTo(3, $this.Height - 1))
        [void]$sb.Append([VT]::TextDim() + $content)
        [void]$sb.Append([VT]::Reset())
        
        return $sb.ToString()
    }
}