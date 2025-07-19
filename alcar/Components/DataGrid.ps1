# DataGrid Component - Advanced tabular data display with scrolling and selection

class DataColumn {
    [string]$Name
    [string]$Property
    [int]$Width
    [string]$Align = "Left"  # Left, Right, Center
    [scriptblock]$Format = $null
    [bool]$Sortable = $true
    
    DataColumn([string]$name, [string]$property, [int]$width) {
        $this.Name = $name
        $this.Property = $property
        $this.Width = $width
    }
}

class DataGrid : Component {
    [System.Collections.ArrayList]$Columns
    [System.Collections.ArrayList]$Data
    [int]$SelectedIndex = 0
    [int]$ScrollOffsetX = 0
    [int]$ScrollOffsetY = 0
    [bool]$ShowHeader = $true
    [bool]$ShowBorder = $true
    [bool]$ShowRowNumbers = $false
    [bool]$AllowSort = $true
    [string]$SortColumn = ""
    [bool]$SortAscending = $true
    
    # Visual settings
    [string]$HeaderColor = ""
    [string]$SelectedColor = ""
    [string]$AlternateRowColor = ""
    [bool]$AlternateRows = $true
    
    # Performance optimization
    hidden [hashtable]$_renderCache = @{}
    hidden [int]$_visibleRows = 0
    hidden [int]$_visibleColumns = 0
    
    DataGrid([string]$name) : base($name) {
        $this.Columns = [System.Collections.ArrayList]::new()
        $this.Data = [System.Collections.ArrayList]::new()
        $this.IsFocusable = $true
    }
    
    [void] AddColumn([DataColumn]$column) {
        $this.Columns.Add($column) | Out-Null
        $this.InvalidateCache()
    }
    
    [void] AddColumns([DataColumn[]]$columns) {
        foreach ($col in $columns) {
            $this.Columns.Add($col) | Out-Null
        }
        $this.InvalidateCache()
    }
    
    [void] SetData([array]$data) {
        $this.Data.Clear()
        if ($data) {
            $this.Data.AddRange($data)
        }
        $this.SelectedIndex = if ($data.Count -gt 0) { 0 } else { -1 }
        $this.ScrollOffsetY = 0
        $this.InvalidateCache()
        $this.Invalidate()
    }
    
    [object] GetSelectedItem() {
        if ($this.SelectedIndex -ge 0 -and $this.SelectedIndex -lt $this.Data.Count) {
            return $this.Data[$this.SelectedIndex]
        }
        return $null
    }
    
    [void] Sort([string]$columnProperty) {
        if (-not $this.AllowSort) { return }
        
        # Toggle sort direction if same column
        if ($this.SortColumn -eq $columnProperty) {
            $this.SortAscending = -not $this.SortAscending
        } else {
            $this.SortColumn = $columnProperty
            $this.SortAscending = $true
        }
        
        # Perform sort
        $sorted = if ($this.SortAscending) {
            $this.Data | Sort-Object -Property $columnProperty
        } else {
            $this.Data | Sort-Object -Property $columnProperty -Descending
        }
        
        $this.Data.Clear()
        $this.Data.AddRange($sorted)
        $this.InvalidateCache()
        $this.Invalidate()
    }
    
    [void] OnRender([object]$buffer) {
        # Calculate visible area
        $this._visibleRows = $this.Height - (if ($this.ShowBorder) { 2 } else { 0 }) - (if ($this.ShowHeader) { 1 } else { 0 })
        
        $currentY = 0
        
        # Draw border top
        if ($this.ShowBorder) {
            $this.DrawBorderLine($buffer, 0, $currentY, "top")
            $currentY++
        }
        
        # Draw header
        if ($this.ShowHeader) {
            $this.DrawHeader($buffer, 0, $currentY)
            $currentY++
        }
        
        # Draw data rows
        $this.DrawDataRows($buffer, 0, $currentY)
        
        # Draw border bottom
        if ($this.ShowBorder) {
            $this.DrawBorderLine($buffer, 0, $this.Height - 1, "bottom")
        }
        
        # Draw scrollbars if needed
        $this.DrawScrollbars($buffer)
    }
    
    [void] DrawHeader([object]$buffer, [int]$x, [int]$y) {
        $headerColor = if ($this.HeaderColor) { $this.HeaderColor } else { [VT]::RGB(150, 150, 200) }
        $line = ""
        
        # Row number column
        if ($this.ShowRowNumbers) {
            $line += " # ".PadRight(5)
            if ($this.ShowBorder) {
                $line += "│ "
            }
        }
        
        # Data columns
        $colX = 0
        foreach ($col in $this.Columns) {
            if ($colX -ge $this.ScrollOffsetX -and $colX -lt $this.ScrollOffsetX + $this._visibleColumns) {
                $headerText = $col.Name
                
                # Add sort indicator
                if ($this.AllowSort -and $col.Property -eq $this.SortColumn) {
                    $sortChar = if ($this.SortAscending) { "▲" } else { "▼" }
                    $headerText = $headerText.PadRight($col.Width - 2) + " $sortChar"
                } else {
                    $headerText = $headerText.PadRight($col.Width)
                }
                
                $line += $headerText
                
                # Column separator
                if ($this.Columns.IndexOf($col) -lt $this.Columns.Count - 1) {
                    $line += " │ "
                }
            }
            $colX++
        }
        
        # Draw the header line
        $this.DrawText($buffer, $x, $y, $headerColor + [VT]::Bold() + $line + [VT]::Reset())
        
        # Draw separator line if border enabled
        if ($this.ShowBorder) {
            $sepLine = ""
            if ($this.ShowRowNumbers) {
                $sepLine += "─" * 5 + "┼─"
            }
            
            foreach ($col in $this.Columns) {
                $sepLine += "─" * $col.Width
                if ($this.Columns.IndexOf($col) -lt $this.Columns.Count - 1) {
                    $sepLine += "─┼─"
                }
            }
            
            $this.DrawText($buffer, $x, $y + 1, [VT]::RGB(80, 80, 100) + $sepLine + [VT]::Reset())
        }
    }
    
    [void] DrawDataRows([object]$buffer, [int]$x, [int]$startY) {
        $endIndex = [Math]::Min($this.ScrollOffsetY + $this._visibleRows, $this.Data.Count)
        
        for ($i = $this.ScrollOffsetY; $i -lt $endIndex; $i++) {
            $row = $this.Data[$i]
            $y = $startY + ($i - $this.ScrollOffsetY)
            $isSelected = ($i -eq $this.SelectedIndex)
            
            # Row background
            if ($isSelected) {
                $bgColor = if ($this.SelectedColor) { $this.SelectedColor } else { [VT]::RGBBG(40, 40, 80) }
                $this.DrawText($buffer, $x, $y, $bgColor + (" " * $this.Width) + [VT]::Reset())
            } elseif ($this.AlternateRows -and ($i % 2 -eq 1)) {
                $altColor = if ($this.AlternateRowColor) { $this.AlternateRowColor } else { [VT]::RGBBG(25, 25, 30) }
                $this.DrawText($buffer, $x, $y, $altColor + (" " * $this.Width) + [VT]::Reset())
            }
            
            # Build row content
            $line = ""
            
            # Row number
            if ($this.ShowRowNumbers) {
                $rowNum = ($i + 1).ToString().PadLeft(4)
                $line += $rowNum + " "
                if ($this.ShowBorder) {
                    $line += "│ "
                }
            }
            
            # Data columns
            foreach ($col in $this.Columns) {
                $value = ""
                
                try {
                    # Get property value
                    $rawValue = $row.($col.Property)
                    
                    # Format value
                    if ($col.Format) {
                        $value = & $col.Format $rawValue
                    } else {
                        $value = if ($null -ne $rawValue) { $rawValue.ToString() } else { "" }
                    }
                    
                    # Align and truncate
                    if ($value.Length -gt $col.Width) {
                        $value = $value.Substring(0, $col.Width - 3) + "..."
                    }
                    
                    $value = switch ($col.Align) {
                        "Right" { $value.PadLeft($col.Width) }
                        "Center" { 
                            $padding = $col.Width - $value.Length
                            $leftPad = [int]($padding / 2)
                            $rightPad = $padding - $leftPad
                            (" " * $leftPad) + $value + (" " * $rightPad)
                        }
                        default { $value.PadRight($col.Width) }
                    }
                } catch {
                    $value = "ERR".PadRight($col.Width)
                }
                
                $line += $value
                
                # Column separator
                if ($this.Columns.IndexOf($col) -lt $this.Columns.Count - 1) {
                    $line += " │ "
                }
            }
            
            # Draw the row
            $textColor = if ($isSelected) { [VT]::RGB(255, 255, 255) } else { [VT]::RGB(200, 200, 200) }
            $this.DrawText($buffer, $x, $y, $textColor + $line + [VT]::Reset())
        }
    }
    
    [void] DrawBorderLine([object]$buffer, [int]$x, [int]$y, [string]$position) {
        $borderColor = [VT]::RGB(80, 80, 120)
        $line = ""
        
        switch ($position) {
            "top" {
                $line = "┌" + ("─" * ($this.Width - 2)) + "┐"
            }
            "bottom" {
                $line = "└" + ("─" * ($this.Width - 2)) + "┘"
            }
        }
        
        $this.DrawText($buffer, $x, $y, $borderColor + $line + [VT]::Reset())
    }
    
    [void] DrawScrollbars([object]$buffer) {
        # Vertical scrollbar
        if ($this.Data.Count -gt $this._visibleRows) {
            $scrollbarX = $this.Width - 1
            $scrollbarHeight = $this._visibleRows
            $scrollbarY = if ($this.ShowBorder) { 1 } else { 0 }
            if ($this.ShowHeader) { $scrollbarY++ }
            
            $thumbSize = [Math]::Max(1, [int]($scrollbarHeight * $scrollbarHeight / $this.Data.Count))
            $thumbPos = [int](($scrollbarHeight - $thumbSize) * $this.ScrollOffsetY / ($this.Data.Count - $this._visibleRows))
            
            for ($i = 0; $i -lt $scrollbarHeight; $i++) {
                $char = if ($i -ge $thumbPos -and $i -lt ($thumbPos + $thumbSize)) { "█" } else { "░" }
                $this.DrawText($buffer, $scrollbarX, $scrollbarY + $i, 
                              [VT]::RGB(60, 60, 80) + $char + [VT]::Reset())
            }
        }
    }
    
    [void] DrawText([object]$buffer, [int]$x, [int]$y, [string]$text) {
        # Placeholder for alcar buffer integration
    }
    
    [void] InvalidateCache() {
        $this._renderCache.Clear()
        $this._needsRedraw = $true
    }
    
    [void] EnsureVisible() {
        # Vertical scrolling
        if ($this.SelectedIndex -lt $this.ScrollOffsetY) {
            $this.ScrollOffsetY = $this.SelectedIndex
        } elseif ($this.SelectedIndex -ge $this.ScrollOffsetY + $this._visibleRows) {
            $this.ScrollOffsetY = $this.SelectedIndex - $this._visibleRows + 1
        }
    }
    
    [bool] HandleInput([System.ConsoleKeyInfo]$key) {
        $handled = $false
        $oldIndex = $this.SelectedIndex
        
        switch ($key.Key) {
            ([ConsoleKey]::UpArrow) {
                if ($this.SelectedIndex -gt 0) {
                    $this.SelectedIndex--
                    $handled = $true
                }
            }
            ([ConsoleKey]::DownArrow) {
                if ($this.SelectedIndex -lt $this.Data.Count - 1) {
                    $this.SelectedIndex++
                    $handled = $true
                }
            }
            ([ConsoleKey]::PageUp) {
                $this.SelectedIndex = [Math]::Max(0, $this.SelectedIndex - $this._visibleRows)
                $this.ScrollOffsetY = [Math]::Max(0, $this.ScrollOffsetY - $this._visibleRows)
                $handled = $true
            }
            ([ConsoleKey]::PageDown) {
                $this.SelectedIndex = [Math]::Min($this.Data.Count - 1, $this.SelectedIndex + $this._visibleRows)
                $handled = $true
            }
            ([ConsoleKey]::Home) {
                $this.SelectedIndex = 0
                $this.ScrollOffsetY = 0
                $handled = $true
            }
            ([ConsoleKey]::End) {
                $this.SelectedIndex = $this.Data.Count - 1
                $handled = $true
            }
            ([ConsoleKey]::LeftArrow) {
                if ($this.ScrollOffsetX -gt 0) {
                    $this.ScrollOffsetX--
                    $handled = $true
                }
            }
            ([ConsoleKey]::RightArrow) {
                # Calculate max horizontal scroll
                $totalWidth = 0
                foreach ($col in $this.Columns) {
                    $totalWidth += $col.Width + 3  # Include separators
                }
                if ($this.ScrollOffsetX -lt $totalWidth - $this.Width) {
                    $this.ScrollOffsetX++
                    $handled = $true
                }
            }
        }
        
        # Handle column sorting with number keys
        if ($key.KeyChar -ge '1' -and $key.KeyChar -le '9') {
            $colIndex = [int]($key.KeyChar.ToString()) - 1
            if ($colIndex -lt $this.Columns.Count) {
                $col = $this.Columns[$colIndex]
                if ($col.Sortable) {
                    $this.Sort($col.Property)
                    $handled = $true
                }
            }
        }
        
        if ($handled) {
            $this.EnsureVisible()
            $this.Invalidate()
        }
        
        return $handled
    }
}