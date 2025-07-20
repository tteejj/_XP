# MultiSelectListBox - PTUI Pattern: Multi-select with spacebar toggle
# Extends SearchableListBox with multiple selection capabilities

class MultiSelectListBox : SearchableListBox {
    [hashtable]$SelectedIndices = @{}
    [string]$SelectionIndicator = "✓ "
    [string]$UnselectedIndicator = "  "
    [bool]$AllowMultiSelect = $true
    
    MultiSelectListBox([string]$name) : base($name) {
        # Multi-select specific initialization
    }
    
    # Toggle selection of current item
    [void] ToggleSelection() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Items.Count) {
            if ($this.SelectedIndices.ContainsKey($this.SelectedIndex)) {
                $this.SelectedIndices.Remove($this.SelectedIndex)
            } else {
                $this.SelectedIndices[$this.SelectedIndex] = $true
            }
            $this.Invalidate()
        }
    }
    
    # Select all filtered items
    [void] SelectAll() {
        if ($this.AllowMultiSelect) {
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $this.SelectedIndices[$i] = $true
            }
            $this.Invalidate()
        }
    }
    
    # Clear all selections
    [void] ClearSelection() {
        $this.SelectedIndices.Clear()
        $this.Invalidate()
    }
    
    # Get all selected items
    [array] GetSelectedItems() {
        $selectedItems = @()
        foreach ($index in $this.SelectedIndices.Keys) {
            if ($index -lt $this.Items.Count) {
                $selectedItems += $this.Items[$index]
            }
        }
        return $selectedItems
    }
    
    # Check if item at index is selected
    [bool] IsSelected([int]$index) {
        return $this.SelectedIndices.ContainsKey($index)
    }
    
    # Override UpdateFilter to maintain selections
    [void] UpdateFilter() {
        # Store currently selected items
        $selectedItems = $this.GetSelectedItems()
        
        # Clear current selections
        $this.SelectedIndices.Clear()
        
        # Call base filter
        ([SearchableListBox]$this).UpdateFilter()
        
        # Restore selections for items that are still visible
        if ($selectedItems.Count -gt 0) {
            for ($i = 0; $i -lt $this.Items.Count; $i++) {
                $item = $this.Items[$i]
                foreach ($selectedItem in $selectedItems) {
                    if ($item -eq $selectedItem) {
                        $this.SelectedIndices[$i] = $true
                        break
                    }
                }
            }
        }
    }
    
    # Enhanced rendering with selection indicators
    [string] Render() {
        $this.CheckSearchTimeout()
        
        $output = ""
        $contentHeight = $this.Height
        
        # Show search box with selection count
        if ($this.ShowSearchBox) {
            $selectedCount = $this.SelectedIndices.Count
            $searchDisplay = $this.SearchPrompt + $this.SearchTerm
            if ($this.SearchTerm) {
                $searchDisplay += " (" + $this.Items.Count + " matches"
                if ($selectedCount -gt 0) {
                    $searchDisplay += ", " + $selectedCount + " selected"
                }
                $searchDisplay += ")"
            } elseif ($selectedCount -gt 0) {
                $searchDisplay += " (" + $selectedCount + " selected)"
            }
            
            # Search box with highlight
            $output += [VT]::MoveTo($this.X, $this.Y)
            $output += [VT]::Warning() + $searchDisplay + [VT]::Reset()
            $output += [VT]::ClearLine() + "`n"
            
            $contentHeight--  # Reduce content area for search box
        }
        
        # Render list items with selection indicators
        $borderAdjustment = if ($this.HasBorder) { 2 } else { 0 }
        $this._visibleItems = $contentHeight - $borderAdjustment
        
        if ($this.HasBorder) {
            $output += $this.RenderBorder()
            $searchAdjustment = if ($this.ShowSearchBox) { 2 } else { 1 }
            $startY = $this.Y + $searchAdjustment
        } else {
            $searchAdjustment = if ($this.ShowSearchBox) { 1 } else { 0 }
            $startY = $this.Y + $searchAdjustment
        }
        
        # Ensure selected item is visible
        $this.AdjustScrollOffset()
        
        # Render visible items with selection indicators
        for ($i = 0; $i -lt $this._visibleItems; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            $y = $startY + $i
            
            $output += [VT]::MoveTo($this.X + 1, $y)
            
            if ($itemIndex -lt $this.Items.Count) {
                $item = $this.Items[$itemIndex]
                $itemText = $this.FormatItem($item)
                
                # Selection indicator
                $indicator = if ($this.IsSelected($itemIndex)) { 
                    [VT]::Accent() + $this.SelectionIndicator + [VT]::Reset()
                } else { 
                    $this.UnselectedIndicator 
                }
                
                # Highlight current item
                if ($itemIndex -eq $this.SelectedIndex) {
                    $output += [VT]::Selected() + $indicator + $this.HighlightSearchTerm($itemText) + [VT]::Reset()
                } else {
                    $output += $indicator + [VT]::Text() + $this.HighlightSearchTerm($itemText) + [VT]::Reset()
                }
            }
            
            $output += [VT]::ClearLine()
        }
        
        return $output
    }
    
    # Navigation methods for compatibility with screens
    [void] NavigateDown() {
        if ($this.SelectedIndex -lt $this.Items.Count - 1) {
            $this.SelectedIndex++
            $this.AdjustScrollOffset()
            $this.Invalidate()
        }
    }
    
    [void] NavigateUp() {
        if ($this.SelectedIndex -gt 0) {
            $this.SelectedIndex--
            $this.AdjustScrollOffset()
            $this.Invalidate()
        }
    }
    
    # Enhanced key handling for multi-select
    [bool] HandleKey([ConsoleKeyInfo]$key) {
        # PTUI Pattern: Spacebar toggles selection
        if ($key.Key -eq [ConsoleKey]::Spacebar -and $this.AllowMultiSelect) {
            $this.ToggleSelection()
            return $true
        }
        
        # Ctrl+A selects all
        if ($key.Key -eq [ConsoleKey]::A -and $key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
            $this.SelectAll()
            return $true
        }
        
        # Ctrl+D clears selection
        if ($key.Key -eq [ConsoleKey]::D -and $key.Modifiers.HasFlag([ConsoleModifiers]::Control)) {
            $this.ClearSelection()
            return $true
        }
        
        # Let base class handle search and navigation
        return ([SearchableListBox]$this).HandleKey($key)
    }
}