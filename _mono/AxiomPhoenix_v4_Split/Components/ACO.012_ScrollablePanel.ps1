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
    hidden [int]$_contentHeight = 0 # Total height of all content

    ScrollablePanel([string]$name) : base($name) {
        $this.IsFocusable = $true
    }

    # Override OnResize to recalculate scroll limits
    [void] OnResize([int]$newWidth, [int]$newHeight) {
        # Call base Panel resize, which updates Width, Height, and _private_buffer
        ([Panel]$this).Resize($newWidth, $newHeight) 
        
        $this.UpdateMaxScroll() # Recalculate max scroll on resize
        $this.RequestRedraw()
    }

    # Override _RenderContent to implement virtual scrolling logic
    hidden [void] _RenderContent() {
        # 1. First, render the base Panel. This clears its own _private_buffer and draws borders/title.
        ([Panel]$this)._RenderContent()

        # 2. Calculate content height and update scroll limits
        $actualContentBottom = 0
        foreach ($child in $this.Children) {
            if ($child.Visible) {
                $childBottom = ($child.Y - $this.ContentY) + $child.Height
                if ($childBottom -gt $actualContentBottom) {
                    $actualContentBottom = $childBottom
                }
            }
        }
        $this._contentHeight = $actualContentBottom
        $this.UpdateMaxScroll()

        # 3. Render visible children directly with viewport clipping
        $viewportTop = $this.ScrollOffsetY
        $viewportBottom = $this.ScrollOffsetY + $this.ContentHeight
        
        foreach ($child in $this.Children | Sort-Object ZIndex) {
            if (-not $child.Visible) { continue }
            
            # Calculate child position relative to content area
            $childRelY = $child.Y - $this.ContentY
            $childTop = $childRelY
            $childBottom = $childRelY + $child.Height
            
            # Skip if completely outside viewport
            if ($childBottom -lt $viewportTop -or $childTop -ge $viewportBottom) {
                continue
            }
            
            # Render child
            $child.Render()
            
            if ($null -ne $child._private_buffer) {
                # Calculate where to place the child in our buffer
                $destX = $child.X
                $destY = $this.ContentY + ($childRelY - $this.ScrollOffsetY)
                
                # Clip the child buffer if it extends beyond viewport
                $sourceY = 0
                $sourceHeight = $child.Height
                
                # Adjust if child is partially above viewport
                if ($childTop -lt $viewportTop) {
                    $clipTop = $viewportTop - $childTop
                    $sourceY = $clipTop
                    $sourceHeight -= $clipTop
                    $destY = $this.ContentY
                }
                
                # Adjust if child is partially below viewport
                if ($childBottom -gt $viewportBottom) {
                    $clipBottom = $childBottom - $viewportBottom
                    $sourceHeight -= $clipBottom
                }
                
                # Blend the visible portion
                if ($sourceHeight -gt 0) {
                    # Create a sub-buffer for the visible portion of the child
                    $visiblePortion = $child._private_buffer.GetSubBuffer(0, $sourceY, $child.Width, $sourceHeight)
                    $this._private_buffer.BlendBuffer($visiblePortion, $destX, $destY)
                }
            }
        }

        # 4. Draw scrollbar if needed
        if ($this.ShowScrollbar -and $this.MaxScrollY -gt 0) {
            $this.DrawScrollbar()
        }

        $this._needs_redraw = $false
    }

    # Helper method to calculate MaxScrollY and clamp ScrollOffsetY
    [void] UpdateMaxScroll() {
        $viewportHeight = $this.ContentHeight # Use ContentHeight as the available rendering area
        
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
