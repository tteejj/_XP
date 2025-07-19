# FastListBox - Zero-overhead listbox implementation

class FastListBox : FastComponentBase {
    # Minimal state
    [array]$Items = @()
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$HasBorder = $true
    [bool]$IsFocused = $false
    
    # Pre-computed values to avoid recalculation
    hidden [int]$_visibleItems
    hidden [string]$_borderTop
    hidden [string]$_borderBottom
    hidden [string]$_borderSide
    
    FastListBox([int]$x, [int]$y, [int]$width, [int]$height) {
        $this.X = $x
        $this.Y = $y
        $this.Width = $width
        $this.Height = $height
        $this.PrecomputeBorders()
        $this._visibleItems = $height - (if ($this.HasBorder) { 2 } else { 0 })
    }
    
    [void] PrecomputeBorders() {
        # Pre-build border strings
        $this._borderTop = "┌" + ("─" * ($this.Width - 2)) + "┐"
        $this._borderBottom = "└" + ("─" * ($this.Width - 2)) + "┘"
        $this._borderSide = "│" + (" " * ($this.Width - 2)) + "│"
    }
    
    # Direct render - no method calls, just string building
    [string] Render() {
        if (-not $this.Visible -or $this.Items.Count -eq 0) { return "" }
        
        $out = [System.Text.StringBuilder]::new(2048)  # Pre-allocate
        
        # Colors based on focus
        $borderColor = if ($this.IsFocused) { 
            [FastComponentBase]::VTCache.Colors['Focus'] 
        } else { 
            "`e[38;2;80;80;100m" 
        }
        
        # Draw border if enabled
        if ($this.HasBorder) {
            # Top border
            [void]$out.Append($this.MT($this.X, $this.Y))
            [void]$out.Append($borderColor)
            [void]$out.Append($this._borderTop)
            
            # Side borders (will be overwritten by content)
            $endY = $this.Y + $this.Height - 1
            for ($y = $this.Y + 1; $y -lt $endY; $y++) {
                [void]$out.Append($this.MT($this.X, $y))
                [void]$out.Append($borderColor)
                [void]$out.Append($this._borderSide)
            }
            
            # Bottom border
            [void]$out.Append($this.MT($this.X, $endY))
            [void]$out.Append($borderColor)
            [void]$out.Append($this._borderBottom)
        }
        
        # Ensure selected item is visible (inline scroll calculation)
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this._visibleItems) {
            $this.ScrollOffset = $this.SelectedIndex - $this._visibleItems + 1
        }
        
        # Draw items - direct loop, no method calls
        $contentX = $this.X + (if ($this.HasBorder) { 1 } else { 0 })
        $contentY = $this.Y + (if ($this.HasBorder) { 1 } else { 0 })
        $contentWidth = $this.Width - (if ($this.HasBorder) { 2 } else { 0 })
        
        $endIndex = [Math]::Min($this.ScrollOffset + $this._visibleItems, $this.Items.Count)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $y = $contentY + ($i - $this.ScrollOffset)
            
            # Move to position
            [void]$out.Append($this.MT($contentX, $y))
            
            # Apply selection highlight
            if ($i -eq $this.SelectedIndex) {
                [void]$out.Append([FastComponentBase]::VTCache.Colors['Selected'])
            } else {
                [void]$out.Append([FastComponentBase]::VTCache.Colors['Normal'])
            }
            
            # Render item text (truncate if needed)
            $text = $this.Items[$i].ToString()
            if ($text.Length -gt $contentWidth) {
                $text = $text.Substring(0, $contentWidth - 3) + "..."
            } else {
                $text = $text.PadRight($contentWidth)
            }
            [void]$out.Append($text)
        }
        
        # Reset at end
        [void]$out.Append([FastComponentBase]::VTCache.Reset)
        
        return $out.ToString()
    }
    
    # Direct input handling - minimal checks
    [bool] Input([ConsoleKey]$key) {
        switch ($key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    return $true
                }
                return $false
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.ScrollOffset = 0
                return $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                return $true
            }
            ([ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._visibleItems)
                return $true
            }
            ([ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._visibleItems)
                return $true
            }
        }
        return $false
    }
    
    # Fast item access
    [object] GetSelected() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
}