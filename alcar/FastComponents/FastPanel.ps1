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
    
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        $sb = [System.Text.StringBuilder]::new(2048)
        
        # Render border if enabled
        if ($this.HasBorder) {
            $chars = [FastPanel]::BorderChars[$this.BorderStyle]
            $color = if ($this.IsFocused) { 
                [FastComponentBase]::VTCache.Colors['Focus'] 
            } else { 
                [FastComponentBase]::VTCache.Colors['Normal'] 
            }
            
            # Top border
            [void]$sb.Append($this.MT($this.X, $this.Y))
            [void]$sb.Append($color)
            [void]$sb.Append($chars.TL)
            
            # Add title if present
            if ($this.Title) {
                [void]$sb.Append($chars.H)
                [void]$sb.Append(" $($this.Title) ")
                $titleLen = $this.Title.Length + 2
                [void]$sb.Append($chars.H * ($this.Width - $titleLen - 3))
            } else {
                [void]$sb.Append($chars.H * ($this.Width - 2))
            }
            
            [void]$sb.Append($chars.TR)
            [void]$sb.Append([FastComponentBase]::VTCache.Reset)
            
            # Sides
            for ($y = 1; $y -lt $this.Height - 1; $y++) {
                # Left side
                [void]$sb.Append($this.MT($this.X, $this.Y + $y))
                [void]$sb.Append($color)
                [void]$sb.Append($chars.V)
                [void]$sb.Append([FastComponentBase]::VTCache.Reset)
                
                # Right side
                [void]$sb.Append($this.MT($this.X + $this.Width - 1, $this.Y + $y))
                [void]$sb.Append($color)
                [void]$sb.Append($chars.V)
                [void]$sb.Append([FastComponentBase]::VTCache.Reset)
            }
            
            # Bottom border
            [void]$sb.Append($this.MT($this.X, $this.Y + $this.Height - 1))
            [void]$sb.Append($color)
            [void]$sb.Append($chars.BL)
            [void]$sb.Append($chars.H * ($this.Width - 2))
            [void]$sb.Append($chars.BR)
            [void]$sb.Append([FastComponentBase]::VTCache.Reset)
        }
        
        # Render children
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                # Render child content (adjust for border if present)
                if ($child -is [FastComponentBase]) {
                    [void]$sb.Append($child.Render())
                }
            }
        }
        
        return $sb.ToString()
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