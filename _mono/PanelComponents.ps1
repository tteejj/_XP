# ==============================================================================
# Axiom-Phoenix v4.0 - Panel, Layout, and Navigation Components
# Contains container components (Panel, ScrollablePanel, GroupPanel) and
# navigation components (NavigationMenu).
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#<!-- PAGE: ACO.011 - Panel Class -->
# ===== CLASS: Panel =====
# Module: panels-class
# Dependencies: UIElement, TuiCell
# Purpose: Container with layout management
class Panel : UIElement {
    [string]$Title = ""
    [string]$BorderStyle = "Single"
    [string]$BorderColor = "#808080"     # FIXED: Changed from ConsoleColor to hex string
    [string]$BackgroundColor = "#000000" # FIXED: Changed from ConsoleColor to hex string
    [bool]$HasBorder = $true
    [string]$LayoutType = "Manual"  # Manual, Vertical, Horizontal, Grid
    [int]$Padding = 0
    [int]$Spacing = 1
    
    # Content area properties
    [int]$ContentX = 1
    [int]$ContentY = 1
    [int]$ContentWidth = 0
    [int]$ContentHeight = 0

    Panel([string]$name) : base($name) {
        $this.IsFocusable = $false
        # Set reasonable defaults
        if ($this.Width -eq 0) { $this.Width = 30 }
        if ($this.Height -eq 0) { $this.Height = 10 }
        # Calculate initial content dimensions
        $this.UpdateContentDimensions()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor("component.background")
            $bgCell = [TuiCell]::new(' ', $bgColor, $bgColor)
            $this._private_buffer.Clear($bgCell)

            # Update content area dimensions
            $this.UpdateContentDimensions()

            if ($this.HasBorder) {
                if ($this.IsFocused) { 
                    $borderColorValue = Get-ThemeColor("Primary") 
                } else { 
                    $borderColorValue = Get-ThemeColor("component.border") 
                }
                
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = $this.BorderStyle; TitleFG = Get-ThemeColor("component.title") } `
                    -Title $this.Title
            }

            # Apply layout to children
            $this.ApplyLayout()
        }
        catch {}
    }

    [void] ApplyLayout() {
        if ($this.LayoutType -eq "Manual") { return }

        if ($this.HasBorder) { 
            $layoutX = 1 + $this.Padding 
        } else { 
            $layoutX = $this.Padding 
        }
        if ($this.HasBorder) { 
            $layoutY = 1 + $this.Padding 
        } else { 
            $layoutY = $this.Padding 
        }
        $layoutWidth = [Math]::Max(0, $this.Width - (2 * $layoutX))
        $layoutHeight = [Math]::Max(0, $this.Height - (2 * $layoutY))

        $visibleChildren = @($this.Children | Where-Object { $_.Visible })
        if ($visibleChildren.Count -eq 0) { return }

        switch ($this.LayoutType) {
            "Vertical" {
                $currentY = $layoutY
                foreach ($child in $visibleChildren) {
                    $child.X = $layoutX
                    $child.Y = $currentY
                    $child.Width = [Math]::Min($child.Width, $layoutWidth)
                    $currentY += $child.Height + $this.Spacing
                }
            }
            "Horizontal" {
                $currentX = $layoutX
                foreach ($child in $visibleChildren) {
                    $child.X = $currentX
                    $child.Y = $layoutY
                    $child.Height = [Math]::Min($child.Height, $layoutHeight)
                    $currentX += $child.Width + $this.Spacing
                }
            }
            "Grid" {
                # Simple grid layout - arrange in rows
                $cols = [Math]::Max(1, [Math]::Floor($layoutWidth / 20))  # Assume 20 char min width
                $col = 0
                $row = 0
                $cellWidth = [Math]::Max(1, [Math]::Floor($layoutWidth / $cols))
                $cellHeight = 3  # Default height
                
                foreach ($child in $visibleChildren) {
                    $child.X = $layoutX + ($col * $cellWidth)
                    $child.Y = $layoutY + ($row * ($cellHeight + $this.Spacing))
                    $child.Width = [Math]::Max(1, $cellWidth - $this.Spacing)
                    $child.Height = $cellHeight
                    
                    $col++
                    if ($col -ge $cols) {
                        $col = 0
                        $row++
                    }
                }
            }
        }
    }

    [hashtable] GetContentArea() {
        $area = @{
            X = if ($this.HasBorder) { 1 + $this.Padding } else { $this.Padding }
            Y = if ($this.HasBorder) { 1 + $this.Padding } else { $this.Padding }
        }
        $area.Width = [Math]::Max(0, $this.Width - (2 * $area.X))
        $area.Height = [Math]::Max(0, $this.Height - (2 * $area.Y))
        return $area
    }
    
    # New method to update content dimensions
    [void] UpdateContentDimensions() {
        $this.ContentX = if ($this.HasBorder) { 1 } else { 0 }
        $this.ContentY = if ($this.HasBorder) { 1 } else { 0 }
        $borderOffset = if ($this.HasBorder) { 2 } else { 0 }
        $this.ContentWidth = [Math]::Max(0, $this.Width - $borderOffset)
        $this.ContentHeight = [Math]::Max(0, $this.Height - $borderOffset)
    }
    
    # Override Resize to update content dimensions
    [void] OnResize() {
        $this.UpdateContentDimensions()
        ([UIElement]$this).OnResize()
    }
}

#<!-- END_PAGE: ACO.011 -->

#<!-- PAGE: ACO.012 - ScrollablePanel Class -->
# ===== CLASS: ScrollablePanel =====
# Module: panels-class
# Dependencies: Panel, TuiCell
# Purpose: Panel with scrolling capabilities
class ScrollablePanel : Panel {
    [int]$ScrollOffsetY = 0
    [int]$MaxScrollY = 0
    [bool]$ShowScrollbar = $true
    hidden [int]$_contentHeight = 0 # This will be the virtual content height
    hidden [TuiBuffer]$_virtual_buffer = $null # NEW: To hold the entire scrollable content

    ScrollablePanel([string]$name) : base($name) {
        $this.IsFocusable = $true
        # Initialize _virtual_buffer with initial dimensions. Will be resized later based on content.
        # Start with max possible height or a reasonable large value, will grow as children are added
        $this._virtual_buffer = [TuiBuffer]::new($this.Width, 1000, "$($this.Name).Virtual") 
    }

    # Override OnResize to ensure virtual buffer matches actual content area needs
    [void] OnResize([int]$newWidth, [int]$newHeight) {
        # Call base Panel resize, which updates Width, Height, and _private_buffer
        ([Panel]$this).Resize($newWidth, $newHeight) 

        # Ensure the virtual buffer is wide enough for the content area
        $targetVirtualWidth = $this.ContentWidth 
        if ($this._virtual_buffer.Width -ne $targetVirtualWidth) {
            $this._virtual_buffer.Resize($targetVirtualWidth, $this._virtual_buffer.Height) # Only resize width for now
        }
        $this.UpdateMaxScroll() # Recalculate max scroll on resize
        $this.RequestRedraw()
    }

    # Override _RenderContent to implement virtual scrolling logic
    hidden [void] _RenderContent() {
        # 1. First, render the base Panel. This clears its own _private_buffer and draws borders/title.
        # This implicitly calls ([Panel]$this).OnRender()
        ([Panel]$this)._RenderContent()

        # 2. Render all children onto the _virtual_buffer
        $this._virtual_buffer.Clear([TuiCell]::new(' ', $this.BackgroundColor, $this.BackgroundColor)) # Clear virtual buffer
        
        $actualContentBottom = 0
        foreach ($child in $this.Children | Sort-Object ZIndex) {
            if ($child.Visible) {
                # Render each child to its own private buffer
                $child.Render() 
                if ($null -ne $child._private_buffer) {
                    # Blend child's buffer onto our _virtual_buffer at its original coordinates
                    # (relative to the panel's content area)
                    $this._virtual_buffer.BlendBuffer($child._private_buffer, $child.X - $this.ContentX, $child.Y - $this.ContentY)
                }
                # Track the maximum vertical extent of children to determine virtual height
                $childExtent = ($child.Y - $this.ContentY) + $child.Height
                if ($childExtent -gt $actualContentBottom) {
                    $actualContentBottom = $childExtent
                }
            }
        }
        $this._contentHeight = $actualContentBottom # Update actual content height

        # 3. Update MaxScrollY and clamp ScrollOffsetY
        $this.UpdateMaxScroll()

        # 4. Extract the visible portion from _virtual_buffer and blend it onto _private_buffer
        #    This accounts for the scroll offset when drawing to screen.
        $viewportWidth = $this.ContentWidth
        $viewportHeight = $this.ContentHeight
        
        # Ensure target size for sub-buffer is positive
        $viewportWidth = [Math]::Max(1, $viewportWidth)
        $viewportHeight = [Math]::Max(1, $viewportHeight)

        $sourceX = 0 # No horizontal scrolling for now, but easily extendable
        $sourceY = $this.ScrollOffsetY
        
        # Get sub-buffer, ensure it's not trying to read beyond virtual buffer bounds
        $effectiveSourceHeight = [Math]::Min($viewportHeight, $this._virtual_buffer.Height - $sourceY)
        if ($effectiveSourceHeight -le 0) {
            # No content to display in viewport
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': No effective content for viewport."
            return
        }

        $visiblePortion = $this._virtual_buffer.GetSubBuffer($sourceX, $sourceY, $viewportWidth, $effectiveSourceHeight)
        
        # Blend the visible portion onto our own _private_buffer, at the content area
        $this._private_buffer.BlendBuffer($visiblePortion, $this.ContentX, $this.ContentY)

        # 5. Draw scrollbar if needed (uses _private_buffer and current ScrollOffsetY)
        if ($this.ShowScrollbar -and $this.MaxScrollY -gt 0) {
            $this.DrawScrollbar()
        }

        $this._needs_redraw = $false
    }

    # Helper method to calculate MaxScrollY and clamp ScrollOffsetY
    [void] UpdateMaxScroll() {
        $viewportHeight = $this.ContentHeight # Use ContentHeight as the available rendering area
        
        # Ensure virtual buffer height is at least content height
        $currentVirtualHeight = $this._virtual_buffer.Height
        $newVirtualHeight = [Math]::Max($currentVirtualHeight, $this._contentHeight)
        if ($newVirtualHeight -ne $currentVirtualHeight) {
            $this._virtual_buffer.Resize($this._virtual_buffer.Width, $newVirtualHeight)
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Resized virtual buffer height to $newVirtualHeight."
        }

        $this.MaxScrollY = [Math]::Max(0, $this._contentHeight - $viewportHeight)
        $this.ScrollOffsetY = [Math]::Max(0, [Math]::Min($this.ScrollOffsetY, $this.MaxScrollY))
        # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': ContentHeight=$($this._contentHeight), ViewportHeight=$($viewportHeight), MaxScrollY=$($this.MaxScrollY), ScrollOffsetY=$($this.ScrollOffsetY)."
    }

    # Keep DrawScrollbar, HandleInput, ScrollUp/Down/PageUp/Down/ToTop/Bottom methods.
    # Ensure DrawScrollbar uses the correct ScrollOffsetY, MaxScrollY, and _contentHeight for calculations.
    # Update SetCell calls in DrawScrollbar to use hex colors.
    [void] DrawScrollbar() {
        $scrollbarX = $this.Width - 1
        if ($this.HasBorder) { 
            $scrollbarY = 1 
        } else { 
            $scrollbarY = 0 
        }
        if ($this.HasBorder) { 
            $scrollbarTrackHeight = $this.Height - 2 
        } else { 
            $scrollbarTrackHeight = $this.Height - 0 
        }

        if ($this._contentHeight -le $scrollbarTrackHeight) { 
            # If content fits, clear any previous scrollbar
            $bgColor = Get-ThemeColor "Background"
            for ($i = 0; $i -lt $scrollbarTrackHeight; $i++) {
                $this._private_buffer.SetCell($scrollbarX, $scrollbarY + $i, [TuiCell]::new(' ', $bgColor, $bgColor))
            }
            return 
        } 

        $scrollFg = Get-ThemeColor "list.scrollbar"
        $scrollBg = Get-ThemeColor "Background"

        # Calculate thumb size and position
        $thumbSize = [Math]::Max(1, [int]($scrollbarTrackHeight * $scrollbarTrackHeight / $this._contentHeight))
        $thumbPos = [int](($scrollbarTrackHeight - $thumbSize) * $this.ScrollOffsetY / $this.MaxScrollY)
        
        for ($i = 0; $i -lt $scrollbarTrackHeight; $i++) {
            $y = $scrollbarY + $i
            $char = '│' # Default track character
            
            if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) {
                $char = '█' # Thumb character
            }
            $this._private_buffer.SetCell($scrollbarX, $y, [TuiCell]::new($char, $scrollFg, $scrollBg))
        }
    }

    # Ensure other scrolling methods call RequestRedraw and UpdateMaxScroll
    [void] ScrollUp([int]$lines = 1) {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $lines)
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled up to $($this.ScrollOffsetY)."
        }
    }

    [void] ScrollDown([int]$lines = 1) {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = [Math]::Min($this.MaxScrollY, $this.ScrollOffsetY + $lines)
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled down to $($this.ScrollOffsetY)."
        }
    }

    [void] ScrollPageUp() {
        $pageSize = $this.ContentHeight
        $this.ScrollUp($pageSize)
    }

    [void] ScrollPageDown() {
        $pageSize = $this.ContentHeight
        $this.ScrollDown($pageSize)
    }

    [void] ScrollToTop() {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = 0
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled to top."
        }
    }

    [void] ScrollToBottom() {
        $oldScroll = $this.ScrollOffsetY
        $this.ScrollOffsetY = $this.MaxScrollY
        if ($this.ScrollOffsetY -ne $oldScroll) {
            $this.RequestRedraw()
            # Write-Log -Level Debug -Message "ScrollablePanel '$($this.Name)': Scrolled to bottom."
        }
    }
}

#<!-- END_PAGE: ACO.012 -->

#<!-- PAGE: ACO.013 - GroupPanel Class -->
# ===== CLASS: GroupPanel =====
# Module: panels-class
# Dependencies: Panel
# Purpose: Themed panel for grouping
class GroupPanel : Panel {
    [bool]$IsExpanded = $true
    [bool]$CanCollapse = $true

    GroupPanel([string]$name) : base($name) {
        $this.BorderStyle = "Double"
        $this.BorderColor = "#008B8B"     # FIXED: DarkCyan in hex
        $this.BackgroundColor = "#000000" # FIXED: Black in hex
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Show children only if expanded
        foreach ($child in $this.Children) {
            $child.Visible = $this.IsExpanded
        }

        # Adjust height if collapsed
        if (-not $this.IsExpanded -and $this.CanCollapse) {
            $this._originalHeight = $this.Height
            $this.Height = 3  # Just title bar
        }
        elseif ($this.IsExpanded -and $this._originalHeight) {
            $this.Height = $this._originalHeight
        }

        # Add expand/collapse indicator to title
        if ($this.CanCollapse -and $this.Title) {
            $indicator = if ($this.IsExpanded) { "[-]" } else { "[+]" }
            $this.Title = "$indicator $($this.Title.TrimStart('[+]', '[-]').Trim())"
        }

        ([Panel]$this).OnRender()
    }

    hidden [int]$_originalHeight = 0

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.CanCollapse) { return $false }
        
        if ($key.Key -eq [ConsoleKey]::Spacebar) {
            $this.Toggle()
            return $true
        }
        
        return $false
    }

    [void] Toggle() {
        $this.IsExpanded = -not $this.IsExpanded
        $this.RequestRedraw()
    }
}

#<!-- END_PAGE: ACO.013 -->

#<!-- PAGE: ACO.021 - NavigationMenu Class -->
# ===== CLASS: NavigationMenu =====
# Module: navigation-class
# Dependencies: UIElement, NavigationItem
# Purpose: Local menu component
class NavigationMenu : UIElement {
    [List[NavigationItem]]$Items
    [int]$SelectedIndex = 0
    [string]$Orientation = "Horizontal"  # Horizontal or Vertical
    [string]$BackgroundColor = "#000000"
    [string]$ForegroundColor = "#FFFFFF"
    [string]$SelectedBackgroundColor = "#0078D4"
    [string]$SelectedForegroundColor = "#FFFF00"

    NavigationMenu([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[NavigationItem]]::new()
        $this.Height = 1
    }

    [void] AddItem([NavigationItem]$item) {
        $this.Items.Add($item)
        $this.RequestRedraw()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $this._private_buffer.Clear([TuiCell]::new(' ', $this.ForegroundColor, $this.BackgroundColor))
            
            if ($this.Orientation -eq "Horizontal") {
                $this.RenderHorizontal()
            }
            else {
                $this.RenderVertical()
            }
        }
        catch {}
    }

    hidden [void] RenderHorizontal() {
        $currentX = 0
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Draw item
            $text = " $($item.Label) "
            if ($item.Key) {
                $text = " $($item.Label) ($($item.Key)) "
            }
            
            if ($currentX + $text.Length -le $this.Width) {
                for ($x = 0; $x -lt $text.Length; $x++) {
                    $this._private_buffer.SetCell($currentX + $x, 0, 
                        [TuiCell]::new($text[$x], $fg, $bg))
                }
            }
            
            $currentX += $text.Length + 1
        }
    }

    hidden [void] RenderVertical() {
        # Ensure height matches item count
        if ($this.Height -ne $this.Items.Count -and $this.Items.Count -gt 0) {
            $this.Height = $this.Items.Count
            # Resize the buffer to match new height
            if ($this._private_buffer) {
                $this._private_buffer.Resize($this.Width, $this.Height)
            }
        }
        
        for ($i = 0; $i -lt $this.Items.Count; $i++) {
            $item = $this.Items[$i]
            $isSelected = ($i -eq $this.SelectedIndex -and $this.IsFocused)
            
            $fg = if ($isSelected) { $this.SelectedForegroundColor } else { $this.ForegroundColor }
            $bg = if ($isSelected) { $this.SelectedBackgroundColor } else { $this.BackgroundColor }
            
            # Clear line
            for ($x = 0; $x -lt $this.Width; $x++) {
                $this._private_buffer.SetCell($x, $i, [TuiCell]::new(' ', $fg, $bg))
            }
            
            # Draw item
            $text = $item.Label
            if ($item.Key) {
                $text = "$($item.Label) ($($item.Key))"
            }
            
            if ($text.Length -gt $this.Width) {
                $text = $text.Substring(0, $this.Width - 3) + "..."
            }
            
            $this._private_buffer.WriteString(0, $i, $text, @{ FG = $fg; BG = $bg })
        }
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $true
        
        if ($this.Orientation -eq "Horizontal") {
            switch ($key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                        $this.SelectedIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    # Check hotkeys
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        else {
            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($this.SelectedIndex -gt 0) {
                        $this.SelectedIndex--
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($this.SelectedIndex -lt $this.Items.Count - 1) {
                        $this.SelectedIndex++
                    }
                }
                ([ConsoleKey]::Enter) {
                    $this.ExecuteItem($this.SelectedIndex)
                }
                default {
                    $handled = $this.CheckHotkey($key)
                }
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
        }
        
        return $handled
    }

    hidden [bool] CheckHotkey([System.ConsoleKeyInfo]$key) {
        foreach ($i in 0..($this.Items.Count - 1)) {
            $item = $this.Items[$i]
            if ($item.Key -and $item.Key.ToUpper() -eq $key.KeyChar.ToString().ToUpper()) {
                $this.SelectedIndex = $i
                $this.ExecuteItem($i)
                return $true
            }
        }
        return $false
    }

    hidden [void] ExecuteItem([int]$index) {
        if ($index -ge 0 -and $index -lt $this.Items.Count) {
            $item = $this.Items[$index]
            if ($item.Action) {
                try {
                    & $item.Action
                }
                catch {}
            }
        }
    }
}

#<!-- END_PAGE: ACO.021 -->