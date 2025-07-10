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
    [string]$ForegroundColor = "#FFFFFF" # Changed from ConsoleColor to hex string
    [string]$BackgroundColor = "#000000" # Changed from ConsoleColor to hex string
    [string]$SelectedForegroundColor = "#000000" # Changed from ConsoleColor to hex string
    [string]$SelectedBackgroundColor = "#00FFFF" # Changed from ConsoleColor to hex string
    [string]$BorderColor = "#808080" # Changed from ConsoleColor to hex string
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
        
        $bgColor = Get-ThemeColor("component.background")
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border
        Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height `
            -Style @{ BorderFG = Get-ThemeColor("component.border"); BG = $bgColor; BorderStyle = "Single" }
            
            # Calculate visible area
            $contentY = 1
            $contentHeight = $this.Height - 2
            $contentX = 1
            $contentWidth = $this.Width - 2
            
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
                if ($isSelected) { 
                    $fgColor = Get-ThemeColor("list.item.selected") 
                } else { 
                    $fgColor = Get-ThemeColor("list.item.normal") 
                }
                if ($isSelected) { 
                    $itemBgColor = Get-ThemeColor("list.item.selected.background") 
                } else { 
                    $itemBgColor = $bgColor 
                }
                
                # Draw item background
                $this._private_buffer.FillRect(1, $contentY + $i, $this.Width - 2, 1, ' ', @{ BG = $itemBgColor })
                
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
