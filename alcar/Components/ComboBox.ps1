# ComboBox Component - Dropdown selection with optional editing

class ComboBox : Component {
    [System.Collections.ArrayList]$Items
    [int]$SelectedIndex = -1
    [string]$SelectedValue = ""
    [string]$DisplayProperty = ""  # For complex objects
    [string]$ValueProperty = ""    # For complex objects
    [bool]$IsEditable = $false
    [string]$Placeholder = "Select an item..."
    [scriptblock]$OnSelectionChanged = $null
    
    # Visual properties
    [bool]$ShowBorder = $true
    [int]$DropdownMaxHeight = 10
    [string]$DropdownColor = ""
    
    # Internal state
    hidden [bool]$_isOpen = $false
    hidden [int]$_highlightedIndex = -1
    hidden [string]$_searchText = ""
    hidden [System.Collections.ArrayList]$_filteredItems
    hidden [int]$_scrollOffset = 0
    
    ComboBox([string]$name) : base($name) {
        $this.Items = [System.Collections.ArrayList]::new()
        $this._filteredItems = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
        $this.Height = if ($this.ShowBorder) { 3 } else { 1 }
        $this.Width = 25
    }
    
    [void] SetItems([array]$items) {
        $this.Items.Clear()
        if ($items) {
            $this.Items.AddRange($items)
        }
        $this.SelectedIndex = -1
        $this.SelectedValue = ""
        $this._searchText = ""
        $this.Invalidate()
    }
    
    [void] SelectItem([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $oldIndex = $this.SelectedIndex
            $this.SelectedIndex = $index
            
            $item = $this.Items[$index]
            $this.SelectedValue = $this.GetItemValue($item)
            
            if (-not $this.IsEditable) {
                $this._searchText = $this.GetItemDisplay($item)
            }
            
            if ($oldIndex -ne $index -and $this.OnSelectionChanged) {
                & $this.OnSelectionChanged $this $item
            }
        }
    }
    
    [string] GetItemDisplay([object]$item) {
        if ($null -eq $item) { return "" }
        
        if ($this.DisplayProperty -and $item.PSObject.Properties[$this.DisplayProperty]) {
            return $item.($this.DisplayProperty).ToString()
        }
        
        return $item.ToString()
    }
    
    [string] GetItemValue([object]$item) {
        if ($null -eq $item) { return "" }
        
        if ($this.ValueProperty -and $item.PSObject.Properties[$this.ValueProperty]) {
            return $item.($this.ValueProperty).ToString()
        }
        
        return $item.ToString()
    }
    
    [void] OpenDropdown() {
        $this._isOpen = $true
        $this.FilterItems()
        
        # Highlight current selection
        $this._highlightedIndex = -1
        if ($this.SelectedIndex -ge 0) {
            for ($i = 0; $i -lt $this._filteredItems.Count; $i++) {
                if ($this._filteredItems[$i].Index -eq $this.SelectedIndex) {
                    $this._highlightedIndex = $i
                    break
                }
            }
        }
        
        if ($this._highlightedIndex -eq -1 -and $this._filteredItems.Count -gt 0) {
            $this._highlightedIndex = 0
        }
        
        $this.Invalidate()
    }
    
    [void] CloseDropdown() {
        $this._isOpen = $false
        if (-not $this.IsEditable) {
            $this._searchText = if ($this.SelectedIndex -ge 0) {
                $this.GetItemDisplay($this.Items[$this.SelectedIndex])
            } else { "" }
        }
        $this.Invalidate()
    }
    
    [void] FilterItems() {
        $this._filteredItems.Clear()
        
        if ([string]::IsNullOrEmpty($this._searchText)) {
            # Show all items
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $this._filteredItems.Add(@{
                    Index = $i
                    Item = $this.Items[$i]
                }) | Out-Null
            }
        } else {
            # Filter based on search text
            $searchLower = $this._searchText.ToLower()
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $displayText = $this.GetItemDisplay($this.Items[$i]).ToLower()
                if ($displayText.Contains($searchLower)) {
                    $this._filteredItems.Add(@{
                        Index = $i
                        Item = $this.Items[$i]
                    }) | Out-Null
                }
            }
        }
        
        # Adjust highlighted index
        if ($this._highlightedIndex -ge $this._filteredItems.Count) {
            $this._highlightedIndex = [Math]::Max(0, $this._filteredItems.Count - 1)
        }
    }
    
    [void] OnRender([object]$buffer) {
        if (-not $this.Visible) { return }
        
        # Colors
        $bgColor = if ($this.BackgroundColor) { $this.BackgroundColor } else { [VT]::RGBBG(30, 30, 35) }
        $fgColor = if ($this.ForegroundColor) { $this.ForegroundColor } else { [VT]::RGB(220, 220, 220) }
        $borderColor = if ($this.BorderColor) { $this.BorderColor } else {
            if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(80, 80, 100) }
        }
        
        # Draw main box
        $this.DrawMainBox($buffer, $bgColor, $fgColor, $borderColor)
        
        # Draw dropdown if open
        if ($this._isOpen) {
            $this.DrawDropdown($buffer)
        }
    }
    
    [void] DrawMainBox([object]$buffer, [string]$bgColor, [string]$fgColor, [string]$borderColor) {
        # Clear background
        for ($y = 0; $y -lt $this.Height; $y++) {
            $this.DrawText($buffer, 0, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw border if enabled
        if ($this.ShowBorder) {
            $this.DrawBorder($buffer, $borderColor)
        }
        
        # Content area
        $contentY = if ($this.ShowBorder) { 1 } else { 0 }
        $contentX = if ($this.ShowBorder) { 1 } else { 0 }
        $contentWidth = $this.Width - (if ($this.ShowBorder) { 3 } else { 1 })  # Space for arrow
        
        # Display text
        $displayText = ""
        if ($this.IsEditable) {
            $displayText = $this._searchText
        } elseif ($this.SelectedIndex -ge 0) {
            $displayText = $this.GetItemDisplay($this.Items[$this.SelectedIndex])
        }
        
        if ([string]::IsNullOrEmpty($displayText) -and -not $this._isOpen) {
            # Show placeholder
            $this.DrawText($buffer, $contentX, $contentY,
                          [VT]::RGB(100, 100, 120) + $this.Placeholder + [VT]::Reset())
        } else {
            # Show text
            if ($displayText.Length -gt $contentWidth) {
                $displayText = $displayText.Substring(0, $contentWidth - 3) + "..."
            }
            $this.DrawText($buffer, $contentX, $contentY, $fgColor + $displayText + [VT]::Reset())
        }
        
        # Draw dropdown arrow
        $arrowX = $this.Width - (if ($this.ShowBorder) { 2 } else { 1 })
        $arrow = if ($this._isOpen) { "▲" } else { "▼" }
        $arrowColor = if ($this.IsFocused) { [VT]::RGB(100, 200, 255) } else { [VT]::RGB(100, 100, 150) }
        $this.DrawText($buffer, $arrowX, $contentY, $arrowColor + $arrow + [VT]::Reset())
    }
    
    [void] DrawDropdown([object]$buffer) {
        $dropY = $this.Height
        $dropHeight = [Math]::Min($this._filteredItems.Count + 2, $this.DropdownMaxHeight)
        
        if ($dropHeight -lt 3) { $dropHeight = 3 }
        
        $dropBgColor = if ($this.DropdownColor) { $this.DropdownColor } else { [VT]::RGBBG(25, 25, 30) }
        $dropBorderColor = [VT]::RGB(80, 80, 100)
        
        # Draw dropdown background
        for ($y = 0; $y -lt $dropHeight; $y++) {
            $this.DrawText($buffer, 0, $dropY + $y, $dropBgColor + (" " * $this.Width) + [VT]::Reset())
        }
        
        # Draw dropdown border
        $this.DrawDropdownBorder($buffer, 0, $dropY, $this.Width, $dropHeight, $dropBorderColor)
        
        # Calculate visible items
        $visibleItems = $dropHeight - 2
        $this._scrollOffset = $this.CalculateScrollOffset($visibleItems)
        
        # Draw items
        $itemY = $dropY + 1
        for ($i = 0; $i -lt $visibleItems -and ($i + $this._scrollOffset) -lt $this._filteredItems.Count; $i++) {
            $filteredItem = $this._filteredItems[$i + $this._scrollOffset]
            $item = $filteredItem.Item
            $isHighlighted = ($i + $this._scrollOffset) -eq $this._highlightedIndex
            $isSelected = $filteredItem.Index -eq $this.SelectedIndex
            
            # Item colors
            if ($isHighlighted) {
                $itemBgColor = [VT]::RGBBG(60, 60, 100)
                $itemFgColor = [VT]::RGB(255, 255, 255)
            } elseif ($isSelected) {
                $itemBgColor = $dropBgColor
                $itemFgColor = [VT]::RGB(100, 200, 255)
            } else {
                $itemBgColor = $dropBgColor
                $itemFgColor = [VT]::RGB(200, 200, 200)
            }
            
            # Clear line and draw item
            $this.DrawText($buffer, 1, $itemY, $itemBgColor + (" " * ($this.Width - 2)) + [VT]::Reset())
            
            $itemText = $this.GetItemDisplay($item)
            if ($itemText.Length -gt $this.Width - 4) {
                $itemText = $itemText.Substring(0, $this.Width - 7) + "..."
            }
            
            $this.DrawText($buffer, 2, $itemY, $itemFgColor + $itemText + [VT]::Reset())
            $itemY++
        }
        
        # Draw scrollbar if needed
        if ($this._filteredItems.Count -gt $visibleItems) {
            $this.DrawScrollbar($buffer, $this.Width - 2, $dropY + 1, $visibleItems, 
                               $this._scrollOffset, $this._filteredItems.Count)
        }
    }
    
    [void] DrawBorder([object]$buffer, [string]$color) {
        $this.DrawText($buffer, 0, 0, $color + "┌" + ("─" * ($this.Width - 2)) + "┐" + [VT]::Reset())
        $this.DrawText($buffer, 0, 1, $color + "│" + [VT]::Reset())
        $this.DrawText($buffer, $this.Width - 1, 1, $color + "│" + [VT]::Reset())
        $this.DrawText($buffer, 0, 2, $color + "└" + ("─" * ($this.Width - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawDropdownBorder([object]$buffer, [int]$x, [int]$y, [int]$w, [int]$h, [string]$color) {
        # Top
        $this.DrawText($buffer, $x, $y, $color + "┌" + ("─" * ($w - 2)) + "┐" + [VT]::Reset())
        # Sides
        for ($i = 1; $i -lt $h - 1; $i++) {
            $this.DrawText($buffer, $x, $y + $i, $color + "│" + [VT]::Reset())
            $this.DrawText($buffer, $x + $w - 1, $y + $i, $color + "│" + [VT]::Reset())
        }
        # Bottom
        $this.DrawText($buffer, $x, $y + $h - 1, $color + "└" + ("─" * ($w - 2)) + "┘" + [VT]::Reset())
    }
    
    [void] DrawScrollbar([object]$buffer, [int]$x, [int]$y, [int]$height, [int]$offset, [int]$total) {
        $thumbSize = [Math]::Max(1, [int]($height * $height / $total))
        $thumbPos = [int](($height - $thumbSize) * $offset / ($total - $height))
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
            $this.DrawText($buffer, $x, $y + $i, [VT]::RGB(60, 60, 80) + $char + [VT]::Reset())
        }
    }
    
    [int] CalculateScrollOffset([int]$visibleItems) {
        if ($this._filteredItems.Count -le $visibleItems) {
            return 0
        }
        
        if ($this._highlightedIndex -lt $this._scrollOffset) {
            return $this._highlightedIndex
        }
        elseif ($this._highlightedIndex -ge $this._scrollOffset + $visibleItems) {
            return $this._highlightedIndex - $visibleItems + 1
        }
        
        return $this._scrollOffset
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if (-not $this.Enabled -or -not $this.IsFocused) { return $false }
        
        if (-not $this._isOpen) {
            # Closed state
            switch ($key.Key) {
                ([ConsoleKey]::Enter) {
                    $this.OpenDropdown()
                    return $true
                }
                ([ConsoleKey]::Spacebar) {
                    if (-not $this.IsEditable) {
                        $this.OpenDropdown()
                        return $true
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    $this.OpenDropdown()
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    $this.OpenDropdown()
                    return $true
                }
            }
            
            # Handle typing for editable combobox
            if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                $this._searchText += $key.KeyChar
                $this.OpenDropdown()
                $this.FilterItems()
                $this.Invalidate()
                return $true
            }
        } else {
            # Open state
            switch ($key.Key) {
                ([ConsoleKey]::Escape) {
                    $this.CloseDropdown()
                    return $true
                }
                ([ConsoleKey]::Enter) {
                    if ($this._highlightedIndex -ge 0 -and 
                        $this._highlightedIndex -lt $this._filteredItems.Count) {
                        $filteredItem = $this._filteredItems[$this._highlightedIndex]
                        $this.SelectItem($filteredItem.Index)
                        $this.CloseDropdown()
                    }
                    return $true
                }
                ([ConsoleKey]::UpArrow) {
                    if ($this._highlightedIndex -gt 0) {
                        $this._highlightedIndex--
                        $this.Invalidate()
                    }
                    return $true
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this._highlightedIndex -lt $this._filteredItems.Count - 1) {
                        $this._highlightedIndex++
                        $this.Invalidate()
                    }
                    return $true
                }
                ([ConsoleKey]::Home) {
                    $this._highlightedIndex = 0
                    $this._scrollOffset = 0
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::End) {
                    $this._highlightedIndex = $this._filteredItems.Count - 1
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::PageUp) {
                    $pageSize = $this.DropdownMaxHeight - 2
                    $this._highlightedIndex = [Math]::Max(0, $this._highlightedIndex - $pageSize)
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::PageDown) {
                    $pageSize = $this.DropdownMaxHeight - 2
                    $this._highlightedIndex = [Math]::Min($this._filteredItems.Count - 1, 
                                                         $this._highlightedIndex + $pageSize)
                    $this.Invalidate()
                    return $true
                }
                ([ConsoleKey]::Backspace) {
                    if ($this.IsEditable -and $this._searchText.Length -gt 0) {
                        $this._searchText = $this._searchText.Substring(0, $this._searchText.Length - 1)
                        $this.FilterItems()
                        $this.Invalidate()
                        return $true
                    }
                }
            }
            
            # Handle typing in open dropdown
            if ($this.IsEditable -and $key.KeyChar -and [char]::IsControl($key.KeyChar) -eq $false) {
                $this._searchText += $key.KeyChar
                $this.FilterItems()
                $this.Invalidate()
                return $true
            }
        }
        
        return $false
    }
    
    [void] OnFocus() {
        $this.Invalidate()
    }
    
    [void] OnBlur() {
        $this.CloseDropdown()
        $this.Invalidate()
    }
    
    # Static factory methods
    static [ComboBox] CreateYesNo([string]$name) {
        $combo = [ComboBox]::new($name)
        $combo.SetItems(@("Yes", "No"))
        return $combo
    }
    
    static [ComboBox] CreateFromEnum([string]$name, [Type]$enumType) {
        $combo = [ComboBox]::new($name)
        $values = [Enum]::GetValues($enumType)
        $combo.SetItems($values)
        return $combo
    }
}