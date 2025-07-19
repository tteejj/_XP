# ListBox Component - Optimized for alcar
# Minimal overhead, fast rendering, virtual scrolling

class ListBox : Component {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = 0
    [int]$ScrollOffset = 0
    [bool]$HasBorder = $true
    [string]$BorderColor = ""
    [string]$SelectedColor = ""
    [scriptblock]$ItemFormatter = $null
    [scriptblock]$OnSelectionChanged = $null
    
    # Performance optimization
    hidden [int]$_visibleItems = 0
    hidden [bool]$_needsScrollbarUpdate = $true
    
    ListBox([string]$name) : base($name) {
        $this.Items = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        $this.Items.AddRange($items)
        $this.SelectedIndex = if ($items.Count -gt 0) { 0 } else { -1 }
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    [void] AddItem([object]$item) {
        $this.Items.Add($item) | Out-Null
        if ($this.SelectedIndex -eq -1) {
            $this.SelectedIndex = 0
        }
        $this.Invalidate()
    }
    
    [void] Clear() {
        $this.Items.Clear()
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            return $this.Items[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] OnRender([object]$buffer) {
        if ($this.HasBorder) {
            $this.DrawBorder($buffer)
            $this._visibleItems = $this.Height - 2
            $contentX = 1
            $contentY = 1
            $contentWidth = $this.Width - 2
        } else {
            $this._visibleItems = $this.Height
            $contentX = 0
            $contentY = 0
            $contentWidth = $this.Width
        }
        
        # Ensure selected item is visible
        $this.EnsureVisible()
        
        # Render visible items only (virtual scrolling)
        $endIndex = [Math]::Min($this.ScrollOffset + $this._visibleItems, $this.Items.Count)
        
        for ($i = $this.ScrollOffset; $i -lt $endIndex; $i++) {
            $item = $this.Items[$i]
            $y = $contentY + ($i - $this.ScrollOffset)
            
            # Format item text
            $text = if ($this.ItemFormatter) {
                & $this.ItemFormatter $item
            } else {
                $item.ToString()
            }
            
            # Truncate if too long
            if ($text.Length -gt $contentWidth - 1) {
                $text = $text.Substring(0, $contentWidth - 4) + "..."
            }
            
            # Draw item
            $isSelected = ($i -eq $this.SelectedIndex)
            if ($isSelected) {
                # Selected item
                $bgColor = if ($this.SelectedColor) { $this.SelectedColor } else { [VT]::RGBBG(40, 40, 80) }
                $fgColor = [VT]::RGB(255, 255, 255)
                
                # Fill entire line
                $line = $bgColor + $fgColor + " " + $text.PadRight($contentWidth - 1) + [VT]::Reset()
                $this.DrawText($buffer, $contentX, $y, $line)
            } else {
                # Normal item
                $this.DrawText($buffer, $contentX + 1, $y, $text)
            }
        }
        
        # Draw scrollbar if needed
        if ($this.Items.Count -gt $this._visibleItems -and $this.HasBorder) {
            $this.DrawScrollbar($buffer)
        }
    }
    
    [void] DrawBorder([object]$buffer) {
        $borderColorValue = if ($this.BorderColor) { $this.BorderColor } else { 
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(100, 100, 150) }
        }
        
        # Top border
        $this.DrawText($buffer, 0, 0, $borderColorValue + "┌" + ("─" * ($this.Width - 2)) + "┐" + [VT]::Reset())
        
        # Sides
        for ($y = 1; $y -lt $this.Height - 1; $y++) {
            $this.DrawText($buffer, 0, $y, $borderColorValue + "│" + [VT]::Reset())
            $this.DrawText($buffer, $this.Width - 1, $y, $borderColorValue + "│" + [VT]::Reset())
        }
        
        # Bottom border
        $this.DrawText($buffer, 0, $this.Height - 1, $borderColorValue + "└" + ("─" * ($this.Width - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawScrollbar([object]$buffer) {
        $scrollbarX = $this.Width - 2
        $scrollbarHeight = $this._visibleItems
        
        # Calculate thumb size and position
        $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
        $maxScroll = $this.Items.Count - $this._visibleItems
        $thumbPos = if ($maxScroll -gt 0) {
            [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffset / $maxScroll)
        } else { 0 }
        
        # Draw scrollbar track and thumb
        for ($i = 0; $i -lt $scrollbarHeight; $i++) {
            $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "│" }
            $color = [VT]::RGB(100, 100, 150)
            $this.DrawText($buffer, $scrollbarX, $i + 1, $color + $char + [VT]::Reset())
        }
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # For alcar, we'll render directly to output
        # This is a simplified approach - in production you'd use the buffer
        # The parent screen will collect these outputs
    }
    
    [void] EnsureVisible() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this._visibleItems) {
            $this.ScrollOffset = $this.SelectedIndex - $this._visibleItems + 1
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        $oldIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $handled = $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                    $this.SelectedIndex++
                    $handled = $true
                }
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $handled = $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
                $handled = $true
            }
            ([ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._visibleItems)
                $handled = $true
            }
            ([ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $this._visibleItems)
                $handled = $true
            }
        }
        
        if ($handled) {
            $this.EnsureVisible()
            $this.Invalidate()
            
            if ($oldIndex -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged $this $this.SelectedIndex
            }
        }
        
        return $handled
    }
}