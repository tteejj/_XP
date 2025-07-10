# ==============================================================================
# Axiom-Phoenix v4.0 - All Components
# UI components that extend UIElement - full implementations from axiom
# ==============================================================================
#
# TABLE OF CONTENTS DIRECTIVE:
# When modifying this file, ensure page markers remain accurate and update
# TableOfContents.md to reflect any structural changes.
#
# Search for "PAGE: ACO.###" to find specific sections.
# Each section ends with "END_PAGE: ACO.###"
# ==============================================================================

using namespace System.Collections.Generic
using namespace System.Management.Automation

#

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
