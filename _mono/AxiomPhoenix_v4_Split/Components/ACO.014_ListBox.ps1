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
    
    # PERFORMANCE OPTIMIZATIONS
    hidden [hashtable]$_itemRenderCache = @{}
    hidden [int]$_firstVisibleIndex = 0
    hidden [int]$_lastVisibleIndex = 0
    hidden [int]$_lastSelectedIndex = -1
    hidden [int]$_lastScrollOffset = -1
    hidden [int]$_cacheVersion = 0

    ListBox([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Items = [List[object]]::new()
        $this.Width = 30
        $this.Height = 10
    }

    [void] AddItem([object]$item) {
        # Handle empty/null items
        if ($null -eq $item -or ($item -is [string] -and [string]::IsNullOrEmpty($item))) {
            $this.Items.Add(" ")  # Use space instead of empty
        } else {
            $this.Items.Add($item)
        }
        $this._itemRenderCache.Clear()
        $this._cacheVersion = $this.Items.Count
        if ($this.SelectedIndex -eq -1 -and $this.Items.Count -eq 1) {
            $this.SelectedIndex = 0
        }
        Request-OptimizedRedraw -Source "ListBox:$($this.Name)"
    }

    [void] ClearItems() {
        $this.Items.Clear()
        $this._itemRenderCache.Clear()
        $this._cacheVersion = 0
        $this.SelectedIndex = -1
        $this.ScrollOffset = 0
        Request-OptimizedRedraw -Source "ListBox:$($this.Name)"
    }

    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        # Get background color using the effective color method from the base class
        $bgColor = $this.GetEffectiveBackgroundColor()
        
        # Clear buffer with background color
        $this._private_buffer.Clear([TuiCell]::new(' ', $bgColor, $bgColor))
        
        # Draw border if enabled
        if ($this.HasBorder) {
            $borderColor = $this.GetEffectiveBorderColor()
            
            $style = @{ 
                BorderFG = $borderColor
                BG = $bgColor
                BorderStyle = $this.BorderStyle
                Title = $this.Title 
            }
            
            Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 -Width $this.Width -Height $this.Height -Style $style
        }
            
        # Calculate visible area
        $contentY = 1
        $contentHeight = $this.Height - 2
        $contentX = 1
        $contentWidth = $this.Width - 2
        
        if (-not $this.HasBorder) {
            $contentY = 0
            $contentHeight = $this.Height
            $contentX = 0
            $contentWidth = $this.Width
        }
            
        # Ensure selected item is visible
        $this.EnsureVisible($this.SelectedIndex)
            
        # PERFORMANCE: Calculate visible range and check for changes
        $this._firstVisibleIndex = $this.ScrollOffset
        $this._lastVisibleIndex = [Math]::Min(
            $this.ScrollOffset + $contentHeight - 1,
            $this.Items.Count - 1
        )
        
        $selectionChanged = ($this._lastSelectedIndex -ne $this.SelectedIndex)
        $scrollChanged = ($this._lastScrollOffset -ne $this.ScrollOffset)
        
        # Clear cache if structure changed
        if ($this.Items.Count -ne $this._cacheVersion) {
            $this._itemRenderCache.Clear()
            $this._cacheVersion = $this.Items.Count
        }
        
        # Draw items with optimized rendering
        $maxIndex = $this.Items.Count
        for ($i = 0; $i -lt $contentHeight; $i++) {
            $itemIndex = $i + $this.ScrollOffset
            if ($itemIndex -ge $maxIndex) { break }
            
            # PERFORMANCE: Check if this item needs redrawing
            $needsRedraw = $scrollChanged -or $this._needs_redraw -or 
                          ($itemIndex -eq $this.SelectedIndex -and $selectionChanged) -or
                          ($itemIndex -eq $this._lastSelectedIndex -and $selectionChanged) -or
                          (-not $this._itemRenderCache.ContainsKey($itemIndex))
            
            if ($needsRedraw) {
                $this.RenderItem($itemIndex, $i, $contentX, $contentY, $contentWidth, $bgColor)
            } else {
                # Use cached rendering
                $cachedInfo = $this._itemRenderCache[$itemIndex]
                if ($cachedInfo) {
                    # Apply cached render to buffer
                    $this.ApplyCachedItem($cachedInfo, $contentX, $contentY + $i, $contentWidth)
                }
            }
        }
        
        # Update tracking variables
        $this._lastSelectedIndex = $this.SelectedIndex
        $this._lastScrollOffset = $this.ScrollOffset
            
        # Draw scrollbar if needed
        if ($this.Items.Count -gt $contentHeight) {
            $scrollbarX = 0
            if ($this.HasBorder) {
                $scrollbarX = $this.Width - 2
            } else {
                $scrollbarX = $this.Width - 1
            }
            
            $scrollbarHeight = $contentHeight
            $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Items.Count))
            
            $thumbPos = 0
            if ($this.Items.Count -gt $scrollbarHeight) {
                $thumbPos = [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffset / ($this.Items.Count - $scrollbarHeight))
            }
            
            $scrollbarColor = Get-ThemeColor "list.scrollbar" "#666666"
            
            for ($j = 0; $j -lt $scrollbarHeight; $j++) {
                $char = '│'
                if ($j -ge $thumbPos -and $j -lt ($thumbPos + $thumbSize)) {
                    $char = '█'
                }
                $cell = [TuiCell]::new($char, $scrollbarColor, $bgColor)
                $this._private_buffer.SetCell($scrollbarX, $contentY + $j, $cell)
            }
        }
        
        $this._needs_redraw = $false
    }

    # PERFORMANCE: Optimized item rendering with caching
    [void] RenderItem([int]$itemIndex, [int]$displayIndex, [int]$contentX, [int]$contentY, [int]$contentWidth, [string]$bgColor) {
        $item = $this.Items[$itemIndex]
        $itemText = ""
        
        if ($item -is [string]) {
            $itemText = $item
            if ([string]::IsNullOrEmpty($item)) { $itemText = " " }
        } else {
            $itemText = " "
            if ($null -ne $item) { $itemText = $item.ToString() }
        }
        
        if ($itemText.Length -gt $contentWidth) {
            $maxLen = $contentWidth - 3
            if ($maxLen -gt 0) {
                $itemText = $itemText.Substring(0, $maxLen) + "..."
            } else {
                $itemText = "..."
            }
        }
        
        $isSelected = ($itemIndex -eq $this.SelectedIndex)
        
        # Determine colors
        [string]$fgColor = ""
        [string]$itemBgColor = ""
        
        if ($isSelected -and $this.IsFocused) {
            if ($this.SelectedForegroundColor) {
                $fgColor = $this.SelectedForegroundColor
            } else {
                $fgColor = Get-ThemeColor "list.selected.foreground" "#ffffff"
            }
            
            if ($this.SelectedBackgroundColor) {
                $itemBgColor = $this.SelectedBackgroundColor
            } else {
                $itemBgColor = Get-ThemeColor "list.selected.background" "#007acc"
            }
        } else {
            if ($this.ItemForegroundColor) {
                $fgColor = $this.ItemForegroundColor
            } else {
                $fgColor = Get-ThemeColor "list.foreground" "#d4d4d4"
            }
            $itemBgColor = $bgColor
        }
        
        # Cache render info
        $this._itemRenderCache[$itemIndex] = @{
            Text = $itemText
            FgColor = $fgColor
            BgColor = $itemBgColor
            IsSelected = $isSelected
            IsFocused = $this.IsFocused
        }
        
        # Draw selection background
        if ($isSelected -and $this.IsFocused) {
            for ($x = $contentX; $x -lt ($contentX + $contentWidth); $x++) {
                $cell = [TuiCell]::new(' ', $fgColor, $itemBgColor)
                $this._private_buffer.SetCell($x, $contentY + $displayIndex, $cell)
            }
        }
        
        # Draw item text
        $style = @{ FG = $fgColor; BG = $itemBgColor }
        Write-TuiText -Buffer $this._private_buffer -X $contentX -Y ($contentY + $displayIndex) -Text $itemText -Style $style
    }
    
    [void] ApplyCachedItem([hashtable]$cachedInfo, [int]$x, [int]$y, [int]$width) {
        # Apply cached colors and text (cache already validated)
        
        # Apply cached colors and text
        if ($cachedInfo.IsSelected -and $cachedInfo.IsFocused) {
            for ($cx = $x; $cx -lt ($x + $width); $cx++) {
                $cell = [TuiCell]::new(' ', $cachedInfo.FgColor, $cachedInfo.BgColor)
                $this._private_buffer.SetCell($cx, $y, $cell)
            }
        }
        
        $style = @{ FG = $cachedInfo.FgColor; BG = $cachedInfo.BgColor }
        Write-TuiText -Buffer $this._private_buffer -X $x -Y $y -Text $cachedInfo.Text -Style $style
    }


    # FIXED: Add OnFocus and OnBlur for visual feedback
    [void] OnFocus() {
        ([UIElement]$this).OnFocus()
        $this.BorderColor = (Get-ThemeColor "input.focused.border" "#00d4ff")
        Request-OptimizedRedraw -Source "ListBox:$($this.Name)"
    }

    [void] OnBlur() {
        ([UIElement]$this).OnBlur()
        $this.BorderColor = (Get-ThemeColor "Panel.Border" "#666666")
        Request-OptimizedRedraw -Source "ListBox:$($this.Name)"
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
                $borderOffset = 0
                if ($this.HasBorder) { $borderOffset = 2 }
                $pageSize = $this.Height - $borderOffset
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $borderOffset = 0
                if ($this.HasBorder) { $borderOffset = 2 }
                $pageSize = $this.Height - $borderOffset
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            Request-OptimizedRedraw -Source "ListBox:$($this.Name)"
            
            # Trigger SelectedIndexChanged event if index changed
            if ($oldIndex -ne $this.SelectedIndex -and $this.SelectedIndexChanged) {
                $this.SelectedIndexChanged.Invoke($this, $this.SelectedIndex)
            }
        }
        
        return $handled
    }

    [void] EnsureVisible([int]$index) {
        if ($index -lt 0 -or $index -ge $this.Items.Count) { return }
        
        $borderOffset = 0
        if ($this.HasBorder) { $borderOffset = 2 }
        $visibleHeight = $this.Height - $borderOffset
        
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