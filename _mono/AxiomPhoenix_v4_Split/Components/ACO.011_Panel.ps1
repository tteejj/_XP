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
            $bgColor = Get-ThemeColor "Panel.Background" "#1e1e1e"
            $bgCell = [TuiCell]::new(' ', $bgColor, $bgColor)
            $this._private_buffer.Clear($bgCell)

            # Update content area dimensions
            $this.UpdateContentDimensions()

            if ($this.HasBorder) {
                if ($this.IsFocused) { 
                    $borderColorValue = Get-ThemeColor "Panel.Title" "#007acc"
                } else { 
                    $borderColorValue = Get-ThemeColor "Panel.Border" "#404040"
                }
                
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColorValue; BG = $bgColor; BorderStyle = $this.BorderStyle; TitleFG = Get-ThemeColor "Panel.Title" "#007acc" } `
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
