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
    [string]$ForegroundColor = "" # Will use theme default
    [string]$BackgroundColor = "" # Will use theme default
    [string]$SelectedForegroundColor = "" # Will use theme default
    [string]$SelectedBackgroundColor = "" # Will use theme default
    [string]$BorderColor = "" # Will use theme default
    [bool]$HasBorder = $true
    [string]$BorderStyle = "Single"
    [string]$Title = ""
    [scriptblock]$SelectedIndexChanged = $null
    [string]$ItemForegroundColor = "" # Will use theme default
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
        
        $bgColor = Get-ThemeColor "List.Background" "#1e1e1e"
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border if enabled
        if ($this.HasBorder) {
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
                -Style @{ BorderFG = Get-ThemeColor "Panel.Border" "#404040"; BG = $bgColor; BorderStyle = $this.BorderStyle; Title = $this.Title }
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
                if ($item -is [string]) { 
                    $itemText = $item 
                } else { 
                    $itemText = $item.ToString() 
                }
                
                if ($itemText.Length -gt $contentWidth) {
                    $itemText = $itemText.Substring(0, $contentWidth - 3) + "..."
                }
                
                $isSelected = ($itemIndex -eq $this.SelectedIndex)
                
                # Use theme colors with fallbacks
                if ($isSelected) { 
                    $fgColor = if ($this.SelectedForegroundColor) { $this.SelectedForegroundColor } else { Get-ThemeColor "List.ItemSelected" "#ffffff" }
                    $itemBgColor = if ($this.SelectedBackgroundColor) { $this.SelectedBackgroundColor } else { Get-ThemeColor "List.ItemSelectedBackground" "#007acc" }
                } else { 
                    $fgColor = if ($this.ItemForegroundColor) { $this.ItemForegroundColor } else { Get-ThemeColor "List.ItemNormal" "#d4d4d4" }
                    $itemBgColor = $bgColor
                }
                
                # Draw item with proper padding to ensure text is visible
                if ($isSelected) {
                    # Draw selection background only for the text area
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
                $scrollbarX = $this.Width - 2
                $scrollbarHeight = $contentHeight
                $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
                $thumbPos = if ($this.Items.Count -gt $scrollbarHeight) {
                    [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffset / ($this.Items.Count - $scrollbarHeight))
                } else { 0 }
                
                $scrollbarColor = Get-ThemeColor "list.scrollbar"
                for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                    $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { '█' } else { '│' }
                    $this._private_buffer.SetCell($scrollbarX, $contentY + $i, 
                        [TuiCell]::new($char, $scrollbarColor, $bgColor))
                }
            }
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
                $pageSize = $this.Height - 2
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 2
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
                & $this.SelectedIndexChanged $this $this.SelectedIndex
            }
        }
        
        return $handled
    }

    [void] EnsureVisible([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Items.Count) { return }
        
        $visibleHeight = $this.Height - 2
        
        if ($index -lt $this.ScrollOffset) {
            $this.ScrollOffset = $index
        }
        elseif ($index -ge $this.ScrollOffset + $visibleHeight) {
            $this.ScrollOffset = $index - $visibleHeight + 1
        }
    }
}

#<!-- END_PAGE: ACO.014 -->
