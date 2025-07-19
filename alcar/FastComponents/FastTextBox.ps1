# FastTextBox - Minimal overhead text input

class FastTextBox : FastComponentBase {
    # State
    [string]$Text = ""
    [int]$CursorPos = 0
    [int]$ScrollOffset = 0
    [bool]$IsFocused = $false
    [int]$MaxLength = 100
    
    # Pre-computed
    hidden [string]$_border
    hidden [int]$_contentWidth
    
    FastTextBox([int]$x, [int]$y, [int]$width) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = 3  # Fixed height for bordered input
        $this._contentWidth = $width - 2
        $this._border = "┌" + ("─" * ($width - 2)) + "┐"
    }
    
    # Direct render
    [string] Render() {
        if (-not $this.Visible) { return "" }
        
        $out = [System.Text.StringBuilder]::new(512)
        
        # Border color
        $borderColor = if ($this.IsFocused) {
            "`e[38;2;100;200;255m"
        } else {
            "`e[38;2;80;80;100m"
        }
        
        # Top border
        [void]$out.Append($this.MT($this.X, $this.Y))
        [void]$out.Append($borderColor)
        [void]$out.Append($this._border)
        
        # Content line
        [void]$out.Append($this.MT($this.X, $this.Y + 1))
        [void]$out.Append($borderColor)
        [void]$out.Append("│")
        
        # Calculate visible text (scroll if needed)
        if ($this.CursorPos -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.CursorPos
        } elseif ($this.CursorPos -ge $this.ScrollOffset + $this._contentWidth) {
            $this.ScrollOffset = $this.CursorPos - $this._contentWidth + 1
        }
        
        # Text content
        [void]$out.Append($this.MT($this.X + 1, $this.Y + 1))
        [void]$out.Append("`e[38;2;220;220;220m")
        
        $visibleText = ""
        if ($this.Text.Length -gt $this.ScrollOffset) {
            $len = [Math]::Min($this._contentWidth, $this.Text.Length - $this.ScrollOffset)
            $visibleText = $this.Text.Substring($this.ScrollOffset, $len)
        }
        [void]$out.Append($visibleText.PadRight($this._contentWidth))
        
        # Right border
        [void]$out.Append($this.MT($this.X + $this.Width - 1, $this.Y + 1))
        [void]$out.Append($borderColor)
        [void]$out.Append("│")
        
        # Bottom border
        [void]$out.Append($this.MT($this.X, $this.Y + 2))
        [void]$out.Append($borderColor)
        [void]$out.Append("└" + ("─" * ($this.Width - 2)) + "┘")
        
        # Cursor (if focused)
        if ($this.IsFocused) {
            $cursorScreenX = $this.X + 1 + ($this.CursorPos - $this.ScrollOffset)
            if ($cursorScreenX -ge $this.X + 1 -and $cursorScreenX -lt $this.X + $this.Width - 1) {
                [void]$out.Append($this.MT($cursorScreenX, $this.Y + 1))
                [void]$out.Append("`e[7m")  # Reverse video for cursor
                $charUnder = if ($this.CursorPos -lt $this.Text.Length) { 
                    $this.Text[$this.CursorPos] 
                } else { ' ' }
                [void]$out.Append($charUnder)
                [void]$out.Append("`e[27m")  # Reset reverse
            }
        }
        
        [void]$out.Append([FastComponentBase]::VTCache.Reset)
        return $out.ToString()
    }
    
    # Direct input
    [bool] Input([ConsoleKey]$key) {
        switch ($key) {
            ([ConsoleKey]::LeftArrow) {
                if ($this.CursorPos -gt 0) {
                    $this.CursorPos--
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::RightArrow) {
                if ($this.CursorPos -lt $this.Text.Length) {
                    $this.CursorPos++
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Home) {
                $this.CursorPos = 0
                $this.ScrollOffset = 0
                return $true
            }
            ([ConsoleKey]::End) {
                $this.CursorPos = $this.Text.Length
                return $true
            }
            ([ConsoleKey]::Backspace) {
                if ($this.CursorPos -gt 0) {
                    $this.Text = $this.Text.Remove($this.CursorPos - 1, 1)
                    $this.CursorPos--
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Delete) {
                if ($this.CursorPos -lt $this.Text.Length) {
                    $this.Text = $this.Text.Remove($this.CursorPos, 1)
                    return $true
                }
                return $false
            }
        }
        return $false
    }
    
    # Fast character input (separate method for speed)
    [bool] InputChar([char]$char) {
        if ($this.Text.Length -lt $this.MaxLength) {
            $this.Text = $this.Text.Insert($this.CursorPos, $char)
            $this.CursorPos++
            return $true
        }
        return $false
    }
}