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

# ===== CLASS: Panel =====
# Module: panels-class
# Dependencies: UIElement, TuiCell
# Purpose: Container with layout management
class Panel : UIElement {
    [string]$Title = ""
    [string]$BorderStyle = "Single"
    # FIXED: Removed explicit BorderColor and BackgroundColor properties.
    # They are now correctly inherited from UIElement, allowing for proper theme fallback.
    [bool]$HasBorder = $true
    [string]$LayoutType = "Manual"  # Manual, Vertical, Horizontal, Grid
    [int]$Padding = 0
    [int]$Spacing = 1
    
    # Content area properties - these define the inner drawable area for children
    [int]$ContentX = 0
    [int]$ContentY = 0
    [int]$ContentWidth = 0
    [int]$ContentHeight = 0
    
    # Layout caching properties (optimized)
    hidden [bool]$_layoutCacheValid = $false
    hidden [object[]]$_cachedChildren = @()
    hidden [hashtable]$_layoutPositions = @{}
    hidden [int]$_lastLayoutChildCount = 0
    hidden [string]$_lastLayoutType = ""
    hidden [int]$_lastContentWidth = 0
    hidden [int]$_lastContentHeight = 0

    Panel([string]$name) : base($name) {
        $this.IsFocusable = $false
        # Set reasonable defaults if not provided by base constructor
        if ($this.Width -eq 0) { $this.Width = 30 }
        if ($this.Height -eq 0) { $this.Height = 10 }
        # Calculate initial content dimensions based on default size
        $this.UpdateContentDimensions()
    }
    
    hidden [void] InvalidateLayoutCache() {
        $this._layoutCacheValid = $false
        $this._cachedChildren = @()
        $this._layoutPositions = @{}
    }
    
    [void] AddChild([UIElement]$child) {
        # Call parent implementation
        ([UIElement]$this).AddChild($child)
        # Invalidate layout cache when children change
        $this.InvalidateLayoutCache()
    }
    
    [void] RemoveChild([UIElement]$child) {
        # Call parent implementation
        ([UIElement]$this).RemoveChild($child)
        # Invalidate layout cache when children change
        $this.InvalidateLayoutCache()
    }
    
    [void] Resize([int]$width, [int]$height) {
        # Call parent implementation
        ([UIElement]$this).Resize($width, $height)
        # Invalidate layout cache when size changes
        $this.InvalidateLayoutCache()
        # Update content dimensions
        $this.UpdateContentDimensions()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            # FIXED: Get theme-aware background color using the effective method from the base class.
            $bgColor = $this.GetEffectiveBackgroundColor()
            $bgCell = [TuiCell]::new(' ', $bgColor, $bgColor)
            $this._private_buffer.Clear($bgCell)

            # Update content area dimensions (important before drawing border or children)
            $this.UpdateContentDimensions()

            if ($this.HasBorder) {
                # FIXED: Determine border color based on focus state and effective properties.
                $borderColorValue = $this.GetEffectiveBorderColor()
                if ($this.IsFocused) {
                    $borderColorValue = Get-ThemeColor "panel.border.focused"
                }
                
                # Draw the panel border and title
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = $this.BorderStyle; TitleFG = (Get-ThemeColor "panel.title") } `
                    -Title $this.Title
            }

            # Apply layout to children
            $this.ApplyLayout()
        }
        catch {
            # Log or handle rendering errors gracefully
            if(Get-Command 'Write-Log' -ErrorAction SilentlyContinue) {
                Write-Log -Level Error -Message "Error rendering Panel '$($this.Name)': $($_.Exception.Message)"
            }
        }
    }

    [void] ApplyLayout() {
        if ($this.LayoutType -eq "Manual") { return }
        
        # Get visible children
        $visibleChildren = @($this.Children.Where({ $_.Visible }))
        if ($visibleChildren.Count -eq 0) { return }
        
        # Check if we can use cached layout (optimized cache validation)
        if ($this._layoutCacheValid -and 
            $this._lastLayoutChildCount -eq $visibleChildren.Count -and
            $this._lastLayoutType -eq $this.LayoutType -and
            $this._lastContentWidth -eq $this.ContentWidth -and
            $this._lastContentHeight -eq $this.ContentHeight -and
            $this._cachedChildren.Count -eq $visibleChildren.Count) {
            
            # Quick validation - check if children are the same (by reference)
            $cacheValid = $true
            for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
                if ($this._cachedChildren[$i] -ne $visibleChildren[$i]) {
                    $cacheValid = $false
                    break
                }
            }
            
            if ($cacheValid) {
                # Apply cached layout positions directly (no method calls)
                for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
                    $child = $visibleChildren[$i]
                    $pos = $this._layoutPositions[$i]
                    if ($pos) {
                        $child.X = $pos.X
                        $child.Y = $pos.Y
                        $child.Width = $pos.Width
                        $child.Height = $pos.Height
                    }
                }
                return
            }
        }
        
        # Calculate new layout
        $layoutX = $this.ContentX
        $layoutY = $this.ContentY
        $layoutWidth = $this.ContentWidth
        $layoutHeight = $this.ContentHeight
        
        # Clear cache and prepare for new calculations
        $this._layoutPositions = @{}
        $this._cachedChildren = @()

        switch ($this.LayoutType) {
            "Vertical" {
                $currentY = $layoutY
                for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
                    $child = $visibleChildren[$i]
                    
                    # Calculate position and size
                    $childX = $layoutX
                    $childY = $currentY
                    $childWidth = [Math]::Min($child.Width, $layoutWidth)
                    $childHeight = $child.Height
                    
                    # Apply layout directly (avoid method call overhead)
                    $child.X = $childX
                    $child.Y = $childY
                    $child.Width = $childWidth
                    $child.Height = $childHeight
                    
                    # Cache the layout position by index (faster than hashtable lookup)
                    $this._layoutPositions[$i] = @{
                        X = $childX
                        Y = $childY
                        Width = $childWidth
                        Height = $childHeight
                    }
                    $this._cachedChildren += $child
                    
                    $currentY += $childHeight + $this.Spacing
                }
            }
            "Horizontal" {
                $currentX = $layoutX
                for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
                    $child = $visibleChildren[$i]
                    
                    # Calculate position and size
                    $childX = $currentX
                    $childY = $layoutY
                    $childWidth = $child.Width
                    $childHeight = [Math]::Min($child.Height, $layoutHeight)
                    
                    # Apply layout directly (avoid method call overhead)
                    $child.X = $childX
                    $child.Y = $childY
                    $child.Width = $childWidth
                    $child.Height = $childHeight
                    
                    # Cache the layout position by index (faster than hashtable lookup)
                    $this._layoutPositions[$i] = @{
                        X = $childX
                        Y = $childY
                        Width = $childWidth
                        Height = $childHeight
                    }
                    $this._cachedChildren += $child
                    
                    $currentX += $childWidth + $this.Spacing
                }
            }
            "Grid" {
                # Simple grid layout - arrange in rows
                $cols = [Math]::Max(1, [Math]::Floor($layoutWidth / 20))  # Assume 20 char min width per cell
                $col = 0
                $row = 0
                $cellWidth = [Math]::Max(1, [Math]::Floor($layoutWidth / $cols))
                $cellHeight = 3  # Default height for grid cells
                
                for ($i = 0; $i -lt $visibleChildren.Count; $i++) {
                    $child = $visibleChildren[$i]
                    
                    # Calculate position and size
                    $childX = $layoutX + ($col * $cellWidth)
                    $childY = $layoutY + ($row * ($cellHeight + $this.Spacing))
                    $childWidth = [Math]::Max(1, $cellWidth - $this.Spacing)
                    $childHeight = $cellHeight
                    
                    # Apply layout directly (avoid method call overhead)
                    $child.X = $childX
                    $child.Y = $childY
                    $child.Width = $childWidth
                    $child.Height = $childHeight
                    
                    # Cache the layout position by index
                    $this._layoutPositions[$i] = @{
                        X = $childX
                        Y = $childY
                        Width = $childWidth
                        Height = $childHeight
                    }
                    $this._cachedChildren += $child
                    
                    $col++
                    if ($col -ge $cols) {
                        $col = 0
                        $row++
                    }
                }
            }
        }
        
        # Mark cache as valid and store current state
        $this._layoutCacheValid = $true
        $this._lastLayoutChildCount = $visibleChildren.Count
        $this._lastLayoutType = $this.LayoutType
        $this._lastContentWidth = $this.ContentWidth
        $this._lastContentHeight = $this.ContentHeight
    }

    [hashtable] GetContentArea() {
        # This method returns the current calculated content area properties
        return @{
            X = $this.ContentX
            Y = $this.ContentY
            Width = $this.ContentWidth
            Height = $this.ContentHeight
        }
    }
    
    # Method to update content dimensions based on border and padding
    [void] UpdateContentDimensions() {
        $borderSize = 0
        if ($this.HasBorder) { $borderSize = 1 }
        
        # FIXED: Account for title height in content dimensions
        $titleHeight = 0
        if ($this.HasBorder -and -not [string]::IsNullOrEmpty($this.Title)) {
            $titleHeight = 0  # Title is integrated in border, no extra space needed
        }
        
        # Store old dimensions for comparison
        $oldContentWidth = $this.ContentWidth
        $oldContentHeight = $this.ContentHeight
        
        # Content area starts after border and padding
        $this.ContentX = $borderSize + $this.Padding
        $this.ContentY = $borderSize + $this.Padding + $titleHeight
        
        # Calculate space used by borders, padding, and title on both sides
        $horizontalUsed = (2 * $borderSize) + (2 * $this.Padding)
        $verticalUsed = (2 * $borderSize) + (2 * $this.Padding) + $titleHeight
        
        # Content width/height is total width/height minus space used by borders, padding, and title
        $this.ContentWidth = [Math]::Max(0, $this.Width - $horizontalUsed)
        $this.ContentHeight = [Math]::Max(0, $this.Height - $verticalUsed)
        
        # Invalidate layout cache if content dimensions changed
        if ($oldContentWidth -ne $this.ContentWidth -or $oldContentHeight -ne $this.ContentHeight) {
            $this.InvalidateLayoutCache()
        }
    }
    
    # Override Resize to update content dimensions after base class handles size change
    [void] OnResize([int]$newWidth, [int]$newHeight) { # Added parameters to match base OnResize
        # Call base class OnResize first to update Width/Height properties and buffer
        ([UIElement]$this).OnResize($newWidth, $newHeight)
        
        # Then update content dimensions based on the new panel size
        $this.UpdateContentDimensions()
    }
}

#<!-- END_PAGE: ACO.011 -->