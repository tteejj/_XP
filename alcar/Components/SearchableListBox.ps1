# SearchableListBox - PTUI Pattern: Type-ahead search with live filtering
# Extends ListBox with real-time search capabilities while maintaining performance

class SearchableListBox : ListBox {
    [string]$SearchTerm = ""
    [System.Collections.ArrayList]$OriginalItems
    [System.Collections.ArrayList]$FilteredItems
    [bool]$ShowSearchBox = $true
    [string]$SearchPrompt = "Search: "
    [int]$SearchTimeout = 1000  # ms to clear search after no input
    [datetime]$LastSearchTime = [datetime]::MinValue
    
    SearchableListBox([string]$name) : base($name) {
        $this.OriginalItems = [System.Collections.ArrayList]::new()
        $this.FilteredItems = [System.Collections.ArrayList]::new()
    }
    
    # Override SetItems to maintain original list
    [void] SetItems([array]$items) {
        $this.OriginalItems.Clear()
        $this.OriginalItems.AddRange($items)
        $this.SearchTerm = ""
        $this.UpdateFilter()
    }
    
    # PTUI Pattern: Live filtering as user types
    [void] UpdateSearch([string]$term) {
        $this.SearchTerm = $term.ToLower()
        $this.LastSearchTime = [datetime]::Now
        $this.UpdateFilter()
        $this.SelectedIndex = 0  # Reset to first match
        $this.ScrollOffset = 0
        $this.Invalidate()
    }
    
    # Filter items based on search term
    [void] UpdateFilter() {
        $this.FilteredItems.Clear()
        
        if ([string]::IsNullOrWhiteSpace($this.SearchTerm)) {
            # No search term - show all items
            $this.FilteredItems.AddRange($this.OriginalItems)
        } else {
            # Filter items that contain search term
            foreach ($item in $this.OriginalItems) {
                $itemText = $this.FormatItem($item).ToLower()
                if ($itemText.Contains($this.SearchTerm)) {
                    $this.FilteredItems.Add($item) | Out-Null
                }
            }
        }
        
        # Update the base ListBox items
        $this.Items.Clear()
        $this.Items.AddRange($this.FilteredItems)
        
        # Adjust selection
        if ($this.Items.Count -eq 0) {
            $this.SelectedIndex = -1
        } elseif ($this.SelectedIndex -ge $this.Items.Count) {
            $this.SelectedIndex = $this.Items.Count - 1
        }
    }
    
    # Clear search after timeout
    [void] CheckSearchTimeout() {
        if ($this.SearchTerm -and 
            ([datetime]::Now - $this.LastSearchTime).TotalMilliseconds -gt $this.SearchTimeout) {
            $this.SearchTerm = ""
            $this.UpdateFilter()
            $this.Invalidate()
        }
    }
    
    # Format item for display and search
    [string] FormatItem([object]$item) {
        if ($this.ItemFormatter) {
            return & $this.ItemFormatter $item
        }
        return $item.ToString()
    }
    
    # Enhanced rendering with search box
    [string] Render() {
        $this.CheckSearchTimeout()
        
        $output = ""
        $contentHeight = $this.Height
        
        # Show search box if enabled
        if ($this.ShowSearchBox) {
            $searchDisplay = $this.SearchPrompt + $this.SearchTerm
            if ($this.SearchTerm) {
                $searchDisplay += " (" + $this.Items.Count + " matches)"
            }
            
            # Search box with highlight
            $output += [VT]::MoveTo($this.X, $this.Y)
            $output += [VT]::Warning() + $searchDisplay + [VT]::Reset()
            $output += [VT]::ClearLine() + "`n"
            
            $contentHeight--  # Reduce content area for search box
        }
        
        # Render list items
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
        
        # Render visible items
        for ($i = 0; $i -lt $this._visibleItems; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            $y = $startY + $i
            
            $output += [VT]::MoveTo($this.X + 1, $y)
            
            if ($itemIndex -lt $this.Items.Count) {
                $item = $this.Items[$itemIndex]
                $itemText = $this.FormatItem($item)
                
                # Highlight selected item
                if ($itemIndex -eq $this.SelectedIndex) {
                    $output += [VT]::Selected() + $this.HighlightSearchTerm($itemText) + [VT]::Reset()
                } else {
                    $output += [VT]::Text() + $this.HighlightSearchTerm($itemText) + [VT]::Reset()
                }
            }
            
            $output += [VT]::ClearLine()
        }
        
        return $output
    }
    
    # PTUI Pattern: Highlight search terms in results
    [string] HighlightSearchTerm([string]$text) {
        if ([string]::IsNullOrWhiteSpace($this.SearchTerm)) {
            return $text
        }
        
        # Simple highlighting - replace search term with highlighted version
        $highlightedTerm = [VT]::Warning() + $this.SearchTerm + [VT]::Reset() + [VT]::Text()
        return $text -ireplace [regex]::Escape($this.SearchTerm), $highlightedTerm
    }
    
    # Handle typing for search
    [bool] HandleKey([ConsoleKeyInfo]$key) {
        # Check for printable characters (a-z, 0-9, space, etc.)
        if ($key.Key -ge [ConsoleKey]::A -and $key.Key -le [ConsoleKey]::Z) {
            $char = $key.KeyChar.ToString().ToLower()
            $this.UpdateSearch($this.SearchTerm + $char)
            return $true
        }
        
        if ($key.Key -ge [ConsoleKey]::D0 -and $key.Key -le [ConsoleKey]::D9) {
            $this.UpdateSearch($this.SearchTerm + $key.KeyChar)
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.UpdateSearch($this.SearchTerm + " ")
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Backspace -and $this.SearchTerm.Length -gt 0) {
            $newTerm = $this.SearchTerm.Substring(0, $this.SearchTerm.Length - 1)
            $this.UpdateSearch($newTerm)
            return $true
        }
        
        if ($key.Key -eq [ConsoleKey]::Escape -and $this.SearchTerm) {
            $this.UpdateSearch("")
            return $true
        }
        
        # Let base class handle navigation keys
        return $false
    }
    
    # Adjust scroll to keep selected item visible
    [void] AdjustScrollOffset() {
        if ($this.SelectedIndex -lt $this.ScrollOffset) {
            $this.ScrollOffset = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffset + $this._visibleItems) {
            $this.ScrollOffset = $this.SelectedIndex - $this._visibleItems + 1
        }
        
        # Ensure scroll offset is valid
        $maxScroll = [Math]::Max(0, $this.Items.Count - $this._visibleItems)
        if ($this.ScrollOffset -gt $maxScroll) {
            $this.ScrollOffset = $maxScroll
        }
        if ($this.ScrollOffset -lt 0) {
            $this.ScrollOffset = 0
        }
    }
    
    # Render border with visual indication of search mode
    [string] RenderBorder() {
        $output = ""
        $borderColor = if ($this.SearchTerm) { [VT]::Warning() } else { [VT]::Border() }
        
        # Top border
        $searchAdjustment = if ($this.ShowSearchBox) { 1 } else { 0 }
        $output += [VT]::MoveTo($this.X, $this.Y + $searchAdjustment)
        $output += $borderColor + [VT]::TL() + ([VT]::H() * ($this.Width - 2)) + [VT]::TR() + [VT]::Reset()
        
        # Side borders
        for ($i = 1; $i -lt $this.Height - 1; $i++) {
            $y = $this.Y + $i + $searchAdjustment
            $output += [VT]::MoveTo($this.X, $y) + $borderColor + [VT]::V() + [VT]::Reset()
            $output += [VT]::MoveTo($this.X + $this.Width - 1, $y) + $borderColor + [VT]::V() + [VT]::Reset()
        }
        
        # Bottom border  
        $output += [VT]::MoveTo($this.X, $this.Y + $this.Height - 1 + $searchAdjustment)
        $output += $borderColor + [VT]::BL() + ([VT]::H() * ($this.Width - 2)) + [VT]::BR() + [VT]::Reset()
        
        return $output
    }
}