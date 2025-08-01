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

# ===== CLASS: Table =====
# Module: advanced-data-components
# Dependencies: UIElement, TuiCell
# Purpose: High-performance data grid with virtual scrolling
class Table : UIElement {
    [List[PSObject]]$Items
    [List[string]]$Columns
    [hashtable]$ColumnWidths
    [int]$SelectedIndex = -1
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$AllowSelection = $true
    [scriptblock]$OnSelectionChanged
    hidden [int]$_scrollOffset = 0
    hidden [int]$_horizontalScroll = 0
    
    # String formatting cache for performance
    hidden [string[]]$_displayStringCache = @()
    hidden [bool]$_cacheValid = $false
    hidden [int]$_lastItemsCount = 0
    
    Table([string]$name) : base($name) {
        $this.IsFocusable = $true
        $this.TabIndex = 0
        $this.Items = [List[PSObject]]::new()
        $this.Columns = [List[string]]::new()
        $this.ColumnWidths = @{}
        $this.Width = 80
        $this.Height = 20
    }
    
    [void] SetColumns([string[]]$columns) {
        $this.Columns.Clear()
        foreach ($col in $columns) {
            $this.Columns.Add($col)
            if (-not $this.ColumnWidths.ContainsKey($col)) {
                $this.ColumnWidths[$col] = 15  # Default width
            }
        }
        $this._InvalidateCache()
    }
    
    [void] SetItems([object[]]$items) {
        $this.Items.Clear()
        foreach ($item in $items) {
            $this.Items.Add($item)
        }
        $this._InvalidateCache()
        $this.RequestRedraw()
    }
    
    [void] AddItem([object]$item) {
        $this.Items.Add($item)
        $this._InvalidateCache()
        $this.RequestRedraw()
    }
    
    [void] ClearItems() {
        $this.Items.Clear()
        $this._InvalidateCache()
        $this.SelectedIndex = -1
        $this.RequestRedraw()
    }
    
    [void] AutoSizeColumns() {
        foreach ($col in $this.Columns) {
            $maxWidth = $col.Length
            
            foreach ($item in $this.Items) {
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $len = $val.ToString().Length
                        if ($len -gt $maxWidth) {
                            $maxWidth = $len
                        }
                    }
                }
            }
            
            $this.ColumnWidths[$col] = [Math]::Min($maxWidth + 2, 30)  # Cap at 30
        }
        $this._InvalidateCache()
    }
    
    hidden [void] _InvalidateCache() {
        $this._cacheValid = $false
        $this._displayStringCache = @()
    }
    
    hidden [void] _EnsureDisplayCache() {
        if ($this._cacheValid -and $this._lastItemsCount -eq $this.Items.Count) {
            return  # Cache is valid
        }
        
        # Rebuild cache
        $this._displayStringCache = @()
        
        foreach ($item in $this.Items) {
            $formattedRow = ""
            $x = 0
            foreach ($col in $this.Columns) {
                $val = ""
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -eq $val) { $val = "" }
                    else { $val = $val.ToString() }
                }
                
                $width = $this.ColumnWidths[$col]
                if ($val.Length -gt $width) {
                    $val = $val.Substring(0, [Math]::Max(1, $width - 3)) + "..."
                }
                
                $formattedRow += $val.PadRight($width) + " "
            }
            
            $this._displayStringCache += $formattedRow
        }
        
        $this._cacheValid = $true
        $this._lastItemsCount = $this.Items.Count
    }
    
    [void] OnRender() {
        if (-not $this.Visible -or $null -eq $this._private_buffer) { return }
        
        try {
            $bgColor = Get-ThemeColor "panel.background"
            $fgColor = Get-ThemeColor "label.foreground"
            if ($this.IsFocused) { 
                $borderColor = Get-ThemeColor "panel.border.focused"
            } else { 
                $borderColor = Get-ThemeColor "panel.border"
            }
            $headerBg = Get-ThemeColor "list.header.background"
            $selectedBg = Get-ThemeColor "list.selected.background"
            
            $this._private_buffer.Clear([TuiCell]::new(' ', $fgColor, $bgColor))
            
            $contentX = 0
            $contentY = 0
            $contentWidth = $this.Width
            $contentHeight = $this.Height
            
            # Draw border if enabled
            if ($this.ShowBorder) {
                Write-TuiBox -Buffer $this._private_buffer -X 0 -Y 0 `
                    -Width $this.Width -Height $this.Height `
                    -Style @{ BorderFG = $borderColor; BG = $bgColor; BorderStyle = "Single" }
                
                $contentX = 1
                $contentY = 1
                $contentWidth = $this.Width - 2
                $contentHeight = $this.Height - 2
            }
            
            $currentY = $contentY
            $dataStartY = $contentY
            
            # Draw header if enabled
            if ($this.ShowHeader -and $this.Columns.Count -gt 0) {
                $this.DrawHeader($contentX, $currentY, $contentWidth, $headerBg)
                $currentY++
                $dataStartY++
                
                # Draw separator line
                for ($x = $contentX; $x -lt $contentX + $contentWidth; $x++) {
                    $this._private_buffer.SetCell($x, $currentY, [TuiCell]::new('-', $borderColor, $bgColor))
                }
                $currentY++
                $dataStartY++
            }
            
            # Calculate visible rows
            $visibleRows = $contentHeight - ($dataStartY - $contentY)
            if ($visibleRows -le 0) { return }
            
            # Adjust scroll offset to keep selection visible
            if ($this.AllowSelection -and $this.SelectedIndex -ge 0) {
                if ($this.SelectedIndex -lt $this._scrollOffset) {
                    $this._scrollOffset = $this.SelectedIndex
                }
                elseif ($this.SelectedIndex -ge $this._scrollOffset + $visibleRows) {
                    $this._scrollOffset = $this.SelectedIndex - $visibleRows + 1
                }
            }
            
            # Draw data rows
            for ($i = 0; $i -lt $visibleRows; $i++) {
                $itemIndex = $i + $this._scrollOffset
                if ($itemIndex -ge $this.Items.Count) { break }
                
                $item = $this.Items[$itemIndex]
                $rowBg = $bgColor
                $rowFg = $fgColor
                
                if ($this.AllowSelection -and $itemIndex -eq $this.SelectedIndex) {
                    $rowBg = $selectedBg
                    $rowFg = Get-ThemeColor "list.selected.foreground"
                }
                
                $this.DrawRow($item, $contentX, $currentY, $contentWidth, $rowFg, $rowBg)
                $currentY++
            }
            
            # Draw scrollbar if needed
            if ($this.Items.Count -gt $visibleRows) {
                $this.DrawScrollbar($contentX + $contentWidth - 1, $dataStartY, $visibleRows)
            }
        }
        catch {}
    }
    
    hidden [void] DrawHeader([int]$x, [int]$y, [int]$maxWidth, [string]$headerBg) {
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    $headerText = $col
                    if ($headerText.Length -gt $visibleWidth) {
                        $headerText = $headerText.Substring(0, $visibleWidth - 1) + ">"
                    }
                    else {
                        $headerText = $headerText.PadRight($visibleWidth)
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $headerText -Style @{ FG = Get-ThemeColor "list.header.foreground"; BG = $headerBg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawRow([PSObject]$item, [int]$x, [int]$y, [int]$maxWidth, [string]$fg, [string]$bg) {
        # Clear row first
        for ($i = 0; $i -lt $maxWidth; $i++) {
            $this._private_buffer.SetCell($x + $i, $y, [TuiCell]::new(' ', $fg, $bg))
        }
        
        $currentX = $x - $this._horizontalScroll
        
        foreach ($col in $this.Columns) {
            $colWidth = $this.ColumnWidths[$col]
            
            if ($currentX + $colWidth -gt $x) {
                $value = ""
                if ($item.PSObject.Properties[$col]) {
                    $val = $item.$col
                    if ($null -ne $val) {
                        $value = $val.ToString()
                    }
                }
                
                $visibleStart = [Math]::Max(0, $x - $currentX)
                $visibleWidth = [Math]::Min($colWidth - $visibleStart, $maxWidth - ($currentX - $x))
                
                if ($visibleWidth -gt 0) {
                    if ($value.Length -gt $visibleWidth - 1) {
                        $value = $value.Substring(0, $visibleWidth - 2) + ".."
                    }
                    
                    $drawX = [Math]::Max($x, $currentX)
                    Write-TuiText -Buffer $this._private_buffer -X $drawX -Y $y -Text $value -Style @{ FG = $fg; BG = $bg }
                }
            }
            
            $currentX += $colWidth
            if ($currentX -ge $x + $maxWidth) { break }
        }
    }
    
    hidden [void] DrawScrollbar([int]$x, [int]$y, [int]$height) {
        $scrollbarHeight = [Math]::Max(1, [int]($height * $height / $this.Items.Count))
        $scrollbarPos = [int](($height - $scrollbarHeight) * $this._scrollOffset / ($this.Items.Count - $height))
        
        $scrollbarColor = Get-ThemeColor "list.scrollbar"
        $bgColor = Get-ThemeColor "panel.background"
        
        for ($i = 0; $i -lt $height; $i++) {
            $char = '│'
            if ($i -ge $scrollbarPos -and $i -lt $scrollbarPos + $scrollbarHeight) { $char = '█' }
            $this._private_buffer.SetCell($x, $y + $i, [TuiCell]::new($char, $scrollbarColor, $bgColor))
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        if ($null -eq $key -or -not $this.AllowSelection) { return $false }
        
        $handled = $true
        $oldSelection = $this.SelectedIndex
        
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
                $pageSize = $this.Height - 4  # Account for border and header
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $pageSize)
            }
            ([ConsoleKey]::PageDown) {
                $pageSize = $this.Height - 4
                $this.SelectedIndex = [Math]::Min($this.Items.Count - 1, $this.SelectedIndex + $pageSize)
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this._horizontalScroll -gt 0) {
                    $this._horizontalScroll = [Math]::Max(0, $this._horizontalScroll - 5)
                }
            }
            ([ConsoleKey]::RightArrow) {
                $totalWidth = 0
                foreach ($col in $this.Columns) {
                    $totalWidth += $this.ColumnWidths[$col]
                }
                $maxScroll = [Math]::Max(0, $totalWidth - $this.Width + 2)
                $this._horizontalScroll = [Math]::Min($maxScroll, $this._horizontalScroll + 5)
            }
            default {
                $handled = $false
            }
        }
        
        if ($handled) {
            if ($oldSelection -ne $this.SelectedIndex -and $this.OnSelectionChanged) {
                try { & $this.OnSelectionChanged $this $this.SelectedIndex } catch {}
            }
            $this.RequestRedraw()
        }
        
        return $handled
    }
}

#endregion Advanced Components

#region Panel Components

#<!-- END_PAGE: ACO.010 -->
