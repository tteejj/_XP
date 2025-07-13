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

# ===== CLASS: ListBox =====
# Module: tui-components (wrapper)
# Dependencies: UIElement, TuiCell
# Purpose: Scrollable item list with selection
class ListBox : UIElement {
    [List[object]]$Items
    [int]$SelectedIndex = -1
    # FIXED: Removed ForegroundColor, BackgroundColor, BorderColor as they are inherited from UIElement
    [string]$SelectedForegroundColor = $null
    [string]$SelectedBackgroundColor = $null
    [string]$ItemForegroundColor = $null
    [bool]$HasBorder = $true
    [string]$BorderStyle = "Single"
    [string]$Title = ""
    [scriptblock]$SelectedIndexChanged = $null
    hidden [int]$ScrollOffset = 0

    ListBox([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.Items = [List[object]]::new()
        $this.Width = 30
        $this.Height = 10
    }

    [void] AddItem([object]$item) {
        $this.Items.Add($item)
        if ($this.SelectedIndex -eq -1 -and $this.Items.Count -eq 1) {
            $this.SelectedIndex = 0
        }
        $this.RequestRedraw()
    }

    [void] ClearItems() {
        $this.Items.Clear()
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        $this.RequestRedraw()
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # FIXED: Use effective colors from base class
        $bgColor = $this.GetEffectiveBackgroundColor()
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border if enabled
        if ($this.HasBorder) {
            # FIXED: Use effective border color from base class
            $borderColor = $this.GetEffectiveBorderColor()
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = $this.BorderStyle; Title = $this.Title }
        }
            
        # Calculate visible area
        $contentY = if ($this.HasBorder) { 1 } else { 0 }
        $contentHeight = if ($this.HasBorder) { $this.Height - 2 } else { $this.Height }
        $contentX = if ($this.HasBorder) { 1 } else { 0 }
        $contentWidth = if ($this.HasBorder) { $this.Width - 2 } else { $this.Width }
            
        # Ensure selected item is visible
        $this.EnsureVisible($this.SelectedIndex)
            
        # Draw items
        for ($i = 0; $i -lt $contentHeight -and ($i + $this.ScrollOffset) -lt $this.Items.Count; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            $item = $this.Items[$itemIndex]
            $itemText = if ($item -is [string]) { $item } else { $item.ToString() }
            
            if ($itemText.Length -gt $contentWidth) {
                $itemText = $itemText.Substring(0, [Math]::Max(0, $contentWidth - 3)) + "..."
            }
            
            $isSelected = ($itemIndex -eq $this.SelectedIndex)
            
            # Use theme colors with fallbacks
            if ($isSelected -and $this.IsFocused) { 
                # FIXED: Correctly check for $null properties
                $fgColor = if ($this.SelectedForegroundColor) { $this.SelectedForegroundColor } else { Get-ThemeColor "List.ItemSelected" "#ffffff" }
                $itemBgColor = if ($this.SelectedBackgroundColor) { $this.SelectedBackgroundColor } else { Get-ThemeColor "List.ItemSelectedBackground" "#007acc" }
            } else { 
                $fgColor = if ($this.ItemForegroundColor) { $this.ItemForegroundColor } else { Get-ThemeColor "List.ItemNormal" "#d4d4d4" }
                $itemBgColor = $bgColor
            }
            
            # Draw selection background only for the text area if selected and focused
            if ($isSelected -and $this.IsFocused) {
                for ($x = $contentX; $x -lt ($contentX + $contentWidth); $x++) {
                    $this._private_buffer.SetCell($x, $contentY + $i, [TuiCell]::new(' ', $fgColor, $itemBgColor))
                }
            }
            
            # Draw item text
            Write-TuiText -Buffer $this._private_buffer -X $contentX -Y ($contentY + $i) -Text $itemText `
                -Style @{ FG = $fgColor; BG = $itemBgColor }
        }
            
        # Draw scrollbar if needed
        if ($this.Items.Count -gt $contentHeight) {
            $scrollbarX = $this.Width - (if ($this.HasBorder) { 2 } else { 1 })
            $scrollbarHeight = $contentHeight
            $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
            $thumbPos = if ($this.Items.Count -gt $scrollbarHeight) {
                [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffset / ($this.Items.Count - $scrollbarHeight))
            } else { 0 }
            
            $scrollbarColor = Get-ThemeColor "list.scrollbar" "#666666"
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { '█' } else { '│' }
                $this._private_buffer.SetCell($scrollbarX, $contentY + $i, 
                    [TuiCell]::new($char, $scrollbarColor, $bgColor))
            }
        }
    }

    # FIXED: Add OnFocus and OnBlur for visual feedback
    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        $this.BorderColor = (Get-ThemeColor "Input.FocusedBorder" "#00d4ff")
        $this.RequestRedraw()
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        $this.BorderColor = (Get-ThemeColor "Panel.Border" "#666666")
        $this.RequestRedraw()
    }

    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or $this.Items.Count -eq 0) { return $false }
        
        $handled = $true
        $oldIndex = $this.SelectedIndex
        
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
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Items.Count - 1
            }
            ([ConsoleKey]::PageUp) {
                $pageSize = $this.Height - (if ($this.HasBorder) { 2 } else { 0 })
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - (if ($this.HasBorder) { 2 } else { 0 })
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            $this.RequestRedraw()
            
            # Trigger SelectedIndexChanged event if index changed
            if ($oldIndex -ne $this.SelectedIndex -and $this.SelectedIndexChanged) {
                # FIXED: Use robust .Invoke() method
                $this.SelectedIndexChanged.Invoke($this, $this.SelectedIndex)
            }
        }
        
        return $handled
    }

    [void] EnsureVisible([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Items.Count) { return }
        
        $visibleHeight = $this.Height - (if ($this.HasBorder) { 2 } else { 0 })
        if ($visibleHeight -le 0) { return }
        
        if ($index -lt $this.ScrollOffset) {
            $this.ScrollOffset = $index
        }
        elseif ($index -ge $this.ScrollOffset + $visibleHeight) {
            $this.ScrollOffset = $index - $visibleHeight + 1
        }
    }
}

#<!-- END_PAGE: ACO.014 -->