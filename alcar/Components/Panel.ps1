# Panel Component - Simple container with optional border

class Panel : Container {
    [bool]$HasBorder = $true
    [string]$Title = ""
    [string]$BorderColor = ""
    [string]$BorderStyle = "Single"  # Single, Double, Rounded
    
    Panel([string]$name) : base($name) {
    }
    
    [void] OnRender([object]$buffer) {
        if ($this.HasBorder) {
            $this.DrawBorder($buffer)
        }
        
        # Render children with adjusted coordinates if border is present
        $offset = if ($this.HasBorder) { 1 } else { 0 }
        
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                # Adjust child position for border
                $originalX = $child.X
                $originalY = $child.Y
                $child.X += $offset
                $child.Y += $offset
                
                # Render child
                ([Component]$child).Render($buffer)
                
                # Restore position
                $child.X = $originalX
                $child.Y = $originalY
            }
        }
    }
    
    [void] DrawBorder([object]$buffer) {
        $color = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(100, 100, 150) }
        }
        
        # Get border characters based on style
        $chars = switch ($this.BorderStyle) {
            "Double" { @{TL="╔"; TR="╗"; BL="╚"; BR="╝"; H="═"; V="║"} }
            "Rounded" { @{TL="╭"; TR="╮"; BL="╰"; BR="╯"; H="─"; V="│"} }
            default { @{TL="┌"; TR="┐"; BL="└"; BR="┘"; H="─"; V="│"} }
        }
        
        # Top border
        $topLine = $color + $chars.TL + ($chars.H * ($this.Width - 2)) + $chars.TR + [VT]::Reset()
        # For alcar, we'll use direct rendering instead of buffer.SetText
        # $buffer.SetText($this.X, $this.Y, $topLine)
        
        # Title if present
        if ($this.Title) {
            $titleText = " $($this.Title) "
            $titleX = $this.X + 2
            # $buffer.SetText($titleX, $this.Y, $color + $titleText + [VT]::Reset())
        }
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            # $buffer.SetText($this.X, $this.Y + $y, $color + $chars.V + [VT]::Reset())
            # $buffer.SetText($this.X + $this.Width - 1, $this.Y + $y, $color + $chars.V + [VT]::Reset())
        }
        
        # Bottom border
        $bottomLine = $color + $chars.BL + ($chars.H * ($this.Width - 2)) + $chars.BR + [VT]::Reset()
        # $buffer.SetText($this.X, $this.Y + $this.Height - 1, $bottomLine)
    }
}