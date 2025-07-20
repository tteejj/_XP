# FastPanel - High-performance panel component with minimal overhead

class FastPanel : FastComponentBase {
    [string]$Title = ""
    [bool]$HasBorder = $true
    [string]$BorderStyle = "Single"  # Single, Double, Rounded
    [bool]$IsFocused = $false
    [System.Collections.ArrayList]$Children
    
    # Pre-cached border characters
    static [hashtable]$BorderChars = @{
        Single = @{TL="┌"; TR="┐"; BL="└"; BR="┘"; H="─"; V="│"}
        Double = @{TL="╔"; TR="╗"; BL="╚"; BR="╝"; H="═"; V="║"}
        Rounded = @{TL="╭"; TR="╮"; BL="╰"; BR="╯"; H="─"; V="│"}
    }
    
    FastPanel([string]$name) {
        $this.Children = [System.Collections.ArrayList]::new()
    }
    
    [void] AddChild([object]$child) {
        $this.Children.Add($child) | Out-Null
    }
    
    # Buffer-based render - zero allocation
    [void] RenderToBuffer([Buffer]$buffer) {
        if (-not $this.Visible) { return }
        
        # Colors
        $borderFG = if ($this.IsFocused) { "#64C8FF" } else { "#646464" }
        $normalBG = "#1E1E23"
        
        # Render border if enabled
        if ($this.HasBorder) {
            $chars = [FastPanel]::BorderChars[$this.BorderStyle]
            
            # Top border
            $buffer.SetCell($this.X, $this.Y, $chars.TL, $borderFG, $normalBG)
            
            # Add title if present
            if ($this.Title) {
                $buffer.SetCell($this.X + 1, $this.Y, $chars.H, $borderFG, $normalBG)
                $buffer.SetCell($this.X + 2, $this.Y, ' ', $borderFG, $normalBG)
                
                # Write title
                for ($i = 0; $i -lt $this.Title.Length; $i++) {
                    $buffer.SetCell($this.X + 3 + $i, $this.Y, $this.Title[$i], $borderFG, $normalBG)
                }
                
                $buffer.SetCell($this.X + 3 + $this.Title.Length, $this.Y, ' ', $borderFG, $normalBG)
                
                # Fill remaining horizontal line
                for ($x = 4 + $this.Title.Length; $x -lt $this.Width - 1; $x++) {
                    $buffer.SetCell($this.X + $x, $this.Y, $chars.H, $borderFG, $normalBG)
                }
            } else {
                # Fill horizontal line
                for ($x = 1; $x -lt $this.Width - 1; $x++) {
                    $buffer.SetCell($this.X + $x, $this.Y, $chars.H, $borderFG, $normalBG)
                }
            }
            
            $buffer.SetCell($this.X + $this.Width - 1, $this.Y, $chars.TR, $borderFG, $normalBG)
            
            # Sides
            for ($y = 1; $y -lt $this.Height - 1; $y++) {
                $buffer.SetCell($this.X, $this.Y + $y, $chars.V, $borderFG, $normalBG)
                $buffer.SetCell($this.X + $this.Width - 1, $this.Y + $y, $chars.V, $borderFG, $normalBG)
            }
            
            # Bottom border
            $buffer.SetCell($this.X, $this.Y + $this.Height - 1, $chars.BL, $borderFG, $normalBG)
            for ($x = 1; $x -lt $this.Width - 1; $x++) {
                $buffer.SetCell($this.X + $x, $this.Y + $this.Height - 1, $chars.H, $borderFG, $normalBG)
            }
            $buffer.SetCell($this.X + $this.Width - 1, $this.Y + $this.Height - 1, $chars.BR, $borderFG, $normalBG)
        }
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible -and ($child -is [FastComponentBase])) {
                $child.RenderToBuffer($buffer)
            }
        }
    }
    
    [bool] Input([ConsoleKey]$key) {
        # Pass input to focused child if any
        foreach ($child in $this.Children) {
            if ($child -is [FastComponentBase] -and $child.Input($key)) {
                return $true
            }
        }
        return $false
    }
}