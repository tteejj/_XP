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

    Panel([string]$name) : base($name) {
        $this.IsFocusable = $false
        # Set reasonable defaults if not provided by base constructor
        if ($this.Width -eq 0) { $this.Width = 30 }
        if ($this.Height -eq 0) { $this.Height = 10 }
        # Calculate initial content dimensions based on default size
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
                $borderColorValue = if ($this.IsFocused) { 
                    Get-ThemeColor "Panel.Title" "#007acc"
                } else { 
                    $this.GetEffectiveBorderColor()
                }
                
                # Draw the panel border and title
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = $this.BorderStyle; TitleFG = (Get-ThemeColor "Panel.Title" "#007acc") } `
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

        # The content area properties already account for border and padding
        $layoutX = $this.ContentX
        $layoutY = $this.ContentY
        $layoutWidth = $this.ContentWidth
        $layoutHeight = $this.ContentHeight

        $visibleChildren = @($this.Children | Where-Object { $_.Visible })
        if ($visibleChildren.Count -eq 0) { return }

        switch ($this.LayoutType) {
            "Vertical" {
                $currentY = $layoutY
                foreach ($child in $visibleChildren) {
                    # Use Move and Resize methods to trigger child's lifecycle hooks
                    $child.Move($layoutX, $currentY)
                    $child.Resize([Math]::Min($child.Width, $layoutWidth), $child.Height) # Cap child width to layout area
                    $currentY += $child.Height + $this.Spacing
                }
            }
            "Horizontal" {
                $currentX = $layoutX
                foreach ($child in $visibleChildren) {
                    # Use Move and Resize methods to trigger child's lifecycle hooks
                    $child.Move($currentX, $layoutY)
                    $child.Resize($child.Width, [Math]::Min($child.Height, $layoutHeight)) # Cap child height to layout area
                    $currentX += $child.Width + $this.Spacing
                }
            }
            "Grid" {
                # Simple grid layout - arrange in rows
                $cols = [Math]::Max(1, [Math]::Floor($layoutWidth / 20))  # Assume 20 char min width per cell
                $col = 0
                $row = 0
                $cellWidth = [Math]::Max(1, [Math]::Floor($layoutWidth / $cols))
                $cellHeight = 3  # Default height for grid cells
                
                foreach ($child in $visibleChildren) {
                    # Use Move and Resize methods to trigger child's lifecycle hooks
                    $child.Move($layoutX + ($col * $cellWidth), $layoutY + ($row * ($cellHeight + $this.Spacing)))
                    $child.Resize([Math]::Max(1, $cellWidth - $this.Spacing), $cellHeight)
                    
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
        $borderSize = if ($this.HasBorder) { 1 } else { 0 }
        
        # Content area starts after border and padding
        $this.ContentX = $borderSize + $this.Padding
        $this.ContentY = $borderSize + $this.Padding
        
        # Calculate space used by borders and padding on both sides
        $horizontalUsed = (2 * $borderSize) + (2 * $this.Padding)
        $verticalUsed = (2 * $borderSize) + (2 * $this.Padding)
        
        # Content width/height is total width/height minus space used by borders and padding
        $this.ContentWidth = [Math]::Max(0, $this.Width - $horizontalUsed)
        $this.ContentHeight = [Math]::Max(0, $this.Height - $verticalUsed)
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