# FastMenu - High-performance menu rendering

class FastMenu : FastComponentBase {
    # State
    [array]$Items = @()
    [int]$SelectedIndex = 0
    [bool]$IsFocused = $false
    
    # Pre-computed
    hidden [hashtable]$_itemCache = @{}
    hidden [int]$_maxWidth = 0
    
    FastMenu([int]$x, [int]$y, [array]$items) {
        $this.X = $x
        $this.Y = $y
        $this.Items = $items
        $this.Height = $items.Count
        $this.CalculateWidth()
        $this.PrecomputeItems()
    }
    
    [void] CalculateWidth() {
        $this._maxWidth = 0
        foreach ($item in $this.Items) {
            $len = $item.ToString().Length
            if ($len -gt $this._maxWidth) {
                $this._maxWidth = $len
            }
        }
        $this.Width = $this._maxWidth + 4  # Padding
    }
    
    [void] PrecomputeItems() {
        # Pre-render each item in normal state
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $text = $this.Items[$i].ToString().PadRight($this._maxWidth)
            $this._itemCache[$i] = "  " + $text + "  "
        }
    }
    
    # Direct render - optimized for vertical menus
    [string] Render() {
        if (-not $this.Visible -or $this.Items.Count -eq 0) { return "" }
        
        $out = [System.Text.StringBuilder]::new(1024)
        
        # Render each item
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            [void]$out.Append($this.MT($this.X, $this.Y + $i))
            
            if ($i -eq $this.SelectedIndex -and $this.IsFocused) {
                # Selected item - full highlight
                [void]$out.Append("`e[48;2;40;40;80m`e[38;2;255;255;255m")
                [void]$out.Append("▶ ")
                [void]$out.Append($this.Items[$i].ToString().PadRight($this._maxWidth))
                [void]$out.Append("  ")
            } else {
                # Normal item
                [void]$out.Append("`e[38;2;200;200;200m")
                [void]$out.Append($this._itemCache[$i])
            }
        }
        
        [void]$out.Append([FastComponentBase]::VTCache.Reset)
        return $out.ToString()
    }
    
    # Direct input
    [bool] Input([ConsoleKey]$key) {
        switch ($key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    return $true
                }
                # Wrap to bottom
                $this.SelectedIndex = $this.Items.Count - 1
                return $true
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    return $true
                }
                # Wrap to top
                $this.SelectedIndex = 0
                return $true
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                return $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                return $true
            }
        }
        return $false
    }
    
    # Quick access by number key
    [bool] InputNumber([int]$num) {
        if ($num -gt 0 -and $num -le $this.Items.Count) {
            $this.SelectedIndex = $num - 1
            return $true
        }
        return $false
    }
    
    # Get selected item
    [object] GetSelected() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
}